param([string]$AssetDirectory = (Join-Path $PSScriptRoot '../src/AsliApp.Api/Education/SeedAssets/Pain'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$data = Get-Content -Raw -Encoding utf8 (Join-Path $AssetDirectory 'lesson.json') | ConvertFrom-Json
foreach ($visual in $data.visuals) {
    $bitmap = [System.Drawing.Bitmap]::new(1080, 900)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F5F7FA'))
    $ink = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#203849'))
    $accent = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#197D84'))
    $soft = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#E0EEF0'))
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $titleFont = [System.Drawing.Font]::new('Segoe UI', 39, [System.Drawing.FontStyle]::Bold)
    $bodyFont = [System.Drawing.Font]::new('Segoe UI', 22)
    $smallFont = [System.Drawing.Font]::new('Segoe UI', 19)
    $graphics.FillRectangle($accent, 0, 0, 1080, 14)
    $graphics.DrawString('ASLI APP  /  AĞRI VE KONFOR', $smallFont, $accent, 62, 45)
    $graphics.DrawString($visual.title, $titleFont, $ink, [System.Drawing.RectangleF]::new(60,105,960,150))
    $graphics.DrawString($visual.caption, $smallFont, $ink, [System.Drawing.RectangleF]::new(62,265,950,90))
    for ($i = 0; $i -lt $visual.lines.Count; $i++) {
        $y = 370 + $i * 108
        $graphics.FillRectangle($white, 62, $y, 956, 90)
        $graphics.FillEllipse($soft, 78, ($y+16), 58, 58)
        $graphics.DrawString([string]($i+1), $bodyFont, $accent, 94, ($y+23))
        $graphics.DrawString($visual.lines[$i], $bodyFont, $ink, [System.Drawing.RectangleF]::new(155,($y+15),830,74))
    }
    $graphics.DrawString('HEMŞİRELİK ÖĞRENCİLERİ İÇİN • EĞİTİM GÖRSELİ', $smallFont, $accent, 62, 830)
    $bitmap.Save((Join-Path $AssetDirectory ($visual.key + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    $ink.Dispose(); $accent.Dispose(); $soft.Dispose(); $white.Dispose()
    $titleFont.Dispose(); $bodyFont.Dispose(); $smallFont.Dispose()
}
