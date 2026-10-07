function Test-TasksToIssuesPrerequisites {
    param($Context)
    $errors = [System.Collections.Generic.List[string]]::new()
    $gitDir = Get-SpecKitGitDir $Context.RepoRoot
    $repository = Get-OriginGitHubRepository $Context.RepoRoot
    $constitution = Join-Path $Context.RepoRoot (
        ".specify/memory/constitution.md"
    )
    $artifactHash = Get-SpecArtifactHash @(
        $Context.Spec,
        $Context.Plan,
        $Context.Tasks,
        $constitution
    )
    if (-not (Test-AnalyzeReceipt (
        Read-AnalyzeReceipt $gitDir
    ) $artifactHash)) {
        $errors.Add("analyze receipt is missing, blocked, or stale")
    }
    $tasksHash = Get-SpecArtifactHash @($Context.Tasks)
    if (Test-TasksToIssuesReceipt (
        Read-TasksToIssuesReceipt $gitDir
    ) $tasksHash $repository) {
        $errors.Add("taskstoissues already completed for current tasks.md")
    }
    return $errors
}
