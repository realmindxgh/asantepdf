# AsantePDF Project State

Updated after renderer-isolated OCR and PDF export workflows reached a green Windows development gate.

## Engineering baseline

RC10 remains the proven release-engineering baseline, not the finished product design. Full RC10 Windows release run `32636807149` proved x64 compilation, smoke tests, self-contained publish, qpdf/Tesseract/LibreOffice staging, final-candidate tests, Inno Setup compilation, silent installation and installed-copy verification.

RC10 installer SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## Active development

Branch: `development/master-upgrade-v2`

Draft PR: `#3` — **AsantePDF master upgrade implementation**

The normalized ordinary source tree is the working codebase.

## Current product architecture

### Home / Launcher

Real Home mode with Open PDF, standalone tools, Recent/Starred, cached PDF thumbnails, Grid/List/Compact layouts, sorting, search, pinning, moved-file handling, context actions and Resume Last Session.

### Multi-document Document Workspace

Real tabs preserve independent page layout, baseline, selected page, zoom, scroll and Undo/Redo. Tabs support active/dirty state, close, drag reorder, middle-click close, overflow, Ctrl+Tab, Ctrl+W and Ctrl+Shift+T. The proven PDFium renderer is transactionally reused when the active tab changes.

### Session persistence

`workspace-state.json` stores the open tab set, active tab, page, zoom, scroll, Recent history and pin state. Resume restores all available tabs and the saved active tab. Crash recovery and unsaved working-layout recovery remain.

### Task System / Task Center

Foreground `RunBusyAsync` work and a real background queue feed the same Task Center. The queue is backed by the core `PdfJobQueue`, is single-worker, and is smoke-tested for pre-queued jobs, serialization and cancellation while queued.

Task Center supports Running, Queued, Completed, Failed and Cancelled states, progress/stage updates, elapsed time, Cancel, Open Result, clear-finished history and single-use Retry for retry-safe jobs.

Current background-capable production workflows:

- Compress
- Repair
- Optimize for Web
- Unlock / Remove Password
- Merge PDFs
- Office → PDF
- PDF → Word
- PDF → Excel
- PDF → PowerPoint
- searchable OCR PDF
- OCR text extraction

### Renderer-isolated OCR / conversion

Renderer-dependent queued work captures the active document path and page layout at queue time. Dirty layouts are first materialized into an isolated temporary PDF. The job then creates its **own PDFium renderer**, so later tab changes and the live preview renderer cannot alter the queued input.

Word and Excel exports run local OCR page by page. Searchable OCR PDF and OCR text extraction do the same. PowerPoint uses isolated page rendering. Installed builds prefer bundled Tesseract for background OCR when available, with the existing local Windows OCR path retained as fallback.

Page-level progress is reported in Task Center, including stages such as `Recognising page 18 of 64`.

### Result routing

Task outputs are type-aware:

- `.pdf` opens as an AsantePDF tab
- `.docx`, `.xlsx`, `.pptx`, `.txt` and other non-PDF files are launched through their associated Windows application

The existing foreground completion dialog remains for the initial PDF transformations. Background results are deliberately non-modal and remain available from Task Center.

## Windows validation

Important green development gates include:

- Architecture Batch 1: `32647383215`
- Recent/session foundation: `32648130725`
- Starred/Resume: `32648422410`
- rolling architecture run: `32649073796`
- multi-tab session job: `97221651603`
- result-completion job: `97222420243`
- background queue job: `97232413507`
- Merge/Office queue expansion: `97232877751`
- renderer-isolated OCR/export: `97233635107`

Job `97233635107` passed staged integration, exact .NET `10.0.202`, Windows x64 Release compilation, core smoke tests and validated source commit.

These are development gates, not the final installer acceptance gate.

## Immediate next work

1. implement real document search instead of the current disabled placeholder
2. implement Bookmarks navigation
3. expand split/multi-output completion workflows
4. continue the context-aware command audit
5. enrich Inspector and PDF Doctor states
6. implement Light / Follow Windows themes and a real Settings experience
7. add first-launch/privacy/recovery polish
8. visually inspect the running Windows app against the canonical Home and Document target screens

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

Do not promote RC10 directly to AsantePDF 1.0 final. A future final release requires material master-spec items to be accepted and the redesigned installed application to survive the full Windows release gate again.
