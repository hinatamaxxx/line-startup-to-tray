param([string]$Setup, [string]$Output, [ValidateSet('Light','Dark')][string]$Theme = 'Light', [double]$Width = 744, [double]$Height = 748)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$assembly = [Reflection.Assembly]::LoadFrom((Resolve-Path $Setup).Path)
$window = [Activator]::CreateInstance($assembly.GetType('SetupWindow'), $true)
$window.ShowInTaskbar = $false
$window.WindowStartupLocation = [Windows.WindowStartupLocation]::Manual
$window.Left = -32000
$window.Top = -32000
$window.Width = $Width
$window.Height = $Height
$assembly.GetType('SetupWindow').GetMethod('SetTheme',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($window,@($Theme -eq 'Dark')) | Out-Null
$window.Show()
$window.UpdateLayout()
$window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Render)
$bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($window)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream = [IO.File]::Create($Output)
$encoder.Save($stream)
$stream.Dispose()
$window.Close()
