# Detects edits to the installed extension files by comparing them against
# install-checksums.json, which ships with each release. Hashes ignore line
# endings so a Windows checkout (CRLF) does not count as an edit.

function Get-NormalizedFileHash {
    param([string]$Path)

    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Test-InstallChecksums {
    param([string]$ExtensionDir)

    $manifestPath = Join-Path $ExtensionDir "install-checksums.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return @("install-checksums.json is missing from $ExtensionDir")
    }
    $files = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).files
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $files.PSObject.Properties) {
        $path = Join-Path $ExtensionDir $entry.Name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $errors.Add("installed file is missing: $($entry.Name)")
            continue
        }
        if ((Get-NormalizedFileHash $path) -ne $entry.Value) {
            $errors.Add("installed file was edited: $($entry.Name)")
        }
    }
    return $errors
}
