# AsantePDF Project State

Updated after hands-on RC49 Windows acceptance invalidated the previous candidate and triggered the exhaustive stabilization plan in `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md`.

## Current product state

- Branch: `development/master-upgrade-v2`
- Draft PR: `#3` — **AsantePDF master upgrade implementation**
- Candidate version: `1.0.0-rc49`
- Exact SDK: `.NET 10.0.202`
- Master requirements implemented in source audit: **49 / 49**
- Master requirements formally accepted: **0 / 49**
- Current release posture: **candidate failed hands-on acceptance; stabilization in progress**

The old statement “implementation is complete and only routine acceptance remains” is no longer sufficient. Hands-on testing exposed architectural theme inconsistency and a real PDF-open reliability failure. The immediate controlling document is now `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md`.

Do not call AsantePDF 1.0 finished merely because CI is green. Do not promote stable `1.0.0` until the stabilization plan, installed-build gate and hands-on acceptance all agree.

## Failed acceptance evidence that reopened stabilization

The user tested the installed RC49 candidate on Windows and demonstrated multiple release blockers, including:

- Light mode with washed-out/near-invisible text and controls;
- Dark mode showing a dark title bar around a predominantly light body with theme-inappropriate text, proving mixed theme state;
- `Resume session`, Grid/List/Compact and related Recent controls becoming effectively invisible in one or more theme states;
- a real PDF-open attempt closing AsantePDF on the user’s machine;
- earlier visual defects such as clipped Welcome content, weak hover states, contrast problems, ribbon alignment/icon issues, maximize/taskbar behaviour and Task Center architecture problems.

Those screenshots are authoritative failed acceptance evidence. Source code that looks correct does not override the installed behaviour the user observed.

## Mandatory stabilization plan

Read and execute:

`docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md`

The controlling priority is:

**theme correctness → PDF opening stability → error containment → visual/layout audit → installed-build verification → remaining functionality**

The plan contains:

- the original fix plan preserved verbatim with no wording omitted;
- an expanded semantic-theme architecture specification;
- complete Recent Files visibility/legibility rules;
- atomic Light/Dark/Follow Windows switching requirements;
- a staged PDF-open pipeline;
- process-wide PDFium concurrency rules;
- secondary-subsystem failure containment;
- realistic PDF regression corpus requirements;
- repeated open/close/multi-tab stress scenarios;
- whole-shell screenshot and contrast evidence requirements;
- 100/125/150/175/200% DPI acceptance matrix;
- installed Program Files release-gate requirements;
- explicit manual acceptance criteria;
- repository/CI cleanup rules;
- a concrete next-installer checklist and stabilization definition of done.

## Current engineering stabilization direction

The active stabilization work replaces theme-history mutation with one semantic live palette. Ordinary UI surfaces must derive from semantic Light/Dark resources rather than remembering their previous colours.

The current direction also introduces/strengthens:

- `DynamicResource` use for semantic theme consumers;
- explicit Recent controls as theme canaries;
- runtime Light/Dark whole-shell verification;
- machine-readable contrast evidence and rendered screenshot artifacts;
- a process-global PDFium execution gate for direct native calls unless explicitly proven safe otherwise;
- staged foreground PDF opening before expensive secondary work;
- realistic multi-page PDF-open stress with Recent/thumbnails/session behaviour enabled;
- longer application survival checks after foreground and thumbnail completion;
- installed-copy repetition of those tests.

Recent Windows validation has already been useful because the expanded runtime gate itself caught defects that the old gate would not. This is the intended posture: tests should fail loudly before another weak installer reaches the user.

## Theme acceptance contract

Theme correctness means whole-shell consistency, not a themed title bar.

Required states include:

- startup Light;
- startup Dark;
- Follow Windows resolution;
- Light → Dark;
- Dark → Light;
- repeated Light → Dark → Light → Dark without restart;
- Recent created after startup;
- document workspace;
- Task Center;
- Settings;
- popups/context menus/dialogs;
- persisted theme after restart.

Controls that are technically visible but visually indistinguishable from their background are failed for acceptance purposes.

Recent Files must explicitly verify:

- Resume session;
- search;
- Last opened sort control and popup;
- Grid;
- List;
- Compact;
- selected mode state;
- filenames;
- metadata;
- thumbnails;
- pin/star state;
- empty state;
- context menu;
- card-lift hover behaviour.

## PDF-open reliability contract

The document-open path must be treated independently from theme work.

Target sequence:

`validate file → open PDFium document → render foreground page → show usable document → load expensive secondary services safely`

Foreground usability must not wait for every secondary subsystem.

Secondary failures such as thumbnails, outlines, annotation inventory, attachments or search/text extraction must degrade those features rather than kill AsantePDF.

Direct PDFium-native callers must obey the approved process-global execution gate unless a documented exception has proven concurrent safety.

The gate must use realistic multi-page PDFs and normal-user features such as Recent tracking and thumbnails. A one-page synthetic PDF with those features disabled is not sufficient release evidence.

## Product architecture present in source

