$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot 'GOW3-BENCHMARK-COMMON.ps1')
Assert-NoShadProcess

$shadRoot = Join-Path $env:APPDATA 'shadPS4'
$configPath = Join-Path $shadRoot 'config.json'
$gameConfigPath = Join-Path (Join-Path $shadRoot 'custom_configs') 'CUSA01623.json'
$benchmarkRoot = Join-Path $shadRoot 'gow3-benchmark'
$stateRoot = Join-Path $benchmarkRoot 'pending-state'
$configBackupRoot = Join-Path $stateRoot 'config-backup'
$saveBackupRoot = Join-Path $stateRoot 'save-backup'

if (Test-Path -LiteralPath $configBackupRoot) {
    $globalBackup = Join-Path $configBackupRoot 'config.json'
    $noGlobalMarker = Join-Path $configBackupRoot 'NO-GLOBAL-CONFIG'
    if (Test-Path -LiteralPath $globalBackup) {
        Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $shadRoot | Out-Null
        Move-Item -LiteralPath $globalBackup -Destination $configPath -Force
    } elseif (Test-Path -LiteralPath $noGlobalMarker) {
        Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
    }

    $gameBackup = Join-Path $configBackupRoot 'CUSA01623.json'
    $noGameMarker = Join-Path $configBackupRoot 'NO-GAME-CONFIG'
    if (Test-Path -LiteralPath $gameBackup) {
        Remove-Item -LiteralPath $gameConfigPath -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gameConfigPath) | Out-Null
        Move-Item -LiteralPath $gameBackup -Destination $gameConfigPath -Force
    } elseif (Test-Path -LiteralPath $noGameMarker) {
        Remove-Item -LiteralPath $gameConfigPath -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path -LiteralPath $saveBackupRoot) {
    $pathFile = Join-Path $saveBackupRoot 'SAVE-PATH.txt'
    $saveBackupData = Join-Path $saveBackupRoot 'CUSA01623'
    if (Test-Path -LiteralPath $saveBackupData) {
        if (-not (Test-Path -LiteralPath $pathFile)) {
            throw "Cannot restore benchmark save: missing $pathFile"
        }
        $savePath = [System.IO.File]::ReadAllText($pathFile).Trim()
        Remove-Item -LiteralPath $savePath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $savePath) | Out-Null
        Move-Item -LiteralPath $saveBackupData -Destination $savePath -Force
    }
}

Remove-Item -LiteralPath $stateRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host 'Any pending benchmark configuration/save backup has been restored.'
