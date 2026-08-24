# AsantePDF Implementation Matrix

This matrix is the acceptance tracker for `ASANTEPDF_MASTER_UPGRADE_SPEC.md`.

**Baseline rule:** backend presence alone is not completion. Each master item is credited only after its full requirement is audited. UI items remain unaccepted until hands-on visual/runtime verification. Release-critical work must survive the Windows gate.

Allowed working states:

- `NOT STARTED`
- `REVIEW REQUIRED`
- `IN PROGRESS`
- `IMPLEMENTED, NOT ACCEPTED`
- `ACCEPTED`

| # | Master requirement | Status | Evidence / notes |
|---:|---|---|---|
| 1 | Rename and fully rebrand PDF Rescue as AsantePDF | REVIEW REQUIRED | Substantial rebranding exists; complete surface/metadata/installer audit still required. |
| 2 | Redesign the Windows installer | REVIEW REQUIRED | RC10 installer engineering is proven; redesigned final installer still needs dedicated audit and release-candidate installed-copy gate. |
| 3 | Replace the current empty screen with a proper Home experience | IN PROGRESS | Real Home, Quick Tools, Recent/Starred, thumbnails, multiple layouts and local-first messaging exist. First-launch and final visual polish remain. |
| 4 | Add proper session persistence | IN PROGRESS | Open tabs, active tab, page, zoom, scroll, Recent/pins and Resume Last Session persist. Crash and unsaved-layout recovery remain. |
| 5 | Implement a real multi-document tab system | IN PROGRESS | Per-document layout/selection/zoom/scroll/Undo state, active/dirty tabs, close/reorder/middle-click/overflow and tab shortcuts exist. Hands-on acceptance and split-view integration remain. |
| 6 | Add split-view PDF comparison | REVIEW REQUIRED | Not yet implemented. This is the remaining dependency for item 19's true original/result side-by-side comparison clause. |
| 7 | Redesign the entire command toolbar/ribbon | IN PROGRESS | Grouped dark File/History/Pages/Edit/Annotate/Convert/Optimize surfaces replace the old button wall. Full command/icon audit remains. |
| 8 | Add a coherent colour system and complete dark mode | IN PROGRESS | Dark design tokens and reusable states are established. Light and Follow Windows themes remain. |
| 9 | Upgrade PDF page navigation | IN PROGRESS | Previous/Next, editable page number and live page count exist. Full shortcut/navigation acceptance remains. |
| 10 | Upgrade zoom and document viewing | IN PROGRESS | Zoom, Fit Width/Fit Page/Actual Size foundations exist. Remaining viewing modes and hands-on acceptance remain. |
| 11 | Make PDF text genuinely interactive | IMPLEMENTED, NOT ACCEPTED | Lazy PDFium text geometry, drag selection, on-page selection, Ctrl+C/right-click Copy and OCR-searchable compatibility. Staged/clean jobs `97256072705` / `97256350665`. |
| 12 | Add first-class document search | IMPLEMENTED, NOT ACCEPTED | Cached native PDFium text index, Ctrl+F, previous/next, snippets and on-page highlights mapped through the working layout. Windows job `97236130041`; hands-on acceptance remains. |
| 13 | Upgrade the left navigation sidebar | IMPLEMENTED, NOT ACCEPTED | Pages, Bookmarks, Search, Comments and Attachments; native outline/annotation/attachment services; bounded resize/collapse/restore. Final clean job `97344623846`, source `b8874135a6883bd6d8f2fc89bb1d66694aadbbdc`. |
| 14 | Implement proper multi-page selection and page management | IMPLEMENTED, NOT ACCEPTED | Ctrl/Shift selection, Select All, rotate/delete/extract/duplicate/move/drag reorder, selected-range feedback, transactional multi-page crop and page-layout Undo/Redo. Staged/clean `97345750241` / `97346132649`. |
| 15 | Make tools usable even when no PDF is already open | IMPLEMENTED, NOT ACCEPTED | Standalone picker/config routes cover all non-canvas tools; only genuinely canvas-dependent markup requires an open PDF. Clean job `97364651130`, source `2c4f4373d93d49b0bea4079aa0c3c9c3dd127958`. |
| 16 | Create proper configuration dialogs for every significant operation | IMPLEMENTED, NOT ACCEPTED | Shared dark modal system with real settings for compression, split, merge, OCR, conversion, page images, Protect, Unlock and Office-to-PDF. Foundation/OCR/advanced clean jobs `97366567224`, `97372254897`, `97374705820`. |
| 17 | Create an application-wide task/progress framework | IMPLEMENTED, NOT ACCEPTED | Foreground and queued work expose task/stage/progress/elapsed/cancel; snapshots and transactional publication prevent partial/corrupt results. Staged/clean `97376499301` / `97377277505`, source `059327d0c37f8a55625dfe59417d875884d9ea20`. |
| 18 | Add a Task Center | IMPLEMENTED, NOT ACCEPTED | Running/Queued/Completed/Failed/Cancelled states, filters, progress, elapsed time, Cancel, Retry, output actions, multiple queued jobs and live navigation badge. Staged/clean `97400172851` / `97400644796`. |
| 19 | Create proper completion workflows | IN PROGRESS | Completion workflows now cover foreground PDF transformations, finishing/markup, Word/Excel/PowerPoint/text results, Split and page-image multi-results, batch results and Task Center outputs. They make source/result explicit and provide Open, safe current-context replacement where applicable, Open Folder, Save As, Run Another and Close. Phase-A staged/clean `97403214120` / `97403748273`; foreground migration staged/clean `97412436863` / `97413038885`; markup/batch final staged/clean `97414112602` / `97414608852`; final completion source `9a8c9993022493c10279c86ed2f9d25ab5012715`. **Remaining:** true side-by-side original/result comparison depends on item 6 split view. |
| 20 | Default to non-destructive processing | IMPLEMENTED, NOT ACCEPTED | Operation-by-operation audit confirms transformations default to separate copies. Configuration validation rejects source=output; qpdf, finishing, markup and form services independently reject source overwrite; queued dirty/scoped work uses disposable snapshots; qpdf/Office/markup/form/image-set writers stage transactionally; batch outputs are unique. New smoke test deliberately attempts in-place compression and proves rejection occurs before qpdf starts while source bytes remain unchanged. Staged/clean jobs `97416112570` / `97416554259`, clean-proven source `c5588b15d39f56ffefc2aa239a951d9158e48f55`, exact .NET `10.0.202`, 0 warnings, 0 errors, all smoke tests passed. Hands-on overwrite/copy UX acceptance remains. |
| 21 | Redesign PDF Doctor | IN PROGRESS | Honest initial state already exists. Current engine reports structural errors/warnings, encryption, file size, page count and PDF version; richer grouped health/findings/actions UI is the next active audit. |
| 22 | Redesign the Inspector | IN PROGRESS | Document-details/Doctor shell exists. Context-specific page/text/annotation/object modes remain. |
| 23 | Build a proper annotation system | REVIEW REQUIRED | |
| 24 | Implement proper Save behaviour | REVIEW REQUIRED | Per-tab dirty state and unsaved-layout protection exist; full Save/Save As/Save a Copy contract still needs dedicated audit. |
| 25 | Strengthen Undo/Redo | IN PROGRESS | Per-document page-layout Undo/Redo exists. Broader edit/annotation history remains. |
| 26 | Add proper drag-and-drop support | REVIEW REQUIRED | PDF/window/page and tab drag behavior exists; full requirement audit remains. |
| 27 | Add robust context menus | REVIEW REQUIRED | Recent-file and selected-text menus exist; page/tab/annotation/canvas coverage remains. |
| 28 | Create a coherent keyboard shortcut system | IN PROGRESS | Major document/tab/search/copy/history/zoom shortcuts exist. Discoverability/conflict/accessibility audit remains. |
| 29 | Add proper printing | REVIEW REQUIRED | |
| 30 | Improve conversion workflows | IN PROGRESS | Configured Word/Excel/PowerPoint and Office-to-PDF use Task Center/background execution where available, page scope and real relevant settings. Fidelity/quality acceptance remains. |
| 31 | Strengthen OCR as a proper feature | IN PROGRESS | Searchable PDF/text OCR, local language discovery, page scope, background execution and page-level progress exist. Broader OCR quality/UX acceptance remains. |
| 32 | Add batch processing | REVIEW REQUIRED | A real batch service/workflow exists for Compress/Repair/Optimize with progress and a multi-result completion panel; complete item-32 rules/UI audit is still required before changing status. |
| 33 | Build proper PDF security workflows | REVIEW REQUIRED | Protect has 256-bit encryption plus print/modify/extract permissions; Unlock is configured and queued. Dedicated item audit remains. |
| 34 | Recent-files privacy controls | REVIEW REQUIRED | Rich Recent history exists; explicit privacy/clear-history controls remain. |
| 35 | Create a real Settings experience | REVIEW REQUIRED | Settings is intentionally unavailable rather than dead. |
| 36 | Professional error and recovery UX | REVIEW REQUIRED | |
| 37 | Improve performance perception | IN PROGRESS | Async/cached Recent thumbnails, non-blocking jobs, isolated renderers, cached search index, lazy outline and page-local interactive text exist. Wider audit remains. |
| 38 | Accessibility and high-DPI support | REVIEW REQUIRED | Typography/focus improvements exist; full scaling/accessibility matrix remains. |
| 39 | Create a tasteful first-launch experience | REVIEW REQUIRED | |
| 40 | Build a proper About and diagnostics section | REVIEW REQUIRED | |
| 41 | Plan a proper application update mechanism | REVIEW REQUIRED | |
| 42 | Establish one coherent application architecture | IN PROGRESS | Home/Launcher, multi-document Workspace, shared tool configuration, Task Center, output routing, search, outline and interactive text are connected. Settings/themes/split view/richer Inspector remain. |
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 full release gate is proven. Development changes are repeatedly staged on Windows, compiled/smoke-tested, promoted to ordinary source, then rerun without patch carriers. Key later gates: items 17 `97376499301`/`97377277505`; item 18 `97400172851`/`97400644796`; item 19 phase A `97403214120`/`97403748273`, foreground `97412436863`/`97413038885`, final markup/batch `97414112602`/`97414608852`; item 20 `97416112570`/`97416554259`. Current clean source `c5588b15d39f56ffefc2aa239a951d9158e48f55` builds exact .NET 10.0.202 with 0 warnings/0 errors and all smoke tests. Full installer/installed-copy gate must be rerun at release-candidate stage. |
| 44 | Make the entire interface context-aware | IN PROGRESS | Home/Document/Task Center modes, tab-specific state, active-document search/text/outline and format-relevant dialog options exist. Full command-by-command context audit remains. |
| 45 | Recent files must support multiple layouts with real PDF thumbnails | IMPLEMENTED, NOT ACCEPTED | Cached async first-page PDFium thumbnails, Grid/List/Compact views, persisted layout, sorting/search/pinning, moved-file handling, context actions and resume metadata. Hands-on visual/use acceptance remains. |
