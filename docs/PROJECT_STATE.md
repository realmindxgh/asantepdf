# AsantePDF Project State

Updated after the first true background-queue batch reached a green Windows development gate.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design.

The full RC10 Windows release pipeline reached green on GitHub Actions run `32636807149`. That release path demonstrated exact .NET SDK selection, Windows x64 compilation, smoke tests, self-contained publish, bundled-engine validation, final-candidate testing, production Inno Setup compilation, silent installation and installed-copy verification.

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development branch

Development branch: `development/master-upgrade-v2`

Draft PR: `#3` — **AsantePDF master upgrade implementation**

The repository contains the normalized ordinary source tree. Development happens directly in `src/`, `tests/`, `assets/`, `installer/` and `scripts/`.

## Product architecture implemented so far

### Home / Launcher

- real Home mode rather than a blank PDF canvas
- Open PDF and standalone tool entry points
- Recent and Starred navigation
- asynchronous cached first-page PDF thumbnails
- Grid, List and Compact Recent layouts
- sorting, search, pinning and moved-file handling
- right-click Recent actions
- Resume Last Session

### Multi-document Document Workspace

- real simultaneous document tabs with per-document state
- active/dirty state and close buttons
- drag reordering, middle-click close and scrollable overflow
- Ctrl+Tab, Ctrl+W and Ctrl+Shift+T reopen
- independent page layout, saved baseline, selected page, zoom, scroll and Undo/Redo per tab
- transactional reuse of the proven PDFium renderer on tab activation
- unsaved-close protection per tab
- successful operation results can open directly as new tabs for the initial completion-workflow set

### Session persistence

`workspace-state.json` stores the open tab set, active-tab index, page, zoom/render width, scroll position, Recent history and pin state. Resume Last Session restores all available saved tabs and returns to the saved active tab. Writes are debounced.

Crash recovery and unsaved working-layout recovery remain future work.

### Task System / Task Center

The Task System now has two connected execution paths:

1. foreground operations tracked through the central `RunBusyAsync` path
2. a true background queue backed by the core `PdfJobQueue`

Current Task Center capabilities:

- Running, Queued, Completed, Failed and Cancelled states
- determinate progress/stage updates where provided
- elapsed time
- graceful Cancel
- finished-history clearing
- Open Result for successful PDF outputs
- Retry for retry-safe failed/cancelled background jobs
- multiple real queued jobs through a single worker
- queued cancellation
- continued use of other document tabs while supported jobs run

The first background-capable operations are:

- Compress
- Repair
- Optimize for Web
- Unlock / Remove Password

For active-document transformations, the job captures the source path plus current page order/rotations at queue time. Dirty layouts are materialized into isolated temporary PDFs inside the background job and cleaned afterward. The active renderer and later tab changes therefore do not mutate the queued job's input.

Unlock is intentionally non-retryable because retaining its password in a retry delegate would extend credential lifetime in memory.

### Result / completion workflow

A shared result workflow distinguishes original and result files and supports Open in New Tab, safe Use Result Here, Open Folder, Save a Copy, Run Another and Close.

Initially wired and Windows-validated for Compress, Repair, Web Optimization and Unlock. Background completions do not interrupt the user with a modal; their results remain available through Task Center.

## Queue engineering validation

The core queue now explicitly accepts jobs that have already been registered as `Queued`, allowing the UI to display real queued state before execution begins.

The smoke suite now verifies:

- normal single-job execution
- pre-queued job execution
- serial execution of multiple jobs
- a second job remaining Queued while the worker is occupied
- cancellation while queued transitioning to Cancelled

Background-queue Windows job `97232413507` passed:

- staged source integration
- exact .NET `10.0.202`
- Windows x64 Release compilation
- the expanded core smoke suite
- validated generated-source commit

## Other important green development gates

- Architecture Batch 1: run `32647383215`
- Recent/session foundation: run `32648130725`
- Starred/Resume integration: run `32648422410`
- later architecture iterations: run `32649073796`
- multi-tab session restoration job: `97221651603`
- result-completion routing job: `97222420243`
- background queue job: `97232413507`

These are development gates, not the final installer acceptance gate.

## Immediate next work

1. migrate more independent operations onto the same background queue, especially Merge and Office-to-PDF
2. extend completion/result routing to remaining PDF-producing workflows
3. migrate OCR/conversion carefully with page/item progress reporting
4. continue the full command/context-awareness audit
5. implement real document search and bookmarks
6. enrich Inspector and PDF Doctor states
7. theme/settings work including Light and Follow Windows
8. visual/runtime acceptance against the canonical Home and Document target screens

## Product source of truth

Future work is governed by:

1. `../ASANTEPDF_MASTER_UPGRADE_SPEC.md`
2. `../IMPLEMENTATION_MATRIX.md`
3. `ASANTEPDF-VISUAL-DIRECTION.md`
4. `design/target-home.svg`
5. `design/target-document-workspace.svg`
6. `../AGENTS.md`

The master specification contains **45 numbered requirements**. `IMPLEMENTATION_MATRIX.md` is the acceptance ledger. Do not upgrade a row to `ACCEPTED` merely because related code exists.

## Engineering cadence

For every coherent batch:

- commit implementation to the development branch
- Windows-compile and run core tests for risky cross-file changes
- commit validated generated changes back to the branch
- update `IMPLEMENTATION_MATRIX.md`
- update this project-state file when the architectural handoff meaningfully changes
- visually inspect affected UI requirements before acceptance
- run the heavyweight installer/installed-copy gate only at release-candidate checkpoints

## Final-release rule

Do not promote RC10 directly to AsantePDF 1.0 final. A future final release requires the material master-spec items to be accepted and the redesigned installed application to survive the full Windows release gate again.
