# AsantePDF Project State

Updated after master item 21 reached a green staged Windows gate and a clean no-patch committed-source rerun. Master item 22 Inspector work is now being staged in smaller, safer increments after the first carrier proved too assumption-heavy.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design. Full RC10 Windows release run `32636807149` proved x64 compilation, smoke tests, self-contained publish, qpdf/Tesseract/LibreOffice staging, final-candidate tests, Inno Setup compilation, silent installation and installed-copy verification.

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development

- Branch: `development/master-upgrade-v2`
- Draft PR: `#3` — **AsantePDF master upgrade implementation**
- Latest clean-proven ordinary source: `8500dcaae8bddf868a33850da57a9d47918fa70a`
- Exact SDK: `.NET 10.0.202`
- Last clean validation: **0 warnings, 0 errors, all smoke tests passed**

Patch carriers under `dev-patches/` are temporary staging mechanisms only. Canonical implementation is the promoted ordinary `src/` / `tests/` tree. Documentation-only or provenance commits may advance branch head without changing the clean-proven source tree.

## Current product architecture

### Home / Launcher

Real Home mode provides Open PDF, standalone Quick Tools, Recent/Starred, cached PDFium thumbnails, Grid/List/Compact layouts, sorting/search/pinning, moved-file handling, context actions and Resume Last Session.

### Multi-document Document Workspace

Real document tabs preserve independent page layout, saved baseline, page selection, zoom, scroll and Undo/Redo. Tabs support active/dirty state, close, drag reorder, middle-click close, overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T.

### Five-mode navigation sidebar

Pages, native Bookmarks/Outline, Search Results, Comments/Annotations and Attachments are implemented. The sidebar is resizable and truly collapsible without a leftover gutter.

### Interactive text and search

PDFium-backed page-local text geometry provides click/drag selection, visible selection highlights, Ctrl+C and context Copy. Native document search has cached indexing, snippets, next/previous navigation and on-page match highlights mapped through the unsaved working layout.

### Task framework / Task Center

Foreground `RunBusyAsync` work and background `PdfJobQueue` / `BackgroundTaskQueueService` feed one task model. Task Center exposes Running, Queued, Completed, Failed and Cancelled states, stage/progress/percentage, elapsed time, Cancel, retry-safe Retry, result actions and a live running+queued navigation badge.

Renderer-dependent queued work owns isolated PDFium renderers. Dirty/scoped active-document work is materialized into disposable layout snapshots so later tab changes cannot alter queued input.

Current background-capable workflows include Compress, Repair, Optimize for Web, Unlock, Merge, Office-to-PDF, PDF-to-Word, PDF-to-Excel, PDF-to-PowerPoint, searchable OCR PDF and OCR-text extraction.

## Master items 11–18

Items 11 through 18 are `IMPLEMENTED, NOT ACCEPTED`.

Key final clean evidence:

- 11 interactive PDF text: staged/clean `97256072705` / `97256350665`
- 12 document search: Windows validation `97236130041`
- 13 sidebar: final clean `97344623846`, source `b8874135a6883bd6d8f2fc89bb1d66694aadbbdc`
- 14 multi-page management: staged/clean `97345750241` / `97346132649`
- 15 standalone tools: clean `97364651130`, source `2c4f4373d93d49b0bea4079aa0c3c9c3dd127958`
- 16 configuration dialogs: final clean `97374705820`
- 17 task/progress framework: staged/clean `97376499301` / `97377277505`, source `059327d0c37f8a55625dfe59417d875884d9ea20`
- 18 Task Center: staged/clean `97400172851` / `97400644796`

Hands-on visual/runtime acceptance remains for these UI-facing items.

## Master item 19 — completion workflows

Status: `IN PROGRESS`.

The code-side completion system covers foreground PDF transformations, OCR, Office conversion, images-to-PDF, finishing/markup, form filling, Split, page-image exports, batch outputs and completed Task Center outputs. Completion makes source versus result explicit and provides the appropriate Open, safe replacement, Open Folder, Save As, Run Another and Close actions.

The remaining item-19 gap is **true side-by-side comparison with the original**, which depends on master item 6 split view.

## Master item 20 — non-destructive processing

Status: `IMPLEMENTED, NOT ACCEPTED`.

The operation-by-operation audit confirms that transformations preserve originals by default. Shared configuration validation, engine-level collision rejection, transactional writers, disposable dirty/scoped snapshots, complete-set publication and unique batch names all contribute to the safety boundary.

Evidence:

- staged item-20 job `97416112570`
- clean no-patch job `97416554259`
- clean-proven source `c5588b15d39f56ffefc2aa239a951d9158e48f55`
- exact .NET `10.0.202`
- 0 warnings, 0 errors
- `PASS  Source PDF overwrite is rejected`
- all AsantePDF smoke tests passed

Hands-on overwrite/copy/result-tab UX acceptance remains before `ACCEPTED`.

## Master item 21 — PDF Doctor

Status: `IMPLEMENTED, NOT ACCEPTED`.

