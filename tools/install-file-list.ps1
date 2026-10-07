# Lists the files a release installs (everything except the .extensionignore
# patterns) and their normalized checksums. Development only: not installed.
. "$PSScriptRoot/../scripts/powershell/installation/install-checksums.ps1"

function Get-ExtensionIgnorePatterns {
    param([string]$RepoRoot)

    $patterns = Get-Content -LiteralPath (Join-Path $RepoRoot ".extensionignore") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
    # Spec Kit never installs .extensionignore; the checksum file lists the others.
    return @($patterns) + @(".extensionignore", "install-checksums.json")
}

function Test-IgnoredPath {
    param([string]$Path, [string[]]$Patterns)

    foreach ($pattern in $Patterns) {
        $isDirectory = $pattern.EndsWith("/")
        if ($isDirectory -and $Path.StartsWith($pattern)) { return $true }
        if (-not $isDirectory -and $Path -eq $pattern) { return $true }
    }
    return $false
}

function Get-InstallableFiles {
    param([string]$RepoRoot)

    $patterns = Get-ExtensionIgnorePatterns $RepoRoot
    $files = git -C $RepoRoot ls-files --cached --others --exclude-standard
    return @($files |
        Where-Object { -not (Test-IgnoredPath $_ $patterns) } |
        Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) -PathType Leaf } |
        Sort-Object)
}

function Get-InstallChecksumMap {
    param([string]$RepoRoot)

    $map = [ordered]@{}
    foreach ($path in (Get-InstallableFiles $RepoRoot)) {
        $map[$path] = Get-NormalizedFileHash (Join-Path $RepoRoot $path)
    }
    return $map
}
