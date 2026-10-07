function Convert-NameStatus {
    param([string[]]$Lines)

    foreach ($line in $Lines) {
        if (-not $line) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }
        if ($parts[0] -match '^R') {
            [PSCustomObject]@{
                Status = "M"
                Path = $parts[2].Replace('\', '/')
            }
        }
        else {
            [PSCustomObject]@{
                Status = $parts[0]
                Path = $parts[1].Replace('\', '/')
            }
        }
    }
}

function Resolve-BaseReference {
    param([string]$RepoRoot, [string]$BaseBranch)

    foreach ($candidate in @($BaseBranch, "origin/$BaseBranch")) {
        $null = git -C $RepoRoot rev-parse --verify "$candidate`^{commit}" 2>$null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }
    throw "Cannot resolve base branch $BaseBranch"
}

function Get-ChangedFiles {
    param([string]$RepoRoot, [string]$BaseBranch)

    $reference = Resolve-BaseReference $RepoRoot $BaseBranch
    $base = (git -C $RepoRoot merge-base HEAD $reference).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $base) {
        throw "Cannot resolve merge-base with $reference"
    }
    $rows = @()
    $rows += Convert-NameStatus @(
        git -C $RepoRoot diff --name-status "$base...HEAD"
    )
    $rows += Convert-NameStatus @(
        git -C $RepoRoot diff --name-status
    )
    $rows += Convert-NameStatus @(
        git -C $RepoRoot diff --cached --name-status
    )
    $rows += git -C $RepoRoot ls-files --others --exclude-standard |
        ForEach-Object {
            [PSCustomObject]@{
                Status = "??"
                Path = $_.Replace('\', '/')
            }
        }
    $byPath = @{}
    foreach ($row in $rows) {
        if (-not $byPath.ContainsKey($row.Path)) {
            $byPath[$row.Path] = $row
        }
        elseif ($row.Status -in @("A", "??")) {
            $byPath[$row.Path] = $row
        }
    }
    return @($byPath.Values | Sort-Object Path)
}

function Get-ChangeFingerprint {
    param([string]$RepoRoot, [object[]]$Files)

    $builder = [System.Text.StringBuilder]::new()
    foreach ($file in $Files | Sort-Object Path) {
        [void]$builder.AppendLine("$($file.Status)`t$($file.Path)")
        $path = Join-Path $RepoRoot $file.Path
        if (Test-Path -LiteralPath $path -PathType Leaf) {
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
