# Diseño: extensión `strict` para Spec Kit

- **Fecha:** 2026-10-06
- **Estado:** aprobado en conversación; pendiente de revisión de este documento
- **Repo:** `JR7-React/spec-kit-strict` (público desde v1.1.0)
- **Spec Kit objetivo:** 1.1.1 (`requires.speckit_version: ">=1.1.0"`)

## 1. Contexto

La plantilla `JR7_Premium_Template_Frontend_Backend_TS_PY` tiene una capa de hooks estrictos
portada desde el proyecto de cliente original: 14 comandos neutrales en `.specify/extensions/strict-hooks/`,
scripts en `.specify/scripts/powershell/{quality,git}/`, un `extensions.yml` mantenido a mano
con 22 hooks en 16 fases, `quality-gates.yml`, un sincronizador manual de adaptadores
(`sync-hook-adapters.ps1`) y 16 tests PowerShell.

Spec Kit 1.x tiene un sistema de extensiones que ya resuelve lo que esa capa hace a mano:
registra los comandos como skills para cada agente instalado, fusiona los hooks del manifiesto
en `extensions.yml`, versiona e instala desde un zip, y conserva `*-config.yml` al actualizar.

## 2. Objetivo

Empaquetar la capa estricta como una extensión real de Spec Kit, versionada en su propio
repo, para instalarla en cualquier proyecto con un comando y mantener una sola fuente.

### Criterios de éxito

1. `specify extension add strict --from <zip del tag v1.0.0>` instala la extensión en un
   proyecto Spec Kit 1.1.1 limpio.
2. Tras instalar, `extensions.yml` contiene los 22 hooks de la sección 5.3, en ese orden y
   todos con `optional: false`.
3. Claude ve los 14 skills `/speckit-strict-*` sin ningún sincronizador manual.
4. La suite de tests de la extensión pasa en local y en CI (Windows y Ubuntu).
5. La plantilla usa la extensión instalada, sin restos de la capa vieja, y la prueba de punta a
   punta de la sección 8.2 pasa.
6. El comportamiento de los gates no cambia: mismas validaciones, receipts y bloqueos.

## 3. Decisiones tomadas

| Tema | Decisión |
|---|---|
| Distribución | Repo propio público (desde v1.1.0; privado hasta v1.0.1) con tags; instalación con `--from <zip>` sin credenciales. Spec Kit pide confirmar la URL (`y`) |
| Alcance | Repo de la extensión v1.0.0 + adopción en la plantilla |
| Nombres | id `strict`; comandos `speckit.strict.*`, sin alias |
| Número de extensiones | Una sola (el orden de hooks solo se garantiza dentro de una extensión) |
| Flujo de trabajo | Esta spec + plan con `writing-plans`, en este repo |
| Configuración | `strict-config.yml` por proyecto, sintaxis JSON (YAML válido) |

## 4. Fuera de alcance

- Migrar el proyecto de cliente original a la extensión (exige subirlo antes a Spec Kit 1.1.1). Trabajo aparte.
- Eventos nativos del agente (`session_start`, guardia de commits en `pre_tool_use`). Trabajo aparte.
- Publicar en un catálogo de Spec Kit.
- Cambiar la lógica de los gates.

## 5. Diseño de la extensión

### 5.1 Estructura del repo

```
spec-kit-strict/
├── extension.yml
├── commands/                    # 14 comandos speckit.strict.*
├── prompts/record-analyze.md
├── scripts/powershell/
│   ├── import-speckit-core.ps1          # localiza y carga el common.ps1 core del proyecto
│   ├── quality/                 # scripts actuales de quality
│   └── git/                     # scripts actuales de git + script de ramas incluido (MIT)
├── config-template.yml          # plantilla de strict-config.yml
├── tests/powershell/            # suite (no se instala en proyectos)
├── .extensionignore             # excluye tests/, docs/, .github/
├── .github/workflows/tests.yml  # CI de la extensión
├── docs/superpowers/            # spec y plan
└── README.md, CHANGELOG.md, LICENSE
```

