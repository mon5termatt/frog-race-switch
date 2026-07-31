#Requires -Version 5.1
<#
.SYNOPSIS
  Rebuild the FrogRaceTest Stock Game after a fresh Steam Skyrim SE install.

.DESCRIPTION
  1. Copies Steam Skyrim SE into D:\Modding\FrogRaceTest\MO2\Stock Game
  2. Removes Creation Club / Creations content
  3. Removes loose frog/test files from Stock Game Data (MO2 mods own those)
  4. Installs SKSE 2.02.06 from this repo's skse64_2_02_06.7z
  5. Points ModOrganizer.ini gamePath at the new Stock Game folder

.NOTES
  Run AFTER Steam finishes reinstalling / verifying Skyrim SE.
  Close MO2 before running.
#>

$ErrorActionPreference = 'Stop'

$SteamSSE = 'D:\SteamLibrary\steamapps\common\Skyrim Special Edition'
$MO2Root  = 'D:\Modding\FrogRaceTest\MO2'
$Stock    = Join-Path $MO2Root 'Stock Game'
$RepoRoot = $PSScriptRoot
$Skse7z   = Join-Path $RepoRoot 'skse64_2_02_06.7z'
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# --- Preflight ---
Write-Step 'Preflight checks'
if (-not (Test-Path (Join-Path $SteamSSE 'SkyrimSE.exe'))) {
  throw "Steam Skyrim SE not found at: $SteamSSE`nFinish the Steam reinstall first."
}
if (-not (Test-Path $MO2Root)) {
  throw "MO2 folder missing: $MO2Root"
}
if (-not (Test-Path $Skse7z)) {
  throw "SKSE archive missing: $Skse7z"
}
if (-not (Test-Path $SevenZip)) {
  throw "7-Zip not found at: $SevenZip"
}

$mo2Proc = Get-Process -Name 'ModOrganizer' -ErrorAction SilentlyContinue
if ($mo2Proc) {
  throw 'Close Mod Organizer 2 before running this script.'
}

Write-Host "Steam source : $SteamSSE"
Write-Host "Stock Game   : $Stock"
Write-Host "SKSE archive : $Skse7z"

# --- Copy game ---
Write-Step 'Copying Skyrim SE into Stock Game (this takes a few minutes)'
New-Item -ItemType Directory -Force -Path $Stock | Out-Null

# /MIR mirrors source -> dest (removes leftover junk from old Stock Game)
# Exclude gpu.txt per stock-game guides
& robocopy $SteamSSE $Stock /MIR /COPY:DAT /R:2 /W:2 /MT:8 /NFL /NDL /NP /XF gpu.txt
$rc = $LASTEXITCODE
if ($rc -ge 8) {
  throw "robocopy failed with exit code $rc"
}
Write-Host "robocopy finished (code $rc)"

if (-not (Test-Path (Join-Path $Stock 'SkyrimSE.exe'))) {
  throw 'Copy finished but SkyrimSE.exe is missing from Stock Game.'
}

# --- Strip Creations / CC ---
Write-Step 'Removing Creation Club / Creations'
$creations = Join-Path $Stock 'Creations'
if (Test-Path $creations) {
  Remove-Item $creations -Recurse -Force
  Write-Host 'Removed Creations\'
}

$data = Join-Path $Stock 'Data'
$cc = Get-ChildItem $data -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'cc*' }
Write-Host "Removing $($cc.Count) cc* files from Data\"
$cc | Remove-Item -Force

# Empty Skyrim.ccc so Steam/game stop asking to download Creations
$ccc = Join-Path $Stock 'Skyrim.ccc'
Set-Content -Path $ccc -Value '' -Encoding Ascii -NoNewline
Write-Host 'Emptied Skyrim.ccc (no Creations download list)'

# Helps SKSE launch without bouncing through Steam Creations UI as hard
Set-Content -Path (Join-Path $Stock 'steam_appid.txt') -Value '489830' -Encoding Ascii

