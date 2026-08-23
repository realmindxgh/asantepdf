# AsantePDF Implementation Matrix

This matrix is the acceptance tracker for `ASANTEPDF_MASTER_UPGRADE_SPEC.md`.

**Baseline rule:** RC10 is not automatically credited as satisfying a master item merely because related backend code exists. Each item must be audited against the full requirement before its status is upgraded.

Initial status `REVIEW REQUIRED` means the current codebase has not yet been item-by-item accepted against that complete requirement.

Allowed working states after review:

- `NOT STARTED`
- `IN PROGRESS`
- `IMPLEMENTED, NOT ACCEPTED`
- `ACCEPTED`

An item may be marked `ACCEPTED` only after its complete requirement has been implemented and concretely verified. UI items require visual verification against the target references. Release-critical changes must survive the Windows release gate.

| # | Master requirement | Status | Evidence / notes |
|---:|---|---|---|
| 1 | Rename and fully rebrand PDF Rescue as AsantePDF | REVIEW REQUIRED | RC10 carries substantial public rebranding, but the full requirement still needs an item-by-item audit after the redesign. |
| 2 | Redesign the Windows installer | REVIEW REQUIRED | RC10 installer is proven; master installer requirements still need a dedicated audit and final-release rerun. |
| 3 | Replace the current empty screen with a proper Home experience | IN PROGRESS | Architecture Batch 1 adds a real Home experience with Open PDF, Quick Tools, Recent/Starred navigation, real Recent thumbnails/layouts/search and local-first messaging. First-launch and remaining Home polish still require visual acceptance. |
| 4 | Add proper session persistence | IN PROGRESS | `workspace-state.json` now persists the open tab set, active-tab index, per-document page, zoom and scroll offsets, alongside Recent history. Resume Last Session restores all available saved tabs and returns to the saved active tab. Writes remain debounced. Crash recovery, unsaved working-layout recovery and broader sidebar/view preferences remain. |
| 5 | Implement a real multi-document tab system | IN PROGRESS | A real per-document model backs multiple simultaneous PDF tabs. Tabs show filenames, active state and dirty `*`, have close buttons, drag reordering, middle-click close, scrollable overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T reopen. Each tab preserves page layout, saved baseline, selection, zoom, scroll and Undo/Redo while the proven PDFium renderer is transactionally reused on activation. Successful PDF outputs can open directly as new tabs through Task Center/result routing. Hands-on visual/use acceptance and full output-route coverage remain. |
| 6 | Add split-view PDF comparison | REVIEW REQUIRED | |
| 7 | Redesign the entire command toolbar/ribbon | IN PROGRESS | Batch 1 replaces the legacy grey-button wall with grouped dark command surfaces for File, History, Pages, Edit/Annotate, Convert and Optimize/Doctor. Full icon/command audit remains. |
| 8 | Add a coherent colour system and complete dark mode | IN PROGRESS | App-level dark design tokens, surfaces, accent, borders, hover/focus/pressed/disabled states and reusable styles added. Light and Follow Windows themes remain. |
| 9 | Upgrade PDF page navigation | IN PROGRESS | Previous/Next controls, editable page number and live page count are wired. Full keyboard/navigation acceptance remains. |
| 10 | Upgrade zoom and document viewing | IN PROGRESS | Existing zoom is retained and Batch 1 adds Fit Page and Actual Size shell actions. Complete viewing-mode set remains. |
| 11 | Make PDF text genuinely interactive | REVIEW REQUIRED | |
| 12 | Add first-class document search | REVIEW REQUIRED | Search field is deliberately disabled with explanatory tooltip until the real search model is implemented. |
| 13 | Upgrade the left navigation sidebar | IN PROGRESS | Pages/Bookmarks/Search navigation shell added. Pages is functional; Bookmarks and Search remain explicit placeholders. |
| 14 | Implement proper multi-page selection and page management | REVIEW REQUIRED | Existing RC10 page model supports part of this requirement but it has not been accepted against the complete item. |
| 15 | Make tools usable even when no PDF is already open | IN PROGRESS | Home launches OCR, Compress, Split, Word conversion and Doctor through file selection; Merge and Images-to-PDF remain directly available. Merge and Office-to-PDF can now be queued without an active document. Full standalone-tool audit remains. |
| 16 | Create proper configuration dialogs for every significant operation | REVIEW REQUIRED | |
| 17 | Create an application-wide task/progress framework | IN PROGRESS | Foreground operations remain centrally tracked through `RunBusyAsync`, while `BackgroundTaskQueueService` gives eligible work genuine queued/running/completed/failed/cancelled execution without globally locking the workspace. Compress, Repair, Optimize for Web, Unlock, Merge and Office-to-PDF now use the same queue. Dirty page layouts are captured into isolated temporary working PDFs and cleaned afterward. Queue serialization and queued cancellation are smoke-tested. Rich page/item counts and background routing for OCR/PDF export remain. |
| 18 | Add a Task Center | IN PROGRESS | Dedicated Task Center shows Running, Queued, Completed, Failed and Cancelled jobs with filtering, elapsed time, progress, errors, Cancel, Open Result and single-use Retry for retry-safe failures/cancellations. The core single-worker queue supports multiple real queued jobs while users continue in other tabs. Sensitive password jobs remain deliberately non-retryable. Six production workflows now use the queue; OCR and other renderer-dependent long jobs remain. |
| 19 | Create proper completion workflows | IN PROGRESS | `OperationResultDialog` and shared result routing distinguish original/result files and provide Open in New Tab, safe Use Result Here, Open Folder, Save a Copy, Run Another and Close. Foreground completion UI is wired for Compress, Repair, Web Optimization and Unlock. Background jobs expose outputs non-modally through Task Center, including Merge and Office-to-PDF. The pattern still needs expansion to split/OCR/PDF exports/security/annotation and other output-producing operations. |
| 20 | Default to non-destructive processing | REVIEW REQUIRED | RC10 has strong non-destructive behavior, and the background queue snapshots dirty layouts into temporary copies rather than mutating source PDFs. The complete operation-by-operation audit remains. |
| 21 | Redesign PDF Doctor | IN PROGRESS | Batch 1 fixes the false initial state: Doctor now starts as “Not analysed yet” with Run PDF Doctor and no fake recommendations. Rich findings/recommendation UX remains. |
| 22 | Redesign the Inspector | IN PROGRESS | Batch 1 provides a contextual document-details/Doctor shell. Selection-specific page/text/annotation/object modes remain. |
| 23 | Build a proper annotation system | REVIEW REQUIRED | |
| 24 | Implement proper Save behaviour | REVIEW REQUIRED | RC10 unsaved-layout protection exists and dirty state is now per-tab, but the complete multi-document save contract is not yet accepted. |
| 25 | Strengthen Undo/Redo | IN PROGRESS | Existing page-layout Undo/Redo is preserved independently per document tab across tab switches. Broader operation/annotation history and full requirement audit remain. |
| 26 | Add proper drag-and-drop support | REVIEW REQUIRED | Existing PDF/window/page drag-drop behavior is preserved; document tabs now also support drag reordering. Full master item audit remains. |
| 27 | Add robust context menus | REVIEW REQUIRED | Recent files now have a real context menu, but the requirement covers the application more broadly and is not yet accepted. |
| 28 | Create a coherent keyboard shortcut system | IN PROGRESS | Existing shortcuts are retained and multi-document commands now include Ctrl+Tab, Ctrl+W and Ctrl+Shift+T. A complete discoverable shortcut map and conflict/accessibility audit remain. |
| 29 | Add proper printing | REVIEW REQUIRED | |
| 30 | Improve conversion workflows | IN PROGRESS | Office-to-PDF now runs through the non-blocking Task Center queue and produces a reopenable PDF result. Existing PDF-to-Word/Excel/PowerPoint engines remain foreground and still need proper settings, progress, output routing and queue integration. |
| 31 | Strengthen OCR as a proper feature | REVIEW REQUIRED | |
| 32 | Add batch processing | REVIEW REQUIRED | The Task Center queue is deliberately the execution foundation for future batch workflows; batch UI/rules are not yet accepted. |
| 33 | Build proper PDF security workflows | REVIEW REQUIRED | |
| 34 | Recent-files privacy controls | REVIEW REQUIRED | Rich Recent history now exists; dedicated privacy/clear-history controls still need implementation. |
| 35 | Create a real Settings experience | REVIEW REQUIRED | Settings is deliberately shown unavailable in Batch 1 rather than leading to a dead action. |
| 36 | Professional error and recovery UX | REVIEW REQUIRED | |
| 37 | Improve performance perception | REVIEW REQUIRED | Recent first-page thumbnails are generated asynchronously and cached by file identity; six eligible transformations can now run through Task Center without freezing or globally locking the workspace. Wider performance-perception work remains. |
| 38 | Accessibility and high-DPI support | REVIEW REQUIRED | Batch 1 raises typography and adds keyboard-focus visuals, but the full scaling/accessibility matrix is not yet tested. |
| 39 | Create a tasteful first-launch experience | REVIEW REQUIRED | |
| 40 | Build a proper About and diagnostics section | REVIEW REQUIRED | |
| 41 | Plan a proper application update mechanism | REVIEW REQUIRED | |
| 42 | Establish one coherent application architecture | IN PROGRESS | AsantePDF has three connected experiences in code: Home / Launcher, a true multi-document Document Workspace, and a Task Center backed by a real application queue. Shared result routing and independent queued execution now cover both active-document and standalone file operations. Remaining architecture work includes renderer-isolated OCR/search, bookmarks/settings and other master-spec systems. |
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 full Windows release gate passed end to end. Architecture Batch 1 passed run 32647383215. Recent/session and later architecture iterations were repeatedly Windows validated. Background queue job `97232413507` passed expanded queue smoke tests. Merge/Office queue expansion job `97232877751` passed patch application, exact .NET 10.0.202 x64 Release compilation, smoke tests and validated commit. Full installer/installed-copy gate must be rerun for a release candidate. |
| 44 | Make the entire interface context-aware | IN PROGRESS | Home, Document and Task Center modes differ genuinely. Existing command-state logic is reused for document commands, tab switching restores document-specific state, and supported background jobs no longer disable unrelated workspace navigation. Full command-by-command recalculation audit remains. |
| 45 | Recent files must support multiple layouts with real PDF thumbnails | IMPLEMENTED, NOT ACCEPTED | `RecentFilesView` provides cached asynchronous first-page PDFium thumbnails, Grid/List/Compact layouts with persisted preference, Last opened/Name/Modified sorting, metadata, search, pinning + Starred navigation, graceful moved-file handling, Open/Pin/Show in Folder/Remove/Remove Missing context actions, and stored page/zoom resume. Windows compile/smoke validation passed; hands-on visual/use acceptance remains. |