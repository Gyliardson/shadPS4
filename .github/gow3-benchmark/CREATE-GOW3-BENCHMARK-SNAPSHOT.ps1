param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot 'GOW3-BENCHMARK-COMMON.ps1')
Assert-NoShadProcess

if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'user')) {
    throw 'A portable user directory exists beside the benchmark artifact. Move/remove it so this benchmark uses the normal %APPDATA%\shadPS4 save root.'
}

$shadRoot = Join-Path $env:APPDATA 'shadPS4'
$savePath = Get-Gow3SavePath $shadRoot
$benchmarkRoot = Join-Path $shadRoot 'gow3-benchmark'
$snapshotRoot = Join-Path $benchmarkRoot 'snapshot'
$snapshotData = Join-Path $snapshotRoot 'CUSA01623'
$manifestPath = Join-Path $snapshotRoot 'SNAPSHOT-MANIFEST.json'

if ((Test-Path -LiteralPath $snapshotRoot) -and -not $Force) {
    throw 'A benchmark snapshot already exists. Use CREATE-GOW3-BENCHMARK-SNAPSHOT.bat -Force only if you intentionally want to replace it.'
}

if (Test-Path -LiteralPath $snapshotRoot) {
    Remove-Item -LiteralPath $snapshotRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $snapshotRoot | Out-Null
Copy-Item -LiteralPath $savePath -Destination $snapshotData -Recurse -Force

$manifest = [ordered]@{
    game_id = 'CUSA01623'
    source_save_path = $savePath
    created_at = (Get-Date).ToString('o')
    note = 'Immutable benchmark input. START-GOW3-BENCHMARK restores the user save after every run.'
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 4)

Write-Host ''
Write-Host 'Benchmark save snapshot created.'
Write-Host "Source:   $savePath"
Write-Host "Snapshot: $snapshotData"
Write-Host 'This persistent snapshot is reused by future benchmark artifacts. Do not modify it during A/B testing.'
