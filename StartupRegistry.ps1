# Use the system registry provider so a packaged caller cannot redirect startup
# settings into its private HKCU view. Target only the current user's real hive.
$script:StartupRegistryUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$script:StartupRegistryHive = [uint32]2147483651 # HKEY_USERS

function Invoke-StartupRegistryMethod {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Key,
        [hashtable]$Arguments = @{},
        [switch]$AllowMissing
    )
    if ([string]::IsNullOrWhiteSpace($Key) -or $Key -match '^(?:\\|HKEY_|HK[A-Z]+:)') {
        throw 'Supply a relative registry key, such as Software\Microsoft\Windows\CurrentVersion\Run.'
    }
    $parameters = @{
        hDefKey = $script:StartupRegistryHive
        sSubKeyName = $script:StartupRegistryUserSid + '\' + $Key
    }
    foreach ($name in $Arguments.Keys) { $parameters[$name] = $Arguments[$name] }
    $result = Invoke-CimMethod -Namespace root/default -ClassName StdRegProv -MethodName $Method -Arguments $parameters -ErrorAction Stop
    if ($result.ReturnValue -ne 0 -and !($AllowMissing -and $result.ReturnValue -eq 2)) {
        throw "System registry operation $Method failed (Windows error $($result.ReturnValue))."
    }
    return $result
}

function Get-StartupRegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateSet('String', 'Binary')][string]$Kind = 'String'
    )
    # Some providers return ERROR_INVALID_FUNCTION for an absent binary value.
    # Enumerate names first so absence is distinct from a genuine read failure.
    $values = Invoke-StartupRegistryMethod -Method EnumValues -Key $Key -AllowMissing
    if ($values.ReturnValue -eq 2 -or $values.sNames -notcontains $Name) { return $null }
    $method = if ($Kind -eq 'Binary') { 'GetBinaryValue' } else { 'GetStringValue' }
    $result = Invoke-StartupRegistryMethod -Method $method -Key $Key -Arguments @{ sValueName = $Name } -AllowMissing
    if ($result.ReturnValue -eq 2) { return $null }
    if ($Kind -eq 'Binary') { return ,([byte[]]$result.uValue) }
    return $result.sValue
}

function Set-StartupRegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('String', 'Binary')][string]$Kind,
        [Parameter(Mandatory = $true)][AllowEmptyString()][AllowEmptyCollection()][object]$Value
    )
    Invoke-StartupRegistryMethod -Method CreateKey -Key $Key | Out-Null
    if ($Kind -eq 'Binary') {
        $expected = [byte[]]$Value
        Invoke-StartupRegistryMethod -Method SetBinaryValue -Key $Key -Arguments @{ sValueName = $Name; uValue = $expected } | Out-Null
        $actual = Get-StartupRegistryValue -Key $Key -Name $Name -Kind Binary
        if ($null -eq $actual -or [Convert]::ToBase64String($actual) -ne [Convert]::ToBase64String($expected)) {
            throw 'The system registry binary value did not match after writing.'
        }
    } else {
        $expected = [string]$Value
        Invoke-StartupRegistryMethod -Method SetStringValue -Key $Key -Arguments @{ sValueName = $Name; sValue = $expected } | Out-Null
        $actual = Get-StartupRegistryValue -Key $Key -Name $Name -Kind String
        if ($null -eq $actual -or $actual -cne $expected) {
            throw 'The system registry string value did not match after writing.'
        }
    }
}

function Remove-StartupRegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Name
    )
    Invoke-StartupRegistryMethod -Method DeleteValue -Key $Key -Arguments @{ sValueName = $Name } -AllowMissing | Out-Null
    $remaining = Invoke-StartupRegistryMethod -Method EnumValues -Key $Key -AllowMissing
    if ($remaining.ReturnValue -eq 0 -and $remaining.sNames -contains $Name) {
        throw 'The system registry value remains after deletion.'
    }
}
