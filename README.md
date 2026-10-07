# spec-kit-strict

Extensión `strict` para [Spec Kit](https://github.com/github/spec-kit) 1.1+: convierte los hooks
del ciclo SDD en gates obligatorios.

## Qué hace

- Gates estrictos para el ciclo `specify → plan → tasks → analyze → implement`.
- Los hallazgos `CRITICAL` o `HIGH` de `/speckit-analyze` bloquean la implementación; `MEDIUM`
  y `LOW` se reportan y permiten continuar.
- Checklists o tasks incompletos bloquean.
- Commits automáticos que incluyen **solo** artefactos SpecKit de la fase actual.
- Una rama git por feature, con el mismo nombre que su carpeta en `specs/`.
- Al implementar: lint, typecheck, build y pruebas mapeadas de frontend; chequeo canónico en
  Docker y pruebas mapeadas de backend. Las suites completas quedan para CI.

## Requisitos

- Spec Kit `>= 1.1.0` (`uv tool install specify-cli`).
- PowerShell 7+ (`pwsh`) y git.
- Docker Compose, si el proyecto usa el gate de backend.

## Instalación

El repo es privado. Spec Kit 1.1 solo envía credenciales a los hosts declarados en
`~/.specify/auth.json`; créalo una vez por máquina (no guarda ningún secreto, lee el token de
`GH_TOKEN`):

```json
{
  "providers": [
    {
      "provider": "github",
      "hosts": ["github.com", "api.github.com", "codeload.github.com"],
      "auth": "bearer",
      "token_env": "GH_TOKEN"
    }
  ]
}
```

Al instalar desde una URL, Spec Kit pide confirmar que confías en la fuente (`y`). En un script
se puede responder con `printf 'y\n' | specify extension add ...`.

```bash
GH_TOKEN=$(gh auth token) specify extension add strict --from https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/v1.0.0.zip
```

En PowerShell:

```powershell
$env:GH_TOKEN = gh auth token
specify extension add strict --from https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/v1.0.0.zip
```

Spec Kit registra los 22 hooks en `.specify/extensions.yml`, genera los skills
`/speckit-strict-*` para cada agente instalado y crea
`.specify/extensions/strict/strict-config.yml` desde `config-template.yml`.

## Configuración

Edita `.specify/extensions/strict/strict-config.yml` con los valores de tu proyecto. Usa
sintaxis JSON (que también es YAML válido) porque PowerShell lo lee sin dependencias.

| Campo | Para qué sirve |
|---|---|
| `base_branch` | Rama contra la que se calcula el alcance de los cambios |
| `line_limits.new` / `line_limits.modified` | Límite de líneas para archivos nuevos y modificados |
| `source_extensions` | Extensiones que cuentan como código fuente |
| `scope_exemptions` | Rutas que no necesitan estar declaradas en `tasks.md` |
| `line_exempt_patterns` | Rutas exentas del límite de líneas (tests, migraciones) |
| `frontend.root`, `frontend.commands`, `frontend.test_rules` | Raíz, comandos y mapeo de pruebas del frontend |
| `backend.root`, `backend.compose_file`, `backend.test_rules` | Raíz, Compose y mapeo de pruebas del backend |

Spec Kit conserva este archivo al actualizar la extensión.

## Actualizar

Repite la instalación con el zip del tag nuevo y `--force`:

```bash
GH_TOKEN=$(gh auth token) specify extension add strict --force --from https://github.com/JR7-React/spec-kit-strict/archive/refs/tags/<tag>.zip
```

## Comandos

| Comando | Qué hace |
|---|---|
| `speckit.strict.branch` | Crea o reutiliza la rama de la feature antes de especificar |
| `speckit.strict.commit` | Commitea solo los artefactos SpecKit de la fase actual |
| `speckit.strict.finalize-tasks` | Commitea `tasks.md` tras un receipt de implementación vigente |
| `speckit.strict.artifacts` | Valida spec, plan, tasks y checklists de la feature activa |
| `speckit.strict.readiness` | Exige artefactos, checklists y analysis receipt vigentes antes de implementar |
| `speckit.strict.implementation-gate` | Ejecuta los gates locales selectivos tras implementar |
| `speckit.strict.before-clarify` | Valida rama y estructura mínima de la specification |
| `speckit.strict.before-plan` | Exige specification y checklist base completos |
| `speckit.strict.before-tasks` | Exige plan y artefactos técnicos válidos |
| `speckit.strict.before-checklist` | Valida la specification antes del checklist |
| `speckit.strict.before-analyze` | Exige artefactos y checklists completos antes de analizar |
| `speckit.strict.after-analyze` | Registra el reporte de analyze y bloquea CRITICAL o HIGH |
| `speckit.strict.before-taskstoissues` | Exige analysis vigente y remoto GitHub válido |
| `speckit.strict.after-taskstoissues` | Verifica una issue única por cada `T###` |

## Hooks

Todos son obligatorios (`optional: false`). Dentro de una fase corren en este orden.

| Fase | Comandos |
|---|---|
| `before_specify` | `branch` |
| `after_specify` | `artifacts` → `commit` |
| `before_clarify` | `before-clarify` |
| `after_clarify` | `artifacts` → `commit` |
| `before_plan` | `before-plan` |
| `after_plan` | `artifacts` → `commit` |
| `before_tasks` | `before-tasks` |
| `after_tasks` | `artifacts` → `commit` |
| `before_checklist` | `before-checklist` |
| `after_checklist` | `artifacts` → `commit` |
| `before_analyze` | `before-analyze` |
| `after_analyze` | `after-analyze` |
| `before_taskstoissues` | `before-taskstoissues` |
| `after_taskstoissues` | `after-taskstoissues` |
| `before_implement` | `readiness` |
| `after_implement` | `implementation-gate` → `finalize-tasks` |

Un resultado `SPECKIT_GATE=BLOCKED` o un exit code distinto de cero detiene la fase.

## Receipts

Los receipts de analyze e implementación viven en `.git/speckit/`: son locales, no se
versionan y se rechazan cuando cambia el fingerprint de sus entradas.

## Contrato de CI del proyecto

Localmente solo corren pruebas focalizadas; las suites completas deben correr en el CI del
proyecto que instala la extensión:

- **Frontend:** ejecutar
  `.specify/extensions/strict/scripts/powershell/quality/invoke-frontend-gate.ps1 -SkipTests`
  y la suite completa (`pnpm test` o `pnpm exec vitest run`).
- **Backend:** ejecutar
  `.specify/extensions/strict/scripts/powershell/quality/invoke-backend-gate.ps1 -SkipTests`
  y `pytest -q`.

## Desarrollo

```bash
uv tool install specify-cli==1.1.1
pwsh -NoProfile -File tests/powershell/run-tests.ps1            # suite completa
pwsh -NoProfile -File tests/powershell/run-tests.ps1 -Filter install
```

`run-tests.ps1` crea proyectos Spec Kit desechables en la carpeta temporal: uno aporta el
`common.ps1` core (vía `SPECKIT_CORE_DIR`) y el test `install` instala la extensión con
`specify extension add <repo> --dev`.

## Créditos

`scripts/powershell/git/create-new-feature-branch.ps1` y `scripts/powershell/git/git-common.ps1`
vienen de [github/spec-kit](https://github.com/github/spec-kit) v1.1.1 (licencia MIT).

## Licencia

MIT.