The prior 49-item implementation work remains valuable and should not be discarded while stabilizing the shell.

### Home / Launcher

Home mode includes Recent, Starred, conditional Resume, Open PDF, standalone tools, cached PDFium thumbnails, Grid/List/Compact layouts, sorting/search/pinning, moved-file handling, context actions and drag/drop.

### Document Workspace

Multi-document tabs preserve page, zoom, scroll, working layout and Undo/Redo state. The source includes:

- Single Page, lazy Continuous and Two Page viewing;
- typed custom zoom, Fit Width, Fit Page and 1:1;
- native PDF text selection and copy;
- document search with snippets/highlights;
- Pages, Bookmarks, Search, Comments/Annotations and Attachments navigation;
- contextual Inspector;
- page management and drag reorder;
- native text markup, notes, shapes, freehand ink and annotation edit/delete;
- Save, Save As and Save a Copy contracts with multi-dirty-tab close handling;
- printing with page scope/orientation/fit controls;
- two-document split comparison with independent or linked scroll/zoom, swap and page alignment.

### Task System

Foreground and queued operations feed one Task Center model with Running/Queued/Completed/Failed/Cancelled states, progress, elapsed time, cancellation, retry and output actions.

### Settings / lifecycle

Settings exposes Light, Dark, Follow Windows, default zoom, default page view, session/recent/privacy controls, OCR default, output folder/naming, overwrite policy, recovery and update preferences.

One-time onboarding, abnormal-shutdown recovery, user-facing error details/log actions, About/Diagnostics, bundled-engine information and explicit user-controlled update download/install are implemented in source, but their UI-facing acceptance remains subject to stabilization.

### Identity

The product uses the restrained Ghana-inspired red/gold/green/black document/A identity in title-bar/vector assets and the Windows ICO used by the application and installer. Light/Dark compatibility still needs installed/manual acceptance.

## Previous release evidence is superseded for final acceptance

Earlier heavyweight Windows release gates proved that the packaging pipeline can:

- verify clean source;
- use the exact SDK;
- compile Release x64;
- stage qpdf, Tesseract and LibreOffice;
- publish self-contained Windows x64;
- build a production Inno Setup installer;
- silently install the exact installer;
- launch/test the Program Files copy;
- verify Windows registration and Start Menu integration;
- write release receipts/checksums;
- silently uninstall and verify cleanup;
- upload a release artifact.

That evidence remains useful for release engineering, but it does **not** prove the current candidate is acceptable because the user subsequently exposed real installed-product failures.

The next release evidence must use the expanded stabilization gate from the fix plan.

## Required evidence progression

For affected requirements distinguish these stages:

1. source implemented;
2. automated validation passed;
3. installed-build validation passed;
4. visual/manual acceptance passed;
5. accepted.

The repository may continue to use `IMPLEMENTED, NOT ACCEPTED` as the matrix state while notes record the intermediate validation evidence. Never skip directly from “compiled” to `ACCEPTED`.

## Immediate work order

1. finish semantic theme architecture stabilization;
2. make the whole-shell Light/Dark runtime probe compile and pass;
3. verify Recent controls explicitly in both themes;
4. complete PDFium concurrency/staged-open hardening;
5. add/verify failure containment for secondary PDF subsystems;
6. run realistic multi-page/repeated-open stress in Light and Dark;
7. retain runtime screenshots/contrast reports/logs;
8. promote only Windows-green source;
9. remove consumed `dev-patches` carriers;
10. run a clean no-patch Windows gate;
11. deliberately trigger the heavyweight installed-copy gate;
12. require the Program Files copy to pass the expanded theme and PDF-open scenarios;
13. give the user the GitHub Actions artifact link rather than attempting a very large ChatGPT attachment;
14. have the user retest the exact installed build;
15. update the defect ledger and matrix from hands-on evidence;
16. repeat until no blocker remains;
17. only then consider stable `1.0.0`.

## Product sources of truth

Read in this order during the current stabilization period:

1. `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md`
2. `MASTER_49_CHECKLIST.md`
3. `ASANTEPDF_MASTER_UPGRADE_SPEC.md`
4. `IMPLEMENTATION_MATRIX.md`
5. `docs/PROJECT_STATE.md`
6. `docs/RC49_UX_ACCEPTANCE_DEFECTS.md`
7. `docs/MASTER_49_COMPLETION_PLAN.md`
8. `docs/ASANTEPDF-VISUAL-DIRECTION.md`
9. `docs/design/target-home.svg`
10. `docs/design/target-document-workspace.svg`
11. `AGENTS.md`

## Non-negotiable acceptance rule

A compiling application is not a finished application. A green CI build is not proof that an installed Windows desktop UI looks correct. A control that technically exists but cannot be read is not accepted. A synthetic PDF fixture that opens once is not proof that real PDFs are reliable.

UI work stays unaccepted until it is actually seen and used on Windows, and release-critical work stays unaccepted until the exact installed Program Files build survives the expanded stabilization gate on the same source being considered for release.
