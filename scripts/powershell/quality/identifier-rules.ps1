function Get-DuplicateIds {
    param([string]$Content, [string]$Pattern)

    $ids = [regex]::Matches($Content, $Pattern) |
        ForEach-Object { $_.Groups[1].Value }
    return $ids | Group-Object | Where-Object Count -gt 1 |
        ForEach-Object Name
}

function Test-StrictlyIncreasingIds {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$ErrorMessage
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $ids = [regex]::Matches($Content, $Pattern) |
        ForEach-Object { [int]$_.Groups[1].Value }
    for ($index = 1; $index -lt $ids.Count; $index++) {
        if ($ids[$index] -le $ids[$index - 1]) {
            $errors.Add($ErrorMessage)
            break
        }
    }
    return $errors
}
