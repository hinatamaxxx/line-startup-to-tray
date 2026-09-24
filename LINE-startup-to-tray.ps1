# Run at sign-in: hide LINE's first visible window and keep its tray icon branded.
param(
    [int]$WaitSeconds = 120
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct LineNotifyIconData {
    public uint cbSize;
    public IntPtr hWnd;
    public uint uID;
    public uint uFlags;
    public uint uCallbackMessage;
    public IntPtr hIcon;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string szTip;
    public uint dwState;
    public uint dwStateMask;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string szInfo;
    public uint uTimeoutOrVersion;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string szInfoTitle;
    public uint dwInfoFlags;
    public Guid guidItem;
    public IntPtr hBalloonIcon;
}

public static class LineStartupWindow {
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder name, int maxCount);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool Shell_NotifyIcon(uint message, ref LineNotifyIconData data);

    public static IntPtr FindTrayWindow(int targetProcessId) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            if (processId != (uint)targetProcessId) return true;
            StringBuilder className = new StringBuilder(128);
            GetClassName(hWnd, className, className.Capacity);
            if (className.ToString().IndexOf("TrayIconMessageWindowClass", StringComparison.OrdinalIgnoreCase) >= 0) {
                found = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static bool SetTrayIcon(IntPtr hWnd, IntPtr hIcon) {
        LineNotifyIconData data = new LineNotifyIconData();
        data.cbSize = (uint)Marshal.SizeOf(typeof(LineNotifyIconData));
        data.hWnd = hWnd;
        data.uID = 0;
        data.uFlags = 0x2; // NIF_ICON: preserve LINE's callback, tooltip, and notifications.
        data.hIcon = hIcon;
        data.szTip = String.Empty;
        data.szInfo = String.Empty;
        data.szInfoTitle = String.Empty;
        return Shell_NotifyIcon(0x1, ref data); // NIM_MODIFY
    }
}
'@

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$iconPath = Join-Path $env:LOCALAPPDATA 'LINE\bin\current\assets\StoreLogo.scale-100.png'
$lineLogo = [System.Drawing.Image]::FromFile($iconPath)
$lineIcon = $lineLogo.GetHicon()
$lineLogo.Dispose()
$initialWindowHandled = $false
$lastPatchedProcessId = 0
$lastPatchAt = [DateTime]::MinValue

while ($true) {
    $lineProcesses = @(Get-Process -Name LINE -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$env:LOCALAPPDATA\LINE\bin\*\LINE.exe" })

    foreach ($lineProcess in $lineProcesses) {
        if (-not $initialWindowHandled -and (Get-Date) -lt $deadline) {
            $window = Get-Process -Id $lineProcess.Id -ErrorAction SilentlyContinue
            if ($window -and $window.MainWindowHandle -ne [IntPtr]::Zero -and
                $window.MainWindowTitle -eq 'LINE') {
                $handle = $window.MainWindowHandle
                if ([LineStartupWindow]::IsWindow($handle) -and
                    [LineStartupWindow]::IsWindowVisible($handle)) {
                    [LineStartupWindow]::ShowWindow($handle, 0) | Out-Null
                    [LineStartupWindow]::PostMessage($handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                    $initialWindowHandled = $true
                }
            }
        }

        $now = Get-Date
        if ($lineProcess.Id -ne $lastPatchedProcessId -or ($now - $lastPatchAt).TotalSeconds -ge 10) {
            $trayWindow = [LineStartupWindow]::FindTrayWindow($lineProcess.Id)
            if ($trayWindow -ne [IntPtr]::Zero -and [LineStartupWindow]::SetTrayIcon($trayWindow, $lineIcon)) {
                $lastPatchedProcessId = $lineProcess.Id
                $lastPatchAt = $now
            }
        }
    }

    Start-Sleep -Milliseconds 1000
}
