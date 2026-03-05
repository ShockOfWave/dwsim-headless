using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;

class SmokeTest
{
    static string _dllDir = "";

    static int Main(string[] args)
    {
        // DLL directory passed as argument or auto-detected
        _dllDir = args.Length > 0 ? args[0] : FindDllDir();
        if (string.IsNullOrEmpty(_dllDir) || !Directory.Exists(_dllDir))
        {
            Console.WriteLine($"ERROR: DLL directory not found: {_dllDir}");
            return 1;
        }

        Console.WriteLine($"=== DWSIM Headless Smoke Test ===");
        Console.WriteLine($"DLL dir: {_dllDir}");
        Console.WriteLine();

        // Set up assembly resolution for transitive deps
        AssemblyLoadContext.Default.Resolving += (ctx, name) =>
        {
            var path = Path.Combine(_dllDir, name.Name + ".dll");
            if (File.Exists(path))
                return ctx.LoadFromAssemblyPath(path);
            return null;
        };

        int passed = 0;
        int failed = 0;

        // Test 1: Load DWSIM.Automation assembly
        Assembly? autoAsm = null;
        try
        {
            autoAsm = Assembly.LoadFrom(Path.Combine(_dllDir, "DWSIM.Automation.dll"));
            Console.WriteLine($"[PASS] DWSIM.Automation.dll loaded ({autoAsm.GetTypes().Length} types)");
            passed++;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[FAIL] Load DWSIM.Automation.dll: {ex.Message}");
            failed++;
            PrintResults(passed, failed);
            return 1;
        }

        // Test 2: Instantiate Automation3
        object? auto = null;
        try
        {
            var autoType = autoAsm.GetType("DWSIM.Automation.Automation3");
            if (autoType == null) throw new Exception("Type DWSIM.Automation.Automation3 not found");
            auto = Activator.CreateInstance(autoType);
            Console.WriteLine("[PASS] Automation3 instantiated");
            passed++;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[FAIL] Automation3 instantiation: {ex.Message}");
            if (ex.InnerException != null)
                Console.WriteLine($"       Inner: {ex.InnerException.Message}");
            failed++;
        }

        // Test 3: CreateFlowsheet
        if (auto != null)
        {
            try
            {
                var method = auto.GetType().GetMethod("CreateFlowsheet");
                if (method == null) throw new Exception("Method CreateFlowsheet not found");
                var fs = method.Invoke(auto, null);
                Console.WriteLine($"[PASS] CreateFlowsheet returned {fs?.GetType().Name}");
                passed++;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FAIL] CreateFlowsheet: {ex.Message}");
                var inner = ex.InnerException;
                while (inner != null)
                {
                    Console.WriteLine($"       Inner: {inner.GetType().Name}: {inner.Message}");
                    inner = inner.InnerException;
                }
                failed++;
            }
        }

        // Test 4: PengRobinson property package
        try
        {
            var thermoAsm = Assembly.LoadFrom(Path.Combine(_dllDir, "DWSIM.Thermodynamics.dll"));
            var prType = thermoAsm.GetType("DWSIM.Thermodynamics.PropertyPackages.PengRobinsonPropertyPackage");
            if (prType == null) throw new Exception("PengRobinson type not found");
            var pr = Activator.CreateInstance(prType);
            Console.WriteLine("[PASS] PengRobinsonPropertyPackage created");
            passed++;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[FAIL] PengRobinson: {ex.Message}");
            if (ex.InnerException != null)
                Console.WriteLine($"       Inner: {ex.InnerException.Message}");
            failed++;
        }

        // Test 5: Mixer unit operation
        try
        {
            var uoAsm = Assembly.LoadFrom(Path.Combine(_dllDir, "DWSIM.UnitOperations.dll"));
            var mixerType = uoAsm.GetType("DWSIM.UnitOperations.UnitOperations.Mixer");
            if (mixerType == null) throw new Exception("Mixer type not found");
            var mixer = Activator.CreateInstance(mixerType);
            Console.WriteLine("[PASS] Mixer created");
            passed++;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[FAIL] Mixer: {ex.Message}");
            if (ex.InnerException != null)
                Console.WriteLine($"       Inner: {ex.InnerException.Message}");
            failed++;
        }

        // Test 6: GlobalSettings
        try
        {
            var gsAsm = Assembly.LoadFrom(Path.Combine(_dllDir, "DWSIM.GlobalSettings.dll"));
            var settingsType = gsAsm.GetType("DWSIM.GlobalSettings.Settings");
            if (settingsType == null) throw new Exception("Settings type not found");
            var verProp = settingsType.GetProperty("CurrentRunningVersion");
            var ver = verProp?.GetValue(null);
            Console.WriteLine($"[PASS] GlobalSettings.CurrentRunningVersion = {ver}");
            passed++;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[FAIL] GlobalSettings: {ex.Message}");
            if (ex.InnerException != null)
                Console.WriteLine($"       Inner: {ex.InnerException.Message}");
            failed++;
        }

        PrintResults(passed, failed);
        return failed > 0 ? 1 : 0;
    }

    static void PrintResults(int passed, int failed)
    {
        Console.WriteLine();
        Console.WriteLine($"=== Results: {passed} passed, {failed} failed ===");
    }

    static string FindDllDir()
    {
        // Try common locations
        foreach (var cfg in new[] { "Debug", "Release" })
        {
            var path = $"/src/DWSIM.Automation/bin/{cfg}/net8.0";
            if (Directory.Exists(path) && File.Exists(Path.Combine(path, "DWSIM.Automation.dll")))
                return path;
        }
        return "";
    }
}