The Doctor result experience uses only evidence the current engine genuinely measures. It has the honest initial state, professional Doctor action icon, Healthy / Attention Needed / Damaged status, health score, Structure/Security/Optimization/Performance grouping, qpdf engine details and contextual Repair PDF / Compress PDF actions only when supported.

The current diagnostics cover structural qpdf errors/warnings, encryption, file size, page count and PDF version. No unsupported diagnosis was invented merely to fill the UI.

Evidence:

- richer Doctor staged/clean `32726442308` / `32726666914`
- final Doctor polish staged/clean `32727012569` / `32727205478`
- final promoted source `8500dcaae8bddf868a33850da57a9d47918fa70a`
- exact .NET `10.0.202`
- 0 warnings, 0 errors
- all AsantePDF smoke tests passed

The item remains `IMPLEMENTED, NOT ACCEPTED` because Doctor/Inspector still needs hands-on visual/runtime acceptance.

## Master item 22 — Inspector

Status: `IN PROGRESS`.

The existing Inspector already exposes document-level file, page-count, size, PDF version, security and feature information. The next layer is context awareness so the same Inspector becomes useful for the current working selection instead of remaining a static document-details panel.

The first attempted carrier, `dev-patches/260-inspector-context.ps1`, was deliberately rejected by the Windows gate. It assumed an annotation-selection code fragment that does not exist in the canonical source. Windows job `32728036402` stopped during patch application before SDK setup or compilation. A rerun of that historical workflow remains pinned to its original event SHA, so it reproduced the same old carrier failure. No item-22 source was promoted from that attempt.

The failed carrier was removed from the branch. A smaller replacement carrier, `dev-patches/261-inspector-context-safe.ps1`, is now staged. It intentionally limits the first step to stable, source-backed context: current document, selected page, multi-page selection and annotation navigation summary. It adds a small partial `MainWindow.InspectorContext.cs` rather than rewriting the large main window file.

This replacement has **not yet received a Windows gate**, so item 22 remains unaccepted and the clean source baseline remains `8500dcaae8bddf868a33850da57a9d47918fa70a` until a green staged gate and clean promoted rerun exist.

## Windows validation ledger

Important later gates:

- item 13 clean: `97344623846`
- item 14 staged/clean: `97345750241` / `97346132649`
- item 15 hardening/clean: `97364231968` / `97364651130`
- item 16 foundation clean: `97366567224`
- item 16 OCR clean: `97372254897`
- item 16 advanced clean: `97374705820`
- item 17 staged/clean: `97376499301` / `97377277505`
- item 18 staged/clean: `97400172851` / `97400644796`
- item 19 Task Center result phase staged/clean: `97403214120` / `97403748273`
- item 19 foreground staged/clean: `97412436863` / `97413038885`
- item 19 markup/batch staged/clean: `97414112602` / `97414608852`
- item 20 staged/clean: `97416112570` / `97416554259`
- item 21 richer Doctor staged/clean: `32726442308` / `32726666914`
- item 21 Doctor polish staged/clean: `32727012569` / `32727205478`
- item 22 first carrier failed at patch application: `32728036402`

The former `MainWindow.DocumentTabs.cs` CS4014 warning was fixed during item 17. Current clean source is compiler-warning-free. GitHub Actions still emits its separate Node-action deprecation notice; that is not a .NET compiler warning.

## Immediate next work

1. validate `261-inspector-context-safe.ps1` on Windows
2. promote only if the staged compile/smoke gate is green
3. rerun the promoted ordinary source with no patch carrier
4. extend Inspector context to text selection and richer annotation details
5. implement master item 6 split-view comparison
6. audit master item 23 annotation coverage and editability
7. audit master item 24 Save / Save As / Save a Copy behavior
8. continue item 44 context-aware command recalculation
9. add Settings, Light / Follow Windows themes, first-launch/privacy/recovery polish
10. reserve the heavyweight installer/installed-copy gate for a release-candidate checkpoint

## Product sources of truth

1. `ASANTEPDF_MASTER_UPGRADE_SPEC.md`
2. `IMPLEMENTATION_MATRIX.md`
3. `docs/ASANTEPDF-VISUAL-DIRECTION.md`
4. `design/target-home.svg`
5. `design/target-document-workspace.svg`
6. `AGENTS.md`

## Engineering cadence

For each coherent batch:

- prefer exactly one staged `dev-patches/*.ps1` carrier
- Windows-compile x64 Release using exact .NET `10.0.202`
- run the core smoke suite
- inspect the staged log and promoted diff/source
- rerun the promoted ordinary source with no patch carrier
- update `IMPLEMENTATION_MATRIX.md` and this state file at meaningful checkpoints
- keep UI requirements unaccepted until hands-on visual/runtime verification
- reserve full publish/installer/silent-install/installed-copy validation for release candidates

Workflow quirk: multiple independent PowerShell carriers are unsafe because the workflow checks `$LASTEXITCODE` after each script. Prefer one carrier. If one script must invoke another, do it explicitly and avoid mutating tracked carriers in place, or promotion cleanup can fail.
