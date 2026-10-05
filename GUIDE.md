# Saleblazers Modding Guide (Unity 6 / IL2CPP)

Welcome to the **Saleblazers** modding documentation!  
This guide explains the technical architecture of the game, how to inspect game code, how to build mods with BepInEx 6, how to hook game logic using Harmony, and how to create clean, responsive in-game UIs (uGUI / TextMeshPro) based on the architecture used in **Saleblazers.JEI**.

---

## 📑 Table of Contents
1. [Game Architecture & Environment](#1-game-architecture--environment)
2. [Setting Up Your Workspace](#2-setting-up-your-workspace)
3. [Decompiling & Inspecting Game Code](#3-decompiling--inspecting-game-code)
4. [Writing Your First Mod (Lifecycle & MonoBehaviours)](#4-writing-your-first-mod-lifecycle--monobehaviours)
5. [Hooking Game Logic with Harmony](#5-hooking-game-logic-with-harmony)
6. [Accessing In-Game Systems & Singletons](#6-accessing-in-game-systems--singletons)
7. [Building In-Game UI (uGUI & TextMeshPro)](#7-building-in-game-ui-ugui--textmeshpro)
8. [Handling Input & Cursor Control](#8-handling-input--cursor-control)
9. [Multiplayer & Co-op Guidelines](#9-multiplayer--co-op-guidelines)

---

## 1. Game Architecture & Environment

Saleblazers uses:
- **Engine:** Unity 6 (`6000.3.18.6209205`)
- **Compilation:** **IL2CPP (x64)** (game code is compiled into native C++ machine code)
- **Mod Loader:** **BepInEx 6.x (Unity IL2CPP build)**
- **Interop Layer:** **Il2CppInterop** (exposes game C++ classes as callable C# classes)

> [!IMPORTANT]
> Standard BepInEx 5 (Mono) will **NOT** work. Always use the pre-configured [Saleblazers.ModdingStarterKit](https://github.com/romrem30-eng/Saleblazers.ModdingStarterKit).

---

## 2. Setting Up Your Workspace

### Prerequisites
- [.NET 6.0 SDK](https://dotnet.microsoft.com/download/dotnet/6.0) or newer
- An IDE (Visual Studio 2022, Rider, or VS Code)
- A copy of [Saleblazers.ModdingStarterKit](https://github.com/romrem30-eng/Saleblazers.ModdingStarterKit)

### Quick Project Setup
Inside `templates/ExampleMod/ExampleMod.csproj`, all references are configured to point to relative BepInEx paths:
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <AssemblyName>MyMod</AssemblyName>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
  </PropertyGroup>

  <ItemGroup>
    <!-- BepInEx 6 & Harmony -->
    <Reference Include="BepInEx.Core" Path="..\..\BepInEx\core\BepInEx.Core.dll" />
    <Reference Include="BepInEx.Unity.IL2CPP" Path="..\..\BepInEx\core\BepInEx.Unity.IL2CPP.dll" />
    <Reference Include="0Harmony" Path="..\..\BepInEx\core\0Harmony.dll" />
    <Reference Include="Il2CppInterop.Runtime" Path="..\..\BepInEx\core\Il2CppInterop.Runtime.dll" />
    <Reference Include="Il2Cppmscorlib" Path="..\..\BepInEx\interop\Il2Cppmscorlib.dll" />

    <!-- Game & Unity Assemblies -->
    <Reference Include="Assembly-CSharp" Path="..\..\BepInEx\interop\Assembly-CSharp.dll" />
    <Reference Include="UnityEngine" Path="..\..\BepInEx\interop\UnityEngine.dll" />
    <Reference Include="UnityEngine.CoreModule" Path="..\..\BepInEx\interop\UnityEngine.CoreModule.dll" />
    <Reference Include="UnityEngine.UI" Path="..\..\BepInEx\interop\UnityEngine.UI.dll" />
    <Reference Include="Unity.TextMeshPro" Path="..\..\BepInEx\interop\Unity.TextMeshPro.dll" />
  </ItemGroup>
</Project>
```

To compile your mod:
```bash
dotnet build -c Release
```
Copy the compiled DLL from `bin/Release/MyMod.dll` into your game's `Saleblazers/Default/BepInEx/plugins/` directory.

---

## 3. Decompiling & Inspecting Game Code

You do not need to disassemble native binaries with IDA/Ghidra. The Starter Kit already includes pre-dumped interop assemblies in `BepInEx/interop/`.

1. Download **[ILSpy](https://github.com/icsharpcode/ILSpy)** or **[dnSpyEx](https://github.com/dnSpyEx/dnSpy)**.
2. Open `BepInEx/interop/Assembly-CSharp.dll`.
3. Useful classes to inspect:
   - `HeroPlayerCharacter`: The local player pawn (movement, interactions, combat).
   - `HRGameInstance` & `BaseGameInstance`: Global game state, mouse cursor manager, scene transitions.
   - `ItemData` / `ItemCatalog`: Item definitions, attributes, durability, pricing.
   - `PlayerInventory`: Player inventory and container slots.
   - `CraftingRecipe` / `CraftingManager`: Stations, crafting recipes, cooking pot inputs/outputs.

---

## 4. Writing Your First Mod (Lifecycle & MonoBehaviours)

A BepInEx 6 IL2CPP mod inherits from `BasePlugin`. Because IL2CPP handles garbage collection and memory differently than standard Mono, **always register custom `MonoBehaviour` classes using `AddComponent<T>()`** if you need `Update()` or frame-by-frame ticks.

```csharp
using System;
using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using UnityEngine;

namespace Saleblazers.MyMod
{
    [BepInPlugin("com.example.saleblazers.mymod", "My Mod", "1.0.0")]
    public class Plugin : BasePlugin
    {
        internal static new ManualLogSource Log;

        public override void Load()
        {
            Log = base.Log;
            Log.LogInfo("Mod loaded!");

            // Register Unity lifecycle runner
            AddComponent<ModRunner>();
        }
    }

    public class ModRunner : MonoBehaviour
    {
        // Required for Il2CppInterop MonoBehaviours
        public ModRunner(IntPtr ptr) : base(ptr) { }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.F8))
            {
                Plugin.Log.LogInfo("F8 key pressed in game!");
            }
        }
    }
}
```

> [!NOTE]
> In IL2CPP, your custom `MonoBehaviour` classes must declare a constructor taking `(IntPtr ptr) : base(ptr)` so the interop layer can bind the unmanaged C++ object to your managed C# class.

---

## 5. Hooking Game Logic with Harmony

You can intercept, alter, or replace existing game methods using Harmony.

### Example: Hooking an Item Pickup or Method Call
```csharp
using HarmonyLib;

[HarmonyPatch(typeof(HeroPlayerCharacter), "OnItemPickedUp")]
internal static class Patch_OnItemPickedUp
{
    // Prefix: runs before the original method. Return false to cancel the original execution!
    private static void Prefix(HeroPlayerCharacter __instance, ItemData item)
    {
        if (item != null)
        {
            Plugin.Log.LogInfo($"Player picked up: {item.DisplayName}");
        }
    }

    // Postfix: runs after the original method
    private static void Postfix(HeroPlayerCharacter __instance)
    {
        // ...
    }
}
```

Apply patches in your `Plugin.Load()`:
```csharp
var harmony = new Harmony("com.example.saleblazers.mymod");
harmony.PatchAll();
```

---

## 6. Accessing In-Game Systems & Singletons

### Finding the Local Player
```csharp
var player = UnityEngine.Object.FindObjectOfType<HeroPlayerCharacter>();
if (player != null)
{
    var health = player.CurrentHealth;
}
```

### Checking if the Player is in Gameplay vs Menu
```csharp
var gi = UnityEngine.Object.FindObjectOfType<HRGameInstance>();
bool inGame = gi != null && gi.IsPlayingWorld; // Player is loaded in the world
```

---

## 7. Building In-Game UI (uGUI & TextMeshPro)

Rather than using legacy `OnGUI()` (which is slow and lacks modern styling), Saleblazers uses Unity's **uGUI Canvas** and **TextMeshPro (TMP)**.

Here is how **Saleblazers.JEI** builds its entire interface programmatically at runtime without external asset bundles:

### 1. Reusable 1x1 White Sprite
Unity 6 uGUI `Image` components render cleanest when assigned a white sprite:
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

### 2. Borrowing Live TextMeshPro Fonts
Instead of shipping a `.ttf` or TMP font asset in your mod, borrow the active game font from the scene:
```csharp
public static TMP_FontAsset GetGameFont()
{
    // 1. Try finding a live TextMeshProUGUI in the scene
    var liveText = UnityEngine.Object.FindObjectOfType<TextMeshProUGUI>();
    if (liveText != null && liveText.font != null)
        return liveText.font;

    // 2. Fall back to default font asset
    return TMP_Settings.defaultFontAsset;
}
```

### 3. Creating a Root Canvas
```csharp
var canvasGo = new GameObject("MyMod_Canvas");
UnityEngine.Object.DontDestroyOnLoad(canvasGo);

var canvas = canvasGo.AddComponent<Canvas>();
canvas.renderMode = RenderMode.ScreenSpaceOverlay;
canvas.sortingOrder = 9999; // Ensure it renders on top

var scaler = canvasGo.AddComponent<CanvasScaler>();
scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
scaler.referenceResolution = new Vector2(1920, 1080);
scaler.matchWidthOrHeight = 0.5f;

var raycaster = canvasGo.AddComponent<GraphicRaycaster>();
```

### 4. Creating a Panel with Background and Text
```csharp
// Panel Background
var panelGo = new GameObject("Panel");
panelGo.transform.SetParent(canvasGo.transform, false);

var rect = panelGo.AddComponent<RectTransform>();
rect.anchorMin = new Vector2(0.5f, 0.5f);
rect.anchorMax = new Vector2(0.5f, 0.5f);
rect.sizeDelta = new Vector2(400, 300);

var img = panelGo.AddComponent<Image>();
img.sprite = WhiteSprite;
img.color = new Color(0.1f, 0.1f, 0.12f, 0.95f); // Dark translucent background

// TextMeshPro Label
var textGo = new GameObject("Title");
textGo.transform.SetParent(panelGo.transform, false);

var textRect = textGo.AddComponent<RectTransform>();
textRect.anchorMin = new Vector2(0, 1);
textRect.anchorMax = new Vector2(1, 1);
textRect.pivot = new Vector2(0.5f, 1f);
textRect.sizeDelta = new Vector2(0, 40);

var tmp = textGo.AddComponent<TextMeshProUGUI>();
tmp.font = GetGameFont();
tmp.fontSize = 20;
tmp.alignment = TextAlignmentOptions.Center;
tmp.text = "Saleblazers Custom Mod Panel";
tmp.color = Color.white;
```

---

## 8. Handling Input & Cursor Control

In first-person games like Saleblazers, the game locks the cursor to the center of the screen (`CursorLockMode.Locked`) and hides it while in gameplay.

If your mod displays a modal window or menu:

### Unlocking the Cursor
You can unlock the cursor while your UI is open:
```csharp
Cursor.visible = true;
Cursor.lockState = CursorLockMode.None;
```

### Preventing Camera Rotation & Weapon Attacks While UI is Open
To stop mouse movement from spinning the camera or swinging tools while interacting with your UI, hook `HeroPlayerCharacter` input methods with Harmony:

```csharp
[HarmonyPatch(typeof(HeroPlayerCharacter), "HandleMouseLookX")]
internal static class Patch_BlockLookX
{
    private static bool Prefix() => !MyUi.IsOpen; // Returns false if UI is open, blocking camera rotation
}

[HarmonyPatch(typeof(HeroPlayerCharacter), "HandleMouseLookY")]
internal static class Patch_BlockLookY
{
    private static bool Prefix() => !MyUi.IsOpen;
}

[HarmonyPatch(typeof(HeroPlayerCharacter), "PrimaryMouseEvent")]
internal static class Patch_BlockClickAttack
{
    private static bool Prefix() => !MyUi.IsOpen; // Prevents weapon swing when clicking buttons
}
```

---

## 9. Multiplayer & Co-op Guidelines

Saleblazers supports online co-op. When developing mods, keep these principles in mind:

1. **Client-Side vs Synchronized:**
   - Visual enhancements, inventory helpers, recipe viewers (like JEI), UI tweaks, and camera mods are completely client-safe.
   - Gameplay mechanics (changing item prices, modifying damage, spawning entities) should only be tested in singleplayer or when all players in the session have the mod installed.
2. **Do Not Break Host Save States:**
   - Modifying item IDs or writing non-standard data into save files can corrupt multiplayer worlds for players who do not run the mod.
3. **Respect Fair Play:**
   - Do not create intrusive griefing tools or multiplayer cheats. Help foster a welcoming, creative modding community!

---

*Happy Modding! If you have questions or build a mod, share it in the official Saleblazers Discord `#mods` channel.*
