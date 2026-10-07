# Rules that compare the strict hooks a project has registered in
# .specify/extensions.yml against the plan declared in the extension manifest.

function Get-HooksSectionLines {
    param([string]$Content)

    $lines = [System.Collections.Generic.List[string]]::new()
    $inHooks = $false
    foreach ($line in ($Content -split '\r?\n')) {
        if ($line -match '^hooks:') { $inHooks = $true; continue }
        if ($inHooks -and $line -match '^\S') { break }
        if ($inHooks) { $lines.Add($line) }
    }
    return $lines
}

# Ordered "phase|command" steps declared by extension.yml.
function Read-ExtensionHookPlan {
    param([string]$ManifestPath)

    $plan = [System.Collections.Generic.List[string]]::new()
    $phase = $null
    foreach ($line in (Get-HooksSectionLines (Get-Content -LiteralPath $ManifestPath -Raw))) {
        if ($line -match '^  ([a-z_]+):\s*$') { $phase = $Matches[1]; continue }
        if ($line -match '^\s+- command: "([^"]+)"') { $plan.Add("$phase|$($Matches[1])") }
    }
    return $plan
}

function ConvertFrom-YamlScalar {
    param([string]$Value)
    return $Value.Trim().Trim("'").Trim('"')
}

# Hook entries as Spec Kit writes them in .specify/extensions.yml.
function Read-ProjectHookEntries {
    param([string]$Content)

    $entries = [System.Collections.Generic.List[object]]::new()
    $phase = $null
    $current = $null
    foreach ($line in (Get-HooksSectionLines $Content)) {
        if ($line -match '^  ([a-z_]+):\s*$') { $phase = $Matches[1]; continue }
        if ($line -match '^\s*- ([a-z_]+): (.*)$') {
            $current = [ordered]@{ Phase = $phase }
            $entries.Add($current)
        }
        elseif ($line -notmatch '^\s+([a-z_]+): (.*)$') { continue }
        if ($null -ne $current) { $current[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2] }
    }
    return $entries | ForEach-Object {
        [PSCustomObject]@{
            Phase = $_.Phase; Extension = $_.extension; Command = $_.command
            Enabled = $_.enabled -ne "false"; Optional = $_.optional -eq "true"
        }
    }
}

function Test-StrictHookRegistration {
    param([string[]]$Plan, [object[]]$Entries)

    $strict = @($Entries | Where-Object { $_.Extension -eq "strict" })
    if ($strict.Count -eq 0) { return @("strict hooks are not registered in .specify/extensions.yml") }

    $errors = [System.Collections.Generic.List[string]]::new()
    $registered = @($strict | ForEach-Object { "$($_.Phase)|$($_.Command)" })
    if (($registered -join ";") -ne ($Plan -join ";")) {
        $errors.Add("strict hooks differ from extension.yml (missing, extra or out of order)")
    }
    foreach ($entry in $strict) {
        $step = "$($entry.Phase)|$($entry.Command)"
        if (-not $entry.Enabled) { $errors.Add("strict hook $step is disabled") }
        if ($entry.Optional) { $errors.Add("strict hook $step is optional") }
    }
    return $errors
}
