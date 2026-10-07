function Get-SpecArtifactHash {
    param([string[]]$Paths)

    $builder = [System.Text.StringBuilder]::new()
    foreach ($path in $Paths | Sort-Object) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            [void]$builder.AppendLine(
                [System.IO.Path]::GetFullPath($path)
            )
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            try {
                $stream = [System.IO.File]::OpenRead($path)
                try {
                    $hashBytes = $sha256.ComputeHash($stream)
                }
                finally {
                    $stream.Dispose()
                }
                $hex = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
                [void]$builder.AppendLine($hex)
            }
            finally {
                $sha256.Dispose()
            }
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $hasher.ComputeHash($bytes)
    }
    finally {
        $hasher.Dispose()
    }
    $hex = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
    return $hex
}

function Write-AnalyzeReceipt {
    param(
        [string]$GitDir,
        [string]$ArtifactHash,
        [int]$Critical,
        [int]$High,
        [int]$Medium,
        [int]$Low
    )

    $directory = Join-Path $GitDir "speckit"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $receipt = [PSCustomObject]@{
        artifact_hash = $ArtifactHash
        critical = $Critical
        high = $High
        medium = $Medium
        low = $Low
        recorded_at = [DateTime]::UtcNow.ToString("o")
    }
    $path = Join-Path $directory "analyze-gate.json"
    $receipt | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
}

function Read-AnalyzeReceipt {
    param([string]$GitDir)

    $path = Join-Path $GitDir "speckit/analyze-gate.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Test-AnalyzeReceipt {
    param($Receipt, [string]$ArtifactHash)

    return $null -ne $Receipt -and
        $Receipt.artifact_hash -eq $ArtifactHash -and
        $Receipt.critical -eq 0 -and
        $Receipt.high -eq 0
}
