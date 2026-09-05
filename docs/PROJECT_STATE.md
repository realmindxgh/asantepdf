# AsantePDF Project State

Updated after the acceptance-driven document-workspace redesign was merged and Candidate C passed the full installed-copy Windows release gate.

## Current product state

- Branch: `development/master-upgrade-v2`
- Promotion PR: `#3` — **AsantePDF 1.0 master upgrade, UX60 and workspace stabilization**
- PR posture: **draft, deliberately held from `main` pending hands-on user acceptance**
- Candidate version: `1.0.0-rc49`
- Candidate label for this acceptance cycle: **Candidate C**
- Exact SDK: `.NET 10.0.202`
- Master requirements implemented in source audit: **49 / 49**
- UX improvement guide implemented in source: **60 / 60**
- Automated validation: **PASSED**
- Exact installed Program Files validation: **PASSED**
- Workspace visual evidence gate: **PASSED and visually inspected before merge**
- Visual/manual user acceptance on the real Windows machine: **PENDING**
- Stable `1.0.0`: **NOT YET DECLARED**

Candidate C supersedes the earlier Candidate B that failed the user's visual acceptance. The new workspace is materially different: the ribbon horizontal scrollbar is removed, document-command chrome is reduced, secondary commands move behind a real `More` menu, `Active Document` has a strong accent rail, the page and Inspector panels are narrower, the Inspector/PDF Doctor surface is lighter, the page-count `/ 0` defect is corrected, and redundant PDF-open start/completion toasts are suppressed.

Do not merge PR #3 to `main`, tag stable `1.0.0`, or mark the 49 master requirements formally accepted until the user installs and tests the exact Candidate C artifact on their Windows machine and confirms the remaining visual/interaction acceptance boundary is resolved.

## Exact Candidate C provenance

Validated product-source merge containing the workspace redesign:

`7f3d5cf8c178084701243277261a48bf0a37274c`

Final-gate trigger/head used to build and install Candidate C:

`7167e1f5181cc725891bcd5ae964928879b649d0`

The difference between those SHAs is the release-trigger text only. The application source in Candidate C is the merged product source at `7f3d5cf8c178084701243277261a48bf0a37274c`.

Later documentation-only state commits may move the development branch head again. They do not redefine the validated Candidate C binary. Any later application-affecting change requires fresh relevant gates and a new exact candidate.

## Candidate C evidence

### Pre-merge workspace redesign validation

- PR #6: **Redesign document workspace for visible UX improvement**
- redesign source head: `f9bfeefb422d7a8b9e9407208968ba23adf6efaf`
- Workspace Visual Redesign Gate run: `33689654700` — **success**
- UX60 Windows Gate run: `33689654651` — **success**
- UX60 Acceptance Fixes Gate run: `33689654708` — **success**
- clean visual evidence artifact: `9869540395`

The visual gate captured the settled document workspace rather than the loading overlay and retained Light/Dark plus effective 100/125/150/175/200% viewport evidence. The resulting screenshots were inspected before PR #6 was merged.

### Post-merge development validation

PR #6 merged into `development/master-upgrade-v2` as:

`7f3d5cf8c178084701243277261a48bf0a37274c`

Post-merge Development Windows Gate:

- workflow run: `33721181665`
- conclusion: **success**

It passed source contracts, exact SDK setup, x64 Release compilation, core smoke tests, whole-shell Light/Dark verification and repeated normal UI PDF-open stress.

### Final installed-copy release gate

Candidate C Final Windows Release Gate:

- workflow run: `33721447166`
- workflow: `AsantePDF Final Windows Release Gate`
- head: `7167e1f5181cc725891bcd5ae964928879b649d0`
- conclusion: **success**
- artifact: `AsantePDF-1.0-final-candidate`
- artifact id: `9880635772`
- artifact size: `305157034` bytes
- artifact digest: `sha256:d704dda3f57d377ccf89bcf979ecf862341447ef1dd082ca2d0f23ee5b395464`
- artifact expiry: `2026-10-03`

The heavyweight final release gate passed end to end. It verified:

- clean promoted source;
- exact .NET SDK;
- self-contained Windows x64 publish;
- bundled required local engines;
- release self-tests;
- production Inno Setup installer generation;
- silent installation of the exact generated installer;
- launch and validation of the exact `C:\Program Files\AsantePDF\AsantePDF.exe` copy;
- whole-shell Light/Dark runtime checks;
- effective 100/125/150/175/200% visual/DPI checks;
- 12-page release-sample opening and thumbnail completion in both themes;
- representative 3/6/8/18/50-page regression corpus opening in both themes;
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

## Workspace visual redesign accepted into source

The Candidate C redesign addresses the visual hierarchy problems seen in Candidate B:

- the document ribbon no longer exposes a horizontal scrollbar;
- the document-command band is reduced from the previous 126px layout to about 84px;
- lower-priority commands move behind `More` instead of forcing sideways scrolling;
- high-frequency commands stay directly visible;
- `Active Document` uses an obvious accent rail and stronger selected state;
- page thumbnails and Inspector consume less default width;
- the PDF canvas receives substantially more of the workspace;
- the Inspector/PDF Doctor presentation uses less card weight;
- page navigation reports the loaded page count correctly rather than `/ 0`;
- routine PDF opening no longer leaves redundant start/completion toast cards covering the workspace.

Source implementation and installed-build validation do not by themselves convert every UX or master-contract row to formal `ACCEPTED`. The remaining stage is the user's hands-on visual and interaction acceptance of this exact candidate.

## Historical failed acceptance evidence

Earlier installed candidates exposed material failures on the user's real Windows machine, including washed-out Light controls, mixed Dark rendering, effectively invisible Recent controls, PDF-open instability and a Candidate B workspace whose visible result did not meet the intended redesign quality.

Those failures remain authoritative historical evidence. Candidate C was created specifically after rejecting source-only or misleading visual-green conclusions and requiring settled screenshots plus exact installed-copy validation.

## Required evidence progression

For acceptance-sensitive requirements continue to distinguish:

1. source implemented;
2. automated validation passed;
3. installed-build validation passed;
4. visual/manual user acceptance passed;
5. accepted.

Candidate C is currently at stage **3**. The pre-merge screenshots strengthen visual evidence but do not replace stage 4 on the user's real installed machine.

## Immediate next action

1. Give the user the Candidate C artifact from Final Windows Release Gate run `33721447166`.
2. The user installs that exact candidate on their Windows machine.
3. Compare the document workspace directly against Candidate B, prioritising the ribbon, canvas dominance, Active Document state, page count, Inspector weight and absence of redundant opening notifications.
4. Retest Light/Dark and live switching, Recent/Resume/Grid/List/Compact, ordinary and multi-page PDF opening, thumbnails, repeated open/close, multiple tabs, restart/session restoration and scaling/layout.
5. Record any hands-on defects without weakening CI to accommodate them.
6. If defects appear, reproduce, fix on development, rerun the relevant Windows and visual gates, and issue a new exact candidate.
7. If hands-on acceptance passes, update the defect ledger and implementation matrices, mark applicable requirements `ACCEPTED`, mark PR #3 ready, resolve its promotion mechanics, and only then promote to `main` and consider stable `1.0.0`.

## Release rule

A green installer gate means Candidate C is technically validated and safe to hand to the user for acceptance. It does not by itself authorize a stable declaration.

Stable `1.0.0` requires agreement between the exact installed build, automated evidence and the user's hands-on Windows experience.
