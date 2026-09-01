param(
    [switch]$Execute,
    [switch]$LivePrecheckOnly,
    [switch]$StaticPrecheckOnly,
    [string]$WorkDir = "",
    [string]$FdlDir = ""
)

$ErrorActionPreference = "Stop"
$hostIsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows
)
if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    $WorkDir = if ($hostIsWindows) { "C:\aruba-unlock-tools" } else { "/tmp/aruba-unlock-tools" }
}

if (([int][bool]$Execute + [int][bool]$LivePrecheckOnly + [int][bool]$StaticPrecheckOnly) -gt 1) {
    throw "Choose exactly one of -Execute, -LivePrecheckOnly, or -StaticPrecheckOnly."
}
if (-not $Execute -and -not $LivePrecheckOnly -and -not $StaticPrecheckOnly) {
    Write-Host "DRY SAFETY STOP: ARUBA v3 runner performs no phone operation without an explicit mode."
    Write-Host "-StaticPrecheckOnly is phone-free. -LivePrecheckOnly is read-only. -Execute enables one guarded single-entry v3 transaction."
    exit 2
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($FdlDir)) {
    $FdlDir = Join-Path $repoRoot "files\unlock"
}
Set-Location $WorkDir

$spd           = Join-Path $WorkDir $(if ($hostIsWindows) { "spd_dump.exe" } else { "spd_dump" })
$execHelper    = Join-Path $WorkDir "custom_exec_no_verify_65015f08.bin"
$fdl1          = Join-Path $FdlDir "fdl1.bin"
$fdl2          = Join-Path $FdlDir "fdl2.bin"
$splUnlock     = Join-Path $FdlDir "spl-unlock.bin"
$miscWipe      = Join-Path $WorkDir "misc-wipe.bin"
$candidate     = Join-Path $FdlDir "uboot-unlock.bin"
$stockUboot    = Join-Path $repoRoot "files\recovery\stock-uboot.bin"
$stockSpl      = Join-Path $repoRoot "files\recovery\stock-spl.bin"

$hashFdl1       = "98A308E4C755219D592288EB668117B938C3435783DD5E0F75E450CDCE5A3076"
$hashFdl2       = "5BCAE75A8E3A940B294F46DDE2CD8FC5817A89A0544C917437A500A9188F03B3"
$hashCandidate  = "F16385309B5F2538D406207411D09B3D02DE23B341E5A10602BF458DFED7E5B3"
$hashSplUnlock  = "2DFE4FC1D5B82768B78247D51A98BE5874A10A54264AAA165D2D2D5639CEF2DB"
$hashStockSpl   = "895FC2EDD262857E48D9472D117AFB63668D17820A289F1E51E57696FE403F77"
$hashStockUboot = "776471A810A4A79B6A5B0084BCE6C1F9E0D40D3F32069D0486E370BB3FD65C56"
$hashMiscWipe   = "BD6B67E852D6072E6FB87040F2AC40216D5B661B7FA661E7024569ECF8DDB3A7"
$hashErased     = "43C87ECCD9B10AA809D1F61A481F1FB6D61DE2662CF5D79624D12488543ADFCD"
$hashZero64     = "F5A5FD42D16A20302798EF6ED309979B43003D2320D9F0E8EA9831A92759FB4B"
$hashV1Invalid  = "8AF340B74CEDDF8D6F3614850B122693899F414B3A17C19FD306D1B9E9A0C0A0"

$expectedOriginal = [byte[]](0x8A,0xFE,0xFF,0x97,0x7F,0x0A,0x00,0x71,0xC1,0x00,0x00,0x54)
$expectedPatch    = [byte[]](0x20,0x00,0x80,0x52,0x70,0xE6,0x01,0x94,0x2B,0x00,0x00,0x14)
$expectedDiffs    = [int[]](0x73DC,0x73DD,0x73DE,0x73DF,0x73E0,0x73E1,0x73E2,0x73E3,0x73E4,0x73E7)

function Get-Sha256([string]$Path) {
    return (Get-FileHash $Path -Algorithm SHA256).Hash
}

