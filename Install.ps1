$ErrorActionPreference = 'Stop'
$target = Join-Path $env:LOCALAPPDATA 'LineTrayStartup'
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$entryName = 'LineTrayStartup'
if (!(Test-Path "$env:LOCALAPPDATA\LINE\bin\LineLauncher.exe")) {
    throw 'LINEのランチャーが見つかりません。'
}
$files = 'LineTrayStart.exe', 'LineTrayHook32.dll', 'LineTrayHook64.dll'
# A finite installation check; no process remains to monitor LINE.
$changed = @($files | Where-Object {
    $destination = Join-Path $target $_
    !(Test-Path $destination) -or (Get-FileHash "$PSScriptRoot\dist\$_").Hash -ne (Get-FileHash $destination).Hash
})
if ($changed.Count -and (Get-Process LINE, LineLauncher -ErrorAction SilentlyContinue)) {
    throw '通知領域のメニューからLINEを終了してから実行してください。'
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
$backupPath = Join-Path $target 'startup-backup.json'
if (!(Test-Path $backupPath)) {
    $state = Get-ItemProperty -Path $approved -Name LINE -ErrorAction SilentlyContinue
    $run = Get-ItemProperty -Path $runKey -Name LINE -ErrorAction SilentlyContinue
    [ordered]@{
        Approved = if ($state) { [Convert]::ToBase64String($state.LINE) } else { $null }
        Run = if ($run) { $run.LINE } else { $null }
    } | ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
}
$backup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
if (!$backup.PSObject.Properties['HelperRun']) {
    $helperRun = Get-ItemProperty -Path $runKey -Name $entryName -ErrorAction SilentlyContinue
    $helperState = Get-ItemProperty -Path $approved -Name $entryName -ErrorAction SilentlyContinue
    $backup | Add-Member -NotePropertyName HelperRun -NotePropertyValue $(if ($helperRun) { $helperRun.$entryName } else { $null })
    $backup | Add-Member -NotePropertyName HelperApproved -NotePropertyValue $(if ($helperState) { [Convert]::ToBase64String($helperState.$entryName) } else { $null })
    $backup | ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
}
foreach ($name in $changed) { Copy-Item -LiteralPath "$PSScriptRoot\dist\$name" -Destination $target }
if (!(Test-Path $runKey)) { New-Item -Path $runKey -Force | Out-Null }
if (!(Test-Path $approved)) { New-Item -Path $approved -Force | Out-Null }
New-ItemProperty -Path $runKey -Name $entryName -PropertyType String -Value ('"' + (Join-Path $target 'LineTrayStart.exe') + '"') -Force | Out-Null
New-ItemProperty -Path $approved -Name $entryName -PropertyType Binary -Value ([byte[]](2,0,0,0,0,0,0,0,0,0,0,0)) -Force | Out-Null
# Leave LINE's original command intact; disable its duplicate automatic launch.
New-ItemProperty -Path $approved -Name LINE -PropertyType Binary -Value ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0)) -Force | Out-Null
$oldTask = Get-ScheduledTask -TaskName 'LINE startup to tray' -ErrorAction SilentlyContinue
if ($oldTask) { Unregister-ScheduledTask -TaskName 'LINE startup to tray' -Confirm:$false }
Write-Output 'Windowsのスタートアップに登録しました。次回サインインから適用されます。'
