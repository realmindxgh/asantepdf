# AsantePDF Project State

Updated after master items 17 and 18 reached green staged Windows gates and clean committed-source reruns.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design. Full RC10 Windows release run `32636807149` proved x64 compilation, smoke tests, self-contained publish, qpdf/Tesseract/LibreOffice staging, final-candidate tests, Inno Setup compilation, silent installation and installed-copy verification.

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development

Branch: `development/master-upgrade-v2`

Draft PR: `#3` — **AsantePDF master upgrade implementation**

The normalized ordinary source tree is the working codebase. Patch carriers under `dev-patches/` are temporary staging mechanisms only and must not be treated as canonical implementation.

The most recent source commit proven by a clean no-patch Windows rerun is:

`db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`

Documentation-only ledger commits may advance the branch head beyond this SHA without changing the proven `src/` tree.

## Current product architecture

### Home / Launcher

Real Home mode with Open PDF, a broad standalone Tool Library, Recent/Starred, cached PDF thumbnails, Grid/List/Compact layouts, sorting, search, pinning, moved-file handling, context actions and Resume Last Session.

### Multi-document Document Workspace

Real tabs preserve independent page layout, baseline, selected page, zoom, scroll and Undo/Redo. Tabs support active/dirty state, close, drag reorder, middle-click close, overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T. The proven PDFium renderer is transactionally reused when the active tab changes.

### Session persistence

`workspace-state.json` stores the open tab set, active tab, page, zoom, scroll, Recent history and pin state. Resume restores all available tabs and the saved active tab. Crash recovery and unsaved working-layout recovery remain future work.

### Task System / Task Center

Foreground `RunBusyAsync` work and a real background queue feed the same Task Center. The queue is backed by the core `PdfJobQueue`, is single-worker, and is smoke-tested for pre-queued jobs, serialization and cancellation while queued.

Task Center supports Running, Queued, Completed, Failed and Cancelled states, progress/stage updates, percentage, elapsed time, Cancel, result options, clear-finished history and single-use Retry for retry-safe jobs. The permanent Task Center navigation entry also carries a live running+queued badge and failed-task attention tooltip, so background work remains visible while the user works elsewhere.

Current background-capable production workflows include Compress, Repair, Optimize for Web, Unlock, Merge, Office-to-PDF, PDF-to-Word, PDF-to-Excel, PDF-to-PowerPoint, searchable OCR PDF and OCR-text extraction. Configured Word/Excel/PowerPoint and OCR jobs preserve the selected working-layout page scope when queued.

Renderer-dependent queued work captures the active document path and relevant page layout at queue time. Dirty or scoped layouts are materialized into isolated temporary PDFs where needed. Jobs then create their own PDFium renderer so later tab changes cannot alter queued input.

## Master item 11 — interactive PDF text

Status: `IMPLEMENTED, NOT ACCEPTED`.

`DocumentTextSelectionService` lazily loads Unicode text and character geometry for the currently rendered page through PDFium. The preview has I-beam interaction, click/drag selection, on-page highlights, Ctrl+C and right-click Copy. Selection resets with page/document context and yields hit testing while annotation markup owns the canvas.

Staged job `97256072705` and clean promoted-source rerun `97256350665` passed. Hands-on selection feel and visual acceptance remain.

## Master item 12 — document search

Status: `IMPLEMENTED, NOT ACCEPTED`.

`DocumentSearchService` builds a cached native PDFium text index. Ctrl+F, live search, previous/next navigation, current/total counts, Search Results sidebar snippets and on-page match highlights are implemented. Results map through the current unsaved working layout, including deleted and duplicated pages.

Windows job `97236130041` passed. Hands-on visual/runtime acceptance remains.

## Master item 13 — five-mode left navigation sidebar

Status: `IMPLEMENTED, NOT ACCEPTED`.