function Assert-Hash([string]$Path,[string]$Expected) {
    if (-not (Test-Path $Path)) { throw "Missing file: $Path" }
    $actual = Get-Sha256 $Path
    if ($actual -ne $Expected) {
        throw "SHA256 mismatch: $Path`nexpected $Expected`nactual   $actual"
    }
}

function Assert-Size([string]$Path,[long]$Expected) {
    if (-not (Test-Path $Path)) { throw "Missing file: $Path" }
    $actual = (Get-Item $Path).Length
    if ($actual -ne $Expected) {
        throw "Size mismatch: $Path expected $Expected actual $actual"
    }
}

function Assert-Bytes([byte[]]$Blob,[int]$Offset,[byte[]]$Expected,[string]$Label) {
    for ($i=0; $i -lt $Expected.Length; $i++) {
        if ($Blob[$Offset+$i] -ne $Expected[$i]) {
            throw ("{0} byte mismatch at 0x{1:X}" -f $Label,($Offset+$i))
        }
    }
}

function Assert-StaticInputs {
    Write-Host "=== V3 STATIC HASH PREFLIGHT ==="
    Assert-Hash $fdl1 $hashFdl1; Assert-Size $fdl1 60664
    Assert-Hash $fdl2 $hashFdl2; Assert-Size $fdl2 1159000
    Assert-Hash $candidate $hashCandidate; Assert-Size $candidate 1159000
    Assert-Hash $splUnlock $hashSplUnlock; Assert-Size $splUnlock 65416
    Assert-Hash $stockSpl $hashStockSpl; Assert-Size $stockSpl 65416
    Assert-Hash $stockUboot $hashStockUboot; Assert-Size $stockUboot 1159000
    Assert-Hash $miscWipe $hashMiscWipe
    Assert-Hash $execHelper "32D8B796FF484C168D7FC63D9ED75D056D0833B55C7D65FBDAF2C548474F3C62"; Assert-Size $execHelper 96

    $stock = [IO.File]::ReadAllBytes($stockUboot)
    $cand = [IO.File]::ReadAllBytes($candidate)
    Assert-Bytes $stock 0x73DC $expectedOriginal "stock v3 site"
    Assert-Bytes $cand 0x73DC $expectedPatch "v3 candidate site"

    $actualDiffs = New-Object System.Collections.Generic.List[int]
    for ($i=0; $i -lt $stock.Length; $i++) {
        if ($stock[$i] -ne $cand[$i]) { [void]$actualDiffs.Add($i) }
    }
    if ($actualDiffs.Count -ne $expectedDiffs.Count) {
        throw "Unexpected candidate diff count: $($actualDiffs.Count)"
    }
    for ($i=0; $i -lt $expectedDiffs.Count; $i++) {
        if ($actualDiffs[$i] -ne $expectedDiffs[$i]) {
            throw ("Unexpected candidate diff at index {0}: 0x{1:X} expected 0x{2:X}" -f $i,$actualDiffs[$i],$expectedDiffs[$i])
        }
    }
    Write-Host "Static files, exact v3 patch bytes, and exact ten-byte diff verified."
}

function Invoke-Spd(
    [string[]]$Arguments,
    [switch]$AllowNonZero,
    [int]$Attempts = 5,
    [int]$RetryDelaySeconds = 2
) {
    if ($Attempts -lt 1) { throw "Attempts must be at least 1" }

    for ($attempt=1; $attempt -le $Attempts; $attempt++) {
        Write-Host ("spd_dump attempt {0}/{1}" -f $attempt,$Attempts)
        $saved = $ErrorActionPreference
        $code = $null
        try {
            $ErrorActionPreference = "Continue"
            & $spd @Arguments | Out-Host
            $code = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $saved
        }

        Write-Host "spd_dump exit code: $code"
        if ($code -eq 0) { return [int]$code }
        if ($AllowNonZero) { return [int]$code }

        if ($attempt -lt $Attempts) {
            Write-Warning ("spd_dump exited with code {0}. Retrying the same idempotent stage in {1}s." -f $code,$RetryDelaySeconds)
            Start-Sleep -Seconds $RetryDelaySeconds
            continue
        }
        throw "spd_dump failed with exit code $code after $Attempts attempts"
    }
}

