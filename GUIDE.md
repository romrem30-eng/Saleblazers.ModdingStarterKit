# Saleblazers Modding Guide (Unity 6 / IL2CPP)

Developer reference and walkthrough for creating mods for Saleblazers.

---

## Table of Contents
1. [Tech Stack & Architecture](#1-tech-stack--architecture)
2. [Project Setup in 2 Minutes](#2-project-setup-in-2-minutes)
3. [Inspecting Game Code (ILSpy / dnSpy)](#3-inspecting-game-code-ilspy--dnspy)
4. [IL2CPP Specifics You Need to Know](#4-il2cpp-specifics-you-need-to-know)
   - [Registering Custom Types (ClassInjector)](#registering-custom-types-classinjector)
   - [Il2Cpp Collections vs System Collections](#il2cpp-collections-vs-system-collections)
5. [Plugin Lifecycle & Config Files](#5-plugin-lifecycle--config-files)
6. [Hooking Game Logic with Harmony](#6-hooking-game-logic-with-harmony)
7. [Building UI at Runtime (uGUI + TextMeshPro)](#7-building-ui-at-runtime-ugui--textmeshpro)
8. [Cursor & Camera Lock Fix](#8-cursor--camera-lock-fix)
9. [Multiplayer & Co-op Rules](#9-multiplayer--co-op-rules)
10. [In-Game Mod Manager & Modded Verification](#10-in-game-mod-manager--modded-verification)

---

## 1. Tech Stack & Architecture

Saleblazers runs on:
* **Engine:** Unity 6 (`6000.3.18.6209205`)
* **Scripting Backend:** IL2CPP x64 (compiled to native C++ machine code)
* **Mod Loader:** BepInEx 6 (IL2CPP build) + Il2CppInterop
* **Target Framework:** .NET 6.0 (`net6.0`)

Standard BepInEx 5 (Mono) does not work here. BepInEx 6 generates managed interop wrappers around native IL2CPP classes. You write standard C# code and interact with game objects as if they were regular managed types.

---

## 2. Project Setup in 2 Minutes

### Requirements
* .NET 6.0 SDK or newer
* Visual Studio 2022, Rider, or VS Code

### Using the Template
Clone or download [Saleblazers.ModdingStarterKit](https://github.com/romrem30-eng/Saleblazers.ModdingStarterKit).

Inside `templates/ExampleMod`, you have a pre-configured `.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <AssemblyName>MyMod</AssemblyName>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
    <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>
    <OutputPath>bin\$(Configuration)\</OutputPath>
  </PropertyGroup>

  <!-- Core BepInEx 6 references -->
  <ItemGroup>
    <Reference Include="BepInEx.Core" HintPath="..\..\BepInEx\core\BepInEx.Core.dll" Private="false" />
    <Reference Include="BepInEx.Unity.IL2CPP" HintPath="..\..\BepInEx\core\BepInEx.Unity.IL2CPP.dll" Private="false" />
    <Reference Include="0Harmony" HintPath="..\..\BepInEx\core\0Harmony.dll" Private="false" />
    <Reference Include="Il2CppInterop.Runtime" HintPath="..\..\BepInEx\core\Il2CppInterop.Runtime.dll" Private="false" />
    <Reference Include="Il2Cppmscorlib" HintPath="..\..\BepInEx\interop\Il2Cppmscorlib.dll" Private="false" />
  </ItemGroup>

  <!-- Game and Unity wrappers -->
  <ItemGroup>
    <Reference Include="Assembly-CSharp" HintPath="..\..\BepInEx\interop\Assembly-CSharp.dll" Private="false" />
    <Reference Include="UnityEngine" HintPath="..\..\BepInEx\interop\UnityEngine.dll" Private="false" />
    <Reference Include="UnityEngine.CoreModule" HintPath="..\..\BepInEx\interop\UnityEngine.CoreModule.dll" Private="false" />
    <Reference Include="UnityEngine.UI" HintPath="..\..\BepInEx\interop\UnityEngine.UI.dll" Private="false" />
    <Reference Include="Unity.TextMeshPro" HintPath="..\..\BepInEx\interop\Unity.TextMeshPro.dll" Private="false" />
  </ItemGroup>
</Project>
```

Build your plugin:
```bash
dotnet build -c Release
```
Then copy `bin/Release/MyMod.dll` into your game's `Saleblazers/Default/BepInEx/plugins/` folder.

---

## 3. Inspecting Game Code (ILSpy / dnSpy)

All game classes, methods, and structures are pre-dumped in `BepInEx/interop/Assembly-CSharp.dll`.

Open this DLL in [ILSpy](https://github.com/icsharpcode/ILSpy) or [dnSpyEx](https://github.com/dnSpyEx/dnSpy).

Key classes to look into:
* `HeroPlayerCharacter`: The player pawn. Controls health, movement, camera look, attacks, interaction raycasts.
* `HRGameInstance`: Top-level game instance manager. Scene switches, active world state, mouse cursor requests.
* `PlayerInventory` & `ItemData`: Inventory slots, container interactions, item stats, prices, attributes.
* `CraftingManager` & `CraftingRecipe`: Crafting stations, recipe definitions, cooking pot inputs/outputs.
* `WorldManager`: World streaming, chunk loading, placed structures.

---

## 4. IL2CPP Specifics You Need to Know

### Registering Custom Types (ClassInjector)
In IL2CPP, Unity's unmanaged engine code needs to know about any custom `MonoBehaviour` you create. If you do not register it before calling `AddComponent<T>()`, you will get a runtime error.

Two rules for custom MonoBehaviours:
1. Include an `IntPtr` constructor.
2. Call `ClassInjector.RegisterTypeInIl2Cpp<T>()` in your plugin's `Load()` method.

```csharp
using System;
using Il2CppInterop.Runtime.Injection;
using UnityEngine;

public class MyModRunner : MonoBehaviour
{
    // Required constructor for IL2CPP wrapper interop
    public MyModRunner(IntPtr ptr) : base(ptr) { }

    private void Update()
    {
        // Runs every frame
    }
}

// In your Plugin.Load():
ClassInjector.RegisterTypeInIl2Cpp<MyModRunner>();
AddComponent<MyModRunner>();
```

### Il2Cpp Collections vs System Collections
Methods in `Assembly-CSharp` often return `Il2CppSystem.Collections.Generic.List<T>` or `Il2CppReferenceArray<T>` instead of standard .NET collections.

```csharp
// Iterating over an Il2Cpp list works with standard foreach:
Il2CppSystem.Collections.Generic.List<ItemData> items = inventory.GetAllItems();
foreach (var item in items)
{
    Plugin.Log.LogInfo(item.DisplayName);
}

// To use LINQ on Il2Cpp collections, convert them to standard arrays first:
var managedArray = items.ToArray();
var matching = managedArray.Where(x => x.BasePrice > 100).ToList();
```

---

## 5. Plugin Lifecycle & Config Files

BepInEx provides a built-in configuration system that automatically generates `.cfg` files in `BepInEx/config/`.

```csharp
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using UnityEngine;

namespace Saleblazers.MyMod
{
    [BepInPlugin(GUID, NAME, VERSION)]
    public class Plugin : BasePlugin
    {
        public const string GUID = "com.author.saleblazers.mymod";
        public const string NAME = "My Mod";
        public const string VERSION = "1.0.0";

        internal static new ManualLogSource Log;
        public static ConfigEntry<KeyCode> HotkeyConfig;
        public static ConfigEntry<bool> EnableLoggingConfig;

        public override void Load()
        {
            Log = base.Log;

            // Bind configuration entries
            HotkeyConfig = Config.Bind("Controls", "ToggleKey", KeyCode.K, "Keyboard shortcut to toggle UI");
            EnableLoggingConfig = Config.Bind("Debug", "VerboseLogs", false, "Print detailed logs to console");

            Log.LogInfo($"{NAME} initialized. Toggle hotkey set to {HotkeyConfig.Value}");
        }
    }
}
```

---

## 6. Hooking Game Logic with Harmony

Harmony lets you modify game behavior without touching executable files.

### Prefix (Run before original method, optional cancel)
```csharp
using HarmonyLib;

// Hooking an attack event on the player
[HarmonyPatch(typeof(HeroPlayerCharacter), "PrimaryMouseEvent", new[] { typeof(bool) })]
internal static class Patch_Attack
{
    // Return false to stop the game from running the original method
    private static bool Prefix(bool isPressed)
    {
        if (MyModUI.IsOpen)
            return false; // Prevent weapon swing when clicking on mod UI

        return true;
    }
}
```

### Postfix (Run after original method, inspect or alter results)
```csharp
[HarmonyPatch(typeof(HeroPlayerCharacter), "OnItemPickedUp")]
internal static class Patch_Pickup
{
    private static void Postfix(HeroPlayerCharacter __instance, ItemData item)
    {
        if (item != null)
        {
            Plugin.Log.LogInfo($"Picked up: {item.DisplayName} (ID: {item.ItemID})");
        }
    }
}
```

Apply all patches during `Load()`:
```csharp
var harmony = new Harmony(GUID);
harmony.PatchAll();
```

---

## 7. Building UI at Runtime (uGUI + TextMeshPro)

Instead of using slow legacy `OnGUI()` or packing asset bundles, you can create sharp uGUI interfaces in pure C# at runtime. This is the exact approach used by **Saleblazers.JEI**.

### 1. Generating a Clean 1x1 Sprite for Backgrounds
Unity 6 uGUI `Image` components need a sprite to render solid colors cleanly:
```csharp
private static Sprite _whiteSprite;
public static Sprite WhiteSprite
{
    get
    {
        if (_whiteSprite == null)
        {
            var tex = Texture2D.whiteTexture;
            _whiteSprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f));
        }
        return _whiteSprite;
    }
}
```

### 2. Borrowing the In-Game Font
Do not bundle custom `.ttf` or `.asset` fonts. Borrow the game font that is already loaded in memory:
```csharp
public static TMP_FontAsset GetGameFont()
{
    // Find an active TextMeshProUGUI in the scene
    var liveText = UnityEngine.Object.FindObjectOfType<TextMeshProUGUI>();
    if (liveText != null && liveText.font != null)
        return liveText.font;

    return TMP_Settings.defaultFontAsset;
}
```

### 3. Setting Up Canvas & Panel Hierarchy
```csharp
public static void CreateUI()
{
    // 1. Root Canvas
    var canvasGo = new GameObject("Mod_Canvas");
    UnityEngine.Object.DontDestroyOnLoad(canvasGo);

    var canvas = canvasGo.AddComponent<Canvas>();
    canvas.renderMode = RenderMode.ScreenSpaceOverlay;
    canvas.sortingOrder = 9999; // Draw over in-game HUD

    var scaler = canvasGo.AddComponent<CanvasScaler>();
    scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
    scaler.referenceResolution = new Vector2(1920, 1080);
    scaler.matchWidthOrHeight = 0.5f;

    canvasGo.AddComponent<GraphicRaycaster>();

    // 2. Background Window
    var windowGo = new GameObject("Window");
    windowGo.transform.SetParent(canvasGo.transform, false);

    var rect = windowGo.AddComponent<RectTransform>();
    rect.anchorMin = new Vector2(0.5f, 0.5f);
    rect.anchorMax = new Vector2(0.5f, 0.5f);
    rect.sizeDelta = new Vector2(500, 400);

    var img = windowGo.AddComponent<Image>();
    img.sprite = WhiteSprite;
    img.color = new Color(0.12f, 0.12f, 0.15f, 0.95f);

    // 3. Header Label
    var titleGo = new GameObject("Title");
    titleGo.transform.SetParent(windowGo.transform, false);

    var titleRect = titleGo.AddComponent<RectTransform>();
    titleRect.anchorMin = new Vector2(0, 1);
    titleRect.anchorMax = new Vector2(1, 1);
    titleRect.pivot = new Vector2(0.5f, 1f);
    titleRect.sizeDelta = new Vector2(0, 45);

    var tmp = titleGo.AddComponent<TextMeshProUGUI>();
    tmp.font = GetGameFont();
    tmp.fontSize = 22;
    tmp.alignment = TextAlignmentOptions.Center;
    tmp.text = "My Custom Mod Menu";
    tmp.color = Color.white;
}
```

---

## 8. Cursor & Camera Lock Fix

In first-person mode, Saleblazers locks the mouse to the center of the screen (`CursorLockMode.Locked`) and hides it.

When your mod menu opens, you need to unlock the mouse and prevent the camera and weapon attacks from triggering while clicking buttons:

```csharp
// 1. Toggle mouse visibility
public static void SetMenuOpen(bool open)
{
    Cursor.visible = open;
    Cursor.lockState = open ? CursorLockMode.None : CursorLockMode.Locked;
}

// 2. Block camera rotation while menu is open
[HarmonyPatch(typeof(HeroPlayerCharacter), "HandleMouseLookX", new[] { typeof(float) })]
internal static class BlockLookX
{
    private static bool Prefix() => !MyMenu.IsOpen;
}

[HarmonyPatch(typeof(HeroPlayerCharacter), "HandleMouseLookY", new[] { typeof(float) })]
internal static class BlockLookY
{
    private static bool Prefix() => !MyMenu.IsOpen;
}

// 3. Block weapon attack while clicking UI
[HarmonyPatch(typeof(HeroPlayerCharacter), "PrimaryMouseEvent", new[] { typeof(bool) })]
internal static class BlockAttack
{
    private static bool Prefix() => !MyMenu.IsOpen;
}
```

---

## 9. Multiplayer & Co-op Rules

Saleblazers has full co-op support. Follow these guidelines so player saves and host sessions do not get corrupted:

1. **Client-side mods are always safe:**
   UI mods, recipe lookups (like JEI), visual indicators, and camera tools do not affect other players or world data.
2. **Gameplay modifiers require caution:**
   Altering item stats, shop prices, or player stats in a multiplayer session will cause desyncs unless both host and clients run matching logic.
3. **Do not modify save data schemas:**
   Adding custom serialized classes into player save files can break loading for vanilla games or when your mod is removed. Store custom mod data in separate `.json` files inside `BepInEx/config/`.

---

## 10. In-Game Mod Manager & Modded Verification

The starter kit bundles `Saleblazers.ModMenu.dll` as a standard plugin. It serves as a reference implementation for integrating custom UI directly into vanilla game menus and managing runtime plugin states.

### Boot Detection & [Modded] Indicator
To confirm that BepInEx has successfully injected into the Unity 6 process:
1. `winhttp.dll` loads `dotnet/coreclr.dll` and initializes `BepInEx.Core`.
2. `Saleblazers.ModMenu` hooks `HRMainMenu.Start` and `HRMainMenu.RefreshButtons` using Harmony.
3. The patch modifies `HRMainMenu.VersionName.text`, appending `<color=#F5D76E>[Modded]</color>`.
4. A clone of the menu's `QuitGameButton` is instantiated as `HRMainMenu_ModsButton`, maintaining native visual styles and sound effects.

### Live Configuration Reloading
Instead of requiring players to restart the game to modify `.cfg` options:
```csharp
if (plugin.Instance is BasePlugin basePlugin && basePlugin.Config != null)
{
    basePlugin.Config.Reload();
}
```
Calling `ConfigFile.Reload()` re-parses the configuration file from disk and immediately updates all bound `ConfigEntry<T>` values in memory.

### Runtime Mod Toggling
Disabling a plugin at runtime is achieved by renaming the file:
- Disabled: `<PluginName>.dll.disabled`
- Enabled: `<PluginName>.dll`

BepInEx 6 IL2CPP only scans and executes files ending with `.dll`, ignoring `.disabled` suffixes on game boot.

---

*Questions or showcase? Join the discussion in the official Saleblazers Discord `#mods` channel.*