Instalada en un proyecto queda en `.specify/extensions/strict/`.

### 5.2 Comandos

| Comando anterior | Comando nuevo | Script que ejecuta |
|---|---|---|
| `speckit.git.branch` | `speckit.strict.branch` | `git/create-new-feature-branch.ps1` |
| `speckit.git.commit` | `speckit.strict.commit` | `git/commit-spec-artifacts.ps1` |
| `speckit.git.finalize-tasks` | `speckit.strict.finalize-tasks` | `git/finalize-tasks.ps1` |
| `speckit.quality.artifacts` | `speckit.strict.artifacts` | `quality/validate-artifacts.ps1` |
| `speckit.quality.readiness` | `speckit.strict.readiness` | `quality/validate-readiness.ps1` |
| `speckit.quality.implementation-gate` | `speckit.strict.implementation-gate` | `quality/invoke-implementation-gate.ps1` |
| `speckit.quality.before-clarify` | `speckit.strict.before-clarify` | `quality/validate-transition.ps1` |
| `speckit.quality.before-plan` | `speckit.strict.before-plan` | `quality/validate-transition.ps1` |
| `speckit.quality.before-tasks` | `speckit.strict.before-tasks` | `quality/validate-transition.ps1` |
| `speckit.quality.before-checklist` | `speckit.strict.before-checklist` | `quality/validate-transition.ps1` |
| `speckit.quality.before-analyze` | `speckit.strict.before-analyze` | `quality/validate-transition.ps1` |
| `speckit.quality.after-analyze` | `speckit.strict.after-analyze` | `prompts/record-analyze.md` → `quality/record-analyze-receipt.ps1` |
| `speckit.quality.before-taskstoissues` | `speckit.strict.before-taskstoissues` | `quality/validate-transition.ps1` |
| `speckit.quality.after-taskstoissues` | `speckit.strict.after-taskstoissues` | `quality/validate-taskstoissues.ps1` |

Cada archivo de comando lleva frontmatter con `description`, usa `$ARGUMENTS` nativo (en vez de
`{{HOOK_ARGUMENTS}}`) y referencia sus scripts con rutas
`.specify/extensions/strict/scripts/powershell/...`.

### 5.3 Hooks (orden exacto)

Todos con `optional: false`. Dentro de una fase, la prioridad crece con el orden (10, 20) para
que el orden del YAML y el orden por `priority` coincidan.

| Fase | # | Comando | Descripción |
|---|---|---|---|
| `before_specify` | 1 | `speckit.strict.branch` | Crea o reutiliza la rama de feature |
| `after_specify` | 1 | `speckit.strict.artifacts` | Valida spec y checklist base |
| `after_specify` | 2 | `speckit.strict.commit` | Commitea solo artefactos de specification |
| `before_clarify` | 1 | `speckit.strict.before-clarify` | Valida rama y estructura minima de la specification |
| `after_clarify` | 1 | `speckit.strict.artifacts` | Revalida la specification aclarada |
| `after_clarify` | 2 | `speckit.strict.commit` | Commitea aclaraciones y checklist |
| `before_plan` | 1 | `speckit.strict.before-plan` | Exige specification y checklist base completos |
| `after_plan` | 1 | `speckit.strict.artifacts` | Valida plan y artefactos tecnicos |
| `after_plan` | 2 | `speckit.strict.commit` | Commitea solo artefactos de plan |
| `before_tasks` | 1 | `speckit.strict.before-tasks` | Exige plan y artefactos tecnicos validos |
| `after_tasks` | 1 | `speckit.strict.artifacts` | Valida tasks y trazabilidad |
| `after_tasks` | 2 | `speckit.strict.commit` | Commitea tasks.md |
| `before_checklist` | 1 | `speckit.strict.before-checklist` | Valida la specification antes del checklist |
| `after_checklist` | 1 | `speckit.strict.artifacts` | Valida estructura y trazabilidad del checklist |
| `after_checklist` | 2 | `speckit.strict.commit` | Commitea solo checklists |
| `before_analyze` | 1 | `speckit.strict.before-analyze` | Exige artefactos y checklists completos |
| `after_analyze` | 1 | `speckit.strict.after-analyze` | Registra el reporte y bloquea CRITICAL o HIGH |
| `before_taskstoissues` | 1 | `speckit.strict.before-taskstoissues` | Exige analysis vigente y remoto GitHub valido |
| `after_taskstoissues` | 1 | `speckit.strict.after-taskstoissues` | Verifica una issue unica por cada T### |
| `before_implement` | 1 | `speckit.strict.readiness` | Exige artefactos, checklists y analysis receipt vigentes |
| `after_implement` | 1 | `speckit.strict.implementation-gate` | Ejecuta gates locales selectivos |
| `after_implement` | 2 | `speckit.strict.finalize-tasks` | Commitea solo tasks.md tras receipt vigente |

