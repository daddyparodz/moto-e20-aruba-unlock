param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "fdl2.bin"
)

$ErrorActionPreference = "Stop"

function U32([byte[]]$buf,[int]$off) {
    return [uint64][BitConverter]::ToUInt32($buf,$off)
}

$inputPath = (Resolve-Path $InputFile).Path
$outputPath = [IO.Path]::GetFullPath($OutputFile)

$d = [IO.File]::ReadAllBytes($inputPath)

if ($d.Length -ne 1159000) {
    throw "Unexpected FDL2 size: $($d.Length), expected 1159000"
}

$expectedHash = "3C12C9673B103CC281E6C0F66E840531A2AB4636714E78E66D597DF4A4977E73"
$actualHash = (Get-FileHash $inputPath -Algorithm SHA256).Hash

if ($actualHash -ne $expectedHash) {
    throw "Unexpected FDL2 SHA256: $actualHash"
}

$expected = @{
    0x0697C = 0x94021A8AL
    0x7F97C = 0xAA1403E1L
    0x7F980 = 0x97FFDD2CL
    0x7F984 = 0x34000080L
    0x7F988 = 0xF8408E60L
    0x7F98C = 0xB5FFFF60L
}

foreach ($p in $expected.Keys) {
    $actual = U32 $d ([int]$p)
    if ($actual -ne $expected[$p]) {
        throw ("Instruction mismatch at 0x{0:X}: actual 0x{1:X8}, expected 0x{2:X8}" -f $p,$actual,$expected[$p])
    }
}

if ((U32 $d 0x7F990) -ne 0x52800020L) {
    throw "Expected MOV W0,#1 at 0x7F990 is missing"
}

$nop = [byte[]](0x1F,0x20,0x03,0xD5)
$patchOffsets = @(0x0697C,0x7F97C,0x7F980,0x7F984,0x7F988,0x7F98C)

foreach ($p in $patchOffsets) {
    [Array]::Copy($nop,0,$d,[int]$p,4)
}

[IO.File]::WriteAllBytes($outputPath,$d)

$resultHash = (Get-FileHash $outputPath -Algorithm SHA256).Hash
$expectedResultHash = "5BCAE75A8E3A940B294F46DDE2CD8FC5817A89A0544C917437A500A9188F03B3"

Write-Host "Output:  $outputPath"
Write-Host "Size:    $((Get-Item $outputPath).Length)"
Write-Host "SHA256:  $resultHash"

if ($resultHash -ne $expectedResultHash) {
    throw "Patched FDL2 hash does not match the verified result"
}

Write-Host "Verified ARUBA FDL2 patch OK"