The sidebar has Pages, Bookmarks/Outline, Search Results, Comments/Annotations and Attachments. Native PDFium outline, annotation and embedded-attachment services are wired. The sidebar is bounded/resizable, truly collapsible, preserves its active mode while collapsed and safely resets to Pages on document replacement.

Evidence:

- sidebar collapse staged `97256927225`
- sidebar collapse clean `97341768147`
- Comments/Attachments staged `97343869116`
- reset hardening `97344342154`
- final clean item-13 run `97344623846`
- final clean item-13 source `b8874135a6883bd6d8f2fc89bb1d66694aadbbdc`

Hands-on visual/runtime acceptance remains.

## Master item 14 — multi-page selection and page management

Status: `IMPLEMENTED, NOT ACCEPTED`.

The page workspace covers Ctrl+Click, Shift+Click, Select All, selected-page Rotate, Delete, Extract, Duplicate, Move Up/Down, drag reorder, Crop, explicit selection-range feedback and page-layout Undo/Redo snapshots.

`PdfMarkupService.CropPagesAsync` applies one normalized crop rectangle transactionally to all selected working-layout positions while leaving unselected pages and the original source untouched.

Evidence:

- staged `97345750241`
- clean `97346132649`
- proven source `ee014c0a7cc1cb0fa97d6551e13a6575930bcb75`

Hands-on Ctrl/Shift selection, range feedback, batch crop, drag reorder and Undo/Redo acceptance remain.

## Master item 15 — standalone tool availability

Status: `IMPLEMENTED, NOT ACCEPTED`.

Non-canvas tools no longer silently require an already-open PDF. When document context is absent they open their own input/configuration workflow instead.

Covered routes include:

- OCR
- Compress
- Split
- Repair
- Optimize for Web
- Protect
- PDF-to-Word
- PDF-to-Excel
- PDF-to-PowerPoint
- page-image export
- OCR-text extraction
- Watermark
- Page Numbers
- Header/Footer
- Metadata
- image stamping
- AcroForm filling
- PDF Doctor

Merge, Unlock, Office-to-PDF and Images-to-PDF were already independently launchable. Only genuinely canvas-dependent actions such as Add Text, Highlight, Crop, Redact and visual signature placement remain active-document-bound.

The shared standalone picker is hardened so cancelling or failing a new file open cannot accidentally run the requested tool against an older active PDF.

Evidence:

- final warning-hardening staged job `97364231968`
- clean committed-source rerun `97364651130`
- clean-proven item-15 source `2c4f4373d93d49b0bea4079aa0c3c9c3dd127958`

The staged and clean builds had zero errors and only the pre-existing `MainWindow.DocumentTabs.cs(142,9)` CS4014 warning. Hands-on standalone workflow acceptance remains.

## Master item 16 — proper configuration dialogs

Status: `IMPLEMENTED, NOT ACCEPTED`.

Significant operations now collect relevant options before execution instead of immediately firing complex work.

### Shared modal system

`ToolConfigurationDialogs` provides a consistent dark AsantePDF configuration shell. The older reusable prompt window has also been moved off its hard-coded white surface and now follows the same dark application resources and button styles.

### Compression

One dialog contains source, Lossless/Balanced/Strong compression profile, real profile explanations and output location.

### Merge

One dialog provides Add PDFs, Remove, Move Up, Move Down, exact merge order and output location.

### Split

One dialog supports fixed-size chunks or explicit page groups such as `1-3; 4-6; 8,10`, validates ranges and publishes explicit-group outputs only after staging succeeds.

### OCR

The OCR configuration workflow now includes:

- input PDF
- actual locally available OCR languages
- Automatic recognition
- bundled English Tesseract when available
- installed Windows OCR recognizer languages
- All Pages or custom page ranges such as `1-3,5,8-10`
- Searchable PDF or UTF-8 plain-text output
- output location

Page scopes refer to current working-layout positions, so reorder/duplicate state is respected. Background OCR snapshots only the requested scope. The bundled Tesseract fallback is currently English-only; the UI does not advertise unsupported languages.