function Quote-ProcessArgument([string]$Value) {
    return '"' + $Value.Replace('"','\"') + '"'
}

function Start-SpdFdl2Interactive {
    $arguments = @(
        "--wait","300",
        "exec_addr","0x65015f08",
        "fdl",$fdl1,"0x65000800",
        "fdl",$fdl2,"0x9efffe00",
        "exec"
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $spd
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    $psi.CreateNoWindow = $false
    $psi.Arguments = (($arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join " ")

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    if (-not $process.Start()) {
        throw "Unable to start interactive spd_dump session"
    }
    $process.StandardInput.AutoFlush = $true
    return $process
}

function Send-SpdCommand([System.Diagnostics.Process]$Process,[string]$Command) {
    if ($Process.HasExited) {
        throw "Interactive spd_dump exited before command: $Command"
    }
    Write-Host ("FDL2 command: " + $Command)
    $Process.StandardInput.WriteLine($Command)
    $Process.StandardInput.Flush()
}

function Wait-ExactFile(
    [string]$Path,
    [long]$ExpectedSize,
    [System.Diagnostics.Process]$Process,
    [int]$TimeoutSeconds = 180
) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $Path) {
            $size1 = (Get-Item $Path).Length
            if ($size1 -eq $ExpectedSize) {
                Start-Sleep -Milliseconds 250
                $size2 = (Get-Item $Path).Length
                if ($size2 -eq $ExpectedSize) { return }
            }
        }
        if ($Process.HasExited) {
            throw "Interactive spd_dump exited before producing $Path"
        }
        Start-Sleep -Milliseconds 250
    }
    throw "Timed out waiting for $Path size $ExpectedSize"
}

function Wait-InteractiveExit(
    [System.Diagnostics.Process]$Process,
    [int]$TimeoutSeconds = 30
) {
    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
        throw "Interactive spd_dump did not exit after requested transport transition"
    }
    Write-Host "interactive spd_dump exit code: $($Process.ExitCode)"
}

function Validate-LiveRecord([string]$Path) {
    Assert-Size $Path 64
    $recHash = Get-Sha256 $Path
    Write-Host "Live record SHA256: $recHash"
    if ($recHash -eq $hashV1Invalid) {
        Write-Host "Live record matches the known persistent historical invalid record."
    }
    elseif ($recHash -eq $hashZero64) {
        Write-Host "Live record matches the known all-zero baseline."
    }
    else {
        throw "Unexpected live miscdata+0x2000 record. Stop before destructive work and preserve it: $recHash"
    }
    return $recHash
}

function Invoke-LivePrecheckOnly {
    Write-Host ""
    Write-Host "=== LIVE READ-ONLY STOCK-CHAIN PRECHECK ==="
    $preSpl   = Join-Path $attemptDir "pre_splloader.bin"
    $preBak   = Join-Path $attemptDir "pre_splloader_bak.bin"
    $preUboot = Join-Path $attemptDir "pre_uboot.bin"
    $preRec   = Join-Path $attemptDir "pre_miscdata_64.bin"

    Invoke-Spd @(
        "--wait","300",
        "exec_addr","0x65015f08",
        "fdl",$fdl1,"0x65000800",
        "fdl",$fdl2,"0x9efffe00",
        "exec",
        "timeout","30000",
        "read_part","splloader","0","65416",$preSpl,
        "read_part","splloader_bak","0","65416",$preBak,
        "read_part","uboot","0","1159000",$preUboot,
        "read_part","miscdata","8192","64",$preRec,
        "poweroff"
    ) | Out-Null

    Assert-Hash $preSpl $hashStockSpl
    Assert-Hash $preBak $hashStockSpl
    Assert-Hash $preUboot $hashStockUboot
    $recHash = Validate-LiveRecord $preRec
    Write-Host "Live U-Boot and both SPL copies match trusted stock hashes."
    Write-Host ""
    Write-Host "V3 LIVE PRECHECK RESULT: PASS"
    Write-Host "No erase or write operation was performed. Phone was powered off without a normal boot."
    return $recHash
}

