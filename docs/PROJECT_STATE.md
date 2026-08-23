# AsantePDF Project State

Updated after the background Task Center queue expanded to six Windows-validated production workflows.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design. The full RC10 Windows release pipeline reached green on GitHub Actions run `32636807149`, including exact SDK selection, Windows x64 compilation, smoke tests, self-contained publish, bundled qpdf/Tesseract/LibreOffice validation, final-candidate tests, Inno Setup compilation, silent installation and installed-copy verification.

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development

Branch: `development/master-upgrade-v2`

Draft PR: `#3` — **AsantePDF master upgrade implementation**

Development uses the normalized ordinary `src/`, `tests/`, `assets/`, `installer/` and `scripts/` tree.

## Current product architecture

### Home / Launcher

Home is a genuine mode with Open PDF, standalone tool entry points, Recent/Starred navigation, asynchronous cached first-page thumbnails, Grid/List/Compact layouts, sorting, search, pinning, moved-file handling, context actions and Resume Last Session.

### Multi-document Document Workspace

The workspace has real simultaneous tabs with independent page layout, saved baseline, selection, zoom, scroll and Undo/Redo. Tabs support active/dirty state, close buttons, drag reordering, middle-click close, scrollable overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T reopen. The proven PDFium renderer is transactionally reused on tab activation.

### Session persistence

`workspace-state.json` stores open tabs, active-tab index, page, zoom/render width, scroll position, Recent history and pin state. Resume Last Session restores all available saved tabs and returns to the saved active tab. Crash recovery and unsaved working-layout recovery remain.

### Task System / Task Center

Two execution paths now share the same Task Center:

1. foreground operations tracked through `RunBusyAsync`
2. independent queued jobs backed by the core `PdfJobQueue`

Task Center currently supports Running, Queued, Completed, Failed and Cancelled states, progress/stage updates, elapsed time, Cancel, Open Result, clear-finished history and single-use Retry for retry-safe jobs.

The core queue is single-worker and smoke-tested for genuine serialization, pre-queued jobs and queued cancellation. Users can continue working in other tabs while supported background jobs execute.

Current background-capable production workflows:

- Compress
- Repair
- Optimize for Web
- Unlock / Remove Password
- Merge PDFs
- Office → PDF

Active-document jobs capture immutable page order/rotation state at queue time. Dirty layouts are materialized into isolated temporary PDFs and cleaned afterward, so later tab edits cannot change queued input. Unlock remains deliberately non-retryable because retaining its password for Retry would extend credential lifetime in memory.

Merge and Office → PDF use captured input file paths and are independent of the active document renderer.

### Result routing

A shared completion workflow distinguishes original and result and supports Open in New Tab, safe Use Result Here, Open Folder, Save a Copy, Run Another and Close for the initial foreground set. Background outputs remain non-modal and reopen through Task Center.

Task Center output handling currently works naturally for PDF outputs. Before PDF-to-Word/Excel/PowerPoint are migrated to background execution, output opening must be generalized so non-PDF results launch in their associated Windows application rather than being sent to `OpenPdfAsync`.

## Windows validation

Important green development gates include:

- Architecture Batch 1: `32647383215`
- Recent/session foundation: `32648130725`
- Starred/Resume: `32648422410`
- rolling architecture gate: `32649073796`
- multi-tab session job: `97221651603`
- result-completion job: `97222420243`
- first background queue job: `97232413507`
- Merge/Office queue expansion job: `97232877751`

Job `97232877751` passed staged integration, exact .NET `10.0.202`, Windows x64 Release compilation, core smoke tests and validated source commit.

These are development gates, not the final installer/installed-copy acceptance gate.

## Immediate next work

1. generalize Task Center output opening for non-PDF results
2. build renderer-isolated background OCR with real `Recognising page X of N` progress
3. migrate PDF → Word/Excel/PowerPoint onto that isolated OCR pipeline
4. expand completion/result routing to split and remaining PDF-producing operations
5. continue the full context-aware command audit
6. implement real document search and bookmarks
7. enrich Inspector and PDF Doctor states
8. implement Light / Follow Windows themes and Settings
9. visually inspect the running Windows UI against the canonical target screens

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

- commit implementation to the development branch
- Windows-compile and run core tests for risky cross-file changes
- commit validated generated changes back to the branch
- update `IMPLEMENTATION_MATRIX.md`
- update this project-state file when the architectural handoff materially changes
- visually inspect affected UI requirements before acceptance
- run the heavyweight installer/installed-copy gate only at release-candidate checkpoints

## Final-release rule

Do not promote RC10 directly to AsantePDF 1.0 final. A future final release requires the material master-spec items to be accepted and the redesigned installed application to survive the full Windows release gate again.
