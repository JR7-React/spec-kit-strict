# Extensión `strict` para Spec Kit — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Empaquetar la capa de hooks estrictos de la plantilla como la extensión `strict` de Spec Kit 1.1, versionada en `JR7-React/spec-kit-strict`, y adoptarla en la plantilla.

**Architecture:** Un solo repo-extensión (`extension.yml` + 14 comandos + scripts PowerShell + plantilla de configuración). Los scripts se portan sin cambiar su lógica; solo cambian la carga del core de Spec Kit (`import-speckit-core.ps1`) y la ruta de configuración (`strict-config.yml`). Spec Kit registra hooks y skills al instalar; la plantilla instala desde el zip del tag `v1.0.0`.

**Tech Stack:** PowerShell 7, Spec Kit CLI 1.1.1 (`specify`), git, GitHub Actions, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-10-06-strict-extension-design.md`

## Rutas usadas en este plan

- `EXT` = `<dev>\spec-kit-strict` (repo de la extensión, rama `main`).
- `TPL` = `<dev>\JR7_Premium_Template_Frontend_Backend_TS_PY` (plantilla, rama `main`).
- En bash (Git Bash): `EXT=<dev>/spec-kit-strict` y `TPL=<dev>/JR7_Premium_Template_Frontend_Backend_TS_PY`.

## Global Constraints

- Spec Kit: `requires.speckit_version: ">=1.1.0"`; tests y CI usan exactamente `specify-cli==1.1.1`.
- Herramientas requeridas: `pwsh` 7+ y `git`.
- id de extensión `strict`; comandos `speckit.strict.*`; sin alias.
- 22 hooks en el orden exacto de la spec §5.3, todos `optional: false`, prioridad 10 para el primer paso de una fase y 20 para el segundo.
- La lógica de los gates no cambia: mismas validaciones, receipts (`.git/speckit/`) y bloqueos.
- Configuración por proyecto en `.specify/extensions/strict/strict-config.yml`, sintaxis JSON. Sin lectura alternativa de `.specify/quality-gates.yml`.
- Archivos de producción nuevos ≤ 100 líneas; modificados ≤ 199. `git/create-new-feature-branch.ps1` y `git/git-common.ps1` son código incluido de terceros (MIT) y quedan exentos.
- Cuerpo de los comandos en inglés (como hoy); `description` de comandos y hooks en español.
- Commits de la plantilla solo locales (sin push). En `EXT`, push de `main` y del tag `v1.0.0` sí está aprobado por la spec.

## Review Focus

1. **Proyecto real, scripts instalados:** al correr un gate desde `.specify/extensions/strict/scripts/powershell/...` debe cargar el core del proyecto y fallar por la razón de negocio (sin feature), nunca con "Spec Kit core not found". Test en Task 4, paso 1.
2. **Ruta con espacios** (`C:\Users\Juan Perez\...`): la carga del core debe funcionar. Test en Task 1 (el sandbox lleva un espacio en el nombre).
3. **Proyecto sin `strict-config.yml`:** el gate debe explicar cómo crearlo. Test en Task 2 (`strict-config.Tests.ps1`).
4. **Actualizar la extensión con `--force`:** la configuración personalizada del proyecto debe sobrevivir. Test en Task 4, paso 1.
5. **Linux (separadores y mayúsculas en rutas):** la suite corre también en Ubuntu. CI de Task 5.

---

### Task 1: Carga del core de Spec Kit y runner de tests

**Files:**
- Create: `EXT/.gitattributes`
- Create: `EXT/LICENSE`
- Create: `EXT/scripts/powershell/import-speckit-core.ps1`
- Create: `EXT/tests/powershell/test-support.ps1` (copia de la plantilla)
- Create: `EXT/tests/powershell/speckit-test-project.ps1`
- Create: `EXT/tests/powershell/run-tests.ps1`
- Test: `EXT/tests/powershell/speckit-core-import.Tests.ps1`

**Interfaces:**
- Produces: `scripts/powershell/import-speckit-core.ps1`, que al cargarse con `. "<ruta>"` deja disponibles las funciones de `common.ps1` del core (`Get-RepoRoot`, `Get-FeaturePathsEnv`, …) o lanza `Spec Kit core not found: ...`.
- Produces: `New-SpecKitTestProject [-Name <string>]` → `[string]` ruta de un proyecto Spec Kit 1.1.1 desechable (git inicializado, integración `claude`, scripts `ps`).
- Produces: `tests/powershell/run-tests.ps1 [-Filter <string>]`; exporta `SPECKIT_CORE_DIR` para la suite y ejecuta `*<Filter>*.Tests.ps1`.

- [ ] **Step 1: Archivos base del repo**

`EXT/.gitattributes`:

```gitattributes
* text=auto eol=lf
```

`EXT/LICENSE`:

```text
MIT License

Copyright (c) 2026 JR7-React

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Copiar el soporte de tests:

```bash
mkdir -p $EXT/tests/powershell && cp $TPL/.specify/tests/powershell/test-support.ps1 $EXT/tests/powershell/
```

- [ ] **Step 2: Helper de proyecto desechable**

`EXT/tests/powershell/speckit-test-project.ps1`:

```powershell
# Creates a throwaway Spec Kit 1.1.1 project for tests that need the core
# scripts or a real `specify extension add`.
function New-SpecKitTestProject {
    param([string]$Name = "strict-test")

    if (-not (Get-Command specify -ErrorAction SilentlyContinue)) {
        throw "specify CLI is required: uv tool install specify-cli==1.1.1"
    }
    $root = Join-Path ([IO.Path]::GetTempPath()) ("$Name-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $root | Out-Null
    git -C $root init -q -b main
    Push-Location $root
    try {
        specify init --here --force --non-interactive --integration claude `
            --script ps --ignore-agent-tools | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "specify init failed in $root" }
    }
    finally {
        Pop-Location
    }
    return $root
}
```

- [ ] **Step 3: Runner con proyecto core**

`EXT/tests/powershell/run-tests.ps1`:

```powershell
param([string]$Filter = "")

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/speckit-test-project.ps1"

