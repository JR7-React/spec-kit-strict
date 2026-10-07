# Changelog

## [1.0.1] - 2026-10-07

### Fixed

- El cargador del core se detiene en la raíz del proyecto: ya no ejecuta el
  `common.ps1` de una carpeta ancestro (proyectos con `--script sh` o anidados) y
  explica cómo obtener el core PowerShell. `~/.specify` no cuenta como proyecto.
- README: la instalación desde el repo privado requiere `~/.specify/auth.json` y
  confirmar la URL.
- Aviso de licencia MIT de los scripts incluidos de github/spec-kit en
  `THIRD_PARTY_NOTICES.md`.

## [1.0.0] - 2026-10-06

### Added

- Extensión `strict` para Spec Kit 1.1: 14 comandos `speckit.strict.*` y 22 hooks
  obligatorios en 16 fases.
- Configuración por proyecto en `strict-config.yml` (plantilla `config-template.yml`).
- Carga del core de Spec Kit desde la copia instalada (`import-speckit-core.ps1`).
- Compatibilidad con Spec Kit 1.1: rama por feature con el script oficial incluido,
  comparación contra la rama git real y commits que omiten rutas ignoradas.
