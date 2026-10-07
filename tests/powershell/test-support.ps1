$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "FAIL: $Message"
    }
}

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [string]$Message
    )

    Assert-True ($Expected -eq $Actual) (
        "$Message (expected=$Expected actual=$Actual)"
    )
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Pattern,
        [string]$Message
    )

    try {
        & $Action
    }
    catch {
        Assert-True ($_.Exception.Message -match $Pattern) $Message
        return
    }

    throw "FAIL: $Message (no exception was thrown)"
}
