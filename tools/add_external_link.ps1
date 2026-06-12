$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $root "assets\external_links"
$file = Join-Path $folder "links.json"

New-Item -ItemType Directory -Force -Path $folder | Out-Null

$name = Read-Host "Podaj nazwe ikony, np. img1_4_8_2o"
$url = Read-Host "Podaj adres URL"

if ([string]::IsNullOrWhiteSpace($name)) {
  throw "Brak nazwy ikony."
}

if ($name -notmatch '^img1_4_8_\d+o$') {
  throw "Nazwa musi wygladac np. img1_4_8_2o"
}

if ($url -notmatch '^https?://') {
  throw "URL musi zaczynac sie od http:// albo https://"
}

if (Test-Path $file) {
  $links = Get-Content -Path $file -Raw | ConvertFrom-Json -AsHashtable
} else {
  $links = @{}
}

$links[$name] = $url

$ordered = [ordered]@{}
foreach ($key in ($links.Keys | Sort-Object)) {
  $ordered[$key] = $links[$key]
}

$ordered |
  ConvertTo-Json -Depth 4 |
  Set-Content -Path $file -Encoding UTF8

Write-Host "Zapisano: $file"
