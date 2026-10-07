function Get-IncompleteChecklistItems {
    param([string]$Content)
    return @([regex]::Matches($Content, '(?m)^\s*- \[ \].+$') |
        ForEach-Object Value)
}

function Test-PlanContent {
    param(
        [string]$Content,
        [string]$FeatureDir
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($heading in @(
        "Technical Context",
        "Constitution Check",
        "Project Structure"
    )) {
        if ($Content -notmatch "(?m)^## ${heading}") {
            $errors.Add("plan missing section $heading")
        }
    }
    if ($Content -match '(?im)(?:\|\s*FAIL\s*\||gate status.*FAIL)') {
        $errors.Add("plan has unresolved constitution failure")
    }
    foreach ($artifact in @("research.md", "data-model.md", "quickstart.md")) {
        if ($Content -match [regex]::Escape($artifact)) {
            if (-not (Test-Path (Join-Path $FeatureDir $artifact))) {
                $errors.Add("plan declares missing $artifact")
            }
        }
    }
    if ($Content -match '(?i)contracts/' -and
        -not (Test-Path (Join-Path $FeatureDir "contracts"))) {
        $errors.Add("plan declares missing contracts directory")
    }
    return $errors
}

function Test-FeatureBranchMatch {
    param([string]$Branch, [string]$FeatureDir)
    $featureName = Split-Path $FeatureDir -Leaf
    $effective = Get-SpecKitEffectiveBranchName $Branch
    if ($effective -eq $featureName) { return @() }
    return @("branch '$Branch' does not match feature '$featureName'")
}
