# AsantePDF Project State

Updated after master item 21 reached a green staged Windows gate and a clean no-patch committed-source rerun.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design. Full RC10 Windows release run `32636807149` proved x64 compilation, smoke tests, self-contained publish, qpdf/Tesseract/LibreOffice staging, final-candidate tests, Inno Setup compilation, silent installation and installed-copy verification.

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development

- Branch: `development/master-upgrade-v2`
- Draft PR: `#3` — **AsantePDF master upgrade implementation**
- Latest clean-proven ordinary source: `8500dcaae8bddf868a33850da57a9d47918fa70a`
- Exact SDK: `.NET 10.0.202`
- Current clean build: **0 warnings, 0 errors, all smoke tests passed**

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

The code-side completion system now covers essentially all output-producing workflows:

- foreground PDF transformations such as Extract, Merge, Compress, Repair, Optimize, Protect and Unlock
- OCR searchable PDF and OCR text
- Office-to-PDF and PDF-to-Word/Excel/PowerPoint
- Images-to-PDF
- Watermark, Page Numbers, Header/Footer, Metadata, image stamping and AcroForm filling
- Add Text, Highlight, Rectangle, Ellipse, Crop, Permanent Redaction and visual signature outputs
- Split PDF multi-output sets
- page-image multi-output sets
- batch Compress/Repair/Optimize result sets
- completed Task Center outputs

Completion makes source versus result explicit and provides the appropriate combination of Open, safe current-context replacement for clean PDF source tabs, Open Folder, Save As, Run Another and Close. Multi-output workflows provide selectable result lists rather than a generic “Done” box.

Evidence:

- Task Center result-options phase staged/clean `97403214120` / `97403748273`
- foreground completion migration staged `97412436863`
- foreground clean `97413038885`
- foreground promoted source `e70c5736508abfb73aeced2ae207d3de0678820e`
- markup/batch completion staged `97414112602`
- markup/batch clean `97414608852`
- final item-19 code source `9a8c9993022493c10279c86ed2f9d25ab5012715`

The remaining master-item-19 gap is **true side-by-side comparison with the original**. That depends on master item 6 split view, which is not yet implemented, so item 19 must remain `IN PROGRESS` rather than being overstated.

## Master item 20 — non-destructive processing

Status: `IMPLEMENTED, NOT ACCEPTED`.

The operation-by-operation audit confirms that transformations preserve originals by default and use new output paths unless the user deliberately chooses another non-source destination.

Safety layers include:

- shared configuration validation rejects source PDF = output path
- qpdf operations independently reject source/output collisions
- finishing, markup and AcroForm services independently reject source overwrite
- qpdf writes stage output and only replace the destination after a successful engine result
- Office/Word/Excel/PowerPoint writers stage before transactional commit
- markup, crop, redaction and form output is staged before commit
- page-image export publishes the complete set with backup/rollback instead of leaving half an export
- Split stages the complete output set before publication
- batch processing generates unique result names
- dirty/scoped queued work uses disposable working-layout snapshots instead of mutating the original PDF
- completion workflows clearly identify original versus result and can open the result alongside the original in another tab

A new smoke test deliberately attempts to compress a PDF onto its own source path. The test requires the operation to be rejected before qpdf starts and verifies the source bytes remain unchanged.

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

The Doctor result experience now uses only evidence the current engine genuinely measures.

Implemented behavior:

- initial state remains **Not analysed yet** with no fake recommendations
- the main **Run PDF Doctor** button has a professional PDF Doctor icon
- health state is presented as **Healthy**, **Attention Needed** or **Damaged**
- health score remains visible beside the status
- findings are grouped by the evidence-backed categories **Structure**, **Security**, **Optimization** and **Performance**
- structural errors and warnings expose **Repair PDF** only when the finding supports repair
- large-file recommendations expose **Compress PDF** only when that finding supports compression
- qpdf engine messages are surfaced under Engine details
- the Inspector continues to show PDF version, security state and the concise document-feature summary
- opening another document resets the Doctor state and its status styling

The current diagnostics truthfully cover structural qpdf errors/warnings, encryption, file size, page count and PDF version. No unsupported font/image/form/OCR diagnosis was invented merely to fill the UI.

Evidence:

- richer Doctor implementation staged Windows gate `32726442308`
- richer Doctor promoted source `732740ce4f734a96ddf53ae33483adc6b889bb0a`
- richer Doctor clean no-patch gate `32726666914`
- final Doctor polish staged Windows gate `32727012569`
- final Doctor promoted source `8500dcaae8bddf868a33850da57a9d47918fa70a`
- final Doctor clean no-patch gate `32727205478`
- exact .NET `10.0.202`
- 0 warnings, 0 errors
- all AsantePDF smoke tests passed

The item remains `IMPLEMENTED, NOT ACCEPTED` because the Doctor/Inspector UI still needs hands-on visual/runtime acceptance. Broader Inspector context behavior is tracked separately under item 22.

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

The former `MainWindow.DocumentTabs.cs` CS4014 warning was fixed during item 17. Current clean source is compiler-warning-free. GitHub Actions still emits its separate Node-action deprecation notice; that is not a .NET compiler warning.

## Immediate next work

1. audit/extend master item 22 Inspector context behavior
2. implement master item 6 split-view comparison, which will close item 19's final comparison gap
3. audit master item 23 annotation coverage and editability
4. audit master item 24 Save / Save As / Save a Copy behavior
5. continue item 44 context-aware command recalculation
6. add Settings, Light / Follow Windows themes, first-launch/privacy/recovery polish
7. visually inspect Home, Workspace, Task Center, PDF Doctor and completion dialogs against canonical visual targets
8. run the heavyweight installer/installed-copy gate only at a release-candidate checkpoint

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
