# AsantePDF Project State

Updated after the multi-document, Task Center and result-completion architecture reached green Windows development gates.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design.

The full RC10 Windows release pipeline reached green on GitHub Actions run `32636807149`. That release path demonstrated:

- exact .NET SDK selection and Windows x64 compilation
- automated smoke tests
- self-contained Windows x64 publish
- staging and validation of qpdf, Tesseract OCR and LibreOffice
- published-app final candidate self-test
- production Inno Setup compilation
- silent installation of the exact generated `AsantePDF Setup.exe`
- installed Program Files copy verification
- release receipt, checksums and evidence generation

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development branch

Development branch: `development/master-upgrade-v2`

Draft PR: `#3` — **AsantePDF master upgrade implementation**

The source tree is normalized and ordinary. Development now happens directly in `src/`, `tests/`, `assets/`, `installer/` and `scripts/` rather than through the old compact release carrier.

## Product architecture implemented so far

### Home / Launcher

- real Home mode rather than a blank PDF canvas
- Open PDF and standalone tool entry points
- Recent and Starred navigation
- real asynchronous cached PDF thumbnails
- Grid, List and Compact Recent layouts
- sorting, search, pinning and moved-file handling
- right-click Recent actions
- Resume Last Session entry point

### Multi-document Document Workspace

- real simultaneous document tabs backed by per-document state
- active/dirty state and close buttons
- tab drag reordering and middle-click close
- scrollable tab overflow
- Ctrl+Tab, Ctrl+W and Ctrl+Shift+T reopen
- independent page layout, saved baseline, selected page, zoom, scroll and Undo/Redo per tab
- transactional reuse of the proven single PDFium renderer when tabs switch
- unsaved-close protection per tab
- successful operation outputs can open as new tabs for the initial completion-workflow set

### Session persistence

`workspace-state.json` now stores:

- open tab set
- active-tab index
- per-document page
- zoom/render width
- horizontal and vertical scroll position
- Recent history and pin state

Resume Last Session restores all available saved tabs and returns to the saved active tab. Writes are debounced. Crash recovery and unsaved working-layout recovery remain future work.

### Task System / Task Center

- `TaskCenterService` wraps the central busy-operation path
- Running, Queued, Completed, Failed and Cancelled states
- determinate progress where page/item progress exists
- stage/status text
- elapsed time
- active-task cancellation
- finished-history clearing
- dedicated Task Center UI and navigation
- completed tasks can retain a PDF output path and expose Open Result

True independent queued/background execution and Retry are the next Task System layer.

### Result / completion workflow

A shared `OperationResultDialog` / completion controller now distinguishes original and result files and supports:

- Open in New Tab
- safe Use Result Here
- Open Folder
- Save a Copy
- Run Another
- Close

Initially wired and Windows-validated for:

- Compress
- Repair
- Web Optimization
- Unlock / Remove Password

The same pattern still needs expansion across the rest of the PDF-producing tools.

## Windows development validation

Important green development gates include:

- Architecture Batch 1: run `32647383215`
- Recent/session foundation: run `32648130725`
- Starred/Resume integration: run `32648422410`
- Task Center and later architecture iterations: run `32649073796`
- multi-tab session restoration successful job: `97221651603`
- result-completion routing successful job: `97222420243`

The result-completion job passed staged patching, exact .NET `10.0.202`, Windows x64 Release compilation, core smoke tests and validated source commit.

These are development gates, not the final installer acceptance gate.

## Immediate next work

1. true queued/background Task Center execution that does not lock the document workspace
2. multiple queued jobs with cancellation and Retry
3. extend result-completion routing to remaining PDF-producing workflows
4. continue the full command/context-awareness audit
5. implement remaining Home/Document requirements including search, bookmarks, richer Inspector and Doctor states
6. theme/settings work including Light and Follow Windows
7. visual/runtime acceptance against the canonical Home and Document target screens

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
