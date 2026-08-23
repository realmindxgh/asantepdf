# AsantePDF

AsantePDF is a Windows PDF productivity toolkit. The repository is also the persistent project memory for future development sessions.

## Read this before continuing development

1. [`AGENTS.md`](AGENTS.md) — continuation rules for future chats/agents.
2. [`ASANTEPDF_MASTER_UPGRADE_SPEC.md`](ASANTEPDF_MASTER_UPGRADE_SPEC.md) — canonical 45-item product contract with the full detailed requirements.
3. [`IMPLEMENTATION_MATRIX.md`](IMPLEMENTATION_MATRIX.md) — item-by-item acceptance tracker. Do not infer completion from the existence of related code.
4. [`docs/ASANTEPDF-VISUAL-DIRECTION.md`](docs/ASANTEPDF-VISUAL-DIRECTION.md) — target visual language.
5. [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) — current baseline, what RC10 proved, and what remains.

### Canonical target screens

- [Home / Launcher target](docs/design/target-home.svg)
- [Document Workspace target](docs/design/target-document-workspace.svg)

These target screens and the master specification belong together. The screenshots define the desired visual hierarchy and product feel. The specification defines the required behaviour. A visually similar shell with non-functional controls is not acceptable.

## Current baseline

AsantePDF 1.0 RC10 established a genuine Windows release baseline. It compiles on Windows, publishes self-contained x64, bundles the required local engines, builds `AsantePDF Setup.exe`, silently installs that exact installer, launches the installed Program Files copy, and runs installed-copy verification.

RC10 is **not** the intended final product UI. Its existing shell is a functional engineering baseline only. Future work must be driven by the master specification and implementation matrix rather than by preserving the RC10 layout.

## Target application architecture

AsantePDF should be developed as three connected experiences:

- **Home / Launcher** — recent and pinned files, session recovery, standalone tools and application-level navigation.
- **Document Workspace** — multi-document tabs, viewing, editing, annotations, navigation, search, split view and contextual Inspector/Doctor information.
- **Task System** — OCR, conversion, compression, repair, batch work and other cancellable background jobs.

Home mode and Document mode must genuinely behave differently. Do not keep extending one giant window with isolated buttons.

## Completion rule

Do not call AsantePDF 1.0 final merely because it compiles, installs or passes backend smoke tests. Final means the applicable master-spec requirements have been implemented, visibly/concretely verified, recorded as accepted in the implementation matrix, and the resulting installer has passed the real Windows release gate.
