function Get-TestTargets {
    param([object[]]$Files, [object[]]$Rules)

    $targets = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            $match = [regex]::Match($file.Path, [string]$rule.pattern)
            if ($match.Success) {
                [void]$targets.Add($match.Result([string]$rule.target))
            }
        }
    }
    return @($targets | Sort-Object)
}

function Add-Target {
    param(
        [System.Collections.Generic.HashSet[string]]$Targets,
        [string]$Target
    )

    if ($Target) { [void]$Targets.Add($Target.Replace('\', '/')) }
}

# Un archivo de prueba eliminado o movido sigue en el diff: pedirlo haría abortar
# a pytest o vitest, así que solo cuentan los que están en disco.
function Test-RepoFile {
    param([string]$RepoRoot, [string]$Path)

    return Test-Path -LiteralPath (Join-Path $RepoRoot $Path) -PathType Leaf
}

function Get-TestFilesByName {
    param(
        [string]$RepoRoot,
        [string]$SearchRoot,
        [string[]]$Names
    )

    $absoluteRoot = Join-Path $RepoRoot $SearchRoot
    if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) {
        return @()
    }
    $nameSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($name in $Names) { [void]$nameSet.Add($name) }
    return @(Get-ChildItem -LiteralPath $absoluteRoot -Recurse -File |
        Where-Object { $nameSet.Contains($_.Name) } |
        ForEach-Object {
            [System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName).Replace('\', '/')
        })
}

function Get-FrontendFocusedTestTargets {
    param(
        [string[]]$ChangedPaths,
        [string]$RepoRoot,
        [string]$FrontendRoot
    )

    $targets = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($path in $ChangedPaths) {
        if ($path -notlike "$FrontendRoot/*") { continue }
        if ($path -match '\.(test|spec)\.(ts|tsx|js|jsx)$') {
            if (Test-RepoFile $RepoRoot $path) {
                Add-Target $targets $path.Substring($FrontendRoot.Length + 1)
            }
            continue
        }
        if ($path -notmatch '\.(ts|tsx|js|jsx)$') { continue }
        $featureMatch = [regex]::Match(
            $path,
            "^$([regex]::Escape($FrontendRoot))/src/features/([^/]+)/"
        )
        if (-not $featureMatch.Success) { continue }
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $names = @(
            "$stem.test.ts",
            "$stem.test.tsx",
            "$stem.spec.ts",
            "$stem.spec.tsx"
        )
        $searchRoot = "$FrontendRoot/src/features/$($featureMatch.Groups[1].Value)"
        foreach ($test in Get-TestFilesByName $RepoRoot $searchRoot $names) {
            Add-Target $targets $test.Substring($FrontendRoot.Length + 1)
        }
    }
    return @($targets | Sort-Object)
}

function Get-BackendFocusedTestTargets {
    param(
        [string[]]$ChangedPaths,
        [string]$RepoRoot,
        [string]$BackendRoot
    )

    $targets = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($path in $ChangedPaths) {
        if ($path -notlike "$BackendRoot/*") { continue }
        if ($path -match "^$([regex]::Escape($BackendRoot))/(.+/tests/.+\.py)$") {
            $target = $Matches[1]
            if (Test-RepoFile $RepoRoot $path) { Add-Target $targets $target }
            continue
        }
        if ($path -notmatch '\.py$') { continue }
        $appMatch = [regex]::Match(
            $path,
            "^$([regex]::Escape($BackendRoot))/apps/([^/]+)/"
        )
        if (-not $appMatch.Success) { continue }
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $names = @("test_$stem.py", "$stem`_test.py")
        $searchRoot = "$BackendRoot/apps/$($appMatch.Groups[1].Value)/tests"
        foreach ($test in Get-TestFilesByName $RepoRoot $searchRoot $names) {
            Add-Target $targets $test.Substring($BackendRoot.Length + 1)
        }
    }
    return @($targets | Sort-Object)
}

function Test-PathMatchesAny {
    param([string]$Path, [object[]]$Patterns)

    foreach ($pattern in $Patterns) {
        if ($Path -match [string]$pattern) { return $true }
    }
    return $false
}
