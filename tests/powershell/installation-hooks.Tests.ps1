. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/installation/hook-registration.ps1"

$root = (Resolve-Path "$PSScriptRoot/../..").Path
$plan = @(Read-ExtensionHookPlan (Join-Path $root "extension.yml"))
Assert-Equal 22 $plan.Count "extension.yml declares 22 strict hooks"
Assert-Equal "before_specify|speckit.strict.branch" $plan[0] "plan starts with the branch hook"

# Renders entries the way Spec Kit writes .specify/extensions.yml.
function ConvertTo-ProjectHooksYml {
    param([object[]]$Entries)
    $lines = @("installed:", "- strict", "settings:", "  auto_execute_hooks: true", "hooks:")
    $phase = $null
    foreach ($entry in $Entries) {
        if ($entry.Phase -ne $phase) { $lines += "  $($entry.Phase):"; $phase = $entry.Phase }
        $lines += "  - extension: $($entry.Extension)"
        $lines += "    command: $($entry.Command)"
        $lines += "    enabled: $("$($entry.Enabled)".ToLower())"
        $lines += "    optional: $("$($entry.Optional)".ToLower())"
        $lines += "    priority: 10"
        $lines += "    prompt: Execute $($entry.Command)?"
        $lines += "    description: 'demo: hook'"
        $lines += "    condition: null"
    }
    return $lines -join "`n"
}

function New-ValidEntries {
    $entries = foreach ($step in $plan) {
        $phase, $command = $step -split '\|'
        [PSCustomObject]@{
            Phase = $phase; Extension = "strict"; Command = $command
            Enabled = $true; Optional = $false
        }
    }
    # Another extension's hook in the same phase must not affect the check.
    $other = [PSCustomObject]@{
        Phase = "before_specify"; Extension = "other"; Command = "speckit.other.x"
        Enabled = $true; Optional = $true
    }
    return @($other) + @($entries)
}

function Get-RegistrationErrors {
    param([object[]]$Entries)
    $parsed = Read-ProjectHookEntries (ConvertTo-ProjectHooksYml $Entries)
    return @(Test-StrictHookRegistration $plan $parsed)
}

$valid = New-ValidEntries
Assert-Equal 0 (Get-RegistrationErrors $valid).Count "registered plan passes"

$optional = New-ValidEntries
$optional[3].Optional = $true
$errors = Get-RegistrationErrors $optional
Assert-True ("$errors" -match "optional") "an optional strict hook is reported"

$disabled = New-ValidEntries
$disabled[5].Enabled = $false
$errors = Get-RegistrationErrors $disabled
Assert-True ("$errors" -match "disabled") "a disabled strict hook is reported"

$missing = New-ValidEntries
$missing = $missing[0..($missing.Count - 2)]
$errors = Get-RegistrationErrors $missing
Assert-True ($errors.Count -gt 0) "a missing strict hook is reported"

$swapped = New-ValidEntries
$swapped[2].Command, $swapped[3].Command = $swapped[3].Command, $swapped[2].Command
$errors = Get-RegistrationErrors $swapped
Assert-True ("$errors" -match "order") "strict hooks out of order are reported"

$none = Read-ProjectHookEntries "installed:`n- bug`nhooks: {}"
$errors = @(Test-StrictHookRegistration $plan $none)
Assert-True ("$errors" -match "not registered") "an uninstalled extension is reported"
