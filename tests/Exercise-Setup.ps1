param([string]$Payload, [string]$DataRoot, [Parameter(Mandatory = $true)][string]$RegistryPrefix)
$ErrorActionPreference = 'Stop'
function Assert($condition, [string]$message) { if (!$condition) { throw $message } }
# Every registry operation must stay below this invocation's isolated GUID key.
if ($RegistryPrefix -notmatch '^Software\\LineTrayStartup\.Tests\\[a-f0-9]{32}\\$') {
    throw 'The test registry prefix must be an isolated GUID key.'
}
. "$Payload\StartupRegistry.ps1"
$env:LOCALAPPDATA = $DataRoot
function Get-ScheduledTask { return @() }
function Get-Process { return @() }
$run = $RegistryPrefix + 'Software\Microsoft\Windows\CurrentVersion\Run'
$approved = $RegistryPrefix + 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
New-Item "$DataRoot\LINE\bin" -ItemType Directory -Force | Out-Null
New-Item "$DataRoot\LINE\bin\LineLauncher.exe" -ItemType File | Out-Null
$original = [byte[]](2,0,0,0,1,2,3,4,5,6,7,8)
Set-StartupRegistryValue -Key $run -Name LINE -Kind String -Value 'original launcher --booting'
Set-StartupRegistryValue -Key $approved -Name LINE -Kind Binary -Value $original
function Get-Process { return [pscustomobject]@{ Id = 123; Modules = @([pscustomobject]@{ ModuleName = 'LineTrayHook64.dll' }) } }
$rejected = $false
try { & "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix } catch { $rejected = $_.Exception.Message -like '*LINE*' }
Assert $rejected 'Installation must reject replacing a hook loaded by LINE before mutation.'
Assert (!(Test-Path "$DataRoot\LineTrayStartup\startup-backup.json")) 'Rejected install wrote a backup.'
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'Rejected install changed the physical LINE command.'
# An unhooked LINE does not hold these files open; initial setup is safe.
function Get-Process { return [pscustomobject]@{ Id = 123; Modules = @([pscustomobject]@{ ModuleName = 'kernel32.dll' }) } }
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
function Get-Process { return @() }
$homePath = "$DataRoot\LineTrayStartup"
$firstBackup = Get-Content "$homePath\startup-backup.json" -Raw
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'LINE startup does not route through the helper.'
Assert ((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)[0] -eq 2) 'LINE startup was not enabled.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LineTrayStartup)) 'A duplicate helper startup entry remains.'
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-Content "$homePath\startup-backup.json" -Raw) -eq $firstBackup) 'Second install replaced the original backup.'
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
Assert ([Convert]::ToBase64String((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)) -eq [Convert]::ToBase64String($original)) 'Original state was not restored exactly.'
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'Original LINE command was not restored.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LineTrayStartup)) 'Helper Run entry remains.'
Assert (!(Test-Path "$homePath\startup-backup.json")) 'A stale backup remains active.'
# Upgrade the prior two-entry installation without replacing its original backup.
$legacyBackup = [ordered]@{Run='original launcher --booting'; Approved=[Convert]::ToBase64String($original); HelperRun=$null; HelperApproved=$null} | ConvertTo-Json
$legacyBackup | Set-Content "$homePath\startup-backup.json" -Encoding UTF8
Set-StartupRegistryValue -Key $run -Name LineTrayStartup -Kind String -Value 'legacy helper command'
Set-StartupRegistryValue -Key $approved -Name LINE -Kind Binary -Value ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0))
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'Legacy installation was not migrated.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LineTrayStartup)) 'Legacy duplicate was not removed.'
Assert ((Get-Content "$homePath\startup-backup.json" -Raw).Trim() -eq $legacyBackup.Trim()) 'Migration replaced the original backup.'
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'Migration restore lost the LINE command.'
Assert ([Convert]::ToBase64String((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)) -eq [Convert]::ToBase64String($original)) 'Migration restore lost the original approval.'
$newState = [byte[]](3,0,0,0,8,7,6,5,4,3,2,1)
Set-StartupRegistryValue -Key $approved -Name LINE -Kind Binary -Value $newState
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
Assert ([Convert]::ToBase64String((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)) -eq [Convert]::ToBase64String($newState)) 'Reinstall did not capture the newer settings.'
Remove-StartupRegistryValue -Key $run -Name LINE
Remove-StartupRegistryValue -Key $approved -Name LINE
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LINE)) 'Restore created a LINE command absent before install.'
Assert ($null -eq (Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)) 'Restore created a LINE approval absent before install.'
Write-Output 'PASS: loaded-hook rejection, unhooked running LINE accepted, physical startup route, idempotence, restore, legacy migration, reinstall, absent-entry restore.'
