function Test-SafeContextChange {
    param([string]$Root, [string]$RelativePath)

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $current = Get-Content -LiteralPath $path -Raw
    $head = @(git -C $Root show "HEAD:$RelativePath" 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0) { return $false }
    $pattern = '(?s)<!-- SPECKIT START -->.*?<!-- SPECKIT END -->'
    if ($current -notmatch $pattern -or $head -notmatch $pattern) {
        return $false
    }
    $current = ($current -replace "`r`n", "`n") -replace $pattern, "BLOCK"
    $head = ($head -replace "`r`n", "`n") -replace $pattern, "BLOCK"
    return $current.TrimEnd() -eq $head.TrimEnd()
}

function Resolve-FeatureArtifactPath {
    param([string]$Root, [string]$ConfiguredPath)

    $rootPath = [System.IO.Path]::GetFullPath($Root)
    $featurePath = if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        [System.IO.Path]::GetFullPath($ConfiguredPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $rootPath $ConfiguredPath))
    }
    $comparison = if ($IsWindows -or $null -eq $IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    $prefix = $rootPath.TrimEnd('\', '/') +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $featurePath.StartsWith($prefix, $comparison)) {
        throw "Feature directory escapes repository root"
    }
    return [PSCustomObject]@{
        FullPath = $featurePath
        RelativePath = [System.IO.Path]::GetRelativePath(
            $rootPath,
            $featurePath
        ).Replace('\', '/')
    }
}
