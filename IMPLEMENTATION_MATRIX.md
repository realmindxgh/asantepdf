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
| 5 | Implement a real multi-document tab system | IN PROGRESS | A real per-document model now backs multiple simultaneous PDF tabs. Tabs show filenames, active state and dirty `*`, have close buttons, drag reordering, middle-click close, scrollable overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T reopen. Each tab preserves page layout, saved baseline, selection, zoom, scroll and Undo/Redo while the proven PDFium renderer is transactionally reused on activation. Operation-result tab creation and hands-on visual/use acceptance remain. |
| 6 | Add split-view PDF comparison | REVIEW REQUIRED | |
| 7 | Redesign the entire command toolbar/ribbon | IN PROGRESS | Batch 1 replaces the legacy grey-button wall with grouped dark command surfaces for File, History, Pages, Edit/Annotate, Convert and Optimize/Doctor. Full icon/command audit remains. |
| 8 | Add a coherent colour system and complete dark mode | IN PROGRESS | App-level dark design tokens, surfaces, accent, borders, hover/focus/pressed/disabled states and reusable styles added. Light and Follow Windows themes remain. |
| 9 | Upgrade PDF page navigation | IN PROGRESS | Previous/Next controls, editable page number and live page count are wired. Full keyboard/navigation acceptance remains. |
| 10 | Upgrade zoom and document viewing | IN PROGRESS | Existing zoom is retained and Batch 1 adds Fit Page and Actual Size shell actions. Complete viewing-mode set remains. |
| 11 | Make PDF text genuinely interactive | REVIEW REQUIRED | |
| 12 | Add first-class document search | REVIEW REQUIRED | Search field is deliberately disabled with explanatory tooltip until the real search model is implemented. |
| 13 | Upgrade the left navigation sidebar | IN PROGRESS | Pages/Bookmarks/Search navigation shell added. Pages is functional; Bookmarks and Search remain explicit placeholders. |
| 14 | Implement proper multi-page selection and page management | REVIEW REQUIRED | Existing RC10 page model supports part of this requirement but it has not been accepted against the complete item. |
| 15 | Make tools usable even when no PDF is already open | IN PROGRESS | Home launches OCR, Compress, Split, Word conversion and Doctor through file selection; Merge and Images-to-PDF remain directly available. Full standalone-tool audit remains. |
| 16 | Create proper configuration dialogs for every significant operation | REVIEW REQUIRED | |
| 17 | Create an application-wide task/progress framework | IN PROGRESS | `TaskCenterService` now wraps the central `RunBusyAsync` path, so existing long PDF operations automatically expose task name/state, stage, determinate percentage where page/item progress is available, elapsed time, failure/cancellation and graceful Cancel. Windows x64 compile and smoke validation passed in run 32649073796. Per-operation richer counts/stages and full independent background execution remain. |
| 18 | Add a Task Center | IN PROGRESS | A dedicated Task Center view and live left-nav entry now show Running, Queued, Completed, Failed and Cancelled task groups with filtering, elapsed time, progress, errors, active-task cancellation and finished-history clearing. Windows x64 compile and smoke validation passed in run 32649073796. Retry, successful-output actions and multiple queued jobs remain; the new tab architecture now provides the document foundation needed for background work. |
| 19 | Create proper completion workflows | REVIEW REQUIRED | |
| 20 | Default to non-destructive processing | REVIEW REQUIRED | RC10 has strong non-destructive behavior, but the full requirement still needs an operation-by-operation audit. |
| 21 | Redesign PDF Doctor | IN PROGRESS | Batch 1 fixes the false initial state: Doctor now starts as “Not analysed yet” with Run PDF Doctor and no fake recommendations. Rich findings/recommendation UX remains. |
| 22 | Redesign the Inspector | IN PROGRESS | Batch 1 provides a contextual document-details/Doctor shell. Selection-specific page/text/annotation/object modes remain. |
| 23 | Build a proper annotation system | REVIEW REQUIRED | |
| 24 | Implement proper Save behaviour | REVIEW REQUIRED | RC10 unsaved-layout protection exists and dirty state is now per-tab, but the complete multi-document save contract is not yet accepted. |
| 25 | Strengthen Undo/Redo | IN PROGRESS | Existing page-layout Undo/Redo is now preserved independently per document tab across tab switches. Broader operation/annotation history and full requirement audit remain. |
| 26 | Add proper drag-and-drop support | REVIEW REQUIRED | Existing PDF/window/page drag-drop behavior is preserved; document tabs now also support drag reordering. Full master item audit remains. |
| 27 | Add robust context menus | REVIEW REQUIRED | Recent files now have a real context menu, but the requirement covers the application more broadly and is not yet accepted. |
| 28 | Create a coherent keyboard shortcut system | IN PROGRESS | Existing shortcuts are retained and multi-document commands now include Ctrl+Tab, Ctrl+W and Ctrl+Shift+T. A complete discoverable shortcut map and conflict/accessibility audit remain. |
| 29 | Add proper printing | REVIEW REQUIRED | |
| 30 | Improve conversion workflows | REVIEW REQUIRED | |
| 31 | Strengthen OCR as a proper feature | REVIEW REQUIRED | |
| 32 | Add batch processing | REVIEW REQUIRED | |
| 33 | Build proper PDF security workflows | REVIEW REQUIRED | |
| 34 | Recent-files privacy controls | REVIEW REQUIRED | Rich Recent history now exists; dedicated privacy/clear-history controls still need implementation. |
| 35 | Create a real Settings experience | REVIEW REQUIRED | Settings is deliberately shown unavailable in Batch 1 rather than leading to a dead action. |
| 36 | Professional error and recovery UX | REVIEW REQUIRED | |
| 37 | Improve performance perception | REVIEW REQUIRED | Recent first-page thumbnails are generated asynchronously and cached by file identity, but the wider performance-perception requirement remains. |
| 38 | Accessibility and high-DPI support | REVIEW REQUIRED | Batch 1 raises typography and adds keyboard-focus visuals, but the full scaling/accessibility matrix is not yet tested. |
| 39 | Create a tasteful first-launch experience | REVIEW REQUIRED | |
| 40 | Build a proper About and diagnostics section | REVIEW REQUIRED | |
| 41 | Plan a proper application update mechanism | REVIEW REQUIRED | |
| 42 | Establish one coherent application architecture | IN PROGRESS | AsantePDF now has three distinct connected experiences in code: Home / Launcher, a true multi-document Document Workspace, and a dedicated Task Center / Task System surface. The next architectural layer is result/completion routing and independent queued background execution. |
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 full Windows release gate passed end to end. Architecture Batch 1 passed run 32647383215. Recent/session integration passed run 32648130725, Starred/Resume passed run 32648422410, and Task Center, multi-document tabs and multi-tab session restoration were repeatedly validated through run 32649073796; the latest successful session job was 97221651603. Full installer/installed-copy gate must be rerun for a release candidate. |
| 44 | Make the entire interface context-aware | IN PROGRESS | Home, Document and Task Center modes now differ genuinely. Existing command-state logic is reused for document commands, and tab switching restores document-specific state. Full command-by-command recalculation audit remains. |
| 45 | Recent files must support multiple layouts with real PDF thumbnails | IMPLEMENTED, NOT ACCEPTED | `RecentFilesView` now provides cached asynchronous first-page PDFium thumbnails, Grid/List/Compact layouts with persisted preference, Last opened/Name/Modified sorting, metadata, search, pinning + Starred navigation, graceful moved-file handling, Open/Pin/Show in Folder/Remove/Remove Missing context actions, and stored page/zoom resume. Windows compile/smoke validation passed; hands-on visual/use acceptance remains. |