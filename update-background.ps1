# Downloads recent Bing "photo of the day" wallpapers, scores each for brightness
# and color vividness, and saves the best pick to images\today.jpg for the clock.
# Runs daily (scheduled task) and at login (via clock.vbs). Pass -Force to refetch
# even if it already ran today.
param([switch]$Force)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$proj    = Split-Path -Parent $MyInvocation.MyCommand.Path
$imgDir  = Join-Path $proj "images"
$target  = Join-Path $imgDir "today.jpg"
$marker  = Join-Path $imgDir ".lastupdate"
$today   = (Get-Date).ToString("yyyy-MM-dd")

New-Item -ItemType Directory -Force -Path $imgDir | Out-Null

# Skip if we already updated today (unless forced)
if (-not $Force -and (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq $today -and (Test-Path $target)) {
  Write-Output "Already updated for $today. Use -Force to refetch."
  return
}

Add-Type -AssemblyName System.Drawing

function Get-ImageScore {
  param([string]$Path)
  $bmp = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    $stepX = [Math]::Max(1, [int]($bmp.Width / 80))
    $stepY = [Math]::Max(1, [int]($bmp.Height / 80))
    $lumSum = 0.0; $satSum = 0.0; $n = 0
    for ($y = 0; $y -lt $bmp.Height; $y += $stepY) {
      for ($x = 0; $x -lt $bmp.Width; $x += $stepX) {
        $p = $bmp.GetPixel($x, $y)
        $r = $p.R / 255.0; $g = $p.G / 255.0; $b = $p.B / 255.0
        $lumSum += (0.2126*$r + 0.7152*$g + 0.0722*$b)
        $mx = [Math]::Max($r, [Math]::Max($g, $b))
        $mn = [Math]::Min($r, [Math]::Min($g, $b))
        if ($mx -gt 0) { $satSum += (($mx - $mn) / $mx) }
        $n++
      }
    }
    $lum = $lumSum / $n      # 0..1 average brightness
    $sat = $satSum / $n      # 0..1 average saturation (vividness)
    # Favor bright AND colorful, but avoid blown-out near-white frames.
    $brightPenalty = if ($lum -gt 0.85) { ($lum - 0.85) * 2 } else { 0 }
    [PSCustomObject]@{ Lum = $lum; Sat = $sat; Score = ($lum + 0.6*$sat - $brightPenalty) }
  } finally { $bmp.Dispose() }
}

try {
  $api = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US"
  $data = Invoke-RestMethod -Uri $api -TimeoutSec 20
} catch {
  Write-Output "Could not reach Bing ($($_.Exception.Message)). Keeping existing background."
  return
}

$tmp = Join-Path $env:TEMP "clockbg"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$best = $null; $bestPath = $null; $i = 0
foreach ($img in $data.images) {
  $i++
  $url = "https://www.bing.com" + $img.urlbase + "_1920x1080.jpg"
  $dest = Join-Path $tmp ("cand_$i.jpg")
  try {
    Invoke-WebRequest -Uri $url -OutFile $dest -TimeoutSec 25
    $s = Get-ImageScore -Path $dest
    Write-Output ("  cand {0}: lum={1:N2} sat={2:N2} score={3:N2}  {4}" -f $i, $s.Lum, $s.Sat, $s.Score, $img.title)
    if (-not $best -or $s.Score -gt $best.Score) { $best = $s; $bestPath = $dest; $script:bestTitle = $img.copyright }
  } catch {
    Write-Output "  cand $i failed: $($_.Exception.Message)"
  }
}

if (-not $bestPath) {
  Write-Output "No candidates downloaded. Keeping existing background."
  return
}

Copy-Item -Path $bestPath -Destination $target -Force
Set-Content -Path $marker -Value $today -NoNewline
Set-Content -Path (Join-Path $imgDir "today.txt") -Value $script:bestTitle -NoNewline
Remove-Item "$tmp\*" -Force -ErrorAction SilentlyContinue
Write-Output ("Selected (lum={0:N2} sat={1:N2}): {2}" -f $best.Lum, $best.Sat, $script:bestTitle)
Write-Output "Saved -> $target"