function Try-InteractiveRecovery([System.Diagnostics.Process]$Process) {
    if ($null -eq $Process -or $Process.HasExited) { return $false }

    Write-Warning "Attempting stock-chain recovery in the still-open FDL2 session."
    $recoveryUboot = Join-Path $attemptDir "RECOVERY_uboot.bin"
    $recoverySpl   = Join-Path $attemptDir "RECOVERY_splloader.bin"
    $recoveryBak   = Join-Path $attemptDir "RECOVERY_splloader_bak.bin"

    Send-SpdCommand $Process "skip_confirm 1"
    Send-SpdCommand $Process "w uboot $stockUboot"
    Send-SpdCommand $Process "w splloader $stockSpl"
    Send-SpdCommand $Process "w splloader_bak $stockSpl"
    Send-SpdCommand $Process "w misc $miscWipe"
    Send-SpdCommand $Process "read_part uboot 0 1159000 $recoveryUboot"
    Send-SpdCommand $Process "read_part splloader 0 65416 $recoverySpl"
    Send-SpdCommand $Process "read_part splloader_bak 0 65416 $recoveryBak"

    Wait-ExactFile $recoveryUboot 1159000 $Process
    Wait-ExactFile $recoverySpl 65416 $Process
    Wait-ExactFile $recoveryBak 65416 $Process
    Assert-Hash $recoveryUboot $hashStockUboot
    Assert-Hash $recoverySpl $hashStockSpl
    Assert-Hash $recoveryBak $hashStockSpl

    Send-SpdCommand $Process "poweroff"
    Wait-InteractiveExit $Process 30
    Write-Host "Emergency stock-chain recovery verified in the existing FDL2 session."
    return $true
}

if (-not (Test-Path $spd)) { throw "Missing spd_dump transport: $spd" }

$savedProbePreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $toolInfo = (& $spd --help 2>&1 | Out-String)
    $toolInfoExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $savedProbePreference
}
if ($toolInfo -notmatch "sha1:fa0becf5e3f026b3b99103c65de6eb9a8348b27c") {
    throw "Unexpected spd_dump build"
}
Write-Host "Verified spd_dump build: fa0becf5e3f026b3b99103c65de6eb9a8348b27c (probe exit $toolInfoExit)"
Assert-StaticInputs

