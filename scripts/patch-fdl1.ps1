param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "fdl1.bin"
)

$ErrorActionPreference = "Stop"

function U32([byte[]]$buf,[int]$off) {
    return [uint64][BitConverter]::ToUInt32($buf,$off)
}

$inputPath = (Resolve-Path $InputFile).Path
$outputPath = [IO.Path]::GetFullPath($OutputFile)

$b = [IO.File]::ReadAllBytes($inputPath)

if ($b.Length -ne 60664) {
    throw "Unexpected FDL1 size: $($b.Length), expected 60664"
}

$expectedHash = "1300593D3772E1E999CA8D3B79F97DC098225612D45906DDE07707C683187C2D"
$actualHash = (Get-FileHash $inputPath -Algorithm SHA256).Hash

if ($actualHash -ne $expectedHash) {
    throw "Unexpected FDL1 SHA256: $actualHash"
}

$expected = @{
    0x9F5C = 0x940000A7L
    0x9F60 = 0x34000040L
    0x9F64 = 0x14000000L
}

foreach ($p in $expected.Keys) {
    $actual = U32 $b ([int]$p)
    if ($actual -ne $expected[$p]) {
        throw ("Instruction mismatch at 0x{0:X}: actual 0x{1:X8}, expected 0x{2:X8}" -f $p,$actual,$expected[$p])
    }
}

$nop = [byte[]](0x1F,0x20,0x03,0xD5)

foreach ($p in @(0x9F5C,0x9F60,0x9F64)) {
    [Array]::Copy($nop,0,$b,[int]$p,4)
}

[IO.File]::WriteAllBytes($outputPath,$b)

$resultHash = (Get-FileHash $outputPath -Algorithm SHA256).Hash
$expectedResultHash = "98A308E4C755219D592288EB668117B938C3435783DD5E0F75E450CDCE5A3076"

Write-Host "Output:  $outputPath"
Write-Host "Size:    $((Get-Item $outputPath).Length)"
Write-Host "SHA256:  $resultHash"

if ($resultHash -ne $expectedResultHash) {
    throw "Patched FDL1 hash does not match the verified result"
}

Write-Host "Verified ARUBA FDL1 patch OK"
