param(
    [string]$AppSource = '',
    [string]$FeatureSource = '',
    [string]$FeatureSourceName = 'feature_graphic_original.png',
    [string]$FeatureOutputName = 'feature_graphic.png',
    [switch]$FeatureOnly
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$brandOutput = Join-Path $taskRoot 'store/branding'
$sourceOutput = Join-Path $brandOutput 'source'
$gameOutput = Join-Path $taskRoot 'Assets/Brand'
New-Item -ItemType Directory -Path $sourceOutput, $gameOutput -Force | Out-Null

if ($AppSource) { Copy-Item -LiteralPath $AppSource -Destination (Join-Path $sourceOutput 'app_icon_original.png') }
foreach ($fileName in @($FeatureSourceName, $FeatureOutputName)) {
    if ([IO.Path]::GetFileName($fileName) -ne $fileName) { throw 'Brand filenames must stay in their output directories.' }
}
if ($FeatureSource) { Copy-Item -LiteralPath $FeatureSource -Destination (Join-Path $sourceOutput $FeatureSourceName) }

function Export-PngSize {
    param([string]$InputPath, [string]$OutputPath, [int]$Width, [int]$Height, [bool]$Alpha)
    $sourceBitmap = [System.Drawing.Image]::FromFile($InputPath)
    $pixelFormat = if ($Alpha) { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
    $targetBitmap = [System.Drawing.Bitmap]::new($Width, $Height, $pixelFormat)
    $graphics = [System.Drawing.Graphics]::FromImage($targetBitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 15, 143, 157))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        # Preserve aspect ratio. The generated banner differs by less than one source pixel.
        $scale = [Math]::Max($Width / $sourceBitmap.Width, $Height / $sourceBitmap.Height)
        $drawWidth = $sourceBitmap.Width * $scale
        $drawHeight = $sourceBitmap.Height * $scale
        $destination = [System.Drawing.RectangleF]::new([single](($Width - $drawWidth) / 2), [single](($Height - $drawHeight) / 2), [single]$drawWidth, [single]$drawHeight)
        $graphics.DrawImage($sourceBitmap, $destination)
        $targetBitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $targetBitmap.Dispose()
        $sourceBitmap.Dispose()
    }
}

if (-not $FeatureOnly) {
    Export-PngSize (Join-Path $sourceOutput 'app_icon_original.png') (Join-Path $brandOutput 'app_icon.png') 512 512 $true
    Copy-Item -LiteralPath (Join-Path $brandOutput 'app_icon.png') -Destination (Join-Path $gameOutput 'app_icon.png')
    Export-PngSize (Join-Path $sourceOutput 'app_icon_original.png') (Join-Path $gameOutput 'launcher_icon.png') 192 192 $true
}
Export-PngSize (Join-Path $sourceOutput $FeatureSourceName) (Join-Path $brandOutput $FeatureOutputName) 1024 500 $false
Get-Item -LiteralPath (Join-Path $brandOutput 'app_icon.png'), (Join-Path $brandOutput $FeatureOutputName), (Join-Path $gameOutput 'launcher_icon.png') | Select-Object Name, Length
