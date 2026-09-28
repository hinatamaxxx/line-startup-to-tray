param([string]$Output = (Join-Path $PSScriptRoot 'app.ico'))
Add-Type -AssemblyName PresentationCore, WindowsBase
$visual = New-Object Windows.Media.DrawingVisual
$draw = $visual.RenderOpen()
$green = New-Object Windows.Media.SolidColorBrush([Windows.Media.ColorConverter]::ConvertFromString('#11734E'))
$draw.DrawRoundedRectangle($green,$null,(New-Object Windows.Rect(0,0,64,64)),14,14)
$pen = New-Object Windows.Media.Pen([Windows.Media.Brushes]::White,3.5)
$pen.StartLineCap = 'Round'; $pen.EndLineCap = 'Round'; $pen.LineJoin = 'Round'
$geometry = [Windows.Media.Geometry]::Parse('M16,35 L16,46 L48,46 L48,35 M32,16 L32,37 M23,28 L32,37 L41,28')
$draw.DrawGeometry($null,$pen,$geometry)
$draw.Close()
$image = New-Object Windows.Media.Imaging.RenderTargetBitmap(64,64,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$image.Render($visual)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image))
$png = New-Object IO.MemoryStream
$encoder.Save($png)
$bytes = $png.ToArray(); $png.Dispose()
$stream = [IO.File]::Create($Output)
$writer = New-Object IO.BinaryWriter($stream)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
$writer.Write([byte]64); $writer.Write([byte]64); $writer.Write([byte]0); $writer.Write([byte]0)
$writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$bytes.Length); $writer.Write([uint32]22)
$writer.Write($bytes); $writer.Dispose()
