# AsantePDF Project State

Updated after source normalization and Architecture Batch 1 reached a green Windows development gate.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design.

The full RC10 Windows release pipeline reached green on GitHub Actions run `32636807149`. That release path demonstrated:

- exact .NET SDK selection and Windows x64 compilation
- automated smoke tests
- self-contained Windows x64 publish
- staging and validation of qpdf, Tesseract OCR and LibreOffice
- published-app final candidate self-test
- production Inno Setup compilation
- silent installation of the exact generated `AsantePDF Setup.exe`
- installed Program Files copy verification
- release receipt, checksums and evidence generation

The RC10 installer produced by that gate had SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Development source is now normalized

The repository is no longer only a compact release carrier. The SHA256-pinned corrected RC10 payload was reconstructed, the Windows compatibility corrections that actually passed RC10 were applied, and the resulting normal source tree was compiled on Windows before being promoted to `development/master-upgrade-v2`.

Normalization run: `32646666533`

The development branch now contains ordinary `src/`, `tests/`, `assets/`, `installer/`, and `scripts/` paths plus the solution and pinned SDK files. Future product work should modify these normal source files rather than the old compact carrier.

Draft development PR: `#3` — **AsantePDF master upgrade implementation**.

## Architecture Batch 1

Architecture Batch 1 is the first real product-shell implementation against the master specification and canonical target screens.

Implemented in this batch so far:

- application-level dark design tokens and reusable WPF styles
- a real Home mode instead of the old blank PDF canvas
- prominent Open PDF workflow and Home Quick Tools
- basic Recent-file loading/search with moved/missing-file detection
- separate Document Workspace presentation
- substantial grouped command ribbon shell
- custom dark application/title/navigation surfaces
- left Pages / Bookmarks / Search navigation shell
- page Previous/Next controls and editable page number
- Fit Page and Actual Size shell controls alongside existing zoom
- contextual right-side Document Details / PDF Doctor shell
- corrected PDF Doctor initial state: **Not analysed yet**, with no fake recommendations before diagnosis
- explicit disabled states/tooltips for not-yet-supported Settings, Task Center, document search and session-resume actions rather than clickable dead controls
- standalone Home entry points for OCR, Compress, Split, Word conversion and PDF Doctor, while preserving Merge and Images-to-PDF availability
- reuse of the existing RC10 command-state and PDF engine code rather than rewriting stable engines for visual reasons

The redesigned `MainWindow.xaml`, dark `App.xaml` design system and `MainWindow.ProductShell.cs` compiled successfully on a real Windows runner and the core smoke tests passed.

Architecture Batch 1 development gate: `32647383215` — **success**.

This is a development compile/smoke gate, not a full installer acceptance gate. No affected UI matrix row is considered `ACCEPTED` yet.

## What remains in Architecture Batch 1 / immediate follow-up

The shell is intentionally not being mistaken for completion. Immediate follow-up includes:

- visual/runtime acceptance of the new shell against both canonical target screens
- real cached PDF thumbnails on Home
- Grid / List / Compact Recent layouts with persisted preference
- Recent sorting, pinning, context actions and privacy controls
- persisted Recent/session/settings model
- real Resume Last Session
- true multi-document document/session model behind the tab shell
- light and Follow Windows themes
- real document search rather than the currently disabled placeholder
- real Bookmarks navigation
- richer contextual Inspector states
- richer PDF Doctor findings and conditional recommendations
- real Task System / Task Center foundation
- broader context-aware command audit as more document types/tabs are introduced

## Product source of truth

Future work is governed by:

1. `../ASANTEPDF_MASTER_UPGRADE_SPEC.md`
2. `../IMPLEMENTATION_MATRIX.md`
3. `ASANTEPDF-VISUAL-DIRECTION.md`
4. `design/target-home.svg`
5. `design/target-document-workspace.svg`
6. `../AGENTS.md`

The master specification contains **45 numbered requirements**. `IMPLEMENTATION_MATRIX.md` is the acceptance tracker. Do not upgrade a row to `ACCEPTED` merely because related code exists.

## Target architecture

AsantePDF is being developed as three connected experiences:

- Home / Launcher
- Document Workspace
- Task System

Home and Document mode must genuinely behave differently. The Task System must eventually allow long-running work without trapping the user in one modal.

## Engineering cadence

After each coherent batch:

- update `IMPLEMENTATION_MATRIX.md`
- add or extend automated tests
- compile on actual Windows
- run core functionality tests
- visually inspect relevant UI requirements
- run the full installer/installed-copy release gate when a release candidate is reached

The development Windows gate should remain lightweight for normal UI iterations. The heavyweight qpdf/Tesseract/LibreOffice staging plus installer build belongs at release-candidate checkpoints.

## Final-release rule

Do not promote RC10 directly to AsantePDF 1.0 final. A future final release requires the material master-spec items to be accepted and the redesigned installed application to survive the full Windows release gate again.
