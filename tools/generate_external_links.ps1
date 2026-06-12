$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $root "assets\external_links"
$file = Join-Path $folder "links.json"

New-Item -ItemType Directory -Force -Path $folder | Out-Null

$prefix = Read-Host "Podaj poczatek nazwy ikon (Enter = img1_4_8)"
if ([string]::IsNullOrWhiteSpace($prefix)) {
  $prefix = "img1_4_8"
}

$from = [int](Read-Host "Od numeru, np. 2")
$to = [int](Read-Host "Do numeru, np. 10")
$urlTemplate = Read-Host "Szablon URL, uzyj {n}, np. https://strona.pl/produkt-{n}"

if ($from -le 0 -or $to -lt $from) {
  throw "Nieprawidlowy zakres numerow."
}

if ($urlTemplate -notmatch '^https?://') {
  throw "URL musi zaczynac sie od http:// albo https://"
}

if ($urlTemplate -notmatch '\{n\}') {
  throw "Szablon URL musi zawierac {n}, np. https://strona.pl/produkt-{n}"
}

if (Test-Path $file) {
  $links = Get-Content -Path $file -Raw | ConvertFrom-Json -AsHashtable
} else {
  $links = @{}
}

for ($i = $from; $i -le $to; $i++) {
  $name = "${prefix}_${i}o"
  $url = $urlTemplate.Replace("{n}", "$i")
  $links[$name] = $url
}

$ordered = [ordered]@{}
foreach ($key in ($links.Keys | Sort-Object)) {
  $ordered[$key] = $links[$key]
}

$ordered |
  ConvertTo-Json -Depth 4 |
  Set-Content -Path $file -Encoding UTF8

Write-Host "Wygenerowano linki od ${prefix}_${from}o do ${prefix}_${to}o"
Write-Host "Zapisano: $file"
