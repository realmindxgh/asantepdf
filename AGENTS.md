# AsantePDF Agent / Continuation Instructions

This repository is the persistent source of truth for the AsantePDF project.

## Mandatory reading before changing the product

1. Read `ASANTEPDF_MASTER_UPGRADE_SPEC.md` in full.
2. Read `IMPLEMENTATION_MATRIX.md`.
3. Review both visual targets:
   - `docs/design/target-home.svg`
   - `docs/design/target-document-workspace.svg`
4. Read `docs/PROJECT_STATE.md`.
5. Read the current release workflow and any current continuation/state notes before modifying release engineering.

## Non-negotiable product rule

Do not treat the current RC10 application shell as the intended UI. RC10 proved the Windows build/release path and many PDF operations, but the master specification defines the target product.

The target architecture has three connected experiences:

- Home / Launcher
- Document Workspace
- Task System

Home mode and Document mode must genuinely behave differently. Avoid bolting more buttons onto one giant window.

## Tracking rule

Every numbered item in the master specification is an acceptance item. Update `IMPLEMENTATION_MATRIX.md` as work progresses.

The baseline matrix may contain `REVIEW REQUIRED` until the current code has been audited item by item. After review, use these working states:

- NOT STARTED
- IN PROGRESS
- IMPLEMENTED, NOT ACCEPTED
- ACCEPTED

Do not mark an item ACCEPTED merely because code exists. Acceptance requires the relevant behaviour to be visibly exercised or otherwise concretely verified. UI items require visual verification. Release-critical changes must also survive the Windows release gate.

## Design rule

The two target images are canonical visual references. Preserve their overall design language:

- modern dark desktop UI
- clear Home and Document modes
- substantial grouped command ribbon
- professional icon family, never emoji
- clear tab hierarchy
- useful left navigation
- contextual right-side Inspector / PDF Doctor
- generous spacing
- deliberate accent colour
- strong disabled, active, hover, focus and pressed states
- no legacy wall of identical grey buttons

Do not copy decorative details at the expense of function. The functional master specification wins when there is tension.

## Engineering rule

Keep the release-quality standard:

- static checks
- real Windows compilation
- automated functionality tests
- self-contained Windows publish
- bundled required engines
- production `AsantePDF Setup.exe`
- silent install of that exact installer
- launch the installed Program Files copy
- installed-copy verification
- downloadable installer only after the gate passes

## Continuation rule for future chats/agents

When asked to "continue AsantePDF", do not start by inventing a new roadmap. Read these repository files, inspect the implementation matrix, continue from the first incomplete/highest-priority batch, and keep the matrix and continuation notes current.

Do not declare AsantePDF 1.0 final while material master-spec items remain unaccepted.