# --- Strip loose frog/test files (MO2 mods provide these) ---
Write-Step 'Removing loose frog/test files from Stock Game Data'
@(
  'Playable Frog.esp',
  'FrogRaceSwitch.esp',
  'FrogRaceSwitch.bsa'
) | ForEach-Object {
  $p = Join-Path $data $_
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Removed $_" }
}

foreach ($dir in @(
  (Join-Path $data 'Scripts'),
  (Join-Path $data 'Scripts\Source'),
  (Join-Path $data 'Source\Scripts')
)) {
  if (Test-Path $dir) {
    Get-ChildItem $dir -Filter 'FRS_*' -ErrorAction SilentlyContinue | ForEach-Object {
      Remove-Item $_.FullName -Force
      Write-Host "Removed $($_.Name)"
    }
  }
}

# --- Install SKSE into Stock Game root + refresh SKSE Scripts mod ---
Write-Step 'Installing SKSE 2.02.06'
$extract = Join-Path $MO2Root '_skse_extract'
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
New-Item -ItemType Directory -Force -Path $extract | Out-Null
& $SevenZip x $Skse7z "-o$extract" -y | Out-Null

$loader = Get-ChildItem $extract -Recurse -Filter 'skse64_loader.exe' | Select-Object -First 1
if (-not $loader) { throw 'skse64_loader.exe not found inside SKSE archive.' }
$skseRoot = $loader.Directory.FullName

Get-ChildItem $skseRoot -File | ForEach-Object {
  Copy-Item $_.FullName $Stock -Force
  Write-Host "Copied $($_.Name)"
}

$skseMod = Join-Path $MO2Root 'mods\SKSE Scripts'
if (Test-Path $skseMod) { Remove-Item $skseMod -Recurse -Force }
New-Item -ItemType Directory -Force -Path $skseMod | Out-Null
$skseData = Join-Path $skseRoot 'Data'
if (Test-Path $skseData) {
  Copy-Item (Join-Path $skseData '*') $skseMod -Recurse -Force
}
@"
[General]
gameName=SkyrimSE
modid=0
version=2.02.06
category=0
installationFile=skse64_2_02_06.7z
repository=Local
comments=SKSE64 2.02.06 scripts
converted=false
validated=false
tracked=0
"@ | Set-Content (Join-Path $skseMod 'meta.ini') -Encoding UTF8
Write-Host "SKSE Scripts mod refreshed: $skseMod"

Remove-Item $extract -Recurse -Force

# --- Point MO2 at new Stock Game path ---
Write-Step 'Updating ModOrganizer.ini gamePath'
$iniPath = Join-Path $MO2Root 'ModOrganizer.ini'
if (Test-Path $iniPath) {
  $ini = Get-Content $iniPath -Raw
  $newPath = 'D:/Modding/FrogRaceTest/MO2/Stock Game'
  if ($ini -match 'gamePath=') {
    $ini = $ini -replace 'gamePath=.*', "gamePath=@ByteArray($($newPath.Replace('\','\\')))"
  } else {
    $ini = $ini -replace '(\[General\]\r?\n)', "`$1gamePath=@ByteArray($($newPath.Replace('\','\\')))`r`n"
  }
  # Fix executable working dirs / binaries that pointed at old Stock Game location
  $ini = $ini -replace 'D:/Modding/FrogRaceTest/Stock Game', $newPath
  $ini = $ini -replace 'D:\\\\Modding\\\\FrogRaceTest\\\\Stock Game', ($newPath -replace '/', '\\' -replace '\\', '\\')
  [System.IO.File]::WriteAllText($iniPath, $ini)
  Write-Host "gamePath -> $newPath"
} else {
  Write-Warning "ModOrganizer.ini not found; open MO2 and set game path manually to:`n  $Stock"
}

