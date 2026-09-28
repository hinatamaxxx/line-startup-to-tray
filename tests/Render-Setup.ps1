param([string]$Setup, [string]$Output)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$assembly = [Reflection.Assembly]::LoadFrom((Resolve-Path $Setup).Path)
$form = [Activator]::CreateInstance($assembly.GetType('SetupForm'), $true)
$form.ShowInTaskbar = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Location = New-Object Drawing.Point(-32000,-32000)
$form.Show()
[System.Windows.Forms.Application]::DoEvents()
$form.PerformLayout()
$bitmap = New-Object Drawing.Bitmap($form.Width, $form.Height)
$form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
$bitmap.Save($Output, [Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
$form.Dispose()