$coreProject = New-SpecKitTestProject "strict-core"
$env:SPECKIT_CORE_DIR = Join-Path $coreProject ".specify/scripts/powershell"
try {
    $tests = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*$Filter*.Tests.ps1" |
        Sort-Object Name
    if ($tests.Count -eq 0) { throw "No tests match filter '$Filter'" }
    foreach ($test in $tests) {
        Write-Output "RUN: $($test.Name)"
        & $test.FullName
    }
    Write-Output "PASS: all strict extension tests"
}
finally {
    Remove-Item -LiteralPath $coreProject -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 4: Escribir el test que falla**

`EXT/tests/powershell/speckit-core-import.Tests.ps1`:

```powershell
. "$PSScriptRoot/test-support.ps1"

$importer = (Resolve-Path "$PSScriptRoot/../../scripts/powershell/import-speckit-core.ps1").Path
# The space in the sandbox name pins paths like "C:\Users\Juan Perez\...".
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("core import-" + [guid]::NewGuid())
$savedCoreDir = $env:SPECKIT_CORE_DIR

function New-FakeCore {
    param([string]$Dir, [string]$Marker)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    "function Get-ProbeMarker { '$Marker' }" |
        Set-Content -LiteralPath (Join-Path $Dir "common.ps1")
}

function Copy-Importer {
    param([string]$Dir)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Copy-Item -LiteralPath $importer -Destination $Dir
    return Join-Path $Dir "import-speckit-core.ps1"
}

function Invoke-Importer {
    param([string]$Path, [string]$CoreDir)
    $env:SPECKIT_CORE_DIR = $CoreDir
    $output = pwsh -NoProfile -Command ". '$Path'; Get-ProbeMarker" 2>&1
    return [PSCustomObject]@{ Code = $LASTEXITCODE; Output = "$output" }
}

try {
    $project = Join-Path $sandbox "project"
    New-FakeCore (Join-Path $project ".specify/scripts/powershell") "project-core"
    $installed = Copy-Importer (
        Join-Path $project ".specify/extensions/strict/scripts/powershell"
    )
    $devCore = Join-Path $sandbox "devcore"
    New-FakeCore $devCore "env-core"
    $lonely = Copy-Importer (Join-Path $sandbox "lonely/scripts/powershell")

    $result = Invoke-Importer $installed $null
    Assert-Equal 0 $result.Code "installed copy loads"
    Assert-Equal "project-core" $result.Output "installed copy finds the project core"

    $result = Invoke-Importer $installed $devCore
    Assert-Equal "project-core" $result.Output "project core wins over SPECKIT_CORE_DIR"

    $result = Invoke-Importer $lonely $devCore
    Assert-Equal "env-core" $result.Output "SPECKIT_CORE_DIR is the dev fallback"

    $result = Invoke-Importer $lonely $null
    Assert-True ($result.Code -ne 0) "missing core fails"
    Assert-True ($result.Output -match "Spec Kit core not found") (
        "missing core explains the failure"
    )
}
finally {
    $env:SPECKIT_CORE_DIR = $savedCoreDir
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 5: Correr y ver que falla**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter speckit-core-import` (desde `EXT`)
Expected: FAIL en `Resolve-Path` porque `import-speckit-core.ps1` no existe.

- [ ] **Step 6: Implementación mínima**

`EXT/scripts/powershell/import-speckit-core.ps1`:

```powershell
# Loads the Spec Kit core helpers (common.ps1) of the project that installed
# this extension. Installed copies live in .specify/extensions/strict/, so the
# core is found by walking up to the project root. SPECKIT_CORE_DIR is only a
# fallback for developing and testing the extension outside a project.

function Find-SpecKitCoreScript {
    param([string]$StartDir)

    $dir = $StartDir
    while ($dir) {
        $candidate = Join-Path $dir ".specify/scripts/powershell/common.ps1"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Resolve-SpecKitCoreScript {
    param([string]$StartDir)

    $projectCore = Find-SpecKitCoreScript $StartDir
    if ($projectCore) { return $projectCore }
    if (-not $env:SPECKIT_CORE_DIR) { return $null }
    $devCore = Join-Path $env:SPECKIT_CORE_DIR "common.ps1"
    if (Test-Path -LiteralPath $devCore -PathType Leaf) { return $devCore }
    return $null
}

$speckitCoreScript = Resolve-SpecKitCoreScript $PSScriptRoot
if (-not $speckitCoreScript) {
    throw ("Spec Kit core not found: no .specify/scripts/powershell/common.ps1 " +
        "above $PSScriptRoot. Install the extension in a Spec Kit project or set " +
        "SPECKIT_CORE_DIR for extension development.")
}
. $speckitCoreScript
```

- [ ] **Step 7: Correr y ver que pasa**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter speckit-core-import`
Expected: `RUN: speckit-core-import.Tests.ps1` y `PASS: all strict extension tests`.

- [ ] **Step 8: Commit**

```bash
cd $EXT && git add .gitattributes LICENSE scripts tests && git commit -m "feat: cargar el core de Spec Kit desde la extension instalada"
```

---

### Task 2: Scripts de quality y git, configuración y suite portada

**Files:**
- Create: `EXT/scripts/powershell/quality/*.ps1` (20 archivos, copia de `TPL/.specify/scripts/powershell/quality/`)
- Create: `EXT/scripts/powershell/git/*.ps1` (5 archivos, copia de `TPL/.specify/scripts/powershell/git/`)
- Modify: `EXT/scripts/powershell/quality/quality-common.ps1:1-10`
- Modify: `EXT/scripts/powershell/git/commit-spec-artifacts.ps1:11-14`
- Create: `EXT/config-template.yml`
- Create: `EXT/tests/powershell/*.Tests.ps1` (12 tests portados) y `EXT/tests/scenarios/analyze-gate-pressure.md`
- Test: `EXT/tests/powershell/strict-config.Tests.ps1`

**Interfaces:**
- Consumes: `import-speckit-core.ps1` (Task 1).
- Produces: `Read-QualityGateConfig` → objeto de `.specify/extensions/strict/strict-config.yml`; lanza `Missing strict config: <ruta>. Copy .specify/extensions/strict/config-template.yml to strict-config.yml ...` si no existe.
- Produces: `config-template.yml` con raíces genéricas `frontend` y `backend` (los tests de Task 2 dependen de esos valores).

- [ ] **Step 1: Portar los tests (todavía sin scripts)**

```bash
cd $EXT
for t in analyze-lifecycle artifact-gate branch-context change-scope commit-scope focused-test-targets implementation-gate quality-config readiness-gate taskstoissues-coverage taskstoissues-gate transition-gate; do
  cp $TPL/.specify/tests/powershell/$t.Tests.ps1 tests/powershell/
done
mkdir -p tests/scenarios && cp $TPL/.specify/tests/scenarios/analyze-gate-pressure.md tests/scenarios/
sed -i 's#\.\./\.\./quality-gates\.yml#../../config-template.yml#g; s#JR7_Frontend#frontend#g' tests/powershell/*.Tests.ps1
```

Reemplazar el contenido de `EXT/tests/powershell/quality-config.Tests.ps1` (hoy busca `.specify/quality-gates.yml` en el repo):

```powershell
. "$PSScriptRoot/test-support.ps1"

$configPath = Join-Path $PSScriptRoot "../../config-template.yml"
Assert-True (Test-Path -LiteralPath $configPath) "config-template.yml exists"

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-Equal 1 $config.schema_version "schema version"
Assert-Equal "main" $config.base_branch "base branch"
Assert-Equal 100 $config.line_limits.new "new-file limit"
Assert-Equal 199 $config.line_limits.modified "modified-file limit"
Assert-Equal "frontend" $config.frontend.root "generic frontend root"
Assert-Equal "backend" $config.backend.root "generic backend root"
Assert-True ($config.frontend.test_rules.Count -ge 3) (
    "frontend test rules exist"
)
Assert-True ($config.backend.test_rules.Count -ge 1) (
    "backend test rules exist"
)
```

- [ ] **Step 2: Escribir el test nuevo de configuración**

`EXT/tests/powershell/strict-config.Tests.ps1`:

```powershell
. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/quality-common.ps1"

$project = Join-Path ([IO.Path]::GetTempPath()) ("strict-config-" + [guid]::NewGuid())
$extensionDir = Join-Path $project ".specify/extensions/strict"
New-Item -ItemType Directory -Path $extensionDir -Force | Out-Null
$savedInitDir = $env:SPECIFY_INIT_DIR
try {
    $env:SPECIFY_INIT_DIR = $project
    Assert-Throws { Read-QualityGateConfig } "config-template\.yml" (
        "missing strict-config.yml explains how to create it"
    )

    Copy-Item "$PSScriptRoot/../../config-template.yml" (
        Join-Path $extensionDir "strict-config.yml"
    )
    $config = Read-QualityGateConfig
    Assert-Equal "frontend" $config.frontend.root (
        "reads strict-config.yml from the installed extension"
    )
}
finally {
    $env:SPECIFY_INIT_DIR = $savedInitDir
    Remove-Item -LiteralPath $project -Recurse -Force
}
```

- [ ] **Step 3: Correr y ver que falla**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1`
Expected: FAIL en el primer test que carga un script de `scripts/powershell/quality/` (no existen todavía).

- [ ] **Step 4: Copiar scripts y crear la plantilla de configuración**

```bash
cd $EXT
mkdir -p scripts/powershell/quality scripts/powershell/git
cp $TPL/.specify/scripts/powershell/quality/*.ps1 scripts/powershell/quality/
cp $TPL/.specify/scripts/powershell/git/*.ps1 scripts/powershell/git/
sed 's#JR7_Frontend#frontend#g' $TPL/.specify/quality-gates.yml > config-template.yml
grep -c 'frontend' config-template.yml   # debe ser > 0
grep -c 'JR7' config-template.yml        # debe ser 0
```

- [ ] **Step 5: Cargar el core y leer la configuración nueva**

En `EXT/scripts/powershell/quality/quality-common.ps1`, reemplazar exactamente este bloque (líneas 1-10):

```powershell
. "$PSScriptRoot/../common.ps1"

function Read-QualityGateConfig {
    $root = Get-RepoRoot
    $path = Join-Path $root ".specify/quality-gates.yml"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing quality config: $path"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}
```

por:

```powershell
. "$PSScriptRoot/../import-speckit-core.ps1"

function Read-QualityGateConfig {
    $root = Get-RepoRoot
    $path = Join-Path $root ".specify/extensions/strict/strict-config.yml"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ("Missing strict config: $path. Copy " +
            ".specify/extensions/strict/config-template.yml to strict-config.yml " +
            "and set this project's frontend and backend roots.")
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}
```

En `EXT/scripts/powershell/git/commit-spec-artifacts.ps1`, reemplazar:

```powershell
if (-not $RepoRoot) {
    . "$PSScriptRoot/../common.ps1"
    $RepoRoot = Get-RepoRoot
}
```

por:

```powershell
if (-not $RepoRoot) {
    . "$PSScriptRoot/../import-speckit-core.ps1"
    $RepoRoot = Get-RepoRoot
}
```

Comprobar que no queda ninguna carga del core vieja:

```bash
grep -rn '\.\./common\.ps1' scripts/   # sin resultados
```

- [ ] **Step 6: Correr y ver que pasa**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1`
Expected: los 14 tests (`speckit-core-import`, `strict-config` y los 12 portados) con `RUN:` y al final `PASS: all strict extension tests`.

- [ ] **Step 7: Revisar límites de líneas**

```bash
wc -l scripts/powershell/import-speckit-core.ps1 scripts/powershell/quality/*.ps1 scripts/powershell/git/commit-spec-artifacts.ps1 scripts/powershell/git/finalize-tasks.ps1 scripts/powershell/git/git-artifact-common.ps1 | sort -n | tail -5
```

Expected: ningún archivo de producción > 199 (los dos scripts incluidos de terceros quedan fuera de la lista).

- [ ] **Step 8: Commit**

```bash
git add scripts config-template.yml tests && git commit -m "feat: portar gates de quality y git con configuracion por proyecto"
```

---

### Task 3: Comandos, prompt y manifiesto

**Files:**
- Create: `EXT/commands/*.md` (14)
- Create: `EXT/prompts/record-analyze.md`
- Create: `EXT/extension.yml`
- Test: `EXT/tests/powershell/manifest.Tests.ps1`
- Test: `EXT/tests/powershell/hooks-manifest.Tests.ps1`

**Interfaces:**
- Consumes: rutas de scripts de Task 2 bajo `.specify/extensions/strict/scripts/powershell/`.
- Produces: `extension.yml` con 14 comandos `speckit.strict.*` y los 22 hooks de la spec §5.3 (Task 4 verifica su registro).

- [ ] **Step 1: Escribir los tests que fallan**

`EXT/tests/powershell/manifest.Tests.ps1`:

```powershell
. "$PSScriptRoot/test-support.ps1"

$root = (Resolve-Path "$PSScriptRoot/../..").Path
$manifest = Get-Content (Join-Path $root "extension.yml") -Raw

Assert-True ($manifest -match '(?m)^  id: "strict"$') "extension id is strict"
Assert-True ($manifest -match 'speckit_version: ">=1\.1\.0"') "requires Spec Kit 1.1+"

$commands = [regex]::Matches(
    $manifest, '(?m)^    - name: "(speckit\.[^"]+)"\r?\n      file: "([^"]+)"'
)
Assert-Equal 14 $commands.Count "manifest declares 14 commands"
foreach ($command in $commands) {
    $name = $command.Groups[1].Value
    $file = $command.Groups[2].Value
    Assert-True ($name -match '^speckit\.strict\.[a-z0-9-]+$') "$name uses the strict namespace"
    Assert-True (Test-Path -LiteralPath (Join-Path $root $file)) "$file exists"
    $body = Get-Content -LiteralPath (Join-Path $root $file) -Raw
    Assert-True ($body -match '(?s)^---\r?\ndescription: ".+"\r?\n---') "$file has a description"
    Assert-True ($body -notmatch 'HOOK_ARGUMENTS') "$file uses native arguments"
    Assert-True ($body -notmatch '\.specify/scripts/powershell/(quality|git)/') (
        "$file points to the installed extension scripts"
    )
}

$prompt = Get-Content (Join-Path $root "prompts/record-analyze.md") -Raw
foreach ($required in @(
    ".specify/extensions/strict/scripts/powershell/quality/record-analyze-receipt.ps1",
    "Do not rerun analysis",
    "-Critical",
    "SPECKIT_GATE=BLOCKED"
)) {
    Assert-True ($prompt -match [regex]::Escape($required)) (
        "record analyze prompt requires $required"
    )
}
```

`EXT/tests/powershell/hooks-manifest.Tests.ps1`:

```powershell
. "$PSScriptRoot/test-support.ps1"

$manifest = Get-Content "$PSScriptRoot/../../extension.yml" -Raw
$expected = @(
    "before_specify|speckit.strict.branch",
    "after_specify|speckit.strict.artifacts",
    "after_specify|speckit.strict.commit",
    "before_clarify|speckit.strict.before-clarify",
    "after_clarify|speckit.strict.artifacts",
    "after_clarify|speckit.strict.commit",
    "before_plan|speckit.strict.before-plan",
    "after_plan|speckit.strict.artifacts",
    "after_plan|speckit.strict.commit",
    "before_tasks|speckit.strict.before-tasks",
    "after_tasks|speckit.strict.artifacts",
    "after_tasks|speckit.strict.commit",
    "before_checklist|speckit.strict.before-checklist",
    "after_checklist|speckit.strict.artifacts",
    "after_checklist|speckit.strict.commit",
    "before_analyze|speckit.strict.before-analyze",
    "after_analyze|speckit.strict.after-analyze",
    "before_taskstoissues|speckit.strict.before-taskstoissues",
    "after_taskstoissues|speckit.strict.after-taskstoissues",
    "before_implement|speckit.strict.readiness",
    "after_implement|speckit.strict.implementation-gate",
    "after_implement|speckit.strict.finalize-tasks"
)

$hooksSection = ($manifest -split '(?m)^hooks:\r?\n', 2)[1]
$hooksSection = ($hooksSection -split '(?m)^\S', 2)[0]
$actual = [System.Collections.Generic.List[string]]::new()
$phase = $null
foreach ($line in ($hooksSection -split '\r?\n')) {
    if ($line -match '^  ([a-z_]+):\s*$') { $phase = $Matches[1]; continue }
    if ($line -match '^\s+- command: "([^"]+)"') { $actual.Add("$phase|$($Matches[1])") }
}
Assert-Equal ($expected -join ";") ($actual -join ";") "22 hooks in the exact order"
Assert-Equal 22 ([regex]::Matches($hooksSection, 'optional: false')).Count (
    "every hook is mandatory"
)
Assert-True ($hooksSection -notmatch 'optional:\s*true') "no optional hooks"
```

- [ ] **Step 2: Correr y ver que fallan**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter manifest`
Expected: FAIL por `extension.yml` inexistente.

- [ ] **Step 3: Crear los 14 comandos**

Cada archivo empieza con frontmatter `description` y conserva el cuerpo actual de `TPL/.specify/extensions/strict-hooks/commands/<viejo>.md`, con dos cambios: `{{HOOK_ARGUMENTS}}` → `$ARGUMENTS` y `.specify/scripts/powershell/` → `.specify/extensions/strict/scripts/powershell/`.

```bash
cd $EXT && mkdir -p commands prompts
OLD=$TPL/.specify/extensions/strict-hooks
port() { # $1 archivo viejo, $2 archivo nuevo, $3 descripcion
  { printf -- '---\ndescription: "%s"\n---\n\n' "$3"
    sed 's#{{HOOK_ARGUMENTS}}#$ARGUMENTS#g; s#\.specify/scripts/powershell/#.specify/extensions/strict/scripts/powershell/#g; s#\.specify/extensions/strict-hooks/#.specify/extensions/strict/#g' "$OLD/commands/$1.md"
  } > "commands/$2.md"
}
port git-branch branch "Crea o reutiliza la rama de la feature antes de especificar"
port git-commit commit "Commitea solo los artefactos SpecKit de la fase actual"
port git-finalize-tasks finalize-tasks "Commitea tasks.md tras un receipt de implementacion vigente"
port quality-artifacts artifacts "Valida spec, plan, tasks y checklists de la feature activa"
port quality-readiness readiness "Exige artefactos, checklists y analysis receipt vigentes antes de implementar"
port quality-implementation-gate implementation-gate "Ejecuta los gates locales selectivos tras implementar"
port quality-before-clarify before-clarify "Valida rama y estructura minima de la specification"
port quality-before-plan before-plan "Exige specification y checklist base completos"
port quality-before-tasks before-tasks "Exige plan y artefactos tecnicos validos"
port quality-before-checklist before-checklist "Valida la specification antes del checklist"
port quality-before-analyze before-analyze "Exige artefactos y checklists completos antes de analizar"
port quality-after-analyze after-analyze "Registra el reporte de analyze y bloquea CRITICAL o HIGH"
port quality-before-taskstoissues before-taskstoissues "Exige analysis vigente y remoto GitHub valido"
port quality-after-taskstoissues after-taskstoissues "Verifica una issue unica por cada T###"
sed 's#\.specify/scripts/powershell/#.specify/extensions/strict/scripts/powershell/#g' "$OLD/prompts/record-analyze.md" > prompts/record-analyze.md
ls commands | wc -l   # 14
```

Resultado esperado, por ejemplo `commands/after-analyze.md`:

```markdown
---
description: "Registra el reporte de analyze y bloquea CRITICAL o HIGH"
---

Read `.specify/extensions/strict/prompts/record-analyze.md` completely and
follow it using the analysis report already present in this conversation.

Never run `speckit-analyze` again from this hook.
```

- [ ] **Step 4: Crear el manifiesto**

`EXT/extension.yml`:

```yaml
schema_version: "1.0"

extension:
  id: "strict"
  name: "Strict SDD Gates"
  version: "1.0.0"
  description: "Gates estrictos de artefactos, readiness e implementacion, ramas por feature y commits acotados de artefactos SpecKit"
  category: "process"
  effect: "read-write"
  author: "JR7-React"
  repository: "https://github.com/JR7-React/spec-kit-strict"
  license: "MIT"
  homepage: "https://github.com/JR7-React/spec-kit-strict"

requires:
  speckit_version: ">=1.1.0"
  tools:
    - name: "pwsh"
      version: ">=7.0.0"
      required: true
    - name: "git"
      required: true

provides:
  commands:
    - name: "speckit.strict.branch"
      file: "commands/branch.md"
      description: "Crea o reutiliza la rama de la feature antes de especificar"
    - name: "speckit.strict.commit"
      file: "commands/commit.md"
      description: "Commitea solo los artefactos SpecKit de la fase actual"
    - name: "speckit.strict.finalize-tasks"
      file: "commands/finalize-tasks.md"
      description: "Commitea tasks.md tras un receipt de implementacion vigente"
    - name: "speckit.strict.artifacts"
      file: "commands/artifacts.md"
      description: "Valida spec, plan, tasks y checklists de la feature activa"
    - name: "speckit.strict.readiness"
      file: "commands/readiness.md"
      description: "Exige artefactos, checklists y analysis receipt vigentes antes de implementar"
    - name: "speckit.strict.implementation-gate"
      file: "commands/implementation-gate.md"
      description: "Ejecuta los gates locales selectivos tras implementar"
    - name: "speckit.strict.before-clarify"
      file: "commands/before-clarify.md"
      description: "Valida rama y estructura minima de la specification"
    - name: "speckit.strict.before-plan"
      file: "commands/before-plan.md"
      description: "Exige specification y checklist base completos"
    - name: "speckit.strict.before-tasks"
      file: "commands/before-tasks.md"
      description: "Exige plan y artefactos tecnicos validos"
    - name: "speckit.strict.before-checklist"
      file: "commands/before-checklist.md"
      description: "Valida la specification antes del checklist"
    - name: "speckit.strict.before-analyze"
      file: "commands/before-analyze.md"
      description: "Exige artefactos y checklists completos antes de analizar"
    - name: "speckit.strict.after-analyze"
      file: "commands/after-analyze.md"
      description: "Registra el reporte de analyze y bloquea CRITICAL o HIGH"
    - name: "speckit.strict.before-taskstoissues"
      file: "commands/before-taskstoissues.md"
      description: "Exige analysis vigente y remoto GitHub valido"
    - name: "speckit.strict.after-taskstoissues"
      file: "commands/after-taskstoissues.md"
      description: "Verifica una issue unica por cada T###"

  config:
    - name: "strict-config.yml"
      template: "config-template.yml"
      description: "Raices de frontend y backend, reglas de tests y limites de lineas del proyecto"
      required: true

hooks:
  before_specify:
    - command: "speckit.strict.branch"
      optional: false
      priority: 10
      description: "Crea o reutiliza la rama de feature"
  after_specify:
    - command: "speckit.strict.artifacts"
      optional: false
      priority: 10
      description: "Valida spec y checklist base"
    - command: "speckit.strict.commit"
      optional: false
      priority: 20
      description: "Commitea solo artefactos de specification"
  before_clarify:
    - command: "speckit.strict.before-clarify"
      optional: false
      priority: 10
      description: "Valida rama y estructura minima de la specification"
  after_clarify:
    - command: "speckit.strict.artifacts"
      optional: false
      priority: 10
      description: "Revalida la specification aclarada"
    - command: "speckit.strict.commit"
      optional: false
      priority: 20
      description: "Commitea aclaraciones y checklist"
  before_plan:
    - command: "speckit.strict.before-plan"
      optional: false
      priority: 10
      description: "Exige specification y checklist base completos"
  after_plan:
    - command: "speckit.strict.artifacts"
      optional: false
      priority: 10
      description: "Valida plan y artefactos tecnicos"
    - command: "speckit.strict.commit"
      optional: false
      priority: 20
      description: "Commitea solo artefactos de plan"
  before_tasks:
    - command: "speckit.strict.before-tasks"
      optional: false
      priority: 10
      description: "Exige plan y artefactos tecnicos validos"
  after_tasks:
    - command: "speckit.strict.artifacts"
      optional: false
      priority: 10
      description: "Valida tasks y trazabilidad"
    - command: "speckit.strict.commit"
      optional: false
      priority: 20
      description: "Commitea tasks.md"
  before_checklist:
    - command: "speckit.strict.before-checklist"
      optional: false
      priority: 10
      description: "Valida la specification antes del checklist"
  after_checklist:
    - command: "speckit.strict.artifacts"
      optional: false
      priority: 10
      description: "Valida estructura y trazabilidad del checklist"
    - command: "speckit.strict.commit"
      optional: false
      priority: 20
      description: "Commitea solo checklists"
  before_analyze:
    - command: "speckit.strict.before-analyze"
      optional: false
      priority: 10
      description: "Exige artefactos y checklists completos"
  after_analyze:
    - command: "speckit.strict.after-analyze"
      optional: false
      priority: 10
      description: "Registra el reporte y bloquea CRITICAL o HIGH"
  before_taskstoissues:
    - command: "speckit.strict.before-taskstoissues"
      optional: false
      priority: 10
      description: "Exige analysis vigente y remoto GitHub valido"
  after_taskstoissues:
    - command: "speckit.strict.after-taskstoissues"
      optional: false
      priority: 10
      description: "Verifica una issue unica por cada T###"
  before_implement:
    - command: "speckit.strict.readiness"
      optional: false
      priority: 10
      description: "Exige artefactos, checklists y analysis receipt vigentes"
  after_implement:
    - command: "speckit.strict.implementation-gate"
      optional: false
      priority: 10
      description: "Ejecuta gates locales selectivos"
    - command: "speckit.strict.finalize-tasks"
      optional: false
      priority: 20
      description: "Commitea solo tasks.md tras receipt vigente"

tags:
  - "quality-gates"
  - "git"
  - "process"
  - "sdd"
```

- [ ] **Step 5: Correr y ver que pasan**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter manifest`
Expected: `RUN: hooks-manifest.Tests.ps1`, `RUN: manifest.Tests.ps1`, `PASS: all strict extension tests`.

- [ ] **Step 6: Commit**

```bash
git add commands prompts extension.yml tests/powershell/manifest.Tests.ps1 tests/powershell/hooks-manifest.Tests.ps1
git commit -m "feat: manifiesto de la extension strict con 14 comandos y 22 hooks"
```

---

### Task 4: Instalación real en un proyecto Spec Kit

**Files:**
- Create: `EXT/.extensionignore`
- Test: `EXT/tests/powershell/install.Tests.ps1`

**Interfaces:**
- Consumes: `New-SpecKitTestProject` (Task 1), `extension.yml` (Task 3), `config-template.yml` (Task 2).
- Produces: garantía de que `specify extension add <ruta> --dev` registra 22 hooks, 14 skills y `strict-config.yml`, y de que `--force` conserva la configuración del proyecto.

- [ ] **Step 1: Escribir el test que falla**

`EXT/tests/powershell/install.Tests.ps1`:

```powershell
. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/speckit-test-project.ps1"

$extensionRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$expected = @(
    "before_specify|speckit.strict.branch",
    "after_specify|speckit.strict.artifacts", "after_specify|speckit.strict.commit",
    "before_clarify|speckit.strict.before-clarify",
    "after_clarify|speckit.strict.artifacts", "after_clarify|speckit.strict.commit",
    "before_plan|speckit.strict.before-plan",
    "after_plan|speckit.strict.artifacts", "after_plan|speckit.strict.commit",
    "before_tasks|speckit.strict.before-tasks",
    "after_tasks|speckit.strict.artifacts", "after_tasks|speckit.strict.commit",
    "before_checklist|speckit.strict.before-checklist",
    "after_checklist|speckit.strict.artifacts", "after_checklist|speckit.strict.commit",
    "before_analyze|speckit.strict.before-analyze",
    "after_analyze|speckit.strict.after-analyze",
    "before_taskstoissues|speckit.strict.before-taskstoissues",
    "after_taskstoissues|speckit.strict.after-taskstoissues",
    "before_implement|speckit.strict.readiness",
    "after_implement|speckit.strict.implementation-gate",
    "after_implement|speckit.strict.finalize-tasks"
)

function Get-RegisteredHooks {
    param([string]$ExtensionsYml)
    $hooks = [System.Collections.Generic.List[string]]::new()
    $phase = $null
    foreach ($line in (Get-Content -LiteralPath $ExtensionsYml)) {
        if ($line -match '^  ([a-z_]+):\s*$') { $phase = $Matches[1]; continue }
        if ($line -match '^\s+command: (\S+)') { $hooks.Add("$phase|$($Matches[1].Trim('"'))") }
    }
    return $hooks
}

function Install-Extension {
    param([string]$Project, [switch]$Force)
    Push-Location $Project
    try {
        $arguments = @("extension", "add", $extensionRoot, "--dev")
        if ($Force) { $arguments += "--force" }
        specify @arguments | Out-Null
        return $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

$project = New-SpecKitTestProject "strict-install"
$savedCoreDir = $env:SPECKIT_CORE_DIR
try {
    Assert-Equal 0 (Install-Extension $project) "specify extension add --dev succeeds"
    $installed = Join-Path $project ".specify/extensions/strict"
    Assert-True (Test-Path "$installed/extension.yml") "extension copied"
    Assert-True (-not (Test-Path "$installed/tests")) "tests are not installed"
    Assert-True (Test-Path "$installed/strict-config.yml") (
        "strict-config.yml scaffolded from the template"
    )
    $skills = @(Get-ChildItem "$project/.claude/skills" -Directory -Filter "speckit-strict-*")
    Assert-Equal 14 $skills.Count "14 strict skills registered for Claude"
    $registered = Get-RegisteredHooks "$project/.specify/extensions.yml"
    Assert-Equal ($expected -join ";") ($registered -join ";") (
        "22 hooks registered in the exact order"
    )

    # Review Focus 1: an installed gate loads the project core and fails for a
    # business reason (no active feature), never for a missing core.
    $env:SPECKIT_CORE_DIR = $null
    Push-Location $project
    $gateOutput = pwsh -NoProfile -File "$installed/scripts/powershell/quality/validate-artifacts.ps1" 2>&1
    Pop-Location
    Assert-True ("$gateOutput" -notmatch "Spec Kit core not found") (
        "installed gate finds the project core"
    )

    # Review Focus 4: updating with --force keeps the project's config.
    $configPath = "$installed/strict-config.yml"
    (Get-Content $configPath -Raw).Replace('"root": "frontend"', '"root": "web"') |
        Set-Content $configPath
    Assert-Equal 0 (Install-Extension $project -Force) "reinstall with --force succeeds"
    Assert-True ((Get-Content $configPath -Raw) -match '"root": "web"') (
        "project config survives an update"
    )
}
finally {
    $env:SPECKIT_CORE_DIR = $savedCoreDir
    Remove-Item -LiteralPath $project -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter install`
Expected: FAIL en `tests are not installed` (todavía no existe `.extensionignore`). Si falla antes, en `strict-config.yml scaffolded`, ir al Step 4.

- [ ] **Step 3: Excluir lo que no debe instalarse**

`EXT/.extensionignore`:

```gitignore
tests/
docs/
.github/
.gitattributes
.gitignore
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter install`
Expected: `PASS: all strict extension tests`.

Si falla solo la aserción `strict-config.yml scaffolded from the template`, Spec Kit no crea la configuración al instalar con `--dev`. En ese caso (riesgo de la spec §9): cambiar esa aserción por `Assert-True (Test-Path "$installed/config-template.yml") "config template installed"`, agregar justo después la copia `Copy-Item "$installed/config-template.yml" "$installed/strict-config.yml"` antes de usar `$configPath`, y documentar el paso de copia en el README (Task 5). Volver a correr hasta `PASS`.

- [ ] **Step 5: Suite completa**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1`
Expected: 17 líneas `RUN:` y `PASS: all strict extension tests`.

- [ ] **Step 6: Commit**

```bash
git add .extensionignore tests/powershell/install.Tests.ps1
git commit -m "test: instalacion real de la extension en un proyecto Spec Kit"
```

---

### Task 5: Documentación, CI y release v1.0.0

**Files:**
- Create: `EXT/README.md`
- Create: `EXT/CHANGELOG.md`
- Create: `EXT/.github/workflows/tests.yml`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: tag `v1.0.0` y la URL de instalación que usa Task 6:
  `https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/v1.0.0.zip` (o la del asset del release si el Step 6 lo exige).

- [ ] **Step 1: README**

`EXT/README.md` con estas secciones y contenido:

- **Qué hace:** gates estrictos para el ciclo `specify → plan → tasks → analyze → implement`; los hallazgos CRITICAL/HIGH bloquean; commits automáticos solo de artefactos SpecKit; rama por feature.
- **Requisitos:** Spec Kit ≥ 1.1.0, PowerShell 7+, git; Docker Compose para el gate de backend.
- **Instalación:**
  ```bash
  GH_TOKEN=$(gh auth token) specify extension add strict --from https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/v1.0.0.zip
  ```
- **Configuración:** editar `.specify/extensions/strict/strict-config.yml` (campos `frontend.root`, `backend.root`, `test_rules`, `line_limits`, `scope_exemptions`); se conserva al actualizar.
- **Actualizar:** el mismo comando con el zip del tag nuevo y `--force`.
- **Comandos:** tabla de los 14 `speckit.strict.*` (spec §5.2).
- **Hooks:** tabla de los 22 hooks (spec §5.3).
- **Receipts:** `.git/speckit/`, locales y no versionados.
- **Contrato de CI del proyecto consumidor:** el workflow de frontend debe ejecutar `.specify/extensions/strict/scripts/powershell/quality/invoke-frontend-gate.ps1 -SkipTests` y la suite completa (`pnpm test` o `pnpm exec vitest run`); el de backend, `invoke-backend-gate.ps1 -SkipTests` y `pytest -q`.
- **Desarrollo:** `uv tool install specify-cli==1.1.1` y `pwsh -NoProfile -File tests/powershell/run-tests.ps1 [-Filter <nombre>]`.
- **Créditos:** `scripts/powershell/git/create-new-feature-branch.ps1` y `git-common.ps1` vienen de github/spec-kit v1.1.1 (MIT).

- [ ] **Step 2: CHANGELOG**

`EXT/CHANGELOG.md`:

```markdown
# Changelog

## [1.0.0] - 2026-10-06

### Added

- Extensión `strict` para Spec Kit 1.1: 14 comandos `speckit.strict.*` y 22 hooks
  obligatorios en 16 fases.
- Configuración por proyecto en `strict-config.yml` (plantilla `config-template.yml`).
- Carga del core de Spec Kit desde la copia instalada (`import-speckit-core.ps1`).
- Compatibilidad con Spec Kit 1.1: rama por feature con el script oficial incluido,
  comparación contra la rama git real y commits que omiten rutas ignoradas.
```

- [ ] **Step 3: CI**

`EXT/.github/workflows/tests.yml`:

```yaml
name: tests

on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:

concurrency:
  group: tests-${{ github.ref }}
  cancel-in-progress: true

jobs:
  powershell-tests:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v6
      - uses: astral-sh/setup-uv@v6
      - name: Install Spec Kit CLI
        run: uv tool install specify-cli==1.1.1
      - name: Configure git identity
        run: |
          git config --global user.name "strict-ci"
          git config --global user.email "strict-ci@example.org"
          git config --global init.defaultBranch main
      - name: Run extension tests
        shell: pwsh
        run: ./tests/powershell/run-tests.ps1
```

- [ ] **Step 4: Suite local y commit**

Run: `pwsh -NoProfile -File tests/powershell/run-tests.ps1`
Expected: `PASS: all strict extension tests`.

```bash
git add README.md CHANGELOG.md .github && git commit -m "docs: README, CHANGELOG y CI de la extension strict"
```

- [ ] **Step 5: Publicar**

```bash
git push -u origin main
gh run list --branch main --limit 1 --json databaseId,headSha --jq '.[0]'   # repetir hasta que headSha sea el de git rev-parse HEAD
gh run watch <databaseId> --exit-status
git tag -a v1.0.0 -m "strict 1.0.0" && git push origin v1.0.0
```

Expected: el run de CI del último commit de `main` termina en verde en Ubuntu y Windows antes de crear el tag.

- [ ] **Step 6: Instalar desde el zip real en un proyecto desechable**

```bash
P=$(mktemp -d) && cd "$P" && git init -q -b main && specify init --here --force --non-interactive --integration claude --script ps --ignore-agent-tools >/dev/null
GH_TOKEN=$(gh auth token) specify extension add strict --from https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/v1.0.0.zip
ls .specify/extensions/strict/extension.yml .specify/extensions/strict/strict-config.yml && ls .claude/skills | grep -c '^speckit-strict-'
```

Expected: ambos archivos existen y el conteo es `14`.

Si la instalación falla porque el zip trae la carpeta raíz `spec-kit-strict-1.0.0/` (riesgo de la spec §9), publicar un zip plano como asset y usar su URL desde aquí en adelante:

```bash
cd $EXT && git archive --format=zip -o strict-1.0.0.zip v1.0.0
gh release create v1.0.0 strict-1.0.0.zip --title "strict 1.0.0" --notes-file CHANGELOG.md
rm strict-1.0.0.zip
cd "$P" && GH_TOKEN=$(gh auth token) specify extension add strict --from https://github.com/JR7-React/spec-kit-strict/releases/download/v1.0.0/strict-1.0.0.zip
```

Al terminar: `rm -rf "$P"`.

---

### Task 6: Adopción en la plantilla

**Files (en `TPL`):**
- Delete: `.specify/extensions/strict-hooks/`, `.specify/scripts/powershell/quality/`, `.specify/scripts/powershell/git/`, `.specify/scripts/powershell/sync-hook-adapters.ps1`, `.specify/tests/`, `.specify/quality-gates.yml`, `.claude/skills/speckit-git-*/`, `.claude/skills/speckit-quality-*/`, `.github/workflows/speckit-hooks-quality.yml`
- Modify: `.specify/extensions.yml`
- Create: `.specify/extensions/strict/` (instalada por `specify`) y `.specify/extensions/strict/strict-config.yml`
- Modify: `.github/workflows/frontend-quality.yml`, `.github/workflows/backend-quality.yml`
- Modify: `AGENTS.md`, `.specify/memory/constitution.md`

**Interfaces:**
- Consumes: URL de instalación de Task 5.

- [ ] **Step 1: Guardar la línea base de hooks y la configuración actual**

```bash
cd $TPL && SP=$(mktemp -d)
cp .specify/quality-gates.yml "$SP/strict-config.yml"
python - "$SP/baseline.txt" <<'EOF'
import sys, yaml
d = yaml.safe_load(open(".specify/extensions.yml", encoding="utf-8"))
with open(sys.argv[1], "w", encoding="utf-8") as out:
    for phase, entries in d["hooks"].items():
        for e in entries:
            out.write(f"{phase}|speckit.strict.{e['command'].split('.')[-1]}\n")
EOF
wc -l < "$SP/baseline.txt"   # 22
```

- [ ] **Step 2: Eliminar la capa vieja**

```bash
git rm -rq .specify/extensions/strict-hooks .specify/scripts/powershell/quality .specify/scripts/powershell/git .specify/scripts/powershell/sync-hook-adapters.ps1 .specify/tests .specify/quality-gates.yml .github/workflows/speckit-hooks-quality.yml
git rm -rq .claude/skills/speckit-git-branch .claude/skills/speckit-git-commit .claude/skills/speckit-git-finalize-tasks
git rm -rq $(git ls-files .claude/skills | grep '/speckit-quality-' | xargs -n1 dirname | sort -u)
python - <<'EOF'
import yaml
path = ".specify/extensions.yml"
d = yaml.safe_load(open(path, encoding="utf-8"))
d.pop("extensions", None)
d.pop("hooks", None)
yaml.safe_dump(d, open(path, "w", encoding="utf-8"), sort_keys=False, allow_unicode=True)
EOF
cat .specify/extensions.yml   # solo installed [assess, bug] y settings
```

- [ ] **Step 3: Instalar la extensión y su configuración**

```bash
GH_TOKEN=$(gh auth token) specify extension add strict --from https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/v1.0.0.zip
cp "$SP/strict-config.yml" .specify/extensions/strict/strict-config.yml
grep -c 'JR7_Frontend' .specify/extensions/strict/strict-config.yml   # > 0
```

(Usar la URL del asset si Task 5, Step 6 la cambió.)

- [ ] **Step 4: Verificar hooks y skills contra la línea base**

```bash
python - "$SP/baseline.txt" <<'EOF'
import sys, yaml
d = yaml.safe_load(open(".specify/extensions.yml", encoding="utf-8"))
actual = [f"{p}|{e['command']}" for p, es in d["hooks"].items() for e in es]
baseline = open(sys.argv[1], encoding="utf-8").read().split()
assert actual == baseline, (actual, baseline)
assert all(e["optional"] is False for es in d["hooks"].values() for e in es)
print("OK: 22 hooks equivalentes a la linea base")
EOF
ls .claude/skills | grep -c '^speckit-strict-'                 # 14
ls .claude/skills | grep -c -E '^speckit-(git|quality)-'      # 0
```

- [ ] **Step 5: CI de la plantilla**

```bash
sed -i 's#\.specify/scripts/powershell/quality/#.specify/extensions/strict/scripts/powershell/quality/#g' .github/workflows/frontend-quality.yml .github/workflows/backend-quality.yml
grep -n 'strict/scripts/powershell/quality' .github/workflows/*.yml
python -c "import yaml,glob; [yaml.safe_load(open(f,encoding='utf-8')) for f in glob.glob('.github/workflows/*.yml')]; print('YAML ok')"
for s in invoke-frontend-gate invoke-backend-gate; do test -f .specify/extensions/strict/scripts/powershell/quality/$s.ps1 && echo "ok $s"; done
```

- [ ] **Step 6: AGENTS.md y constitución**

En `AGENTS.md`, sección "Workflow Spec-Driven", reemplazar:

```markdown
- La configuración canónica vive en `.specify/quality-gates.yml`. Los agentes instalados y CI deben invocar los mismos scripts de `.specify/scripts/powershell/`.
- Los adaptadores `/speckit-git-*` y `/speckit-quality-*` se generan desde `.specify/extensions/strict-hooks/commands/` con `pwsh -NoProfile -File .specify/scripts/powershell/sync-hook-adapters.ps1`; no editarlos a mano.
```

por:

```markdown
- Los hooks estrictos vienen de la extensión `strict` (repo `JR7-React/spec-kit-strict`), instalada en `.specify/extensions/strict/`. Sus skills son `/speckit-strict-*` y los genera Spec Kit; no editarlos a mano.
- La configuración del proyecto vive en `.specify/extensions/strict/strict-config.yml` y se conserva al actualizar. Los agentes y CI invocan los mismos scripts de `.specify/extensions/strict/scripts/powershell/`.
- Para actualizar la extensión: `GH_TOKEN=$(gh auth token) specify extension add strict --from <zip del tag nuevo> --force`.
```

En `.specify/memory/constitution.md`:
- `(strict-hooks layer)` → `(extensión \`strict\`)`.
- En el reporte del encabezado: `Version Change: (new) -> 1.0.0` → `Version Change: 1.0.0 -> 1.0.1` y agregar la línea `PATCH: los hooks estrictos ahora vienen de la extensión strict de Spec Kit.`
- Pie: `**Version**: 1.0.1 | **Ratified**: 2026-10-06 | **Last Amended**: 2026-10-06`.

```bash
grep -rn -E 'quality-gates\.yml|strict-hooks|sync-hook-adapters|speckit\.(quality|git)\.|speckit-(quality|git)-' AGENTS.md .specify .github .claude   # sin resultados
```

- [ ] **Step 7: Prueba de punta a punta en un repo desechable**

```bash
E=$(mktemp -d) && cd "$E" && git init -q -b main && cp -r $TPL/.specify . && rm -f .specify/feature.json && git add -A && git -c user.name=t -c user.email=t@example.org commit -qm init
S=.specify/extensions/strict/scripts/powershell
pwsh -NoProfile -File $S/git/create-new-feature-branch.ps1 -Json -AllowExistingBranch -ShortName smoke-test "Smoke test"   # BRANCH_NAME 001-smoke-test
mkdir -p specs/001-smoke-test && cp .specify/templates/spec-template.md specs/001-smoke-test/spec.md && printf '{"feature_directory":"specs/001-smoke-test"}' > .specify/feature.json
pwsh -NoProfile -File $S/quality/validate-artifacts.ps1 2>&1 | grep SPECKIT_GATE      # SPECKIT_GATE=BLOCKED (spec sin completar)
git checkout -q -b otra-rama
pwsh -NoProfile -File $S/quality/validate-readiness.ps1 2>&1 | grep "does not match"   # branch 'otra-rama' does not match feature '001-smoke-test'
git checkout -q 001-smoke-test && mkdir -p specs/001-smoke-test/checklists && echo "- [x] ok" > specs/001-smoke-test/checklists/requirements.md
pwsh -NoProfile -File $S/git/commit-spec-artifacts.ps1 -Phase Specify && git log --oneline -1   # docs(spec): especificacion de la feature 001-smoke-test
cd $TPL && rm -rf "$E" "$SP"
```

Expected: cada comando produce el resultado comentado a su derecha.

- [ ] **Step 8: Commit**

```bash
cd $TPL && git add -A && git status --short
git commit -m "chore(speckit): adoptar la extension strict v1.0.0 en lugar de la capa local de hooks"
```

Expected: el commit solo contiene rutas de `.specify/`, `.claude/skills/`, `.github/workflows/`, `AGENTS.md`; ningún archivo de `JR7_Frontend/` ni `backend/`.
