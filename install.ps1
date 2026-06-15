<#
  Installer for the desktop clock. Sets it up to run exactly like a configured
  machine: a chromeless, fixed-position Edge window, optional launch-at-login,
  and an optional daily background refresh. Run it via install.bat (double-click)
  or directly. Parameters allow a silent/non-interactive install.
#>
[CmdletBinding()]
param(
  [string]$Position,                 # "X,Y"
  [string]$Size,                     # "W,H"
  [Nullable[bool]]$Startup,          # add to Windows startup
  [Nullable[bool]]$DailyBackground,  # register daily image refresh
  [Nullable[bool]]$LaunchNow,        # launch the clock when done
  [switch]$NoPrompt                  # don't ask; use params/defaults
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$TaskName = "FreeGoodLookingClock Daily Background"

function Section($t) { Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function Info($t)    { Write-Host "   $t" }
function Good($t)    { Write-Host "   $t" -ForegroundColor Green }
function Warn($t)    { Write-Host "   $t" -ForegroundColor Yellow }

function Ask-YesNo($question, $default) {
  if ($NoPrompt) { return $default }
  $suffix = if ($default) { "[Y/n]" } else { "[y/N]" }
  while ($true) {
    $a = (Read-Host "$question $suffix").Trim().ToLower()
    if ($a -eq "")  { return $default }
    if ($a -in @("y","yes")) { return $true }
    if ($a -in @("n","no"))  { return $false }
  }
}

Write-Host ""
Write-Host "  Desktop Clock - Setup" -ForegroundColor White
Write-Host "  Folder: $root"

# --- 1. Prerequisite: Microsoft Edge ---
Section "Checking Microsoft Edge"
$edgeCandidates = @(
  "$([Environment]::GetFolderPath('ProgramFilesX86'))\Microsoft\Edge\Application\msedge.exe",
  "$([Environment]::GetFolderPath('ProgramFiles'))\Microsoft\Edge\Application\msedge.exe",
  "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe"
)
$edge = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) {
  Warn "Microsoft Edge was not found. Install Edge (it ships with Windows 11) and re-run."
  if (-not $NoPrompt) { Read-Host "Press Enter to exit" }
  exit 1
}
Good "Found Edge: $edge"

# --- 2. Window placement ---
Section "Window position and size"
function Parse2($s) { if ($s -and $s -match '^\s*(-?\d+)\s*,\s*(-?\d+)\s*$') { return @([int]$Matches[1], [int]$Matches[2]) } return $null }

$pos = Parse2 $Position
$siz = Parse2 $Size
$cfgPath = Join-Path $root "window.cfg"

if (-not ($pos -and $siz)) {
  Add-Type -AssemblyName System.Windows.Forms
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $w = 480; $h = 210
  $presets = [ordered]@{
    "1" = @{ name = "Bottom center"; x = [int]($b.X + ($b.Width - $w)/2);  y = [int]($b.Y + $b.Height - $h - 60); w=$w; h=$h }
    "2" = @{ name = "Top-right";     x = [int]($b.X + $b.Width - $w - 40); y = [int]($b.Y + 40);                  w=$w; h=$h }
    "3" = @{ name = "Center";        x = [int]($b.X + ($b.Width - $w)/2);  y = [int]($b.Y + ($b.Height - $h)/2); w=$w; h=$h }
  }
  if ($NoPrompt) {
    $c = $presets["1"]; $pos = @($c.x, $c.y); $siz = @($c.w, $c.h)
  } else {
    Info "Primary screen: $($b.Width) x $($b.Height)"
    Write-Host "   [1] Bottom center   [2] Top-right   [3] Center"
    if (Test-Path $cfgPath) { Write-Host "   [4] Keep current settings" }
    Write-Host "   [5] Custom (enter X Y Width Height)"
    $choice = (Read-Host "   Choose 1-5 (default 1)").Trim()
    if ($choice -eq "") { $choice = "1" }
    switch ($choice) {
      "4" { if (Test-Path $cfgPath) { $pos = $null; $siz = $null } else { $c=$presets["1"]; $pos=@($c.x,$c.y); $siz=@($c.w,$c.h) } }
      "5" {
        $vals = (Read-Host "   Enter: X Y Width Height (e.g. 100 100 480 210)") -split '\s+' | Where-Object { $_ -ne "" }
        if ($vals.Count -ge 4) { $pos = @([int]$vals[0], [int]$vals[1]); $siz = @([int]$vals[2], [int]$vals[3]) }
        else { $c=$presets["1"]; $pos=@($c.x,$c.y); $siz=@($c.w,$c.h); Warn "Not enough numbers - using Bottom center." }
      }
      default { $c = $presets[$choice]; if (-not $c) { $c = $presets["1"] }; $pos = @($c.x, $c.y); $siz = @($c.w, $c.h) }
    }
  }
}

if ($pos -and $siz) {
  Set-Content -Path $cfgPath -Value @("$($pos[0])","$($pos[1])","$($siz[0])","$($siz[1])") -Encoding ASCII
  Good "Saved placement: position $($pos[0]),$($pos[1])  size $($siz[0])x$($siz[1])  -> window.cfg"
} elseif (Test-Path $cfgPath) {
  Good "Keeping existing window.cfg"
}
Info "(You can change this anytime by editing window.cfg or re-running install.)"

# --- 3. Desktop shortcut ---
Section "Creating the desktop shortcut"
$icon = Join-Path $root "icons\clock.ico"
$shell = New-Object -ComObject WScript.Shell
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "Clock.lnk"
$sc = $shell.CreateShortcut($desktopLnk)
$sc.TargetPath = "$env:WINDIR\System32\wscript.exe"
$sc.Arguments = """$root\clock.vbs"""
$sc.WorkingDirectory = $root
if (Test-Path $icon) { $sc.IconLocation = "$icon,0" } else { $sc.IconLocation = "$edge,0" }
$sc.Description = "Desktop clock"
$sc.WindowStyle = 7
$sc.Save()
Good "Desktop shortcut: $desktopLnk"

# --- 4. Launch at login ---
Section "Launch at Windows login"
$wantStartup = if ($Startup -ne $null) { [bool]$Startup } else { Ask-YesNo "   Launch the clock automatically when you sign in?" $true }
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) "Clock.lnk"
if ($wantStartup) {
  Copy-Item -Path $desktopLnk -Destination $startupLnk -Force
  Good "Added to startup: $startupLnk"
} else {
  if (Test-Path $startupLnk) { Remove-Item $startupLnk -Force }
  Info "Not launching at login."
}