### 5.4 Manifiesto (`extension.yml`)

- `extension`: `id: strict`, `version: 1.0.0`, `category: process`, `effect: read-write`,
  `license: MIT`, `repository: https://github.com/JR7-React/spec-kit-strict`.
- `requires`: `speckit_version: ">=1.1.0"`; `tools`: `pwsh` (7+) y `git`, ambos requeridos.
- `provides.commands`: los 14 de la sección 5.2.
- `provides.config`: `strict-config.yml` desde `config-template.yml`, `required: true`.
- `hooks`: los de la sección 5.3; las fases con dos pasos se declaran como lista.

### 5.5 Configuración por proyecto

- `config-template.yml` conserva el esquema actual de `quality-gates.yml` (`schema_version`,
  `base_branch`, `line_limits`, `source_extensions`, `scope_exemptions`,
  `line_exempt_patterns`, `frontend`, `backend`) con valores genéricos de ejemplo
  (`frontend`, `backend`).
- Cada proyecto tiene `.specify/extensions/strict/strict-config.yml` con sus valores. Spec Kit
  lo conserva al actualizar la extensión.
- Sintaxis JSON (subconjunto de YAML): PowerShell lo lee con `ConvertFrom-Json` sin
  dependencias y Spec Kit lo puede leer como YAML.
- Si falta, el gate falla con un mensaje que indica copiar `config-template.yml`. No hay lectura
  alternativa de `.specify/quality-gates.yml`.

### 5.6 Cambios en los scripts

La lógica de validación no cambia. Solo cambia la resolución de rutas:

- **`import-speckit-core.ps1` (nuevo):** sube desde `$PSScriptRoot` hasta encontrar
  `.specify/scripts/powershell/common.ps1` y lo carga. Si no lo encuentra, usa
  `$env:SPECKIT_CORE_DIR` (solo para desarrollo y tests de la extensión); si tampoco existe,
  falla con un error claro. Lo usan `quality/quality-common.ps1` y
  `git/commit-spec-artifacts.ps1`, que hoy cargan `$PSScriptRoot/../common.ps1`.
- **`Read-QualityGateConfig`:** lee `.specify/extensions/strict/strict-config.yml`.
- **Se conservan** las cuatro correcciones de compatibilidad con 1.1.1 ya hechas en la plantilla:
  script de ramas incluido (MIT, con nota de origen), `Get-SpecKitEffectiveBranchName`,
  `Get-QualityCurrentBranch` (rama git real) y omisión de rutas ignoradas en
  `commit-spec-artifacts.ps1`.
- **Se elimina** `sync-hook-adapters.ps1`.
- Los receipts siguen en `.git/speckit/`.

## 6. Tests de la extensión

- Se mantienen los tests actuales de la plantilla, ajustando rutas: `analyze-lifecycle`,
  `artifact-gate`, `branch-context`, `change-scope`, `commit-scope`, `focused-test-targets`,
  `implementation-gate`, `quality-config`, `readiness-gate`, `taskstoissues-coverage`,
  `taskstoissues-gate` y `transition-gate`.
