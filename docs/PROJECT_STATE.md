# AsantePDF Project State

Updated after the UX60 implementation was merged into the stabilized development line and the expanded final installed-copy Windows release gate passed.

## Current product state

- Branch: `development/master-upgrade-v2`
- Promotion PR: `#3` — **AsantePDF 1.0 master upgrade and UX60 stabilization**
- PR posture: **draft, deliberately held from `main` pending hands-on user acceptance**
- Candidate version: `1.0.0-rc49`
- Exact SDK: `.NET 10.0.202`
- Master requirements implemented in source audit: **49 / 49**
- UX improvement guide implemented in source: **60 / 60**
- Automated validation: **PASSED**
- Installed Program Files validation: **PASSED**
- Visual/manual user acceptance: **PENDING**
- Stable `1.0.0`: **NOT YET DECLARED**

The project has moved beyond the earlier failed RC49 candidate that triggered stabilization. The previous hands-on failures remain authoritative historical acceptance evidence, but the current exact candidate has now passed the expanded automated and installed-copy gates designed to reproduce those failure classes.

Do not merge PR #3 to `main`, tag stable `1.0.0`, or mark the 49 master requirements formally accepted until the user retests the exact validated installer on their Windows machine and confirms the relevant release blockers are resolved.

## Exact validated candidate

Final-gate trigger/head:

`c94e5201c2b66903498c1be56564ab2004872610`

UX60 merge commit into the development line:

`996bbc4d635552bddf942df61eec07b248ac840c`

Final Windows Release Gate:

- workflow run: `33333449541`
- workflow: `AsantePDF Final Windows Release Gate`
- conclusion: **success**
- artifact: `AsantePDF-1.0-final-candidate`
- artifact id: `9738428445`
- artifact digest: `sha256:9effb43d628b2f3510b28c522c1464ef0119a66883b43139ce66fe630dca9545`

## Evidence passed on the current candidate

### UX60 branch validation

The dedicated UX60 Windows gate passed on the implementation branch before merge. It verified:

- x64 Release compilation;
- core smoke tests;
- UX60 source surfaces;
- representative PDF corpus generation;
- real WPF application startup;
- PDF opening and completed thumbnail rendering;
- process survival after opening;
- five representative PDF shapes in both Light and Dark.

The corpus included:

- 18-page research-like text/vector PDF;
- 8-page image-only scanned-style PDF;
- 3-page feature-rich PDF with bookmarks, annotation and form field;
- 6-page rotated/cropped PDF;
- 50-page larger text PDF.

### Post-merge development Windows gate

After UX60 was merged into `development/master-upgrade-v2`, the established development gate also passed. It verified:

- staged-patch handling and clean source contracts;
- theme and PDFium source contracts;
- exact SDK;
- x64 Release compilation;
- core smoke tests;
- Light and Dark product surfaces;
- repeated normal UI PDF-open stress in both themes;
- retained runtime theme evidence.

### Final installed-copy release gate

The heavyweight final release gate passed end to end on the exact candidate. It verified:

- clean promoted source;
- exact .NET SDK;
- self-contained Windows x64 publish;
- bundled required local engines;
- release self-tests;
- production Inno Setup installer generation;
- silent installation of the exact generated installer;
- launch and validation of the exact `Program Files\AsantePDF\AsantePDF.exe` copy;
- whole-shell Light/Dark runtime checks;
- effective 100/125/150/175/200% visual/DPI checks;
- release-sample opening and thumbnail completion in both themes;
- the representative regression corpus in both themes;
- post-open process survival;
- two-process first-launch/restart lifecycle verification;
- onboarding non-recurrence;
- theme/settings persistence;
- Recent population;
- Grid/List/Compact controls;
- Resume restoring a multi-tab session and page position;
- OCR, PDFium, qpdf, LibreOffice and document-operation self-tests;
- Windows PDF/Open With registration;
- Start Menu shortcut integration;
- release receipt and checksum generation;
- uninstall cleanup;
- final candidate artifact packaging and upload.

## UX60 implementation state

The 60-item UX guide is implemented in source and tracked in:

`docs/UX60_EXECUTION_MATRIX.md`

Key additions include:

- global operation/progress feedback;
- per-button busy states;
- background-task toasts and Task Center state;
- honest indeterminate progress;
- document-opening skeleton feedback;
- progressive/priority thumbnail rendering;
- save and dirty-state acknowledgement;
- Ctrl+K command palette;
- adaptive ribbon behaviour;
- richer context menus and page drag/drop cues;
- persistent panel sizes and collapse state;
- Focus Mode;
- improved zoom/Fit state;
- richer document status information;
- PDF Doctor progress/severity feedback;
- multi-PDF opening into tabs;
- task continuation/retry/cancel/output flows;
- accessibility and tooltip improvements;
- annotation Escape handling;
- undo/redo history clarity;
- dismissible local-first messaging;
- Explorer integration and active-document window titles.

Source implementation and installed-build validation do not by themselves convert every UX or master-contract row to formal `ACCEPTED`. The remaining stage is hands-on user acceptance.

## Historical failed acceptance evidence

The earlier installed RC49 candidate exposed material failures on the user’s real Windows machine, including:

- Light-mode washed-out or near-invisible controls;
- mixed/incorrect Dark-mode rendering;
- Recent controls such as Resume/Grid/List/Compact becoming effectively invisible;
- a real PDF-open attempt closing AsantePDF;
- earlier visual defects including clipped onboarding, weak hover states, contrast problems, ribbon/icon issues, maximize/taskbar behaviour and Task Center architecture problems.

These failures drove `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md` and must remain in the acceptance history. The current candidate was specifically tested against expanded gates designed to cover those classes of failure.

## Required evidence progression

For acceptance-sensitive requirements continue to distinguish:

1. source implemented;
2. automated validation passed;
3. installed-build validation passed;
4. visual/manual acceptance passed;
5. accepted.

Current candidate status is at stage **3**. Do not skip stage 4.

## Immediate next action

1. Give the user the GitHub Actions artifact from final gate run `33333449541`.
2. The user installs and tests that exact candidate on their Windows machine.
3. Retest the previously failed areas first: Light mode, Dark mode, live switching, Recent controls, opening ordinary/multi-page PDFs, thumbnails, repeated open/close, multiple tabs, restart/session Resume, scaling and general layout.
4. Record any hands-on defects without weakening CI to accommodate them.
5. If defects appear, reproduce, fix on development, rerun the relevant Windows gates and issue a new exact candidate.
6. If hands-on acceptance passes, update the defect ledger and implementation matrix, move applicable master requirements to `ACCEPTED`, mark PR #3 ready, and only then promote to `main` and consider stable `1.0.0`.

## Release rule

A green installer gate means the candidate is technically validated and safe to hand to the user for acceptance. It does not by itself authorize a stable declaration.

The release becomes stable only when the exact installed build, the automated evidence and the user’s hands-on Windows experience agree.