$ErrorActionPreference = 'Stop'

function Assert-NoShadProcess {
    if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'shadPS4*' }) {
        throw 'Close every running shadPS4 instance before using the benchmark save tools.'
    }
}

function Get-Gow3SavePath([string]$ShadRoot) {
    $homeRoot = Join-Path $ShadRoot 'home'
    if (-not (Test-Path -LiteralPath $homeRoot)) {
        throw "shadPS4 home directory was not found: $homeRoot"
    }

    $candidates = @()
    foreach ($userDir in @(Get-ChildItem -LiteralPath $homeRoot -Directory -ErrorAction SilentlyContinue)) {
        $candidate = Join-Path $userDir.FullName 'savedata\CUSA01623'
        if (Test-Path -LiteralPath $candidate) {
            $candidates += $candidate
        }
    }

    if ($candidates.Count -eq 0) {
        throw 'No CUSA01623 save directory was found under %APPDATA%\shadPS4\home\<user>\savedata. Start GOW3 once and make sure the existing save is visible.'
    }
    if ($candidates.Count -gt 1) {
        throw ("Multiple CUSA01623 save directories were found. Keep only the benchmark user active or resolve manually: {0}" -f ($candidates -join '; '))
    }
    return $candidates[0]
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}