- `extensions-manifest` pasa a validar los hooks de `extension.yml`.
- `adapter-sync` se reemplaza por `manifest`: existen los 14 comandos y sus archivos, todos los
  nombres cumplen `speckit.strict.*` y todos los hooks tienen `optional: false`.
- `ci-reuse` sale de la suite: verifica el CI del proyecto consumidor, no el de la extensión.
  Queda como contrato documentado en el README.
- Nuevo test `install`: crea un proyecto desechable con `specify init` (1.1.1, Claude, `ps`),
  instala la extensión con `specify extension add --dev`, y verifica los 22 hooks en orden en
  `extensions.yml`, los 14 skills en `.claude/skills/` y el `strict-config.yml` generado.
- `run-tests.ps1` prepara una vez un proyecto Spec Kit desechable para obtener el `common.ps1`
  core y exporta `SPECKIT_CORE_DIR` para el resto de la suite.
- CI (`.github/workflows/tests.yml`): Windows y Ubuntu, instala `uv` y `specify-cli==1.1.1`,
  corre `run-tests.ps1`.

## 7. Adopción en la plantilla

1. Eliminar la capa vieja: `.specify/extensions/strict-hooks/`,
   `.specify/scripts/powershell/{quality,git}/`, `.specify/scripts/powershell/sync-hook-adapters.ps1`,
   `.specify/tests/`, `.specify/quality-gates.yml` y los 14 skills `speckit-{git,quality}-*`.
2. En `extensions.yml`, quitar la clave `extensions:` y los 22 hooks manuales.
3. Instalar con `GH_TOKEN=$(gh auth token) specify extension add strict --from <zip v1.0.0>`.
4. Escribir `strict-config.yml` con los valores actuales de `quality-gates.yml`
   (`JR7_Frontend`, `backend`, límites 100/199, reglas de tests).
5. Versionar la copia instalada en `.specify/extensions/strict/`.
6. CI: `frontend-quality` y `backend-quality` apuntan a
   `.specify/extensions/strict/scripts/powershell/quality/`; se elimina `speckit-hooks-quality`.
7. `AGENTS.md`: nombres `/speckit-strict-*`, ruta de configuración, cómo actualizar la extensión;
   sin mención al sincronizador.
8. Constitución: "extensión `strict`" en vez de "strict-hooks layer" (cambio PATCH, v1.0.1).

## 8. Verificación

### 8.1 Repo de la extensión

- Suite completa en local y en CI (Windows y Ubuntu).
- Tag `v1.0.0` publicado.

### 8.2 Plantilla

- Instalación desde el zip real del tag (no `--dev`).
- Los 22 hooks registrados equivalen a los actuales, con los nombres de la sección 5.3.
- Los 14 skills `/speckit-strict-*` existen; no queda ningún `speckit-{git,quality}-*`.
- Prueba de punta a punta en un repo desechable con la extensión instalada:
  1. el hook de ramas crea `001-...`;
  2. el gate de artefactos bloquea un spec sin completar;
  3. readiness bloquea en una rama equivocada;
  4. el commit de la fase Specify funciona con `feature.json` ignorado.
- Los workflows de CI son YAML válido y apuntan a scripts que existen.
- Ningún cambio en código de la app (frontend y backend sin tocar).

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| El zip de un tag de GitHub trae una carpeta raíz (`spec-kit-strict-1.0.0/`) | Probarlo primero en un proyecto desechable; si falla, adjuntar un zip plano como asset del release |
| Spec Kit reescribe el formato de `extensions.yml` al instalar | Ya observado: cambia formato, no contenido. La verificación compara por contenido |
| Spec Kit ordena hooks por `priority` en otros contextos | Prioridades crecientes que coinciden con el orden del YAML |
| Falta `pwsh` 7 o git | Declarados en `requires.tools` y en el README |
| Spec Kit no genera `strict-config.yml` desde la plantilla al instalar | Verificarlo en el test `install`; si no lo hace, documentar el paso de copia y crearlo en la adopción |
| Fallo en la plantilla tras adoptar | Cambios en commits separados; se revierte con `git revert` |
