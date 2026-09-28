using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("LINE Tray Startup Setup")]
[assembly: AssemblyVersion("0.2.0.0")]
[assembly: AssemblyFileVersion("0.2.0.0")]

internal static class Program
{
    internal const string Version = "0.2.0-preview.1";
    internal static readonly string Home = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LineTrayStartup");
    internal static readonly string Shortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "LINE Tray Startup.lnk");
    internal static readonly string[] Payloads = { "Install.ps1", "Uninstall.ps1", "LineTrayStart.exe", "LineTrayHook32.dll", "LineTrayHook64.dll", "LICENSE.txt", "Detours-LICENSE.txt", "GUIDE.txt" };

    [STAThread]
    private static int Main(string[] args)
    {
        // Used by the release smoke test; does not install or change startup settings.
        if (args.Length == 2 && args[0] == "--extract") { Extract(args[1]); return 0; }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new SetupForm());
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

internal sealed class SetupForm : Form
{
    private readonly Label state = new Label();
    private readonly Button install = new Button();
    private readonly Button restore = new Button();
    private readonly Button launch = new Button();
    private bool busy;

    internal SetupForm()
    {
        Text = "LINE Tray Startup — セットアップ";
        ClientSize = new Size(600, 490);
        MinimumSize = new Size(620, 530);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Yu Gothic UI", 10);
        BackColor = Color.White;
        AutoScaleMode = AutoScaleMode.Dpi;
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(28), ColumnCount = 1, RowCount = 7 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 50));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 82));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 25));
        layout.Controls.Add(new Label { Text = "LINEを、画面を出さずに起動", Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 19, FontStyle.Bold) }, 0, 0);
        layout.Controls.Add(new Label { Text = "PCへのサインイン時に、LINEを通知領域（時計の近く）へ起動します。\r\n開きたいときは、LINEアイコンをダブルクリックします。", Dock = DockStyle.Fill }, 0, 1);
        layout.Controls.Add(new Label { Text = "準備\r\n1. LINE本体で自動ログインをONにします。\r\n2. 通知領域のLINEを右クリックして「終了」します。", Dock = DockStyle.Fill }, 0, 2);
        var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false };
        install.Text = "セットアップ";
        install.Size = new Size(155, 39);
        install.BackColor = Color.FromArgb(0, 120, 72);
        install.ForeColor = Color.White;
        install.FlatStyle = FlatStyle.Flat;
        restore.Text = "設定を元に戻す";
        restore.Size = new Size(160, 39);
        launch.Text = "LINEを起動";
        launch.Size = new Size(140, 39);
        buttons.Controls.AddRange(new Control[] { install, restore, launch });
        layout.Controls.Add(buttons, 0, 3);
        state.Dock = DockStyle.Fill;
        state.Padding = new Padding(0, 12, 0, 0);
        state.ForeColor = Color.FromArgb(65, 65, 65);
        state.Text = "管理者権限や追加のダウンロードは不要です。\r\n確認済みのLINE: 26.4.2.3957／プレビュー版 " + Program.Version;
        layout.Controls.Add(state, 0, 4);
        var links = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false };
        var folder = new LinkLabel { Text = "保存先を開く", AutoSize = true, Margin = new Padding(0,0,24,0) };
        folder.LinkClicked += delegate { if (Directory.Exists(Program.Home)) Process.Start("explorer.exe", "\"" + Program.Home + "\""); };
        var help = new LinkLabel { Text = "使い方を見る", AutoSize = true };
        help.LinkClicked += delegate {
            string guide = Path.Combine(Program.Home, "使い方.txt");
            if (File.Exists(guide)) Process.Start("notepad.exe", "\"" + guide + "\"");
            else Process.Start("https://github.com/hinatamaxxx/line-startup-to-tray#readme");
        };
        links.Controls.Add(folder);
        links.Controls.Add(help);
        layout.Controls.Add(links, 0, 5);
        layout.Controls.Add(new Label { Text = "非公式ツールです。LINEの更新で動作しなくなる場合があります。", Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 9) }, 0, 6);
        Controls.Add(layout);
        install.Click += async delegate { await Apply(false); };
        restore.Click += async delegate { await Apply(true); };
        launch.Click += delegate { StartLine(); };
        FormClosing += delegate(object sender, FormClosingEventArgs e) { if (busy) e.Cancel = true; };
        RefreshButtons();
    }

    private void RefreshButtons()
    {
        install.Enabled = !busy;
        restore.Enabled = !busy && File.Exists(Path.Combine(Program.Home, "startup-backup.json"));
        launch.Enabled = !busy && File.Exists(Path.Combine(Program.Home, "startup-backup.json")) && File.Exists(Path.Combine(Program.Home, "LineTrayStart.exe"));
    }

    private bool LineRunning()
    {
        Process[] processes = Process.GetProcessesByName("LINE");
        Process[] launchers = Process.GetProcessesByName("LineLauncher");
        bool found = processes.Length > 0 || launchers.Length > 0;
        foreach (Process process in processes) process.Dispose();
        foreach (Process process in launchers) process.Dispose();
        return found;
    }

    private async Task Apply(bool undo)
    {
        if (!undo && LineRunning())
        {
            MessageBox.Show(this, "LINEが起動しています。\r\n通知領域のLINEを右クリックして「終了」し、もう一度セットアップしてください。\r\nウィンドウの×ボタンでは終了しません。", "LINEを終了してください", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        if (undo && MessageBox.Show(this, "自動起動設定を、このツールの導入前の状態に戻します。\r\nLINEのログイン情報は変更しません。続けますか？", "設定を元に戻す", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        busy = true;
        RefreshButtons();
        state.Text = undo ? "自動起動設定を戻しています…" : "セットアップしています…";
        string temp = Path.Combine(Path.GetTempPath(), "LineTrayStartup-Setup", Guid.NewGuid().ToString("N"));
        try
        {
            await Task.Run(delegate {
                Program.Extract(temp);
                Program.RunScript(temp, undo ? "Uninstall.ps1" : "Install.ps1");
                if (!undo) Program.SaveSupportFiles(temp, Program.Home, Application.ExecutablePath, Program.Shortcut);
                else if (File.Exists(Program.Shortcut)) File.Delete(Program.Shortcut);
            });
            state.Text = undo
                ? "設定を元に戻しました。\r\nLINEを通常終了して起動し直すと、通常の動作に戻ります。\r\n保存したファイルは残ります。削除方法はREADMEをご覧ください。"
                : "セットアップが完了しました。次回サインインから適用されます。\r\n「LINEを起動」で今すぐ動作を確認できます。\r\n設定を戻すときは、このセットアップをもう一度開いてください。";
        }
        catch (Exception error)
        {
            state.Text = "処理が完了しませんでした。エラー内容を確認してください。";
            MessageBox.Show(this, error.Message, "セットアップのエラー", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            // Only the GUID directory created by this operation is eligible for cleanup.
            string expectedRoot = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "LineTrayStartup-Setup")) + Path.DirectorySeparatorChar;
            if (Path.GetFullPath(temp).StartsWith(expectedRoot, StringComparison.OrdinalIgnoreCase))
                try { Directory.Delete(temp, true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            busy = false;
            RefreshButtons();
        }
    }

    private void StartLine()
    {
        if (LineRunning()) { MessageBox.Show(this, "LINEはすでに起動しています。通知領域のLINEアイコンをダブルクリックしてください。"); return; }
        try { Process.Start(new ProcessStartInfo(Path.Combine(Program.Home, "LineTrayStart.exe")) { UseShellExecute = false, CreateNoWindow = true }); }
        catch (Exception error) { MessageBox.Show(this, error.Message, "LINEの起動エラー"); }
    }
}
