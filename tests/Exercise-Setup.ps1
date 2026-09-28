param([string]$Payload, [string]$DataRoot, [string]$RegistryPath)
$ErrorActionPreference = 'Stop'
function Assert($condition, [string]$message) { if (!$condition) { throw $message } }
# Remap only this test process's PowerShell registry drive, never the real Run keys.
Remove-PSDrive HKCU
New-PSDrive -Name HKCU -PSProvider Registry -Root ("HKEY_CURRENT_USER\" + $RegistryPath) | Out-Null
$env:LOCALAPPDATA = $DataRoot
function Get-ScheduledTask { return @() }
function Get-Process { return @() }
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
New-Item $run -Force | Out-Null
New-Item $approved -Force | Out-Null
New-Item "$DataRoot\LINE\bin" -ItemType Directory -Force | Out-Null
New-Item "$DataRoot\LINE\bin\LineLauncher.exe" -ItemType File | Out-Null
$original = [byte[]](2,0,0,0,1,2,3,4,5,6,7,8)
New-ItemProperty $run -Name LINE -Value 'original launcher --booting' -PropertyType String | Out-Null
New-ItemProperty $approved -Name LINE -Value $original -PropertyType Binary | Out-Null
function Get-Process { return [pscustomobject]@{ Id = 123 } }
$rejected = $false
try { & "$Payload\Install.ps1" } catch { $rejected = $_.Exception.Message -like '*LINE*' }
Assert $rejected 'Installation must reject a running LINE before mutation.'
Assert (!(Test-Path "$DataRoot\LineTrayStartup\startup-backup.json")) 'Rejected install wrote a backup.'
function Get-Process { return @() }
& "$Payload\Install.ps1"
$homePath = "$DataRoot\LineTrayStartup"
$firstBackup = Get-Content "$homePath\startup-backup.json" -Raw
Assert ((Get-ItemProperty $run).LINE -eq 'original launcher --booting') 'Original Run command changed.'
Assert ((Get-ItemProperty $approved).LINE[0] -eq 3) 'Duplicate startup was not disabled.'
Assert ((Get-ItemProperty $approved).LineTrayStartup[0] -eq 2) 'New startup was not enabled.'
Assert ((Get-ItemProperty $run).LineTrayStartup -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'Helper startup command is incorrect.'
& "$Payload\Install.ps1"
Assert ((Get-Content "$homePath\startup-backup.json" -Raw) -eq $firstBackup) 'Second install replaced the original backup.'
& "$Payload\Uninstall.ps1"
Assert ([Convert]::ToBase64String((Get-ItemProperty $approved).LINE) -eq [Convert]::ToBase64String($original)) 'Original state was not restored exactly.'
Assert ($null -eq (Get-ItemProperty $run).LineTrayStartup) 'Helper Run entry remains.'
Assert (!(Test-Path "$homePath\startup-backup.json")) 'A stale backup remains active.'
$newState = [byte[]](3,0,0,0,8,7,6,5,4,3,2,1)
Set-ItemProperty $approved -Name LINE -Value $newState
& "$Payload\Install.ps1"
& "$Payload\Uninstall.ps1"
Assert ([Convert]::ToBase64String((Get-ItemProperty $approved).LINE) -eq [Convert]::ToBase64String($newState)) 'Reinstall did not capture the newer settings.'
Write-Output 'PASS: running-app rejection, installation, idempotence, restore, reinstall.'
