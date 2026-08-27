# AsantePDF 49-Item Completion Plan

This is the execution plan for finishing the product contract in `MASTER_49_CHECKLIST.md`.

The work is treated as one coordinated completion programme, but code is promoted in coherent Windows-validated batches so a failure in one area does not contaminate the proven source.

## Execution order

### Batch A — contract, Inspector and state reconciliation

- Lock the 49-item contract into agent instructions and tracking.
- Finish contextual Inspector page and text-selection foundation.
- Extend Inspector to annotation context where the source model supports it.
- Reconcile stale matrix/project-state claims against actual source and Windows evidence.

### Batch B — split view and completion workflows

- Implement two-tab split comparison.
- Independent left/right document choice.
- Independent scroll and zoom.
- Linked scrolling and synchronized zoom toggles.
- Swap panes.
- Align page numbers.
- Exit split view without closing documents.
- Wire operation results to original/result comparison.
- Close item 19's side-by-side dependency.

### Batch C — Save, Undo/Redo, annotation and context interaction

- Implement Save, Save As and Save a Copy contracts.
- Add Ctrl+S and Ctrl+Shift+S behaviour.
- Handle multi-tab unsaved exit with Save / Don't Save / Cancel semantics.
- Expand edit history beyond page layout where technically safe.
- Complete annotation tools including underline, strikeout, notes/comments, freehand where practical, colour and opacity.
- Add selection/edit/delete behaviour for supported annotations.
- Complete page, tab, annotation and canvas context menus.

### Batch D — printing, viewing, navigation and drag/drop

- Implement printing with printer selection, page range, current/selected pages, copies, orientation and fit/scale options.
- Complete page-navigation keyboard contract.
- Complete viewing modes including single-page, continuous and two-page where practical.
- Complete drag/drop coverage for Home, Merge, Images-to-PDF, compatible dialogs, tabs and pages.
- Audit shortcut discoverability and tooltips.

### Batch E — Settings, themes, privacy and session recovery

- Implement a real Settings experience.
- Add Light, Dark and Follow Windows themes.
- Add visible top-right Light/Dark switch with professional sun/moon icons.
- Persist theme choice.
- Add default zoom and page-view settings.
- Add OCR defaults, output folder/naming and overwrite preferences.
- Add recent-file controls, thumbnail controls and clear-history/cache actions.
- Hide Resume when no valid resumable session exists.
- Add crash/unsaved working-state recovery using separate recovery storage.

### Batch F — first launch, errors, accessibility and diagnostics

- Add dismissible one-time onboarding.
- Add user-facing operation error panels with source-safety messaging and recovery actions.
- Preserve detailed technical logging.
- Audit keyboard-only navigation and focus.
- Add automation properties/screen-reader names to significant controls.
- Validate 125%, 150%, 175% and 200% scaling through the Windows validation matrix.
- Add About/Diagnostics with app/build/architecture and local engine information.

### Batch G — updates, branding and installer

- Add explicit user-controlled update checking and update-state UI.
- Preserve settings/session data across updates.
- Remove any stale PDF Rescue branding found by source/installer audit.
- Replace the generic blue mark with a restrained Ghana-inspired red/gold/green/black document/A identity across title bar and vector UI surfaces.
- Update icon/installer assets where reproducible source assets exist.
- Verify there is no Premium, Upgrade, Subscription or payment-gated UI anywhere.
- Complete installer Open With registration, VC++ handling and uninstall cleanup audit.

### Batch H — final acceptance and release gate

- Audit every sub-bullet of all 49 requirements against current source.
- Move code-complete items to `IMPLEMENTED, NOT ACCEPTED` only with evidence.
- Perform all automatable runtime acceptance.
- Run x64 Windows compile and smoke tests on clean source.
- Publish self-contained application.
- Stage PDFium/qpdf/Tesseract/LibreOffice dependencies.
- Build production `AsantePDF Setup.exe`.
- Silent-install that exact installer.
- Launch and test installed Program Files copy.
- Record hashes and release evidence.
- Leave only genuinely hands-on visual observations as unaccepted, if any.

## Validation discipline

For every coherent implementation batch:

1. change only source required for that batch
2. compile Release x64 on Windows with exact SDK
3. run the core smoke suite
4. promote validated source
5. rerun clean source without patch carriers where appropriate
6. update `IMPLEMENTATION_MATRIX.md` and `docs/PROJECT_STATE.md`
7. do not call UI work accepted until visually/runtime verified

## Finish condition

AsantePDF is not finished when it merely builds. The completion target is all 49 requirements implemented and tracked, with a production installer that survives the full release gate.