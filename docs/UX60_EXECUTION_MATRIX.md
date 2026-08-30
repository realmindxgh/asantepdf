# AsantePDF UX60 Execution Matrix

## Status rule

This matrix tracks the 60-item UX guide against the normalized development source. `IMPLEMENTED IN SOURCE` means the behaviour has concrete source support on `development/ux-60-execution`. It does **not** mean Windows acceptance has passed. Acceptance remains separate under the repository's RC49 stabilization rules.

| # | UX improvement | Source status | Primary evidence |
|---:|---|---|---|
| 1 | Global operation/progress system | IMPLEMENTED IN SOURCE | `MainWindow.Ux60.cs`, `TaskCenterService.cs` global activity chip and task state model |
| 2 | Per-button busy states | IMPLEMENTED IN SOURCE | `MainWindow.Ux60.cs` maps initiating buttons to live tasks and blocks repeat mouse invocation |
| 3 | Prominent background-task notifications | IMPLEMENTED IN SOURCE | `MainWindow.Ux60.cs` transient start/completion/failure toasts with Task Center action |
| 4 | Task Center badge | IMPLEMENTED IN SOURCE | Existing nav badge plus UX60 active/failed state treatment |
| 5 | Proper Task Center task cards | IMPLEMENTED IN SOURCE | `TaskCenterView.xaml`, `TaskCenterView.xaml.cs` source, stage, progress, elapsed, output, folder, retry, cancel and error details |
| 6 | Honest indeterminate progress | IMPLEMENTED IN SOURCE | `TaskCenterItem.IsIndeterminate` and `ProgressLabel`; Task Center and global chip bind to it |
| 7 | Immediate document-opening feedback | IMPLEMENTED IN SOURCE | UX60 opening overlay with skeleton, stage text and first-page handoff |
| 8 | Progressive thumbnail rendering | IMPLEMENTED IN SOURCE | Existing incremental renderer plus UX60 selected-page and surrounding-page priority rendering |
| 9 | Search feedback | IMPLEMENTED IN SOURCE | `MainWindow.Search.cs` Searching state, counts, highlights, Enter/Shift+Enter and Escape |
| 10 | Unsaved-change visibility | IMPLEMENTED IN SOURCE | `MainWindow.DocumentTabs.cs` dirty state and Save/Don't Save/Cancel close flow |
| 11 | Better save acknowledgement | IMPLEMENTED IN SOURCE | initiating-button busy state, completion toast and `Saved · HH:mm` status |
| 12 | Autosave/recovery | IMPLEMENTED IN SOURCE | existing recovery snapshots and startup restore in `MainWindow.Lifecycle.cs` |
| 13 | Navigation-state correction | IMPLEMENTED IN SOURCE | product-shell navigation follows Home vs Active Document state |
| 14 | Navigation/actions distinction | IMPLEMENTED IN SOURCE | grouped DESTINATION / WORKSPACE / STORAGE shell plus separate command ribbon |
| 15 | Ribbon density reduction | IMPLEMENTED IN SOURCE | existing File, History, Pages, Edit & Annotate and Convert group containers |
| 16 | Adaptive ribbon | IMPLEMENTED IN SOURCE | UX60 keeps primary groups and collapses lower-priority groups behind `More` on narrow windows |
| 17 | Context-sensitive controls | IMPLEMENTED IN SOURCE | existing `UpdateCommandStates` disables unavailable commands |
| 18 | Richer hover tooltips | IMPLEMENTED IN SOURCE | UX60 fills missing button tooltips and appends known shortcuts |
| 19 | Keyboard shortcut discovery | IMPLEMENTED IN SOURCE | existing gesture labels plus UX60 tooltip hints and command palette |
| 20 | Command palette | IMPLEMENTED IN SOURCE | Ctrl+K command/destination palette in `MainWindow.Ux60.cs` |
| 21 | Right-click context menus | IMPLEMENTED IN SOURCE | existing page/tab menus plus UX60 move, insert-copy, copy, properties, Close All and Copy Path additions |
| 22 | Drag-and-drop page management | IMPLEMENTED IN SOURCE | existing reorder logic plus UX60 visible insertion cue |
| 23 | Multi-page selection | IMPLEMENTED IN SOURCE | `PagesList SelectionMode=Extended` and bulk rotate/delete/extract/duplicate logic |
| 24 | Sidebar resizing | IMPLEMENTED IN SOURCE | existing GridSplitters plus UX60 hover/cursor affordance |
| 25 | Remember panel sizes | IMPLEMENTED IN SOURCE | new `AppPreferences` panel widths/collapse state and UX60 load/save |
| 26 | Quick collapse controls | IMPLEMENTED IN SOURCE | existing left/right collapse/expand controls, keyboard-focusable buttons |
| 27 | Focus/reading mode | IMPLEMENTED IN SOURCE | F11 and Ctrl+Shift+F hide app nav, ribbon, thumbnails and Inspector |
| 28 | Better zoom interaction | IMPLEMENTED IN SOURCE | existing editable zoom/presets/per-tab zoom plus UX60 Ctrl+mouse-wheel zoom |
| 29 | Fit Width / Fit Page state | IMPLEMENTED IN SOURCE | UX60 active fit-button treatment and reset on manual zoom |
| 30 | Page number jump | IMPLEMENTED IN SOURCE | existing editable page box and Enter navigation |
| 31 | Document status strip | IMPLEMENTED IN SOURCE | existing status/page/zoom/local strip plus UX60 file size, PDF version and drag handle |
| 32 | Status bar as secondary feedback | IMPLEMENTED IN SOURCE | UX60 primary chip/toast layer above existing secondary status strip |
| 33 | Success feedback | IMPLEMENTED IN SOURCE | completion toasts, result workflow, Task Center result/folder actions |
| 34 | Actionable errors | IMPLEMENTED IN SOURCE | existing guarded error dialog plus failure toast, retry and copyable Task Center error details |
| 35 | PDF Doctor progress | IMPLEMENTED IN SOURCE | UX60 Inspector analysis state and inline determinate/indeterminate progress |
| 36 | Doctor severity summary | IMPLEMENTED IN SOURCE | existing health status plus UX60 issue/severity count summary |
| 37 | First-use micro-onboarding | IMPLEMENTED IN SOURCE | existing `FirstLaunchWindow`/lifecycle onboarding; UX60 exposes Ctrl+K in tooltips/palette |
| 38 | Empty-state improvement | IMPLEMENTED IN SOURCE | existing deliberate Home/Recent/Starred/Task Center empty states |
| 39 | Recent-document context | IMPLEMENTED IN SOURCE | `RecentDocumentService` and recent view track name, time, location, pages, pin state, file metadata and actions |
| 40 | Drag PDF anywhere to open | IMPLEMENTED IN SOURCE | window-wide drag/drop plus UX60 large drop overlay |
| 41 | Multiple-file opening | IMPLEMENTED IN SOURCE | UX60 multi-select Open and multi-PDF drop open each PDF as a tab |
| 42 | Tab improvements | IMPLEMENTED IN SOURCE | existing dirty marker, path tooltip, middle-close, drag reorder, context menu and scrolling overflow |
| 43 | Close-tab behaviour during jobs | IMPLEMENTED IN SOURCE | independent background tasks continue; UX60 explicitly tells the user when a closed tab still has live work |
| 44 | Background-operation resilience | IMPLEMENTED IN SOURCE | `BackgroundTaskQueueService` jobs are app-level and survive document switching |
| 45 | Cancel long operations | IMPLEMENTED IN SOURCE | foreground CTS and per-task cancellation where technically safe |
| 46 | Retry failed operations | IMPLEMENTED IN SOURCE | Task Center retry delegates and retry button |
| 47 | Completion history | IMPLEMENTED IN SOURCE | Task Center retains finished jobs for the session until Clear Finished |
| 48 | Output destination clarity | IMPLEMENTED IN SOURCE | result workflow plus Task Center output name/path and Show Folder |
| 49 | Accessibility pass | IMPLEMENTED IN SOURCE | existing accessibility metadata plus UX60 automation names, keyboard access, resize affordances and tooltip help; Windows scaling/contrast remain acceptance tests |
| 50 | Reduce tiny text | IMPLEMENTED IN SOURCE | UX60 raises sub-12 non-glyph UI text to a 12px floor at runtime |
| 51 | Better selection feedback | IMPLEMENTED IN SOURCE | existing selected page/annotation states plus UX60 active Fit state and focused command states |
| 52 | Annotation-mode Escape | IMPLEMENTED IN SOURCE | UX60 class key handler ends active markup mode on Escape |
| 53 | Dangerous-action confirmation | IMPLEMENTED IN SOURCE | permanent redaction already confirms; destructive exports are non-destructive; page deletion is immediately undoable |
| 54 | Undo/redo history clarity | IMPLEMENTED IN SOURCE | UX60 named history tooltips and right-click multi-step history menus |
| 55 | Recover accidental page deletion | IMPLEMENTED IN SOURCE | page deletion records undo state before removal; UX60 toast points to Ctrl+Z |
| 56 | Network/offline communication | IMPLEMENTED IN SOURCE | existing Processed locally status and Local-first privacy card |
| 57 | Dismissible Local-first card | IMPLEMENTED IN SOURCE | UX60 dismiss button with persisted preference |
| 58 | First-run vs everyday UI | IMPLEMENTED IN SOURCE | one-time onboarding plus dismissible privacy explanation |
| 59 | Explorer integration | IMPLEMENTED IN SOURCE | existing Open With registration/Show in Folder plus UX60 Copy Path, drag current file out and Recent PDFs Windows jump list |
| 60 | Window title information | IMPLEMENTED IN SOURCE | UX60 updates title to `<document> · AsantePDF` for the active tab |

## UX60 source additions

- `src/PdfRescue.App/MainWindow.Ux60.cs`
- `src/PdfRescue.App/MainWindow.Ux60.PageMenus.cs`
- `src/PdfRescue.App/Services/AppSettingsService.cs`
- `src/PdfRescue.App/Services/TaskCenterService.cs`
- `src/PdfRescue.App/TaskCenterView.xaml`
- `src/PdfRescue.App/TaskCenterView.xaml.cs`
- `.github/workflows/ux60-pr-gate.yml`

## Acceptance still required

The source pass does not replace hands-on Windows acceptance. Before any UX60 item is promoted to accepted, run the exact candidate on Windows in Light and Dark, exercise real PDFs and repeated open/close cycles, verify 100/125/150/175/200% scaling and high-contrast behaviour, inspect Task Center foreground/background transitions, and verify the exact installed Program Files copy under the repository's final release gate.
