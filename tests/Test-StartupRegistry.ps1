$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\StartupRegistry.ps1')

function Assert-Registry($Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
}

$testId = [Guid]::NewGuid().ToString('N')
$testKey = 'Software\WindowsLineStartup.Tests\' + $testId
$testSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$physicalKey = $testSid + '\' + $testKey
$physicalArguments = @{ hDefKey = [uint32]2147483651; sSubKeyName = $physicalKey }

try {
    Assert-Registry ($null -eq (Get-StartupRegistryValue -Key $testKey -Name Text)) 'An absent key returned a value.'
    Remove-StartupRegistryValue -Key $testKey -Name Missing
    $text = '"C:\Program Files\WindowsLineStartup.Tests\example.exe" --booting'
    Set-StartupRegistryValue -Key $testKey -Name Text -Kind String -Value $text
    $rawText = Invoke-CimMethod -Namespace root/default -ClassName StdRegProv -MethodName GetStringValue -Arguments ($physicalArguments + @{ sValueName = 'Text' })
    Assert-Registry ($rawText.ReturnValue -eq 0 -and $rawText.sValue -ceq $text) 'The physical string read-back did not match.'
    Assert-Registry ((Get-StartupRegistryValue -Key $testKey -Name Text) -ceq $text) 'The helper string read-back did not match.'

    Set-StartupRegistryValue -Key $testKey -Name EmptyText -Kind String -Value ''
    Assert-Registry ((Get-StartupRegistryValue -Key $testKey -Name EmptyText) -ceq '') 'An empty string was not preserved.'

    $binary = [byte[]](2,0,0,0,1,2,3,4,5,6,7,255)
    Set-StartupRegistryValue -Key $testKey -Name Binary -Kind Binary -Value $binary
    $rawBinary = Invoke-CimMethod -Namespace root/default -ClassName StdRegProv -MethodName GetBinaryValue -Arguments ($physicalArguments + @{ sValueName = 'Binary' })
    Assert-Registry ($rawBinary.ReturnValue -eq 0 -and [Convert]::ToBase64String([byte[]]$rawBinary.uValue) -eq [Convert]::ToBase64String($binary)) 'The physical binary read-back did not match.'
    $returnedBinary = Get-StartupRegistryValue -Key $testKey -Name Binary -Kind Binary
    Assert-Registry ($returnedBinary -is [byte[]]) 'The helper did not return a byte array.'
    Assert-Registry ([Convert]::ToBase64String($returnedBinary) -eq [Convert]::ToBase64String($binary)) 'The helper binary read-back did not match.'

    Assert-Registry ($null -eq (Get-StartupRegistryValue -Key $testKey -Name Missing -Kind Binary)) 'An absent value returned binary data.'
    Remove-StartupRegistryValue -Key $testKey -Name Missing
    Remove-StartupRegistryValue -Key $testKey -Name Text
    Remove-StartupRegistryValue -Key $testKey -Name Binary
    Remove-StartupRegistryValue -Key $testKey -Name EmptyText
    Remove-StartupRegistryValue -Key $testKey -Name Text
    Assert-Registry ($null -eq (Get-StartupRegistryValue -Key $testKey -Name Text)) 'The deleted string value remains.'
    Assert-Registry ($null -eq (Get-StartupRegistryValue -Key $testKey -Name Binary -Kind Binary)) 'The deleted binary value remains.'
    $remaining = Invoke-CimMethod -Namespace root/default -ClassName StdRegProv -MethodName EnumValues -Arguments $physicalArguments
    Assert-Registry ($remaining.ReturnValue -eq 0 -and ($null -eq $remaining.sNames -or @($remaining.sNames).Count -eq 0)) 'Values remain in the physical test key.'
    Write-Output 'PASS: physical WMI string/binary writes and reads, empty string, absent values, idempotent removal.'
} finally {
    # Never delete a key unless it is exactly this invocation's isolated GUID key.
    $expectedKey = $testSid + '\Software\WindowsLineStartup.Tests\' + $testId
    if ($physicalKey -eq $expectedKey -and $testId -match '^[a-f0-9]{32}$') {
        $cleanup = Invoke-CimMethod -Namespace root/default -ClassName StdRegProv -MethodName DeleteKey -Arguments $physicalArguments
        if ($cleanup.ReturnValue -ne 0 -and $cleanup.ReturnValue -ne 2) { throw "Test key cleanup failed (Windows error $($cleanup.ReturnValue))." }
    } else {
        throw 'Refused to clean up a registry key outside the isolated test key.'
    }
}
