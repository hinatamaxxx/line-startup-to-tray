param([string]$RegistryPrefix = '')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\StartupRegistry.ps1"
if (!$RegistryPrefix -and $env:CODEX_WINDOWS_SANDBOX_PACKAGE_FAMILY) { throw 'セットアップEXEから実行してください。Windowsの実際の保存先へ適用する必要があります。' }
$target = Join-Path $env:LOCALAPPDATA 'LineTrayStartup'
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$approved = $RegistryPrefix + 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$runKey = $RegistryPrefix + 'Software\Microsoft\Windows\CurrentVersion\Run'
$entryName = 'LineTrayStartup'
if (!(Test-Path "$env:LOCALAPPDATA\LINE\bin\LineLauncher.exe")) {
    throw 'LINEのランチャーが見つかりません。'
}
$files = 'LineTrayStart.exe', 'LineTrayHook32.dll', 'LineTrayHook64.dll'
foreach ($name in $files) {
    if (!(Test-Path -LiteralPath "$PSScriptRoot\dist\$name" -PathType Leaf)) { throw "セットアップに必要なファイルがありません: $name" }
}
# A finite installation check; no process remains to monitor LINE.
$changed = @($files | Where-Object {
    $destination = Join-Path $target $_
    !(Test-Path $destination) -or (Get-FileHash "$PSScriptRoot\dist\$_").Hash -ne (Get-FileHash $destination).Hash
})
if ($changed.Count -and @(Get-Process LINE, LineLauncher -ErrorAction SilentlyContinue | ForEach-Object { $_.Modules } | Where-Object { $_.ModuleName -match '^LineTrayHook(?:32|64)\.dll$' }).Count) {
    throw '通知領域のメニューからLINEを終了してから実行してください。'
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
$backupPath = Join-Path $target 'startup-backup.json'
if (!(Test-Path $backupPath)) {
    $state = Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary
    $run = Get-StartupRegistryValue -Key $runKey -Name LINE
    [ordered]@{
        Approved = if ($null -ne $state) { [Convert]::ToBase64String($state) } else { $null }
        Run = $run
    } | ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
}
$backup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
if (!$backup.PSObject.Properties['HelperRun']) {
    $helperRun = Get-StartupRegistryValue -Key $runKey -Name $entryName
    $helperState = Get-StartupRegistryValue -Key $approved -Name $entryName -Kind Binary
    $backup | Add-Member -NotePropertyName HelperRun -NotePropertyValue $helperRun
    $backup | Add-Member -NotePropertyName HelperApproved -NotePropertyValue $(if ($null -ne $helperState) { [Convert]::ToBase64String($helperState) } else { $null })
    $backup | ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
}
foreach ($name in $changed) { Copy-Item -LiteralPath "$PSScriptRoot\dist\$name" -Destination $target }
# Route the existing LINE startup entry through the helper, with one launch path.
Set-StartupRegistryValue -Key $runKey -Name LINE -Kind String -Value ('"' + (Join-Path $target 'LineTrayStart.exe') + '"')
Set-StartupRegistryValue -Key $approved -Name LINE -Kind Binary -Value ([byte[]](2,0,0,0,0,0,0,0,0,0,0,0))
Remove-StartupRegistryValue -Key $runKey -Name $entryName
Remove-StartupRegistryValue -Key $approved -Name $entryName
$oldTask = Get-ScheduledTask -TaskName 'LINE startup to tray' -ErrorAction SilentlyContinue
if ($oldTask) { Unregister-ScheduledTask -TaskName 'LINE startup to tray' -Confirm:$false }
Write-Output 'Windowsのスタートアップに登録しました。次回サインインから適用されます。'
