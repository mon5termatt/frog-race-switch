# Fix FrogRaceSwitch.esp:
# 1) Re-add Playable Frog.esp master (FormIDs already expect it at index 03)
# 2) Wire QuestScript on the three potion magic-effect scripts
param(
    [string]$EspPath = 'C:\Users\Matt\Github\frog-race-switch\FrogRaceSwitch.esp',
    [string]$DeployTo = 'D:\Modding\FrogRaceTest\MO2\mods\Frog Race Switch\FrogRaceSwitch.esp'
)

$ErrorActionPreference = 'Stop'

function Get-UInt16([byte[]]$b, [int]$i) { [BitConverter]::ToUInt16($b, $i) }
function Get-UInt32([byte[]]$b, [int]$i) { [BitConverter]::ToUInt32($b, $i) }
function Set-UInt16([byte[]]$b, [int]$i, [uint16]$v) { [BitConverter]::GetBytes($v).CopyTo($b, $i) }
function Set-UInt32([byte[]]$b, [int]$i, [uint32]$v) { [BitConverter]::GetBytes($v).CopyTo($b, $i) }

function Concat-Bytes {
    $ms = New-Object System.IO.MemoryStream
    foreach ($part in $args) {
        if ($null -eq $part) { continue }
        if ($part -is [byte[]]) {
            if ($part.Length -gt 0) { $ms.Write($part, 0, $part.Length) }
        }
        else {
            foreach ($p in @($part)) {
                if ($null -ne $p -and $p.Length -gt 0) { $ms.Write($p, 0, $p.Length) }
            }
        }
    }
    ,$ms.ToArray()
}

function Encode-WString([string]$s) {
    $chars = [Text.Encoding]::ASCII.GetBytes($s + [char]0)
    ,(Concat-Bytes ([BitConverter]::GetBytes([uint16]$chars.Length)) $chars)
}

function Encode-PropName([string]$s) {
    $chars = [Text.Encoding]::ASCII.GetBytes($s)
    ,(Concat-Bytes ([BitConverter]::GetBytes([uint16]$chars.Length)) $chars)
}

function New-ObjectProperty([string]$name, [uint32]$formId) {
    $body = New-Object byte[] 10
    $body[0] = 1
    $body[1] = 1
    Set-UInt16 $body 2 0
    Set-UInt16 $body 4 0xFFFF
    Set-UInt32 $body 6 $formId
    ,(Concat-Bytes (Encode-PropName $name) $body)
}

