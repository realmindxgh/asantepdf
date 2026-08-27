# AsantePDF Project State

Updated after the full 49-item source reconciliation, custom zoom completion and updater version-ordering hardening.

## Current product state

- Branch: `development/master-upgrade-v2`
- Draft PR: `#3` — **AsantePDF master upgrade implementation**
- Candidate version: `1.0.0-rc49`
- Exact SDK: `.NET 10.0.202`
- Latest Windows-validated promoted feature source: `50f953237f7276c010e9e7c457ad9970551a9770`
- Master requirements implemented in source: **49 / 49**
- Master requirements accepted: **0 / 49**

`IMPLEMENTED, NOT ACCEPTED` is intentional. The implementation phase is complete, but UI-facing requirements still require hands-on Windows visual/runtime acceptance. Do not call AsantePDF 1.0 finished merely because CI is green.

`IMPLEMENTATION_MATRIX.md` is now the authoritative 49-item source audit. `MASTER_49_CHECKLIST.md` remains the compact contract index and `ASANTEPDF_MASTER_UPGRADE_SPEC.md` contains the detailed sub-requirements for items 1–45.

## Engineering state

Development changes continue to use Windows validation before promotion:

1. stage one coherent `dev-patches/*.ps1` carrier
2. compile x64 Release on Windows with exact .NET `10.0.202`
3. run the core smoke suite
4. promote only after green validation
5. remove the carrier so ordinary `src/` / `tests/` source remains canonical

The branch currently has **no `dev-patches` directory**. The latest promoted code includes:

- direct custom zoom percentage entry plus a distinct 1:1/100% control
- human-facing default zoom percentage in Settings rather than internal render width
- screen-reader metadata updated for the new zoom surface
- stable/prerelease-aware update ordering so `1.0.0-rc49` correctly recognizes stable `1.0.0` as newer

Custom zoom staged validation initially exposed one stale `ZoomButton` accessibility reference. That attempt failed safely before promotion. The corrected carrier passed Windows run `33111445879` and promoted at `95ac65a3f98aeb6608a06e2024bf2dd0418c2f1a`.

Updater version-ordering hardening passed Windows run `33111633571` and promoted at `50f953237f7276c010e9e7c457ad9970551a9770`.

## Product architecture now present

### Home / Launcher

Real Home mode provides Recent, Starred, conditional Resume, Open PDF, standalone tools, cached PDFium thumbnails, Grid/List/Compact layouts, sorting/search/pinning, moved-file handling, context actions and drag/drop.

### Document Workspace

Multi-document tabs preserve page, zoom, scroll, working layout and Undo/Redo state. The workspace includes:

- Single Page, lazy Continuous and Two Page viewing
- typed custom zoom, Fit Width, Fit Page and 1:1
- native PDF text selection and copy
- native document search with snippets/highlights
- five-mode navigation sidebar: Pages, Bookmarks, Search, Comments/Annotations, Attachments
- contextual Inspector
- page management and drag reorder
- native text markup, notes, shapes, freehand ink and annotation edit/delete
- Save, Save As and Save a Copy contracts with multi-dirty-tab close handling
- printing with page scope/orientation/fit controls
- two-document split comparison with independent or linked scroll/zoom, swap and page alignment

### Task System

Foreground and queued operations feed one Task Center model with Running/Queued/Completed/Failed/Cancelled states, progress, elapsed time, cancellation, retry and output actions.

Background-capable workflows include compression, repair, optimize-for-web, unlock, merge, Office-to-PDF, PDF-to-Word/Excel/PowerPoint and OCR outputs. Dirty/scoped active documents are materialized into isolated snapshots so queued work cannot be changed by later tab edits.

### Settings / lifecycle

Settings now exposes Light, Dark, Follow Windows, default zoom, default page view, session/recent/privacy controls, OCR default, output folder/naming, overwrite policy, recovery and update preferences.

One-time onboarding, abnormal-shutdown recovery, user-facing error details/log actions, About/Diagnostics, bundled-engine information and explicit user-controlled update download/install are implemented.

### Identity

The product uses the restrained Ghana-inspired red/gold/green/black document/A identity in title-bar/vector assets and the Windows ICO used by the application and installer. Internal `PdfRescue.*` namespaces/project folders remain technical implementation names only and are not product-facing branding.

## Full installed-copy release evidence

Full RC49 Windows release gate run `33107418982` passed end to end on source `a08d0c6eb31dd367217d71ea70a5cd95a40717f2`:

- clean-source verification
- exact SDK
- Release x64 compile and smoke tests
- self-contained Windows x64 publish
- pinned qpdf, Tesseract and LibreOffice staging
- bundled VC++ redistributable
- published-app final-candidate self-test
- production Inno Setup compilation
- silent installation of the exact generated installer
- Program Files launch and final-candidate self-test
- Windows PDF/Open With registration and Start Menu verification
- release receipt and SHA256 generation
- silent uninstall and registration/application cleanup verification
- release package/artifact upload

That gate predates the final custom-zoom and updater-ordering refinements. Therefore the heavyweight installed-copy gate must be rerun on the current source before the candidate is ready for hands-on acceptance.

## Remaining work

There is no known missing master-feature implementation after the 49-item source audit. Remaining work is acceptance and final release evidence:

1. obtain a clean no-patch Windows compile/smoke run on the current promoted source after the reconciliation commits
2. rerun the heavyweight RC49 installed-copy release gate on that exact final candidate
3. retain installer/checksum/release evidence
4. perform hands-on Windows acceptance for visual quality, typography, overlaps, responsive layout, Light/Dark appearance, 125/150/175/200% scaling, keyboard/screen-reader focus, representative printing/OCR/conversion/security workflows and installed branding
5. move individual matrix rows to `ACCEPTED` only when their required evidence exists
6. promote `1.0.0-rc49` to stable `1.0.0` only after all 49 are accepted or explicitly documented not applicable with evidence

## Product sources of truth

1. `MASTER_49_CHECKLIST.md`
2. `ASANTEPDF_MASTER_UPGRADE_SPEC.md`
3. `IMPLEMENTATION_MATRIX.md`
4. `docs/PROJECT_STATE.md`
5. `docs/MASTER_49_COMPLETION_PLAN.md`
6. `docs/ASANTEPDF-VISUAL-DIRECTION.md`
7. `docs/design/target-home.svg`
8. `docs/design/target-document-workspace.svg`
9. `AGENTS.md`

## Non-negotiable acceptance rule

A compiling application is not a finished application. UI work stays unaccepted until it is actually seen and used on Windows, and release-critical work stays unaccepted until the final installer survives the full installed-copy gate on the same source being considered for release.
