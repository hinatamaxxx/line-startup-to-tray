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
Assert ((Get-StartupRegistryValue -Key $run -Name WindowsLineStartToTray) -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'Independent helper startup is missing.'
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'Native LINE command was unnecessarily replaced.'
Assert ((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)[0] -eq 3) 'Native LINE startup was not disabled.'
Assert ((Get-StartupRegistryValue -Key $approved -Name WindowsLineStartToTray -Kind Binary)[0] -eq 2) 'Helper startup was not enabled.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LineTrayStartup)) 'A duplicate helper startup entry remains.'
# Simulate an updater rewriting LINE's Run value: the independent entry must survive.
Set-StartupRegistryValue -Key $run -Name LINE -Kind String -Value 'updated launcher --booting'
Assert ((Get-StartupRegistryValue -Key $run -Name WindowsLineStartToTray) -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'An update lost the helper route.'
Assert ((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)[0] -eq 3) 'An updated LINE command was enabled.'
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'updated launcher --booting') 'Reinstall overwrote an updated native command.'
Assert ((Get-Content "$homePath\startup-backup.json" -Raw) -eq $firstBackup) 'Second install replaced the original backup.'
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
Assert ([Convert]::ToBase64String((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)) -eq [Convert]::ToBase64String($original)) 'Original state was not restored exactly.'
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'Original LINE command was not restored.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LineTrayStartup)) 'Helper Run entry remains.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name WindowsLineStartToTray)) 'Independent helper Run entry remains.'
Assert ($null -eq (Get-StartupRegistryValue -Key $approved -Name WindowsLineStartToTray -Kind Binary)) 'Independent helper approval remains.'
Assert (!(Test-Path "$homePath\startup-backup.json")) 'A stale backup remains active.'
# Upgrade the prior two-entry installation without replacing its original backup.
$legacyBackup = [ordered]@{Run='original launcher --booting'; Approved=[Convert]::ToBase64String($original); HelperRun=$null; HelperApproved=$null} | ConvertTo-Json
$legacyBackup | Set-Content "$homePath\startup-backup.json" -Encoding UTF8
Set-StartupRegistryValue -Key $run -Name LineTrayStartup -Kind String -Value 'legacy helper command'
Set-StartupRegistryValue -Key $approved -Name LINE -Kind Binary -Value ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0))
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-StartupRegistryValue -Key $run -Name WindowsLineStartToTray) -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'Legacy installation was not migrated.'
Assert ($null -eq (Get-StartupRegistryValue -Key $run -Name LineTrayStartup)) 'Legacy duplicate was not removed.'
$migratedBackup = Get-Content "$homePath\startup-backup.json" -Raw | ConvertFrom-Json
Assert ($migratedBackup.Run -eq 'original launcher --booting' -and $migratedBackup.Approved -eq [Convert]::ToBase64String($original)) 'Migration replaced the original backup.'
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'Migration restore lost the LINE command.'
Assert ([Convert]::ToBase64String((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)) -eq [Convert]::ToBase64String($original)) 'Migration restore lost the original approval.'
# Migrate the preview.4/.5 single-entry setup and preserve original restoration.
$legacyBackup | Set-Content "$homePath\startup-backup.json" -Encoding UTF8
Set-StartupRegistryValue -Key $run -Name LINE -Kind String -Value ('"' + "$homePath\LineTrayStart.exe" + '"')
& "$Payload\Install.ps1" -RegistryPrefix $RegistryPrefix
Assert ((Get-StartupRegistryValue -Key $run -Name LINE) -eq 'original launcher --booting') 'The hijacked LINE entry was not restored during migration.'
Assert ((Get-StartupRegistryValue -Key $approved -Name LINE -Kind Binary)[0] -eq 3) 'Migration left native startup enabled.'
Assert ((Get-StartupRegistryValue -Key $run -Name WindowsLineStartToTray) -eq ('"' + "$homePath\LineTrayStart.exe" + '"')) 'Migration lost the independent entry.'
& "$Payload\Uninstall.ps1" -RegistryPrefix $RegistryPrefix
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
Write-Output 'PASS: loaded-hook rejection, independent startup, updater Run rewrite, idempotence, restore, two-entry and single-entry migration, reinstall, absent-entry restore.'
