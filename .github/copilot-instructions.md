# AsantePDF repository instructions

Before making product changes, read these files in order:

1. `AGENTS.md`
2. `ASANTEPDF_MASTER_UPGRADE_SPEC.md`
3. `IMPLEMENTATION_MATRIX.md`
4. `docs/PROJECT_STATE.md`
5. `docs/ASANTEPDF-VISUAL-DIRECTION.md`
6. `docs/design/target-home.svg`
7. `docs/design/target-document-workspace.svg`

The current RC10 UI is a legacy functional shell and is **not** the visual/product target.

Treat all 45 numbered master-spec items as acceptance requirements. Do not mark a requirement complete because related backend code exists. UI requirements need visual/behavioural verification, and release-critical integration must survive the real Windows release gate.

Target architecture:

- Home / Launcher
- Document Workspace
- Task System

Preserve the working PDF engines while replacing the product shell deliberately and coherently. Do not add random isolated buttons to the old window as a substitute for the specified architecture.
