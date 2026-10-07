function Test-LinePolicy {
    param(
        [object[]]$Files,
        [int]$NewLimit,
        [int]$ModifiedLimit,
        [string[]]$SourceExtensions,
        [string]$RepoRoot = (Get-Location).Path,
        [string[]]$ExemptPatterns = @()
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $Files) {
        $extension = [System.IO.Path]::GetExtension($file.Path)
        if ($extension -notin $SourceExtensions) { continue }
        $exempt = $false
        foreach ($pat in $ExemptPatterns) {
            if ($file.Path -match $pat) { $exempt = $true; break }
        }
        if ($exempt) { continue }
        $path = if ([System.IO.Path]::IsPathRooted($file.Path)) {
            $file.Path
        } else {
            Join-Path $RepoRoot $file.Path
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $count = @(Get-Content -LiteralPath $path).Count
        $isNew = $file.Status -in @("A", "??")
        $limit = if ($isNew) { $NewLimit } else { $ModifiedLimit }
        if ($count -gt $limit) {
            $violations.Add(
                "$($file.Path): $count lines exceeds $limit"
            )
        }
    }
    return $violations
}
