param([string]$Setup = (Join-Path $PSScriptRoot '..\release\WindowsLineStartToTray-Setup-0.2.0-preview.4.exe'))
$ErrorActionPreference = 'Stop'
$Setup = (Resolve-Path $Setup).Path
$id = [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("LineTrayStartup-Test-$id")
$registryPath = "Software\LineTrayStartup.Tests\$id"
New-Item -ItemType Directory -Path $testRoot | Out-Null
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($registryPath); $key.Close()
try {
    $payload = Join-Path $testRoot 'payload'
    $process = Start-Process -FilePath $Setup -ArgumentList @('--extract', ('"' + $payload + '"')) -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'Payload extraction failed.' }
    foreach ($name in 'LineTrayStart.exe','LineTrayHook32.dll','LineTrayHook64.dll') {
        if ((Get-FileHash "$payload\dist\$name").Hash -ne (Get-FileHash "$PSScriptRoot\..\dist\$name").Hash) { throw "Payload mismatch: $name" }
    }
    $powershell = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    & $powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Exercise-Setup.ps1" -Payload $payload -DataRoot "$testRoot\data" -RegistryPath $registryPath
    if ($LASTEXITCODE -ne 0) { throw 'Isolated install/restore test failed.' }
    $assembly = [Reflection.Assembly]::LoadFrom($Setup)
    $method = $assembly.GetType('Program').GetMethod('SaveSupportFiles', [Reflection.BindingFlags]'NonPublic,Static')
    $homePath = "$testRoot\data\LineTrayStartup"
    $shortcutPath = "$testRoot\setup.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $legacyPath = "$testRoot\LINE Tray Startup.lnk"
    $legacy = $shell.CreateShortcut($legacyPath)
    $legacy.TargetPath = "$homePath\Setup.exe"
    $legacy.Save()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($legacy)
    $method.Invoke($null, [object[]]@([string]$payload, [string]$homePath, [string]$Setup, [string]$shortcutPath)) | Out-Null
    if (Test-Path -LiteralPath $legacyPath) { throw 'Legacy shortcut was not migrated.' }
    $legacy = $shell.CreateShortcut($legacyPath)
    $legacy.TargetPath = "$testRoot\unrelated.exe"
    $legacy.Save()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($legacy)
    $method.Invoke($null, [object[]]@([string]$payload, [string]$homePath, [string]$Setup, [string]$shortcutPath)) | Out-Null
    if (!(Test-Path -LiteralPath $legacyPath)) { throw 'Unrelated shortcut was removed.' }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ($shortcut.TargetPath -ne "$homePath\Setup.exe") { throw 'Start menu shortcut target mismatch.' }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    Write-Output 'PASS: embedded payload hashes, setup shortcut, legacy migration, unrelated shortcut preserved.'
} finally {
    if ($registryPath -match '^Software\\LineTrayStartup\.Tests\\[a-f0-9]{32}$') { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($registryPath, $false) }
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $expected = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ("LineTrayStartup-Test-$id")))
    if ($resolved -eq $expected -and (Test-Path -LiteralPath $resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
