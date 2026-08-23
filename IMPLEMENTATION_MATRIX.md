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
| 1 | Rename and fully rebrand PDF Rescue as AsantePDF | REVIEW REQUIRED | |
| 2 | Redesign the Windows installer | REVIEW REQUIRED | |
| 3 | Replace the current empty screen with a proper Home experience | REVIEW REQUIRED | |
| 4 | Add proper session persistence | REVIEW REQUIRED | |
| 5 | Implement a real multi-document tab system | REVIEW REQUIRED | |
| 6 | Add split-view PDF comparison | REVIEW REQUIRED | |
| 7 | Redesign the entire command toolbar/ribbon | REVIEW REQUIRED | |
| 8 | Add a coherent colour system and complete dark mode | REVIEW REQUIRED | |
| 9 | Upgrade PDF page navigation | REVIEW REQUIRED | |
| 10 | Upgrade zoom and document viewing | REVIEW REQUIRED | |
| 11 | Make PDF text genuinely interactive | REVIEW REQUIRED | |
| 12 | Add first-class document search | REVIEW REQUIRED | |
| 13 | Upgrade the left navigation sidebar | REVIEW REQUIRED | |
| 14 | Implement proper multi-page selection and page management | REVIEW REQUIRED | |
| 15 | Make tools usable even when no PDF is already open | REVIEW REQUIRED | |
| 16 | Create proper configuration dialogs for every significant operation | REVIEW REQUIRED | |
| 17 | Create an application-wide task/progress framework | REVIEW REQUIRED | |
| 18 | Add a Task Center | REVIEW REQUIRED | |
| 19 | Create proper completion workflows | REVIEW REQUIRED | |
| 20 | Default to non-destructive processing | REVIEW REQUIRED | |
| 21 | Redesign PDF Doctor | REVIEW REQUIRED | |
| 22 | Redesign the Inspector | REVIEW REQUIRED | |
| 23 | Build a proper annotation system | REVIEW REQUIRED | |
| 24 | Implement proper Save behaviour | REVIEW REQUIRED | |
| 25 | Strengthen Undo/Redo | REVIEW REQUIRED | |
| 26 | Add proper drag-and-drop support | REVIEW REQUIRED | |
| 27 | Add robust context menus | REVIEW REQUIRED | |
| 28 | Create a coherent keyboard shortcut system | REVIEW REQUIRED | |
| 29 | Add proper printing | REVIEW REQUIRED | |
| 30 | Improve conversion workflows | REVIEW REQUIRED | |
| 31 | Strengthen OCR as a proper feature | REVIEW REQUIRED | |
| 32 | Add batch processing | REVIEW REQUIRED | |
| 33 | Build proper PDF security workflows | REVIEW REQUIRED | |
| 34 | Recent-files privacy controls | REVIEW REQUIRED | |
| 35 | Create a real Settings experience | REVIEW REQUIRED | |
| 36 | Professional error and recovery UX | REVIEW REQUIRED | |
| 37 | Improve performance perception | REVIEW REQUIRED | |
| 38 | Accessibility and high-DPI support | REVIEW REQUIRED | |
| 39 | Create a tasteful first-launch experience | REVIEW REQUIRED | |
| 40 | Build a proper About and diagnostics section | REVIEW REQUIRED | |
| 41 | Plan a proper application update mechanism | REVIEW REQUIRED | |
| 42 | Establish one coherent application architecture | REVIEW REQUIRED | |
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 Windows gate passed end to end; must be rerun after the master upgrade batch. |
| 44 | Make the entire interface context-aware | REVIEW REQUIRED | |
| 45 | Recent files must support multiple layouts with real PDF thumbnails | REVIEW REQUIRED | |
