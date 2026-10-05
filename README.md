# Saleblazers Modding Starter Kit (BepInEx 6 IL2CPP)

Pre-configured BepInEx 6 IL2CPP environment and modding template for **Saleblazers** (Unity 6 / `6000.3.18`).

Because Saleblazers runs on Unity 6 IL2CPP x64, standard BepInEx 5 builds do not work. This starter kit provides everything configured and ready out of the box — the Doorstop loader, .NET 6 runtime, dumped interop assemblies, and an example mod template.

---

## 🚀 For Players: How to Install

1. Download the latest release `.zip` from [Releases](https://github.com/romrem30-eng/Saleblazers.ModdingStarterKit/releases).
2. Open your Saleblazers game folder:
   - In Steam, right-click **Saleblazers** -> **Manage** -> **Browse local files**.
   - Navigate into the folder containing `Saleblazers.exe` (usually `Saleblazers/Default`).
3. Extract the contents of the zip into this folder.
   Your game directory should look like this:
   ```text
   Saleblazers/Default/
   ├── BepInEx/
   │   ├── config/
   │   ├── core/
   │   ├── interop/
   │   └── plugins/
   ├── dotnet/
   ├── doorstop_config.ini
   ├── winhttp.dll
   └── Saleblazers.exe
   ```
4. Put any mod `.dll` files into `BepInEx/plugins/`.
5. Launch the game normally via Steam. A console window will show BepInEx loading.

---

## 🛠️ For Modders: Creating Your First Mod

### Requirements
- [.NET 6.0 SDK](https://dotnet.microsoft.com/download/dotnet/6.0) or newer
- Any IDE: Visual Studio 2022, Rider, or VS Code

### Using the Template
Inside [`templates/ExampleMod`](templates/ExampleMod):

1. Open the project in your IDE or open a terminal in that directory.
2. The project is already wired up to reference:
   - `BepInEx.Core.dll` and `BepInEx.Unity.IL2CPP.dll`
   - `0Harmony.dll` (for hooking game methods)
   - `Assembly-CSharp.dll` (all game code & classes)
   - Unity engine modules (`UnityEngine.dll`, `UnityEngine.CoreModule.dll`, `UnityEngine.UI.dll`, etc.)
3. Build the mod:
   ```bash
   dotnet build -c Release
   ```
4. Copy the compiled DLL from `bin/Release/ExampleMod.dll` into your game's `BepInEx/plugins/` directory.

### Quick Code Example

```csharp
using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;

namespace Saleblazers.MyMod
{
    [BepInPlugin("com.yourname.saleblazers.mymod", "My Mod", "1.0.0")]
    public class Plugin : BasePlugin
    {
        internal static new ManualLogSource Log;

        public override void Load()
        {
            Log = base.Log;
            Log.LogInfo("Mod loaded successfully!");

            var harmony = new Harmony("com.yourname.saleblazers.mymod");
            harmony.PatchAll();
        }
    }
}
```

---

## ⚙️ Configuration & Console

- **Console Window**: Enabled by default in `BepInEx/config/BepInEx.cfg` under `[Logging.Console] Enabled = true` so you can monitor logs and errors in real time.
- If you want to disable the black console popup, set `Enabled = false` in `BepInEx/config/BepInEx.cfg`.

---

## ⚖️ License & Credits

- [BepInEx](https://github.com/BepInEx/BepInEx) is licensed under the LGPL-2.1.
- Interop stubs are generated via [Il2CppInterop](https://github.com/BepInEx/Il2CppInterop).
- Saleblazers is developed by [Airstrafe Interactive](https://store.steampowered.com/app/1419850/Saleblazers/).
