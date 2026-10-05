# Saleblazers Modding Starter Kit (BepInEx 6 IL2CPP)

Pre-configured BepInEx 6 IL2CPP environment and modding template for **Saleblazers** (Unity 6 / `6000.3.18`).

Saleblazers runs on Unity 6 IL2CPP x64. Standard BepInEx 5 builds do not work with this engine and backend. This starter kit provides a ready-to-use configuration: Doorstop loader, .NET 6 runtime, dumped interop assemblies, an example mod template, and an integrated in-game mod manager.

For developer documentation covering architecture, Harmony patches, runtime uGUI creation, and IL2CPP interop details, see [GUIDE.md](GUIDE.md).

---

## Mod Loader & Verification

### Architecture & Boot Sequence
1. When the game launches, `winhttp.dll` (Doorstop proxy) intercepts execution before Unity engine initialization.
2. Doorstop starts the .NET 6 runtime (`dotnet/coreclr.dll`) and hands execution over to BepInEx 6 IL2CPP chainloader.
3. BepInEx loads generated IL2CPP interop wrappers from `BepInEx/interop/` and executes mod plugins located in `BepInEx/plugins/`.
4. The integrated mod manager (`Saleblazers.ModMenu.dll`) hooks into `HRMainMenu` to provide the native in-game interface.

### How to Verify the Game is Modded
- **Version Indicator:** In the main menu, the version text in the lower corner displays `[Modded]` next to the game version (for example, `v0.14.x [Modded]`).
- **Main Menu Button:** A native `MODS` button appears in the main menu layout directly above the Quit button, displaying the count of installed mods.
- **Console Window:** By default, an external console window opens alongside the game process displaying real-time BepInEx logs.

---

## In-Game Mod Manager Features

The starter kit bundles `Saleblazers.ModMenu.dll` in `BepInEx/plugins/`:
- **Mod Management:** Lists all installed mods, their GUID, version, file path, and active status.
- **Enable / Disable Toggles:** Disables or enables mod DLLs directly from the UI without manual file renaming (`.dll` <-> `.dll.disabled`).
- **In-Game Config Editor:** Edit `.cfg` parameters in real time through an integrated modal window.
- **Live Memory Reload:** Saving configuration changes immediately invokes `BasePlugin.Config.Reload()`, updating values in memory without restarting the game.

---

## Installation Guide for Players

### Automated Installation (1-Click)
1. Download `Saleblazers.BepInExPack-v6.0.0.zip` from [Releases](https://github.com/romrem30-eng/Saleblazers.ModdingStarterKit/releases).
2. Unpack the zip into any folder.
3. Run `install.bat`.
   - Automatically detects your Saleblazers installation across all Steam libraries (including Cyrillic/custom paths).
   - Installs BepInEx 6 IL2CPP, Doorstop, .NET 6 runtime, and the in-game Mod Manager.
4. Launch the game through Steam. The main menu will display `[Modded]` and a native `MODS` button!

### Manual Installation (Without Scripts)
If you prefer installing manually without running batch scripts:
1. Download `Saleblazers.BepInExPack-v6.0.0.zip` from [Releases](https://github.com/romrem30-eng/Saleblazers.ModdingStarterKit/releases).
2. Open your Saleblazers game folder:
   - In Steam, right-click **Saleblazers** -> **Manage** -> **Browse local files**.
   - Open the directory containing `Saleblazers.exe` (typically `Saleblazers/Default`).
3. Extract the contents of the archive directly into this directory:
   ```text
   Saleblazers/Default/
   ├── BepInEx/
   │   ├── config/
   │   ├── core/
   │   ├── interop/
   │   └── plugins/
   │       └── Saleblazers.ModMenu.dll
   ├── dotnet/
   ├── doorstop_config.ini
   ├── winhttp.dll
   └── Saleblazers.exe
   ```
4. Place any additional mod `.dll` files into `BepInEx/plugins/`.
5. Launch the game through Steam.

### Uninstallation
- **Automated:** Run `uninstall.bat` from the zip folder or game folder. You can choose to either temporarily disable the loader (keeping your downloaded mods) or completely wipe all mod files back to clean vanilla.
- **Manual:** Delete `winhttp.dll` and `doorstop_config.ini` from your `Saleblazers/Default/` folder. This instantly restores the vanilla game.

---

## Mod Development Guide

### Requirements
- [.NET 6.0 SDK](https://dotnet.microsoft.com/download/dotnet/6.0) or newer
- IDE: Visual Studio 2022, JetBrains Rider, or VS Code

### Building the Example Mod
The template project is located in `templates/ExampleMod`:

1. Open a terminal or your IDE in `templates/ExampleMod`.
2. Core references to BepInEx, Harmony, and Unity/game interop assemblies are pre-configured in `ExampleMod.csproj`.
3. Compile the project:
   ```bash
   dotnet build -c Release
   ```
4. Copy `bin/Release/ExampleMod.dll` into `Saleblazers/Default/BepInEx/plugins/`.

### Minimal Plugin Code

```csharp
using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;

namespace Saleblazers.MyMod
{
    [BepInPlugin("com.author.saleblazers.mymod", "My Mod", "1.0.0")]
    public class Plugin : BasePlugin
    {
        internal static new ManualLogSource Log;

        public override void Load()
        {
            Log = base.Log;
            Log.LogInfo("Plugin initialized");

            var harmony = new Harmony("com.author.saleblazers.mymod");
            harmony.PatchAll();
        }
    }
}
```

---

## Configuration & Logging

- **Console Output:** Configured in `BepInEx/config/BepInEx.cfg` under `[Logging.Console] Enabled = true`.
- To hide the console window, set `Enabled = false` in `BepInEx/config/BepInEx.cfg`.
- Mod configurations are stored in `BepInEx/config/<plugin_guid>.cfg`.

---

## License & Third-Party Notice

- BepInEx is licensed under LGPL-2.1.
- Interop generation is powered by Il2CppInterop.
- Saleblazers is developed by Airstrafe Interactive.