### PDF conversion

A shared Convert PDF dialog supports Word, Excel and PowerPoint. Word/Excel expose page scope and actual OCR language selection. PowerPoint exposes page scope and real render widths of 1200, 1800 or 2400 pixels. Irrelevant options are disabled instead of pretending every format has the same settings.

### Page-image export

The export dialog provides page scope, PNG/JPEG, render width and JPEG quality where applicable, plus output base location. Exported names preserve the working page position.

### Protect / Unlock

Protect uses 256-bit qpdf encryption and now exposes opening/owner password plus real printing, modification and extraction permissions. Accessibility remains enabled. Passwords still use the sensitive temporary argument-file path rather than the normal process command line.

Unlock now has one consistent dialog for input protected PDF, current password and output location.

### Office-to-PDF

Office-to-PDF now has one consistent dialog for Office source and output PDF instead of a disconnected picker/save sequence.

Evidence:

- configuration foundation staged `97365833964`
- configuration foundation clean `97366567224`
- foundation source `686b735e6096dcd3440fd108707bcf18d52566e5`
- OCR configuration staged `97371701920`
- OCR clean committed-source rerun `97372254897`
- clean OCR source `d41ba0bf4942b2179f5fa534101b32c479853876`
- advanced conversion/export/security staged `97374175885`
- advanced clean committed-source rerun `97374705820`
- final clean item-16 source `db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`

The final staged and clean builds compiled exact .NET `10.0.202` Windows x64 Release with zero errors and only the pre-existing CS4014 warning. All smoke tests passed, including assertions that selected qpdf printing/modification/extraction permissions reach the sensitive argument file.

Hands-on sizing, keyboard flow, validation messaging, theme consistency and real-operation acceptance remain before item 16 can become `ACCEPTED`.

## Master item 17 — application-wide task/progress framework

Status: `IMPLEMENTED, NOT ACCEPTED`.

Foreground and queued work now share the same task model, with task name, stage, percentage/progress, elapsed time, page/item counts where useful and graceful cancellation. Renderer-dependent queued work owns isolated renderers; dirty/scoped layouts use disposable snapshots; transactional writers preserve sources/destinations on failure. Page-image export additionally stages the complete image set and publishes it with backup/rollback so cancellation cannot leave a half-exported set.

Evidence:

- staged `97376499301`
- clean `97377277505`
- clean-proven source `059327d0c37f8a55625dfe59417d875884d9ea20`
- exact .NET 10.0.202 Windows x64 Release
- 0 warnings, 0 errors, all smoke tests passed

Hands-on progress/cancellation UX acceptance remains.

## Master item 18 — Task Center

Status: `IMPLEMENTED, NOT ACCEPTED`.

Task Center exposes Running, Queued, Completed, Failed and Cancelled work with filters, progress, elapsed time, cancellation, retry for retry-safe failures, output opening and multiple queued jobs. Users can continue working in other tabs. A live badge on the permanent Task Center navigation entry now acts as the minimized task indicator and reports active or failed-task attention without forcing a modal progress window.

Evidence:

- staged `97400172851`
- clean `97400644796`
- clean-proven source `db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`
- exact .NET 10.0.202 Windows x64 Release
- 0 warnings, 0 errors, all smoke tests passed

Hands-on visual/runtime acceptance remains.

## Result routing

Task outputs are type-aware:

- `.pdf` opens as an AsantePDF tab
- `.docx`, `.xlsx`, `.pptx`, `.txt` and other non-PDF files launch through their associated Windows application

The existing foreground completion workflow remains for initial PDF transformations. Background results are non-modal and remain available from Task Center.

## Windows validation

Important green development gates include:

