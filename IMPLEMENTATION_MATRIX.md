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
| 3 | Replace the current empty screen with a proper Home experience | IN PROGRESS | Architecture Batch 1 adds a real Home overlay with Open PDF, Quick Tools, Recent search/list, local-first messaging and explicit unavailable states. Thumbnails, richer Recent layouts and session resume remain. |
| 4 | Add proper session persistence | REVIEW REQUIRED | Resume Last Session is visibly unavailable rather than a dead control until persistence is implemented. |
| 5 | Implement a real multi-document tab system | REVIEW REQUIRED | Batch 1 establishes the tab visual shell only. A real per-document model is not implemented yet. |
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
| 17 | Create an application-wide task/progress framework | REVIEW REQUIRED | Existing RC10 progress/cancel infrastructure is preserved but not yet audited against the full requirement. |
| 18 | Add a Task Center | REVIEW REQUIRED | Task Center navigation is deliberately disabled with tooltip until the architecture exists. |
| 19 | Create proper completion workflows | REVIEW REQUIRED | |
| 20 | Default to non-destructive processing | REVIEW REQUIRED | RC10 has strong non-destructive behavior, but the full requirement still needs an operation-by-operation audit. |
| 21 | Redesign PDF Doctor | IN PROGRESS | Batch 1 fixes the false initial state: Doctor now starts as “Not analysed yet” with Run PDF Doctor and no fake recommendations. Rich findings/recommendation UX remains. |
| 22 | Redesign the Inspector | IN PROGRESS | Batch 1 provides a contextual document-details/Doctor shell. Selection-specific page/text/annotation/object modes remain. |
| 23 | Build a proper annotation system | REVIEW REQUIRED | |
| 24 | Implement proper Save behaviour | REVIEW REQUIRED | RC10 unsaved-layout protection exists, but the multi-document save contract is not yet implemented. |
| 25 | Strengthen Undo/Redo | REVIEW REQUIRED | |
| 26 | Add proper drag-and-drop support | REVIEW REQUIRED | Existing PDF/window/page drag-drop behavior is preserved; full master item audit remains. |
| 27 | Add robust context menus | REVIEW REQUIRED | |
| 28 | Create a coherent keyboard shortcut system | REVIEW REQUIRED | |
| 29 | Add proper printing | REVIEW REQUIRED | |
| 30 | Improve conversion workflows | REVIEW REQUIRED | |
| 31 | Strengthen OCR as a proper feature | REVIEW REQUIRED | |
| 32 | Add batch processing | REVIEW REQUIRED | |
| 33 | Build proper PDF security workflows | REVIEW REQUIRED | |
| 34 | Recent-files privacy controls | REVIEW REQUIRED | |
| 35 | Create a real Settings experience | REVIEW REQUIRED | Settings is deliberately shown unavailable in Batch 1 rather than leading to a dead action. |
| 36 | Professional error and recovery UX | REVIEW REQUIRED | |
| 37 | Improve performance perception | REVIEW REQUIRED | |
| 38 | Accessibility and high-DPI support | REVIEW REQUIRED | Batch 1 raises typography and adds keyboard-focus visuals, but the full scaling/accessibility matrix is not yet tested. |
| 39 | Create a tasteful first-launch experience | REVIEW REQUIRED | |
| 40 | Build a proper About and diagnostics section | REVIEW REQUIRED | |
| 41 | Plan a proper application update mechanism | REVIEW REQUIRED | |
| 42 | Establish one coherent application architecture | IN PROGRESS | Architecture Batch 1 establishes distinct Home and Document workspace modes and preserves a dedicated future Task System entry point. The underlying multi-document/task models remain. |
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 full Windows release gate passed end to end. Architecture Batch 1 also passed Windows x64 compile and core smoke tests in run 32647383215; full installer/installed-copy gate must be rerun for a release candidate. |
| 44 | Make the entire interface context-aware | IN PROGRESS | Home and Document modes now differ genuinely. Existing command-state logic is reused for document commands; unsupported future commands are visibly disabled with tooltips. Full command-by-command audit and future tab switching remain. |
| 45 | Recent files must support multiple layouts with real PDF thumbnails | IN PROGRESS | Home now loads/searches recent files and identifies moved/missing entries gracefully. Real cached PDF thumbnails, Grid/List/Compact modes, persisted view preference, sorting, pinning and context actions remain. |
