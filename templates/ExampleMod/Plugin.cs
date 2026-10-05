using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;
using UnityEngine;

namespace Saleblazers.ExampleMod
{
    [BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
    public class Plugin : BasePlugin
    {
        public const string PLUGIN_GUID = "com.community.saleblazers.examplemod";
        public const string PLUGIN_NAME = "Saleblazers Example Mod";
        public const string PLUGIN_VERSION = "1.0.0";

        internal static new ManualLogSource Log;

        public override void Load()
        {
            Log = base.Log;
            Log.LogInfo($"{PLUGIN_NAME} v{PLUGIN_VERSION} is loaded!");

            // Register Harmony patches
            var harmony = new Harmony(PLUGIN_GUID);
            harmony.PatchAll();

            // Register Unity MonoBehaviour runner if you need Update / OnGUI
            AddComponent<ModRunner>();
        }
    }

    public static class MyPluginInfo
    {
        public const string PLUGIN_GUID = Plugin.PLUGIN_GUID;
        public const string PLUGIN_NAME = Plugin.PLUGIN_NAME;
        public const string PLUGIN_VERSION = Plugin.PLUGIN_VERSION;
    }

    public class ModRunner : MonoBehaviour
    {
        private void Update()
        {
            // Example: Press F8 in-game to log a message or trigger your custom logic
            if (Input.GetKeyDown(KeyCode.F8))
            {
                Plugin.Log.LogInfo("F8 pressed! Mod runner is active.");
            }
        }
    }

    // Example Harmony Patch:
    // [HarmonyPatch(typeof(SomeGameClass), nameof(SomeGameClass.SomeMethod))]
    // internal static class Patch_SomeMethod
    // {
    //     private static void Prefix()
    //     {
    //         Plugin.Log.LogInfo("Hook called!");
    //     }
    // }
}
