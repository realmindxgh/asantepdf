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
| 4 | Add proper session persistence | IN PROGRESS | `workspace-state.json` persists open tabs, active-tab index, per-document page, zoom and scroll offsets, alongside Recent history. Resume Last Session restores all available saved tabs and the saved active tab. Crash recovery, unsaved working-layout recovery and broader sidebar/view preferences remain. |
| 5 | Implement a real multi-document tab system | IN PROGRESS | Real per-document tabs preserve page layout, saved baseline, selection, zoom, scroll and Undo/Redo and support active/dirty state, close, drag reorder, middle-click close, overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T. PDF Task Center outputs can open as new tabs. Hands-on visual/use acceptance remains. |
| 6 | Add split-view PDF comparison | REVIEW REQUIRED | |
| 7 | Redesign the entire command toolbar/ribbon | IN PROGRESS | Batch 1 replaces the legacy grey-button wall with grouped dark command surfaces for File, History, Pages, Edit/Annotate, Convert and Optimize/Doctor. Full icon/command audit remains. |
| 8 | Add a coherent colour system and complete dark mode | IN PROGRESS | App-level dark design tokens, surfaces, accent, borders, hover/focus/pressed/disabled states and reusable styles added. Light and Follow Windows themes remain. |
| 9 | Upgrade PDF page navigation | IN PROGRESS | Previous/Next controls, editable page number and live page count are wired. Full keyboard/navigation acceptance remains. |
| 10 | Upgrade zoom and document viewing | IN PROGRESS | Existing zoom is retained and Batch 1 adds Fit Page and Actual Size shell actions. Complete viewing-mode set remains. |
| 11 | Make PDF text genuinely interactive | REVIEW REQUIRED | |
| 12 | Add first-class document search | IMPLEMENTED, NOT ACCEPTED | `DocumentSearchService` builds a cached native PDFium text index with Unicode character geometry. Ctrl+F focuses a live active-document search strip; Enter/Shift+Enter and buttons navigate next/previous matches, the UI shows current/total counts, the Search sidebar lists page/snippet results, and the preview highlights all matches on the current page with stronger emphasis for the active result. Search results are expanded onto the current unsaved working layout, so deleted pages disappear and duplicated pages duplicate their hits. OCR-generated searchable PDFs participate through their real PDF text layer. Clear removes search without changing document position. Windows job `97236130041` passed staged integration, exact .NET 10.0.202 x64 Release compilation, smoke tests and validated source commit. Hands-on visual/runtime acceptance remains. |
| 13 | Upgrade the left navigation sidebar | IN PROGRESS | Pages and Search Results are now real navigation modes. Search shows native text-result snippets and page navigation. Bookmarks/Outline remains the next missing primary mode; comments/annotations, attachments, resize/collapse and broader acceptance still remain. |
| 14 | Implement proper multi-page selection and page management | REVIEW REQUIRED | Existing RC10 page model supports part of this requirement but it has not been accepted against the complete item. |
| 15 | Make tools usable even when no PDF is already open | IN PROGRESS | Home launches OCR, Compress, Split, Word conversion and Doctor through file selection; Merge and Images-to-PDF remain directly available. Merge and Office-to-PDF queue without an active document. Full standalone-tool audit remains. |
| 16 | Create proper configuration dialogs for every significant operation | REVIEW REQUIRED | |
| 17 | Create an application-wide task/progress framework | IN PROGRESS | Foreground operations remain centrally tracked through `RunBusyAsync`, while `BackgroundTaskQueueService` now runs Compress, Repair, Optimize for Web, Unlock, Merge, Office-to-PDF, PDF-to-Word, PDF-to-Excel, PDF-to-PowerPoint, searchable OCR PDF and OCR-text extraction without globally locking the workspace. Renderer-dependent jobs own isolated PDFium renderers and report page-level stages such as `Recognising page 18 of 64`. Dirty layouts are snapshotted into temporary PDFs and cleaned afterward. Remaining work is broader migration/audit and richer counts for every applicable operation. |
| 18 | Add a Task Center | IN PROGRESS | Task Center shows Running, Queued, Completed, Failed and Cancelled jobs with filtering, elapsed time, progress, Cancel, Open Result and single-use Retry for retry-safe jobs. Multiple real queued jobs are supported while users continue in other tabs. PDF outputs open as AsantePDF tabs; non-PDF outputs open through their associated Windows application. Sensitive password jobs remain non-retryable. Eleven production workflows now use the queue. |
| 19 | Create proper completion workflows | IN PROGRESS | Shared result routing distinguishes original/result files and supports Open in New Tab, safe Use Result Here, Open Folder, Save a Copy, Run Another and Close for the initial foreground set. Background jobs expose results non-modally through Task Center. Task Center now routes `.pdf` back into AsantePDF and `.docx`/`.xlsx`/`.pptx`/`.txt` to Windows. Split/multi-output and remaining transformation workflows still need completion treatment. |
| 20 | Default to non-destructive processing | REVIEW REQUIRED | RC10 has strong non-destructive behavior, and queued active-document work snapshots dirty layouts into temporary copies rather than mutating source PDFs. Complete operation-by-operation audit remains. |
| 21 | Redesign PDF Doctor | IN PROGRESS | Batch 1 fixes the false initial state: Doctor starts as “Not analysed yet” with Run PDF Doctor and no fake recommendations. Rich findings/recommendation UX remains. |
| 22 | Redesign the Inspector | IN PROGRESS | Batch 1 provides a contextual document-details/Doctor shell. Selection-specific page/text/annotation/object modes remain. |
| 23 | Build a proper annotation system | REVIEW REQUIRED | |
| 24 | Implement proper Save behaviour | REVIEW REQUIRED | RC10 unsaved-layout protection exists and dirty state is now per-tab, but the complete multi-document save contract is not yet accepted. |
| 25 | Strengthen Undo/Redo | IN PROGRESS | Existing page-layout Undo/Redo is preserved independently per document tab. Broader operation/annotation history and full requirement audit remain. |
| 26 | Add proper drag-and-drop support | REVIEW REQUIRED | Existing PDF/window/page drag-drop behavior is preserved; document tabs also support drag reordering. Full master item audit remains. |
| 27 | Add robust context menus | REVIEW REQUIRED | Recent files have a real context menu, but the requirement covers the application more broadly and is not yet accepted. |
| 28 | Create a coherent keyboard shortcut system | IN PROGRESS | Existing shortcuts are retained and multi-document commands include Ctrl+Tab, Ctrl+W and Ctrl+Shift+T. Ctrl+F now focuses native active-document search. A complete discoverable shortcut map and conflict/accessibility audit remain. |
| 29 | Add proper printing | REVIEW REQUIRED | |
| 30 | Improve conversion workflows | IN PROGRESS | Office-to-PDF and PDF-to-Word/Excel/PowerPoint now run through the non-blocking Task Center queue. Word/Excel use isolated page-by-page local OCR; PowerPoint uses isolated page rendering. Non-PDF results open via the associated Windows application. Proper conversion configuration/options and visual acceptance remain. |
| 31 | Strengthen OCR as a proper feature | IN PROGRESS | Searchable OCR PDF and OCR-text extraction now run in the background queue with an isolated renderer, local bundled-Tesseract preference, cancellation and page-level progress. The existing searchable-PDF builder and Windows OCR fallback remain. Language/page-range/output-option configuration and complete OCR UX still need implementation. |
| 32 | Add batch processing | REVIEW REQUIRED | The Task Center queue is the execution foundation for future batch workflows; batch UI/rules are not yet accepted. |
| 33 | Build proper PDF security workflows | REVIEW REQUIRED | |
| 34 | Recent-files privacy controls | REVIEW REQUIRED | Rich Recent history exists; dedicated privacy/clear-history controls still need implementation. |
| 35 | Create a real Settings experience | REVIEW REQUIRED | Settings is deliberately unavailable rather than dead. |
| 36 | Professional error and recovery UX | REVIEW REQUIRED | |
| 37 | Improve performance perception | IN PROGRESS | Recent thumbnails are asynchronous/cached, eleven transformations run without freezing or globally locking the workspace, renderer-heavy OCR/conversion uses private renderers, and native document-search indexes are cached by PDF size/modification identity. Wider performance/perception audit remains. |
| 38 | Accessibility and high-DPI support | REVIEW REQUIRED | Batch 1 raises typography and adds keyboard-focus visuals, but the full scaling/accessibility matrix is not yet tested. |
| 39 | Create a tasteful first-launch experience | REVIEW REQUIRED | |
| 40 | Build a proper About and diagnostics section | REVIEW REQUIRED | |
| 41 | Plan a proper application update mechanism | REVIEW REQUIRED | |
| 42 | Establish one coherent application architecture | IN PROGRESS | Home / Launcher, true multi-document Document Workspace and a Task Center backed by a real queue are connected. Shared output routing, isolated renderer-dependent background execution and native active-document search are now established. Remaining systems include Bookmarks/Outline, Settings, richer Inspector/Doctor, themes and split view. |
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 full Windows release gate passed end to end. Redesign iterations have been repeatedly Windows compiled/smoke-tested. Background queue job `97232413507`, Merge/Office expansion job `97232877751`, isolated OCR/export job `97233635107`, and native document-search job `97236130041` all passed staged integration, exact .NET 10.0.202 x64 Release compilation, smoke tests and validated source commit. Full installer/installed-copy gate must be rerun for a release candidate. |
| 44 | Make the entire interface context-aware | IN PROGRESS | Home, Document and Task Center modes differ genuinely. Tab switching restores document-specific state, background jobs no longer disable unrelated workspace navigation, and document search always targets the active PDF/working layout and resets when document context changes. Full command-by-command recalculation audit remains. |
| 45 | Recent files must support multiple layouts with real PDF thumbnails | IMPLEMENTED, NOT ACCEPTED | `RecentFilesView` provides cached asynchronous first-page PDFium thumbnails, Grid/List/Compact layouts with persisted preference, sorting, metadata, search, pinning + Starred, graceful moved-file handling, context actions and stored page/zoom resume. Windows compile/smoke validation passed; hands-on visual/use acceptance remains. |
