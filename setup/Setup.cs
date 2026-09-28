using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

[assembly: AssemblyTitle("LINE Tray Startup Setup")]
[assembly: AssemblyVersion("0.2.0.1")]
[assembly: AssemblyFileVersion("0.2.0.1")]

internal static class Program
{
    internal const string Version = "0.2.0-preview.2";
    internal static readonly string Home = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LineTrayStartup");
    internal static readonly string Shortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "LINE Tray Startup.lnk");
    internal static readonly string[] Payloads = { "Install.ps1", "Uninstall.ps1", "LineTrayStart.exe", "LineTrayHook32.dll", "LineTrayHook64.dll", "LICENSE.txt", "Detours-LICENSE.txt", "GUIDE.txt" };

    [STAThread]
    private static int Main(string[] args)
    {
        // Used by the release smoke test; does not install or change startup settings.
        if (args.Length == 2 && args[0] == "--extract") { Extract(args[1]); return 0; }


        new Application().Run(new SetupWindow());
        return 0;
    }

    internal static void Extract(string directory)
    {
        Directory.CreateDirectory(Path.Combine(directory, "dist"));
        foreach (string name in Payloads)
        {
            string path = Path.Combine(directory, name.EndsWith(".exe") || name.EndsWith(".dll") ? "dist\\" + name : name);
            using (Stream input = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
            {
                if (input == null) throw new IOException("セットアップに必要なファイルがありません: " + name);
                using (FileStream output = File.Create(path)) input.CopyTo(output);
            }
        }
    }

    internal static string RunScript(string root, string name)
    {
        string ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell\\v1.0\\powershell.exe");
        var start = new ProcessStartInfo(ps, "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + Path.Combine(root, name) + "\"");
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        start.WindowStyle = ProcessWindowStyle.Hidden;
        start.RedirectStandardOutput = true;
        start.RedirectStandardError = true;
        start.StandardOutputEncoding = Encoding.UTF8;
        start.StandardErrorEncoding = Encoding.UTF8;
        using (Process process = Process.Start(start))
        {
            Task<string> output = process.StandardOutput.ReadToEndAsync();
            Task<string> error = process.StandardError.ReadToEndAsync();
            process.WaitForExit();
            Task.WaitAll(output, error);
            if (process.ExitCode != 0) throw new IOException(error.Result.Length > 0 ? error.Result : output.Result);
            return output.Result;
        }
    }

    internal static void SaveSupportFiles(string root, string home, string executablePath, string shortcutPath)
    {
        string target = Path.Combine(home, "Setup.exe");
        if (!String.Equals(Path.GetFullPath(executablePath), target, StringComparison.OrdinalIgnoreCase))
            File.Copy(executablePath, target, true);
        File.Copy(Path.Combine(root, "Uninstall.ps1"), Path.Combine(home, "Uninstall.ps1"), true);
        File.Copy(Path.Combine(root, "LICENSE.txt"), Path.Combine(home, "LICENSE.txt"), true);
        File.Copy(Path.Combine(root, "Detours-LICENSE.txt"), Path.Combine(home, "Detours-LICENSE.txt"), true);
        File.Copy(Path.Combine(root, "GUIDE.txt"), Path.Combine(home, "使い方.txt"), true);
        Type shellType = Type.GetTypeFromProgID("WScript.Shell");
        object shell = Activator.CreateInstance(shellType);
        object shortcut = null;
        try
        {
            shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
            Type type = shortcut.GetType();
            type.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { target });
            type.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { home });
            type.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { "LINE Tray Startup の設定と解除" });
            type.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
        }
        finally
        {
            if (shortcut != null) Marshal.ReleaseComObject(shortcut);
            Marshal.ReleaseComObject(shell);
        }
    }
}