function Expand-MgefVmad([byte[]]$recData, [uint32]$questFormId) {
    $i = 0
    while ($i + 6 -le $recData.Length) {
        $type = [Text.Encoding]::ASCII.GetString($recData, $i, 4)
        $size = Get-UInt16 $recData ($i + 4)
        $dataStart = $i + 6
        $dataEnd = $dataStart + $size
        if ($dataEnd -gt $recData.Length) { throw "Bad subrecord at $i" }

        if ($type -eq 'VMAD') {
            $vmad = New-Object byte[] $size
            [Array]::Copy($recData, $dataStart, $vmad, 0, $size)

            $version = Get-UInt16 $vmad 0
            $objFmt = Get-UInt16 $vmad 2
            $scriptCount = Get-UInt16 $vmad 4
            if ($scriptCount -ne 1) { throw "Expected 1 script, got $scriptCount" }

            $p = 6
            $nameLen = Get-UInt16 $vmad $p
            $p += 2
            $scriptName = [Text.Encoding]::ASCII.GetString($vmad, $p, $nameLen).Trim([char]0)
            $p += $nameLen

            $questProp = New-ObjectProperty 'QuestScript' $questFormId
            $newVmad = Concat-Bytes `
                ([BitConverter]::GetBytes([uint16]$version)) `
                ([BitConverter]::GetBytes([uint16]$objFmt)) `
                ([BitConverter]::GetBytes([uint16]1)) `
                (Encode-WString $scriptName) `
                ([byte[]]@(0)) `
                ([BitConverter]::GetBytes([uint16]1)) `
                $questProp

            $before = if ($i -gt 0) { $recData[0..($i - 1)] } else { [byte[]]@() }
            $after = if ($dataEnd -lt $recData.Length) { $recData[$dataEnd..($recData.Length - 1)] } else { [byte[]]@() }
            $vmadHeader = Concat-Bytes ([Text.Encoding]::ASCII.GetBytes('VMAD')) ([BitConverter]::GetBytes([uint16]$newVmad.Length))
            $newRec = Concat-Bytes $before $vmadHeader $newVmad $after
            Write-Host "  Patched VMAD on script $scriptName (VMAD $size -> $($newVmad.Length))"
            return ,$newRec
        }
        $i = $dataEnd
    }
    throw "No VMAD found in record"
}

function Add-Master([byte[]]$bytes, [string]$masterName) {
    $tes4Size = Get-UInt32 $bytes 4
    $tes4End = 24 + $tes4Size

    $text = [Text.Encoding]::ASCII.GetString($bytes, 24, [int]$tes4Size)
    if ($text.Contains($masterName)) {
        Write-Host "Master already present: $masterName"
        return ,$bytes
    }

    $insertAt = $tes4End
    $i = 24
    while ($i + 6 -le $tes4End) {
        $type = [Text.Encoding]::ASCII.GetString($bytes, $i, 4)
        $size = Get-UInt16 $bytes ($i + 4)
        if ($type -eq 'INTV') { $insertAt = $i; break }
        $i += 6 + $size
    }

    $mastName = [Text.Encoding]::ASCII.GetBytes($masterName + [char]0)
    $mast = Concat-Bytes ([Text.Encoding]::ASCII.GetBytes('MAST')) ([BitConverter]::GetBytes([uint16]$mastName.Length)) $mastName
    $data = Concat-Bytes ([Text.Encoding]::ASCII.GetBytes('DATA')) ([BitConverter]::GetBytes([uint16]8)) ([byte[]]@(0,0,0,0,0,0,0,0))
    $insert = Concat-Bytes $mast $data

    $before = $bytes[0..($insertAt - 1)]
    $after = $bytes[$insertAt..($bytes.Length - 1)]
    $out = Concat-Bytes $before $insert $after
    Set-UInt32 $out 4 ([uint32]($tes4Size + $insert.Length))
    Write-Host "Added master $masterName (+$($insert.Length) bytes)"
    return ,$out
}

function Get-EditorId([byte[]]$data) {
    $j = 0
    while ($j + 6 -le $data.Length) {
        $st = [Text.Encoding]::ASCII.GetString($data, $j, 4)
        $ss = Get-UInt16 $data ($j + 4)
        $j += 6
        if ($j + $ss -gt $data.Length) { break }
        if ($st -eq 'EDID') {
            return [Text.Encoding]::ASCII.GetString($data, $j, $ss).Trim([char]0)
        }
        $j += $ss
    }
    return $null
}

# --- main ---
if (-not (Test-Path $EspPath)) { throw "ESP not found: $EspPath" }

$originalBytes = [IO.File]::ReadAllBytes($EspPath)
$backup = "$EspPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
[IO.File]::WriteAllBytes($backup, $originalBytes)
Write-Host "Backup: $backup ($($originalBytes.Length) bytes)"

$src = Add-Master $originalBytes 'Playable Frog.esp'
$questFormId = [uint32]0x040036C8

$tes4Size = Get-UInt32 $src 4
$readPos = 24 + $tes4Size

$ms = New-Object System.IO.MemoryStream
$ms.Write($src, 0, [int]$readPos)

# Stack of output offsets where GRUP size fields need patching when the group ends
$grupStack = New-Object System.Collections.Generic.Stack[int]

function Write-GrupHeader([byte[]]$hdr24) {
    $offset = [int]$ms.Position
    $ms.Write($hdr24, 0, 24)
    $grupStack.Push($offset)
}

function Close-Grup {
    $offset = $grupStack.Pop()
    $size = [uint32]($ms.Position - $offset)
    $sizeBytes = [BitConverter]::GetBytes($size)
    $ms.Position = $offset + 4
    $ms.Write($sizeBytes, 0, 4)
    $ms.Position = $ms.Length
}

function Process-Range([int]$end) {
    while ($readPos + 24 -le $end -and $readPos + 24 -le $src.Length) {
        $type = [Text.Encoding]::ASCII.GetString($src, $readPos, 4)
        if ($type -eq 'GRUP') {
            $groupSize = Get-UInt32 $src ($readPos + 4)
            $groupEnd = $readPos + $groupSize
            $hdr = New-Object byte[] 24
            [Array]::Copy($src, $readPos, $hdr, 0, 24)
            Write-GrupHeader $hdr
            $script:readPos += 24
            Process-Range $groupEnd
            Close-Grup
            $script:readPos = $groupEnd
            continue
        }

        $dataSize = Get-UInt32 $src ($readPos + 4)
        $flags = Get-UInt32 $src ($readPos + 8)
        $formId = Get-UInt32 $src ($readPos + 12)
        $vc = Get-UInt32 $src ($readPos + 16)
        $ver = Get-UInt16 $src ($readPos + 20)
        $unk = Get-UInt16 $src ($readPos + 22)
        $dataStart = $readPos + 24
        $data = New-Object byte[] $dataSize
        [Array]::Copy($src, $dataStart, $data, 0, $dataSize)

        $edid = Get-EditorId $data
        if ($type -eq 'MGEF' -and $edid -and $edid.StartsWith('FRS_ME_Become')) {
            Write-Host "Patching $edid (0x$($formId.ToString('X8')))"
            $data = Expand-MgefVmad $data $questFormId
        }

        $hdr = New-Object byte[] 24
        [Text.Encoding]::ASCII.GetBytes($type).CopyTo($hdr, 0)
        Set-UInt32 $hdr 4 ([uint32]$data.Length)
        Set-UInt32 $hdr 8 $flags
        Set-UInt32 $hdr 12 $formId
        Set-UInt32 $hdr 16 $vc
        Set-UInt16 $hdr 20 $ver
        Set-UInt16 $hdr 22 $unk
        $ms.Write($hdr, 0, 24)
        $ms.Write($data, 0, $data.Length)

        $script:readPos = $dataStart + $dataSize
    }
}

$script:readPos = $readPos
Process-Range $src.Length

if ($grupStack.Count -ne 0) { throw "Unclosed GRUP count=$($grupStack.Count)" }

$outBytes = $ms.ToArray()
$verify = [Text.Encoding]::ASCII.GetString($outBytes)
if (-not $verify.Contains('QuestScript')) { throw 'QuestScript missing after patch' }
if (-not $verify.Contains('Playable Frog.esp')) { throw 'Playable Frog.esp master missing after patch' }

[IO.File]::WriteAllBytes($EspPath, $outBytes)
Write-Host "Wrote $EspPath ($($outBytes.Length) bytes; original $($originalBytes.Length))"

if ($DeployTo -and (Test-Path (Split-Path $DeployTo -Parent))) {
    Copy-Item $EspPath $DeployTo -Force
    Write-Host "Deployed to $DeployTo"
}

# Masters summary
$b2 = $outBytes
$ts = Get-UInt32 $b2 4
$i = 24
$end = 24 + $ts
$masters = @()
while ($i + 6 -le $end) {
    $t = [Text.Encoding]::ASCII.GetString($b2, $i, 4)
    $s = Get-UInt16 $b2 ($i + 4)
    $i += 6
    if ($t -eq 'MAST') { $masters += [Text.Encoding]::ASCII.GetString($b2, $i, $s).Trim([char]0) }
    $i += $s
}
Write-Host "Masters: $($masters -join ' | ')"
Write-Host "Done."