# --- 5. Daily background refresh ---
Section "Daily background photo"
$wantDaily = if ($DailyBackground -ne $null) { [bool]$DailyBackground } else { Ask-YesNo "   Download a fresh, bright photo every morning?" $true }
if ($wantDaily) {
  $ps = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$root\update-background.ps1`""
  $action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ps -WorkingDirectory $root
  $trigger = New-ScheduledTaskTrigger -Daily -At 6:30am
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Description "Downloads a fresh, bright background for the desktop clock each morning." -Force | Out-Null
  Good "Scheduled daily refresh at 6:30 AM (task: $TaskName)"
  Info "Fetching the first background now..."
  try { & (Join-Path $root "update-background.ps1") -Force | ForEach-Object { Info $_ } }
  catch { Warn "Could not fetch a background right now (no internet?). It'll try again later." }
} else {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Info "Daily photos off. The clock will use a built-in gradient (press Theme to change)."
}

# --- Done ---
Section "Done"
Good "The clock is installed."
Info "Launch it from the Desktop 'Clock' shortcut anytime."
if ($wantStartup) { Info "It will also open automatically when you sign in." }

$launch = if ($LaunchNow -ne $null) { [bool]$LaunchNow } else { Ask-YesNo "   Launch the clock now?" $true }
if ($launch) {
  Start-Process "$env:WINDIR\System32\wscript.exe" -ArgumentList """$root\clock.vbs"""
  Good "Launched."
}
Write-Host ""
