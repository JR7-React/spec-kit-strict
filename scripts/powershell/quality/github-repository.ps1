function ConvertTo-GitHubRepository {
    param([string]$RemoteUrl)
    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { return $null }
    $patterns = @(
        '^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$',
        '^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$',
        '^ssh://git@github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$'
    )
    foreach ($pattern in $patterns) {
        if ($RemoteUrl -match $pattern) {
            return "$($Matches[1])/$($Matches[2])"
        }
    }
    return $null
}

function Get-OriginGitHubRepository {
    param([string]$RepoRoot)
    $remote = git -C $RepoRoot config --get remote.origin.url
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remote)) {
        throw "remote.origin.url is missing"
    }
    $repository = ConvertTo-GitHubRepository $remote.Trim()
    if (-not $repository) { throw "origin is not a github.com repository" }
    return $repository
}
