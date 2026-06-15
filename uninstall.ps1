<#
  Uninstaller for the desktop clock. Removes the Desktop/Startup shortcuts, the
  daily-background scheduled task, the dedicated Edge profile, and stops the
  running clock window and its background server. Does NOT delete this folder
  (delete it yourself afterwards if you like). Run via uninstall.bat.

  -DryRun      show what would be removed, change nothing
  -KeepProfile leave the Edge profile (settings/cache) in place
  -NoPrompt    don't ask for confirmation
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$KeepProfile,
  [switch]$NoPrompt
)

$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$TaskName   = "FreeGoodLookingClock Daily Background"
$profileDir = Join-Path $env:LocalAppData "FreeGoodLookingClock-Edge"
$serverPath = Join-Path $root "server.ps1"
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "Clock.lnk"
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) "Clock.lnk"

function Section($t) { Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function Did($t)     { Write-Host "   $t" -ForegroundColor Green }
function Skip($t)    { Write-Host "   $t" -ForegroundColor DarkGray }
function Would($t)   { Write-Host "   would: $t" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  Desktop Clock - Uninstall" -ForegroundColor White
Write-Host "  Folder: $root"
if ($DryRun) { Write-Host "  (dry run - nothing will be changed)" -ForegroundColor Yellow }

if (-not $NoPrompt -and -not $DryRun) {
  $a = (Read-Host "  Remove the clock's shortcuts, task, and profile? [y/N]").Trim().ToLower()
  if ($a -notin @("y","yes")) { Write-Host "  Cancelled."; return }
}

# Helper: remove a Clock.lnk only if it points at THIS folder's clock.vbs
function Remove-ClockShortcut($path, $label) {
  if (-not (Test-Path $path)) { Skip "$label shortcut not present"; return }
  $sh = New-Object -ComObject WScript.Shell
  $args = $sh.CreateShortcut($path).Arguments
  if ($args -like "*$root*clock.vbs*" -or $args -like "*clock.vbs*") {
    if ($DryRun) { Would "remove $label shortcut: $path" }
    else { Remove-Item -LiteralPath $path -Force; Did "Removed $label shortcut" }
  } else {
    Skip "$label 'Clock.lnk' points elsewhere - left alone"
  }
}

# --- 1. Stop the running clock window (its dedicated Edge profile) ---
Section "Stopping the clock"
$edgeProcs = Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine -like "*FreeGoodLookingClock-Edge*" }
if ($edgeProcs) {
  if ($DryRun) { Would "stop $(@($edgeProcs).Count) clock Edge process(es)" }
  else { $edgeProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; Did "Closed the clock window" }
} else { Skip "Clock window not running" }

# --- 2. Stop the background server ---
Section "Stopping the local server"
$srvProcs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine -like "*server.ps1*" -and $_.CommandLine -like "*$root*" }
if ($srvProcs) {
  if ($DryRun) { Would "stop $(@($srvProcs).Count) server process(es)" }
  else { $srvProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; Did "Stopped the server" }
} else { Skip "Server not running" }

# --- 3. Shortcuts ---
Section "Removing shortcuts"
Remove-ClockShortcut $desktopLnk "Desktop"
Remove-ClockShortcut $startupLnk "Startup"

# --- 4. Scheduled task ---
Section "Removing the daily background task"
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  if ($DryRun) { Would "unregister scheduled task '$TaskName'" }
  else { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Did "Removed scheduled task" }
} else { Skip "Scheduled task not present" }

# --- 5. Edge profile ---
Section "Removing the Edge profile"
if ($KeepProfile) {
  Skip "Keeping profile (-KeepProfile): $profileDir"
} elseif (Test-Path $profileDir) {
  if ($DryRun) { Would "delete profile folder: $profileDir" }
  else {
    Start-Sleep -Milliseconds 800   # let Edge fully release the folder
    Remove-Item -LiteralPath $profileDir -Recurse -Force
    if (Test-Path $profileDir) { Skip "Could not fully delete profile (in use?) - delete manually: $profileDir" }
    else { Did "Removed Edge profile" }
  }
} else { Skip "Edge profile not present" }

# --- Done ---
Section "Done"
if ($DryRun) {
  Write-Host "   Dry run complete - nothing was changed." -ForegroundColor Yellow
} else {
  Did "The clock has been uninstalled."
  Write-Host "   This folder was left in place - delete it whenever you're ready:" -ForegroundColor Gray
  Write-Host "   $root" -ForegroundColor Gray
}
Write-Host ""
