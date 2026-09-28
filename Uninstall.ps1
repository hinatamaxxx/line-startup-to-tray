$ErrorActionPreference = 'Stop'
$target = Join-Path $env:LOCALAPPDATA 'LineTrayStartup'
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$backupPath = Join-Path $target 'startup-backup.json'
if (!(Test-Path $backupPath)) { throw '自動起動設定のバックアップが見つかりません。' }
$backup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
if ($null -ne $backup.HelperRun) {
    New-ItemProperty -Path $runKey -Name LineTrayStartup -PropertyType String -Value $backup.HelperRun -Force | Out-Null
} else {
    Remove-ItemProperty -Path $runKey -Name LineTrayStartup -ErrorAction SilentlyContinue
}
if ($null -ne $backup.HelperApproved) {
    New-ItemProperty -Path $approved -Name LineTrayStartup -PropertyType Binary -Value ([Convert]::FromBase64String($backup.HelperApproved)) -Force | Out-Null
} else {
    Remove-ItemProperty -Path $approved -Name LineTrayStartup -ErrorAction SilentlyContinue
}
if ($null -ne $backup.Approved) {
    New-ItemProperty -Path $approved -Name LINE -PropertyType Binary -Value ([Convert]::FromBase64String($backup.Approved)) -Force | Out-Null
} else {
    Remove-ItemProperty -Path $approved -Name LINE -ErrorAction SilentlyContinue
}
# A later installation must capture the user's then-current settings again.
Move-Item -LiteralPath $backupPath -Destination (Join-Path $target 'startup-backup.restored.json') -Force
Write-Output 'LINE本来の自動起動設定に戻しました。LINEを通常終了して再起動するとフックも外れます。'
