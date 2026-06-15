# Dependency-free static file server for the clock (serves this folder on
# 127.0.0.1:8080). Uses raw TCP sockets so it needs no admin rights and no
# Python/Node — just Windows PowerShell. Launched hidden by clock.vbs; if a
# server is already running on the port it simply exits.
param([int]$Port = 8080)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootFull = [System.IO.Path]::GetFullPath($root)

$mime = @{
  ".html"="text/html; charset=utf-8"; ".css"="text/css; charset=utf-8";
  ".js"="text/javascript; charset=utf-8"; ".json"="application/json";
  ".webmanifest"="application/manifest+json"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg";
  ".png"="image/png"; ".ico"="image/x-icon"; ".svg"="image/svg+xml"; ".txt"="text/plain; charset=utf-8"
}

try {
  $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
  $listener.Start()
} catch {
  return   # port already in use -> another instance is serving; exit quietly
}

function Write-Response($stream, [string]$status, [string]$contentType, [byte[]]$body) {
  $head = "HTTP/1.1 $status`r`n" +
          "Content-Type: $contentType`r`n" +
          "Content-Length: $($body.Length)`r`n" +
          "Cache-Control: no-cache`r`n" +
          "Connection: close`r`n`r`n"
  $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb, 0, $hb.Length)
  if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
  $stream.Flush()
}

while ($true) {
  $client = $null
  try {
    $client = $listener.AcceptTcpClient()
    $client.ReceiveTimeout = 5000
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $requestLine = $reader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($requestLine)) { $client.Close(); continue }

    $rawPath = ($requestLine -split ' ')[1]
    $path = ($rawPath -split '\?')[0]
    $path = [System.Uri]::UnescapeDataString($path)
    if ($path -eq '/' -or $path -eq '') { $path = '/index.html' }
    $rel = ($path.TrimStart('/')) -replace '/', '\'
    $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))

    if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Response $stream "403 Forbidden" "text/plain" ([System.Text.Encoding]::ASCII.GetBytes("403"))
    } elseif (Test-Path -LiteralPath $full -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $ct = $mime[$ext]; if (-not $ct) { $ct = "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($full)
      Write-Response $stream "200 OK" $ct $bytes
    } else {
      Write-Response $stream "404 Not Found" "text/plain" ([System.Text.Encoding]::ASCII.GetBytes("404"))
    }
  } catch {
  } finally {
    if ($client) { try { $client.Close() } catch {} }
  }
}
