param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$EbootPath
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot 'GOW3-BENCHMARK-COMMON.ps1')
Assert-NoShadProcess

$exe = Join-Path $PSScriptRoot 'shadPS4-gow3-b580-benchmark.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    throw "Benchmark executable not found: $exe"
}
if (-not (Test-Path -LiteralPath $EbootPath)) {
    throw "eboot.bin not found: $EbootPath"
}
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'user')) {
    throw 'A portable user directory exists beside the benchmark artifact. Move/remove it so the benchmark uses the normal %APPDATA%\shadPS4 paths.'
}

$shadRoot = Join-Path $env:APPDATA 'shadPS4'
$customDir = Join-Path $shadRoot 'custom_configs'
$logDir = Join-Path $shadRoot 'log'
$configPath = Join-Path $shadRoot 'config.json'
$gameConfigPath = Join-Path $customDir 'CUSA01623.json'
$benchmarkRoot = Join-Path $shadRoot 'gow3-benchmark'
$stateRoot = Join-Path $benchmarkRoot 'pending-state'
$configBackupRoot = Join-Path $stateRoot 'config-backup'
$saveBackupRoot = Join-Path $stateRoot 'save-backup'
$snapshotRoot = Join-Path $benchmarkRoot 'snapshot'
$snapshotData = Join-Path $snapshotRoot 'CUSA01623'
$snapshotManifest = Join-Path $snapshotRoot 'SNAPSHOT-MANIFEST.json'
$outputRoot = Join-Path $PSScriptRoot 'test-output\benchmark-readback'

if (-not (Test-Path -LiteralPath $snapshotData)) {
    throw 'Benchmark save snapshot is missing. First close shadPS4 and run CREATE-GOW3-BENCHMARK-SNAPSHOT.bat while your desired checkpoint save is the current save.'
}
if (Test-Path -LiteralPath $stateRoot) {
    throw 'A pending benchmark state already exists. Run RESTORE-GOW3-BENCHMARK-STATE.ps1 before another benchmark.'
}

$savePath = Get-Gow3SavePath $shadRoot
$saveParent = Split-Path -Parent $savePath
$hadGlobalConfig = Test-Path -LiteralPath $configPath
$hadGameConfig = Test-Path -LiteralPath $gameConfigPath
New-Item -ItemType Directory -Force -Path $shadRoot, $customDir, $logDir, $benchmarkRoot, $stateRoot, $configBackupRoot, $saveBackupRoot, $outputRoot | Out-Null
if (-not $hadGlobalConfig) {
    New-Item -ItemType File -Force -Path (Join-Path $configBackupRoot 'NO-GLOBAL-CONFIG') | Out-Null
}
if (-not $hadGameConfig) {
    New-Item -ItemType File -Force -Path (Join-Path $configBackupRoot 'NO-GAME-CONFIG') | Out-Null
}

function Backup-IfPresent([string]$Path, [string]$Name) {
    if (Test-Path -LiteralPath $Path) {
        Move-Item -LiteralPath $Path -Destination (Join-Path $configBackupRoot $Name)
    }
}

$saveBackupData = Join-Path $saveBackupRoot 'CUSA01623'

try {
    Backup-IfPresent $configPath 'config.json'
    Backup-IfPresent $gameConfigPath 'CUSA01623.json'
    Write-Utf8NoBom (Join-Path $saveBackupRoot 'SAVE-PATH.txt') $savePath
    Move-Item -LiteralPath $savePath -Destination $saveBackupData
    Copy-Item -LiteralPath $snapshotData -Destination $savePath -Recurse -Force

    Write-Utf8NoBom $configPath '{}'
    $testConfig = [ordered]@{
        GPU = [ordered]@{
            copy_gpu_buffers = $false
            readbacks_mode = 1
            readback_linear_images_enabled = $true
            direct_memory_access_enabled = $false
            vblank_frequency = 60
        }
        Vulkan = [ordered]@{
            pipeline_cache_enabled = $false
            pipeline_cache_archived = $false
        }
    }
    $configJson = $testConfig | ConvertTo-Json -Depth 5
    Write-Utf8NoBom $gameConfigPath $configJson
    Write-Utf8NoBom (Join-Path $outputRoot 'TEST-CONFIG.json') $configJson
    if (Test-Path -LiteralPath $snapshotManifest) {
        Copy-Item -LiteralPath $snapshotManifest -Destination (Join-Path $outputRoot 'SNAPSHOT-MANIFEST.json') -Force
    }

    foreach ($name in @('shad_log.txt', 'perf_trace.csv', 'shadps4.log')) {
        Remove-Item -LiteralPath (Join-Path $logDir $name) -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $outputRoot $name) -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host '=== GOW3 deterministic gameplay benchmark ==='
    Write-Host 'Config: Relaxed readbacks + Linear Images ON; DMA/Copy GPU Buffers/Pipeline Cache OFF.'
    Write-Host 'The benchmark snapshot has replaced the live save only for this emulator run.'
    Write-Host ''
    Write-Host '1. Load Game and enter the benchmark checkpoint.'
    Write-Host '2. Stand at the agreed starting position.'
    Write-Host '3. Press F6 once: CSV capture STARTS and frame numbering resets to 0.'
    Write-Host '4. Perform the same 30-60 second route/action sequence.'
    Write-Host '5. Press F6 again: CSV capture STOPS and flushes to disk.'
    Write-Host '6. Close shadPS4 normally.'
    Write-Host ''

    & $exe -g $EbootPath --show-fps
    $emulatorExitCode = $LASTEXITCODE
}
finally {
    foreach ($name in @('shad_log.txt', 'perf_trace.csv', 'shadps4.log')) {
        $source = Join-Path $logDir $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $outputRoot $name) -Force
        }
    }

    $globalBackup = Join-Path $configBackupRoot 'config.json'
    if (Test-Path -LiteralPath $globalBackup) {
        Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath) | Out-Null
        Move-Item -LiteralPath $globalBackup -Destination $configPath -Force
    } elseif (-not $hadGlobalConfig) {
        Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
    }

    $gameBackup = Join-Path $configBackupRoot 'CUSA01623.json'
    if (Test-Path -LiteralPath $gameBackup) {
        Remove-Item -LiteralPath $gameConfigPath -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gameConfigPath) | Out-Null
        Move-Item -LiteralPath $gameBackup -Destination $gameConfigPath -Force
    } elseif (-not $hadGameConfig) {
        Remove-Item -LiteralPath $gameConfigPath -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $saveBackupData) {
        Remove-Item -LiteralPath $savePath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $saveParent | Out-Null
        Move-Item -LiteralPath $saveBackupData -Destination $savePath -Force
    }

    Remove-Item -LiteralPath $stateRoot -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ''
    Write-Host 'Original configuration and live save restored.'
    Write-Host "Benchmark outputs: $outputRoot"
}

if ($null -ne $emulatorExitCode) {
    exit $emulatorExitCode
}
