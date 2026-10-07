. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/targeted-tests.ps1"

# Un archivo de prueba eliminado o movido sigue en el diff, pero pytest y vitest
# abortan si se les pide un archivo que ya no existe: el gate solo debe pedir
# pruebas que estén en disco.
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("speckit-focused-" + [guid]::NewGuid())
try {
    $kept = Join-Path $root "backend/apps/demo/tests/test_kept.py"
    $keptFront = Join-Path $root "frontend/src/features/demo/kept.test.tsx"
    New-Item -ItemType File -Force -Path $kept, $keptFront | Out-Null

    $backend = @(Get-BackendFocusedTestTargets @(
        "backend/apps/demo/tests/test_kept.py",
        "backend/apps/demo/tests/test_deleted.py"
    ) $root "backend")
    Assert-Equal 1 $backend.Count "backend: only the test file on disk"
    Assert-Equal "apps/demo/tests/test_kept.py" $backend[0] "backend: kept test selected"

    $frontend = @(Get-FrontendFocusedTestTargets @(
        "frontend/src/features/demo/kept.test.tsx",
        "frontend/src/features/demo/deleted.test.tsx"
    ) $root "frontend")
    Assert-Equal 1 $frontend.Count "frontend: only the test file on disk"
    Assert-Equal "src/features/demo/kept.test.tsx" $frontend[0] "frontend: kept test selected"
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