# --- Ensure profile still has core mods enabled ---
Write-Step 'Refreshing Default profile modlist / plugins'
$profile = Join-Path $MO2Root 'profiles\Default'
New-Item -ItemType Directory -Force -Path $profile | Out-Null

@"
# This file was automatically generated by Mod Organizer.
+Frog Race Switch
+Playable Frog Race
+SKSE Scripts
*DLC: Dawnguard
*DLC: Dragonborn
*DLC: HearthFires
"@ | Set-Content (Join-Path $profile 'modlist.txt') -Encoding UTF8

@"
# This file was automatically generated by Mod Organizer.
*Playable Frog.esp
*FrogRaceSwitch.esp
"@ | Set-Content (Join-Path $profile 'plugins.txt') -Encoding UTF8

@"
# This file was automatically generated by Mod Organizer.
Skyrim.esm
Update.esm
Dawnguard.esm
HearthFires.esm
Dragonborn.esm
Playable Frog.esp
FrogRaceSwitch.esp
"@ | Set-Content (Join-Path $profile 'loadorder.txt') -Encoding UTF8


# --- Copy Maya Riften test saves into profile local saves ---
Write-Step 'Copying Riften test saves into MO2 profile'
$saveSrc = Join-Path $env:USERPROFILE 'Documents\My Games\Skyrim Special Edition\Saves'
$saveDst = Join-Path $profile 'saves'
New-Item -ItemType Directory -Force -Path $saveDst | Out-Null
if (Test-Path $saveSrc) {
  $mayaSaves = Get-ChildItem $saveSrc -File -ErrorAction SilentlyContinue | Where-Object { #Requires -Version 5.1
<#
.SYNOPSIS
  Rebuild the FrogRaceTest Stock Game after a fresh Steam Skyrim SE install.

.DESCRIPTION
  1. Copies Steam Skyrim SE into D:\Modding\FrogRaceTest\MO2\Stock Game
  2. Removes Creation Club / Creations content
  3. Removes loose frog/test files from Stock Game Data (MO2 mods own those)
  4. Installs SKSE 2.02.06 from this repo's skse64_2_02_06.7z
  5. Points ModOrganizer.ini gamePath at the new Stock Game folder

.NOTES
  Run AFTER Steam finishes reinstalling / verifying Skyrim SE.
  Close MO2 before running.
#>

$ErrorActionPreference = 'Stop'

$SteamSSE = 'D:\SteamLibrary\steamapps\common\Skyrim Special Edition'
$MO2Root  = 'D:\Modding\FrogRaceTest\MO2'
$Stock    = Join-Path $MO2Root 'Stock Game'
$RepoRoot = $PSScriptRoot
$Skse7z   = Join-Path $RepoRoot 'skse64_2_02_06.7z'
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# --- Preflight ---
Write-Step 'Preflight checks'
if (-not (Test-Path (Join-Path $SteamSSE 'SkyrimSE.exe'))) {
  throw "Steam Skyrim SE not found at: $SteamSSE`nFinish the Steam reinstall first."
}
if (-not (Test-Path $MO2Root)) {
  throw "MO2 folder missing: $MO2Root"
}
if (-not (Test-Path $Skse7z)) {
  throw "SKSE archive missing: $Skse7z"
}
if (-not (Test-Path $SevenZip)) {
  throw "7-Zip not found at: $SevenZip"
}

$mo2Proc = Get-Process -Name 'ModOrganizer' -ErrorAction SilentlyContinue
if ($mo2Proc) {
  throw 'Close Mod Organizer 2 before running this script.'
}

Write-Host "Steam source : $SteamSSE"
Write-Host "Stock Game   : $Stock"
Write-Host "SKSE archive : $Skse7z"

# --- Copy game ---
Write-Step 'Copying Skyrim SE into Stock Game (this takes a few minutes)'
New-Item -ItemType Directory -Force -Path $Stock | Out-Null

# /MIR mirrors source -> dest (removes leftover junk from old Stock Game)
# Exclude gpu.txt per stock-game guides
& robocopy $SteamSSE $Stock /MIR /COPY:DAT /R:2 /W:2 /MT:8 /NFL /NDL /NP /XF gpu.txt
$rc = $LASTEXITCODE
if ($rc -ge 8) {
  throw "robocopy failed with exit code $rc"
}
Write-Host "robocopy finished (code $rc)"

if (-not (Test-Path (Join-Path $Stock 'SkyrimSE.exe'))) {
  throw 'Copy finished but SkyrimSE.exe is missing from Stock Game.'
}

# --- Strip Creations / CC ---
Write-Step 'Removing Creation Club / Creations'
$creations = Join-Path $Stock 'Creations'
if (Test-Path $creations) {
  Remove-Item $creations -Recurse -Force
  Write-Host 'Removed Creations\'
}

$data = Join-Path $Stock 'Data'
$cc = Get-ChildItem $data -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'cc*' }
Write-Host "Removing $($cc.Count) cc* files from Data\"
$cc | Remove-Item -Force

# Empty Skyrim.ccc so Steam/game stop asking to download Creations
$ccc = Join-Path $Stock 'Skyrim.ccc'
Set-Content -Path $ccc -Value '' -Encoding Ascii -NoNewline
Write-Host 'Emptied Skyrim.ccc (no Creations download list)'

# Helps SKSE launch without bouncing through Steam Creations UI as hard
Set-Content -Path (Join-Path $Stock 'steam_appid.txt') -Value '489830' -Encoding Ascii

# --- Strip loose frog/test files (MO2 mods provide these) ---
Write-Step 'Removing loose frog/test files from Stock Game Data'
@(
  'Playable Frog.esp',
  'FrogRaceSwitch.esp',
  'FrogRaceSwitch.bsa'
) | ForEach-Object {
  $p = Join-Path $data $_
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Removed $_" }
}

foreach ($dir in @(
  (Join-Path $data 'Scripts'),
  (Join-Path $data 'Scripts\Source'),
  (Join-Path $data 'Source\Scripts')
)) {
  if (Test-Path $dir) {
    Get-ChildItem $dir -Filter 'FRS_*' -ErrorAction SilentlyContinue | ForEach-Object {
      Remove-Item $_.FullName -Force
      Write-Host "Removed $($_.Name)"
    }
  }
}

# --- Install SKSE into Stock Game root + refresh SKSE Scripts mod ---
Write-Step 'Installing SKSE 2.02.06'
$extract = Join-Path $MO2Root '_skse_extract'
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
New-Item -ItemType Directory -Force -Path $extract | Out-Null
& $SevenZip x $Skse7z "-o$extract" -y | Out-Null

$loader = Get-ChildItem $extract -Recurse -Filter 'skse64_loader.exe' | Select-Object -First 1
if (-not $loader) { throw 'skse64_loader.exe not found inside SKSE archive.' }
$skseRoot = $loader.Directory.FullName

Get-ChildItem $skseRoot -File | ForEach-Object {
  Copy-Item $_.FullName $Stock -Force
  Write-Host "Copied $($_.Name)"
}

$skseMod = Join-Path $MO2Root 'mods\SKSE Scripts'
if (Test-Path $skseMod) { Remove-Item $skseMod -Recurse -Force }
New-Item -ItemType Directory -Force -Path $skseMod | Out-Null
$skseData = Join-Path $skseRoot 'Data'
if (Test-Path $skseData) {
  Copy-Item (Join-Path $skseData '*') $skseMod -Recurse -Force
}
@"
[General]
gameName=SkyrimSE
modid=0
version=2.02.06
category=0
installationFile=skse64_2_02_06.7z
repository=Local
comments=SKSE64 2.02.06 scripts
converted=false
validated=false
tracked=0
"@ | Set-Content (Join-Path $skseMod 'meta.ini') -Encoding UTF8
Write-Host "SKSE Scripts mod refreshed: $skseMod"

Remove-Item $extract -Recurse -Force

# --- Point MO2 at new Stock Game path ---
Write-Step 'Updating ModOrganizer.ini gamePath'
$iniPath = Join-Path $MO2Root 'ModOrganizer.ini'
if (Test-Path $iniPath) {
  $ini = Get-Content $iniPath -Raw
  $newPath = 'D:/Modding/FrogRaceTest/MO2/Stock Game'
  if ($ini -match 'gamePath=') {
    $ini = $ini -replace 'gamePath=.*', "gamePath=@ByteArray($($newPath.Replace('\','\\')))"
  } else {
    $ini = $ini -replace '(\[General\]\r?\n)', "`$1gamePath=@ByteArray($($newPath.Replace('\','\\')))`r`n"
  }
  # Fix executable working dirs / binaries that pointed at old Stock Game location
  $ini = $ini -replace 'D:/Modding/FrogRaceTest/Stock Game', $newPath
  $ini = $ini -replace 'D:\\\\Modding\\\\FrogRaceTest\\\\Stock Game', ($newPath -replace '/', '\\' -replace '\\', '\\')
  [System.IO.File]::WriteAllText($iniPath, $ini)
  Write-Host "gamePath -> $newPath"
} else {
  Write-Warning "ModOrganizer.ini not found; open MO2 and set game path manually to:`n  $Stock"
}

# --- Ensure profile still has core mods enabled ---
Write-Step 'Refreshing Default profile modlist / plugins'
$profile = Join-Path $MO2Root 'profiles\Default'
New-Item -ItemType Directory -Force -Path $profile | Out-Null

@"
# This file was automatically generated by Mod Organizer.
+Frog Race Switch
+Playable Frog Race
+SKSE Scripts
*DLC: Dawnguard
*DLC: Dragonborn
*DLC: HearthFires
"@ | Set-Content (Join-Path $profile 'modlist.txt') -Encoding UTF8

@"
# This file was automatically generated by Mod Organizer.
*Playable Frog.esp
*FrogRaceSwitch.esp
"@ | Set-Content (Join-Path $profile 'plugins.txt') -Encoding UTF8

@"
# This file was automatically generated by Mod Organizer.
Skyrim.esm
Update.esm
Dawnguard.esm
HearthFires.esm
Dragonborn.esm
Playable Frog.esp
FrogRaceSwitch.esp
"@ | Set-Content (Join-Path $profile 'loadorder.txt') -Encoding UTF8

# --- Done ---
Write-Step 'Done'
Write-Host @"

Stock Game ready at:
  $Stock

Next:
  1. Open $MO2Root\ModOrganizer.exe
  2. Confirm mods: SKSE Scripts, Playable Frog Race, Frog Race Switch
  3. Run SKSE from the executables dropdown

"@ -ForegroundColor Green
.Name -match '_A26BF6F5_0_4D617961_' }
  foreach ($f in $mayaSaves) {
    Copy-Item $f.FullName $saveDst -Force
    $skseCosave = [IO.Path]::ChangeExtension($f.FullName, '.skse')
    if (Test-Path $skseCosave) { Copy-Item $skseCosave $saveDst -Force }
    Write-Host "Copied save $($f.Name)"
  }
  if (-not $mayaSaves) { Write-Warning 'No Maya Riften saves found to copy' }
} else {
  Write-Warning "Documents Saves folder missing: $saveSrc"
}
# --- Done ---
Write-Step 'Done'
Write-Host @"

Stock Game ready at:
  $Stock

Next:
  1. Open $MO2Root\ModOrganizer.exe
  2. Confirm mods: SKSE Scripts, Playable Frog Race, Frog Race Switch
  3. Run SKSE from the executables dropdown

"@ -ForegroundColor Green

