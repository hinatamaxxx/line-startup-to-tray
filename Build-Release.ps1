param([switch]$SkipNativeBuild)
$ErrorActionPreference = 'Stop'
$version = '0.2.0-preview.1'
Push-Location $PSScriptRoot
try {
    if (!$SkipNativeBuild) {
        & cmd.exe /c build.cmd
        if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
    }
    New-Item -ItemType Directory -Path release -Force | Out-Null
    $output = Join-Path $PSScriptRoot "release\LineTrayStartup-Setup-$version.exe"
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $arguments = @('/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/utf8output', '/win32manifest:setup\app.manifest', "/out:$output",
        '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll', '/reference:System.Core.dll',
        '/resource:Install.ps1,Install.ps1', '/resource:Uninstall.ps1,Uninstall.ps1', '/resource:setup\GUIDE.txt,GUIDE.txt',
        '/resource:dist\LineTrayStart.exe,LineTrayStart.exe', '/resource:dist\LineTrayHook32.dll,LineTrayHook32.dll',
        '/resource:dist\LineTrayHook64.dll,LineTrayHook64.dll', '/resource:LICENSE,LICENSE.txt',
        '/resource:third_party\Detours\LICENSE.md,Detours-LICENSE.txt', 'setup\Setup.cs')
    & $compiler @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Setup build failed.' }
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($output))" | Set-Content release\SHA256SUMS.txt -Encoding ASCII
    Write-Output $output
} finally { Pop-Location }
