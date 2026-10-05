using System;
using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;
using Il2CppInterop.Runtime.Injection;
using UnityEngine;

namespace Saleblazers.ExampleMod
{
    [BepInPlugin(PLUGIN_GUID, PLUGIN_NAME, PLUGIN_VERSION)]
    public class Plugin : BasePlugin
    {
        public const string PLUGIN_GUID = "com.community.saleblazers.examplemod";
        public const string PLUGIN_NAME = "Saleblazers Example Mod";
        public const string PLUGIN_VERSION = "1.0.0";

        internal static new ManualLogSource Log;

        public override void Load()
        {
            Log = base.Log;
            Log.LogInfo($"{PLUGIN_NAME} v{PLUGIN_VERSION} initialized");

            var harmony = new Harmony(PLUGIN_GUID);
            harmony.PatchAll();

            ClassInjector.RegisterTypeInIl2Cpp<ModRunner>();
            var host = new GameObject("ExampleModHost");
            UnityEngine.Object.DontDestroyOnLoad(host);
            host.hideFlags = HideFlags.HideAndDontSave;
            host.AddComponent<ModRunner>();
        }
    }

    public class ModRunner : MonoBehaviour
    {
        public ModRunner(IntPtr ptr) : base(ptr) { }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.F8))
            {
                Plugin.Log.LogInfo("F8 key pressed");
            }
        }
    }
}
