#Requires -Version 5.1
# Copies the Maya Riften test save(s) into the FrogRaceTest MO2 profile local saves.
$ErrorActionPreference = 'Stop'
$src = Join-Path $env:USERPROFILE 'Documents\My Games\Skyrim Special Edition\Saves'
$dst = 'D:\Modding\FrogRaceTest\MO2\profiles\Default\saves'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
if (-not (Test-Path $src)) { throw "Documents Saves not found: $src" }

$files = Get-ChildItem $src -File | Where-Object { $_.Name -match '_A26BF6F5_0_4D617961_' }
if (-not $files) { throw 'No Maya (A26BF6F5) saves found in Documents\Saves' }

foreach ($f in $files) {
  Copy-Item $f.FullName $dst -Force
  $skse = [IO.Path]::ChangeExtension($f.FullName, '.skse')
  if (Test-Path $skse) { Copy-Item $skse $dst -Force }
  Write-Host "Copied $($f.Name)"
}
Write-Host "Done. Saves are in: $dst"
Write-Host "MO2 profile has LocalSaves=true, so these show in Continue/Load."