- Architecture Batch 1: `32647383215`
- Recent/session foundation: `32648130725`
- Starred/Resume: `32648422410`
- rolling architecture run: `32649073796`
- multi-tab session: `97221651603`
- result completion: `97222420243`
- background queue: `97232413507`
- Merge/Office queue expansion: `97232877751`
- renderer-isolated OCR/export: `97233635107`
- native document search: `97236130041`
- native Bookmarks staged: `97254983823`
- native Bookmarks clean: `97255242296`
- interactive text staged: `97256072705`
- interactive text clean: `97256350665`
- sidebar collapse staged: `97256927225`
- sidebar collapse clean: `97341768147`
- Comments/Attachments staged: `97343869116`
- sidebar reset hardening: `97344342154`
- item 13 clean: `97344623846`
- item 14 staged: `97345750241`
- item 14 clean: `97346132649`
- item 15 warning-hardening staged: `97364231968`
- item 15 clean: `97364651130`
- item 16 configuration foundation staged: `97365833964`
- item 16 configuration foundation clean: `97366567224`
- item 16 OCR staged: `97371701920`
- item 16 OCR clean: `97372254897`
- item 16 advanced configuration staged: `97374175885`
- item 16 final clean: `97374705820`
- item 17 task/progress hardening staged: `97376499301`
- item 17 clean: `97377277505`
- item 18 live Task Center indicator staged: `97400172851`
- item 18 clean: `97400644796`

The former `MainWindow.DocumentTabs.cs` CS4014 warning was explicitly fixed during item 17. Current clean source compiles with 0 warnings and 0 errors.

These are development gates, not the final installer acceptance gate. UI items remain unaccepted until hands-on visual/runtime verification is completed.

## Immediate next work

1. expand master item 19 so background Task Center results get the same meaningful completion choices as foreground PDF transformations
2. keep side-by-side original/result comparison explicitly pending until master item 6 split view is implemented
3. audit item 20 non-destructive behavior operation by operation
4. continue the context-aware command audit
5. enrich Inspector and PDF Doctor states
6. implement Light / Follow Windows themes and a real Settings experience
7. add first-launch/privacy/recovery polish
8. implement remaining viewing modes and split-view comparison
9. visually inspect the running Windows app against the canonical Home and Document targets

## Item 19 audit starting point

The existing foreground PDF result dialog already makes ORIGINAL versus RESULT explicit and provides Open in New Tab, safe Use Result Here, Open Folder, Save As/Copy, Run Another and Close. The remaining gap is shared completion treatment for background Task Center outputs and multi-output workflows. True side-by-side comparison depends on master item 6 split view and must not be credited before that feature exists.
## Product source of truth

Future work is governed by:

1. `../ASANTEPDF_MASTER_UPGRADE_SPEC.md`
2. `../IMPLEMENTATION_MATRIX.md`
3. `ASANTEPDF-VISUAL-DIRECTION.md`
4. `design/target-home.svg`
5. `design/target-document-workspace.svg`
6. `../AGENTS.md`

The master specification contains 45 numbered requirements. `IMPLEMENTATION_MATRIX.md` is the acceptance ledger. Do not mark a row `ACCEPTED` merely because related code exists.

## Engineering cadence

For every coherent batch:

- make one coherent source batch, preferably with exactly one staged patch carrier
- Windows-compile and run core smoke tests
- inspect the staged job log and promoted diff/source
- rerun the promoted source with no staged patch carrier
- update `IMPLEMENTATION_MATRIX.md`
- update this project-state file when the handoff materially changes
- visually inspect affected UI requirements before acceptance
- run the heavyweight installer/installed-copy gate only at release-candidate checkpoints

Important workflow quirk: multiple independent `.ps1` files under `dev-patches/` are unsafe because the workflow checks `$LASTEXITCODE` after each PowerShell script. Prefer exactly one carrier. If a carrier must invoke another script, do so explicitly in the first carrier and avoid modifying staged carrier files in place, otherwise promotion cleanup can fail.

## Final-release rule

Do not promote RC10 directly to AsantePDF 1.0 final. A future final release requires material master-spec items to be accepted and the redesigned installed application to survive the full Windows release gate again.