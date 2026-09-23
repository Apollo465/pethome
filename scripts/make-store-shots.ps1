# Compose AppGallery store screenshots (1080x1920) from raw device screenshots.
#
# Uses System.Drawing (GDI+), so no extra Python packages are needed.
# Titles/subtitles come from design/store/promo_titles.json (UTF-8) to keep this
# script ASCII-only (Windows PowerShell 5.1 reads non-BOM .ps1 as ANSI).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\make-store-shots.ps1

param(
    [string]$StoreDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'design\store')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$W = 1080
$H = 1920
$shotW = 760
$shotH = 1565           # 1320x2719 scaled to width 760
$shotX = [int](($W - $shotW) / 2)
$shotY = 356
$radius = 44
$statusBar = 137

$outDir = Join-Path $StoreDir 'out'
$shotsDir = Join-Path $StoreDir 'shots\new'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outDir 'screenshots') | Out-Null

$pages = Get-Content (Join-Path $StoreDir 'promo_titles.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function New-RoundedPath([int]$x, [int]$y, [int]$w, [int]$h, [int]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

$brand = ''
$index = 0
foreach ($page in $pages) {
    $index++
    if ($page.brand) { $brand = $page.brand }
    $src = Join-Path $shotsDir $page.shot
    if (-not (Test-Path $src)) { throw "Missing screenshot: $src" }

    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    # 每张用不同底色：一是区分度更好，二是避免应用市场把同模板的图判成"重复"
    $bgColor = [System.Drawing.ColorTranslator]::FromHtml($page.bg)
    $glowColor = [System.Drawing.ColorTranslator]::FromHtml($page.glow)
    $g.Clear($bgColor)

    # soft warm glow at the top
    $glowRect = New-Object System.Drawing.Rectangle 0, 0, $W, 620
    $glowBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $glowRect,
        $glowColor,
        [System.Drawing.Color]::FromArgb(0, $bgColor),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $g.FillRectangle($glowBrush, $glowRect)
    $glowBrush.Dispose()

    # brand mark + name
    $markPath = New-RoundedPath 96 88 72 72 22
    $markBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 138, 91))
    $g.FillPath($markBrush, $markPath)
    $markBrush.Dispose()
    $markPath.Dispose()

    $fontBold = New-Object System.Drawing.Font 'Microsoft YaHei', 40, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontTitle = New-Object System.Drawing.Font 'Microsoft YaHei', 62, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontSub = New-Object System.Drawing.Font 'Microsoft YaHei', 30, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 31, 27, 24))
    $subBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 138, 128, 120))

    $g.DrawString($brand, $fontBold, $textBrush, 192, 100)
    $g.DrawString($page.title, $fontTitle, $textBrush, 92, 205)
    $g.DrawString($page.subtitle, $fontSub, $subBrush, 96, 300)

    # screenshot: crop the status bar, scale, round the corners, add a soft shadow
    $raw = [System.Drawing.Image]::FromFile($src)
    $cropW = $raw.Width
    $cropH = $raw.Height - $statusBar
    $cropRect = New-Object System.Drawing.Rectangle 0, $statusBar, $cropW, $cropH
    $card = New-Object System.Drawing.Bitmap $shotW, $shotH
    $gCard = [System.Drawing.Graphics]::FromImage($card)
    $gCard.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gCard.DrawImage($raw, (New-Object System.Drawing.Rectangle 0, 0, $shotW, $shotH), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $gCard.Dispose()

    # 阴影与裁剪都必须用「屏幕坐标」的圆角路径，否则会偏出卡片
    $cardPath = New-RoundedPath $shotX $shotY $shotW $shotH $radius
    $shadowPath = New-RoundedPath ($shotX + 8) ($shotY + 20) $shotW $shotH $radius
    $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(46, 138, 58, 18))
    $g.FillPath($shadowBrush, $shadowPath)
    $shadowBrush.Dispose()
    $shadowPath.Dispose()

    $state = $g.Save()
    $g.SetClip($cardPath)
    $g.DrawImage($card, $shotX, $shotY, $shotW, $shotH)
    $g.Restore($state)

    $cardPath.Dispose()
    $card.Dispose()
    $raw.Dispose()

    $dest = Join-Path $outDir ("promo-{0}.png" -f $index)
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("wrote {0}" -f $dest)

    $fontBold.Dispose(); $fontTitle.Dispose(); $fontSub.Dispose()
    $textBrush.Dispose(); $subBrush.Dispose()
    $g.Dispose(); $bmp.Dispose()
}