if ($StaticPrecheckOnly) {
    Write-Host "V3 STATIC PRECHECK RESULT: PASS"
    Write-Host "phone_operation_performed=NO"
    exit 0
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$prefix = if ($LivePrecheckOnly) { "V3_LIVE_PRECHECK_" } else { "V3_TRANSACTION_" }
$attemptDir = Join-Path $WorkDir ($prefix + $stamp)
New-Item -ItemType Directory -Path $attemptDir | Out-Null
$transcript = Join-Path $attemptDir "transcript.txt"
Start-Transcript -Path $transcript | Out-Null
$transcriptStarted = $true

$destructiveStarted = $false
$stockRestored = $false
$mainError = $null
$restoreError = $null
$preRecordHash = $null
$postCandidateRecordHash = $null
$postRestoreRecordHash = $null
$unlockLoaderExit = $null
$interactive = $null
$stage4Interactive = $null

try {
    if ($LivePrecheckOnly) {
        $preRecordHash = Invoke-LivePrecheckOnly
    }
    else {
        Write-Host ""
        Write-Host "=== SINGLE-ENTRY V3 TRANSACTION ==="
        Write-Host "One initial BootROM entry only. No further volume-key re-entry is expected."
        Write-Host "The live precheck, SPL erase, and candidate write stay in one FDL2 session."

        $preSpl   = Join-Path $attemptDir "pre_splloader.bin"
        $preBak   = Join-Path $attemptDir "pre_splloader_bak.bin"
        $preUboot = Join-Path $attemptDir "pre_uboot.bin"
        $preRec   = Join-Path $attemptDir "pre_miscdata_64.bin"

        $precheckReady = $false
        $precheckLastError = $null
        for ($precheckAttempt = 1; $precheckAttempt -le 5; $precheckAttempt++) {
            Write-Host ("retained FDL2 precheck attempt {0}/5" -f $precheckAttempt)
            foreach ($partial in @($preSpl,$preBak,$preUboot,$preRec)) {
                if (Test-Path $partial) { Remove-Item -Force $partial }
            }
            $interactive = $null
            try {
                $interactive = Start-SpdFdl2Interactive
                Send-SpdCommand $interactive "timeout 30000"

                Write-Host ""
                Write-Host "=== LIVE READ-ONLY STOCK-CHAIN PRECHECK IN RETAINED FDL2 SESSION ==="
                Send-SpdCommand $interactive "read_part splloader 0 65416 $preSpl"
                Send-SpdCommand $interactive "read_part splloader_bak 0 65416 $preBak"
                Send-SpdCommand $interactive "read_part uboot 0 1159000 $preUboot"
                Send-SpdCommand $interactive "read_part miscdata 8192 64 $preRec"

                Wait-ExactFile $preSpl 65416 $interactive
                Wait-ExactFile $preBak 65416 $interactive
                Wait-ExactFile $preUboot 1159000 $interactive
                Wait-ExactFile $preRec 64 $interactive

                Assert-Hash $preSpl $hashStockSpl
                Assert-Hash $preBak $hashStockSpl
                Assert-Hash $preUboot $hashStockUboot
                $preRecordHash = Validate-LiveRecord $preRec
                $precheckReady = $true
                break
            }
            catch {
                $precheckLastError = $_
                $retryableEarlyExit = $_.Exception.Message -like "Interactive spd_dump exited before*"
                if (-not $retryableEarlyExit) { throw }
                if ($null -ne $interactive -and -not $interactive.HasExited) {
                    throw "Retained FDL2 precheck failed while spd_dump is still active; refusing automatic retry."
                }
                if ($precheckAttempt -ge 5) { throw }
                Write-Warning "Pre-destructive spd_dump session exited before a complete readback. Retrying without any erase/write."
                Start-Sleep -Seconds 2
            }
        }
        if (-not $precheckReady) {
            if ($precheckLastError) { throw $precheckLastError }
            throw "Retained FDL2 precheck did not reach PASS."
        }
        Write-Host "Live U-Boot and both SPL copies match trusted stock hashes."
        Write-Host "V3 retained-session live precheck: PASS"
        Write-Host "No destructive command has been sent before this PASS."

        Write-Host ""
        Write-Host "=== STAGE 1: ERASE BOTH SPL COPIES IN SAME FDL2 SESSION ==="
        Send-SpdCommand $interactive "skip_confirm 1"
        $destructiveStarted = $true
        $eraseMain = Join-Path $attemptDir "splloader_after_erase.bin"
        $eraseBak  = Join-Path $attemptDir "splloader_bak_after_erase.bin"

        Send-SpdCommand $interactive "e splloader"
        Send-SpdCommand $interactive "e splloader_bak"
        Send-SpdCommand $interactive "read_part splloader 0 65416 $eraseMain"
        Send-SpdCommand $interactive "read_part splloader_bak 0 65416 $eraseBak"

        Wait-ExactFile $eraseMain 65416 $interactive
        Wait-ExactFile $eraseBak 65416 $interactive
        Assert-Hash $eraseMain $hashErased
        Assert-Hash $eraseBak $hashErased
        Write-Host "Both SPL erase readbacks verified."

        Write-Host ""
        Write-Host "=== STAGE 2: WRITE AND VERIFY ARUBA CBOOT V3 IN SAME FDL2 SESSION ==="
        $candidateReadback = Join-Path $attemptDir "uboot_cboot_v3_readback.bin"

        Send-SpdCommand $interactive "w uboot $candidate"
        Send-SpdCommand $interactive "read_part uboot 0 1159000 $candidateReadback"
        Wait-ExactFile $candidateReadback 1159000 $interactive
        Assert-Hash $candidateReadback $hashCandidate
        Write-Host "Cboot v3 readback verified."

        Write-Host "Issuing NORMAL RESET only now, after both on-disk SPL copies are verified erased."
        Write-Host "With both SPL copies erased, the tested unlock flow falls back to BootROM automatically."
        Send-SpdCommand $interactive "reset"
        Wait-InteractiveExit $interactive 30
        $interactive = $null
        Start-Sleep -Seconds 3

        Write-Host ""
        Write-Host "=== STAGE 3: EXECUTE SPL-UNLOCK ONCE ==="
        Write-Host "No volume-key action is expected. The phone should already be in BootROM because both on-disk SPL copies are erased."
        Write-Host "USB removal or a non-zero process exit can occur during this one non-idempotent stage."
        $unlockLoaderExit = Invoke-Spd @(
            "--wait","300",
            "exec_addr","0x65015f08",
            "fdl",$splUnlock,"0x65000800"
        ) -AllowNonZero -Attempts 1
        Write-Host "spl-unlock stage process exit code: $unlockLoaderExit"
        Start-Sleep -Seconds 5

        Write-Host ""
        Write-Host "=== STAGE 4: AUTO-RECONNECT, CAPTURE RECORD, RESTORE STOCK CHAIN ==="
        Write-Host "No volume-key action is expected. SPL remains erased until stock restoration is verified."

        $recordAfter    = Join-Path $attemptDir "miscdata_after_cboot_v3.bin"
        $ubootRestored  = Join-Path $attemptDir "uboot_after_restore.bin"
        $splRestored    = Join-Path $attemptDir "splloader_after_restore.bin"
        $splBakRestored = Join-Path $attemptDir "splloader_bak_after_restore.bin"
        $recordPost     = Join-Path $attemptDir "miscdata_after_restore.bin"

        $stage4Interactive = Start-SpdFdl2Interactive
        Send-SpdCommand $stage4Interactive "timeout 30000"
        Send-SpdCommand $stage4Interactive "skip_confirm 1"

        Send-SpdCommand $stage4Interactive "read_part miscdata 8192 64 $recordAfter"
        Send-SpdCommand $stage4Interactive "w uboot $stockUboot"
        Send-SpdCommand $stage4Interactive "w splloader $stockSpl"
        Send-SpdCommand $stage4Interactive "w splloader_bak $stockSpl"
        Send-SpdCommand $stage4Interactive "w misc $miscWipe"
        Send-SpdCommand $stage4Interactive "read_part uboot 0 1159000 $ubootRestored"
        Send-SpdCommand $stage4Interactive "read_part splloader 0 65416 $splRestored"
        Send-SpdCommand $stage4Interactive "read_part splloader_bak 0 65416 $splBakRestored"
        Send-SpdCommand $stage4Interactive "read_part miscdata 8192 64 $recordPost"

        Wait-ExactFile $recordAfter 64 $stage4Interactive
        Wait-ExactFile $ubootRestored 1159000 $stage4Interactive
        Wait-ExactFile $splRestored 65416 $stage4Interactive
        Wait-ExactFile $splBakRestored 65416 $stage4Interactive
        Wait-ExactFile $recordPost 64 $stage4Interactive

        Assert-Hash $ubootRestored $hashStockUboot
        Assert-Hash $splRestored $hashStockSpl
        Assert-Hash $splBakRestored $hashStockSpl

        $postCandidateRecordHash = Get-Sha256 $recordAfter
        $postRestoreRecordHash = Get-Sha256 $recordPost

        Write-Host "record before v3 SHA256 : $preRecordHash"
        Write-Host "record after v3 SHA256  : $postCandidateRecordHash"
        Write-Host "record after restore    : $postRestoreRecordHash"

        if ($postRestoreRecordHash -ne $postCandidateRecordHash) {
            throw "Unexpected miscdata record change during stock-chain restoration. Preserve all artifacts."
        }

        $stockRestored = $true
        Write-Host "Stock U-Boot and both SPL copies are verified restored."
        Write-Host "Powering phone off only after verified stock restoration."
        Send-SpdCommand $stage4Interactive "poweroff"
        Wait-InteractiveExit $stage4Interactive 30
        $stage4Interactive = $null

        Write-Host ""
        Write-Host "V3 TRANSACTION MECHANICS: COMPLETE"
        Write-Host "THIS IS NOT YET PROOF OF BOOTLOADER UNLOCK."
        Write-Host "Independent verification after a manual normal stock boot is mandatory."
    }
}
catch {
    $mainError = $_
    Write-Host ("ERROR: " + $_.Exception.Message)
}
finally {
    if ($destructiveStarted -and -not $stockRestored -and $mainError) {
        Write-Host ""
        Write-Warning "Error after destructive work began. Attempting stock-chain recovery without asking for another volume-key entry."
        try {
            $recovered = $false
            if ($null -ne $stage4Interactive -and -not $stage4Interactive.HasExited) {
                $recovered = Try-InteractiveRecovery $stage4Interactive
            }
            elseif ($null -ne $interactive -and -not $interactive.HasExited) {
                $recovered = Try-InteractiveRecovery $interactive
            }

            if (-not $recovered) {
                Write-Warning "No live FDL2 session remains. Trying automatic BootROM recovery while on-disk SPL is erased."
                $recoveryUboot = Join-Path $attemptDir "RECOVERY_uboot.bin"
                $recoverySpl   = Join-Path $attemptDir "RECOVERY_splloader.bin"
                $recoveryBak   = Join-Path $attemptDir "RECOVERY_splloader_bak.bin"

                Invoke-Spd @(
                    "--wait","300",
                    "exec_addr","0x65015f08",
                    "fdl",$fdl1,"0x65000800",
                    "fdl",$fdl2,"0x9efffe00",
                    "exec",
                    "timeout","30000",
                    "w","uboot",$stockUboot,
                    "w","splloader",$stockSpl,
                    "w","splloader_bak",$stockSpl,
                    "w","misc",$miscWipe,
                    "read_part","uboot","0","1159000",$recoveryUboot,
                    "read_part","splloader","0","65416",$recoverySpl,
                    "read_part","splloader_bak","0","65416",$recoveryBak,
                    "poweroff"
                ) | Out-Null

                Assert-Hash $recoveryUboot $hashStockUboot
                Assert-Hash $recoverySpl $hashStockSpl
                Assert-Hash $recoveryBak $hashStockSpl
                $recovered = $true
                Write-Host "Emergency automatic BootROM stock-chain recovery verified."
            }

            if ($recovered) { $stockRestored = $true }
        }
        catch {
            $restoreError = $_
            Write-Host ("EMERGENCY RECOVERY FAILED: " + $_.Exception.Message)
        }
    }

    if ($transcriptStarted) { Stop-Transcript | Out-Null }
}

$summary = Join-Path $attemptDir "result-summary.txt"
@(
    "mode=" + $(if ($LivePrecheckOnly) { "live-precheck-only" } else { "v3-single-entry-transaction" }),
    "candidate_sha256=$hashCandidate",
    "pre_record_sha256=$preRecordHash",
    "post_v3_record_sha256=$postCandidateRecordHash",
    "post_restore_record_sha256=$postRestoreRecordHash",
    "spl_unlock_process_exit=$unlockLoaderExit",
    "stock_chain_restored=$stockRestored",
    "manual_volume_entries_expected=1",
    "unlock_state=NOT_VERIFIED_BY_THIS_SCRIPT"
) | Set-Content $summary -Encoding ASCII

Write-Host ""
Write-Host "Artifacts: $attemptDir"
Write-Host "Summary:   $summary"

if ($restoreError) {
    throw "FINAL ERROR: automatic stock-chain recovery could not be verified. Do not attempt normal boot."
}
if ($mainError) { throw $mainError }

if ($LivePrecheckOnly) { exit 0 }
if (-not $stockRestored) {
    throw "FINAL ERROR: stock-chain restoration was not verified."
}
if ($postCandidateRecordHash -eq $preRecordHash) {
    Write-Warning "FINAL V3 RESULT: stock chain restored, but the 64-byte record did not change."
    exit 3
}

Write-Host "FINAL V3 MECHANICAL RESULT: stock chain restored and the 64-byte record changed."
Write-Host "Phone is powered off. Boot Android manually and verify ro.boot.flash.locked=0 and ro.boot.vbmeta.device_state=unlocked before calling the bootloader unlocked."
exit 0
