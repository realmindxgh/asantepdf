# AsantePDF Agent / Continuation Instructions

This repository is the persistent source of truth for the AsantePDF project.

## Mandatory reading before changing the product

Read these files in this order before touching product code:

1. `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md`
2. `MASTER_49_CHECKLIST.md`
3. `ASANTEPDF_MASTER_UPGRADE_SPEC.md` in full
4. `IMPLEMENTATION_MATRIX.md`
5. `docs/PROJECT_STATE.md`
6. `docs/RC49_UX_ACCEPTANCE_DEFECTS.md`
7. `docs/ASANTEPDF-VISUAL-DIRECTION.md`
8. `docs/design/target-home.svg`
9. `docs/design/target-document-workspace.svg`
10. the current Windows validation workflow and release workflow when changing engineering or packaging

The RC49 stabilization plan is currently the highest-priority continuation contract because hands-on Windows testing invalidated the previous candidate. If an older state document says implementation is complete and only routine acceptance remains, interpret that through the stabilization plan and the latest acceptance evidence.

## The contract has 49 requirements

Do not use an old 45-item interpretation of the project. `MASTER_49_CHECKLIST.md` is the continuation index and explicitly adds requirements 46-49 to the original specification.

The 49 master requirements are:

1. Rebrand PDF Rescue as AsantePDF.
2. Redesign the Windows installer.
3. Proper Home experience.
4. Session persistence and recovery.
5. Real multi-document tabs.
6. Split-view PDF comparison.
7. Professional grouped command ribbon.
8. Coherent colour system and complete theming.
9. Better page navigation.
10. Better zoom and viewing modes.
11. Interactive PDF text.
12. First-class document search.
13. Multi-mode navigation sidebar.
14. Multi-page selection and management.
15. Standalone tools without an already-open PDF.
16. Proper configuration dialogs.
17. Application-wide task/progress framework.
18. Task Center.
19. Proper completion workflows.
20. Non-destructive processing by default.
21. PDF Doctor redesign.
22. Contextual Inspector.
23. Proper annotation system.
24. Proper Save, Save As and Save a Copy behaviour.
25. Stronger Undo/Redo.
26. Proper drag and drop.
27. Robust context menus.
28. Coherent keyboard shortcuts.
29. Proper printing.
30. Better conversion workflows.
31. Strong OCR feature.
32. Batch processing.
33. PDF security workflows.
34. Recent-file privacy controls.
35. Real Settings experience.
36. Professional error and recovery UX.
37. Performance perception and responsiveness.
38. Accessibility and high-DPI support.
39. Tasteful first-launch experience.
40. About and diagnostics.
41. Update mechanism.
42. Coherent Home / Workspace / Task architecture.
43. Release-quality engineering standard.
44. Context-aware interface.
45. Recent files with Grid/List/Compact layouts and real thumbnails.
46. Visible top-right Light/Dark switching plus Light, Dark and Follow Windows settings.
47. AsantePDF remains completely free, with no Premium, Upgrade, Subscription or payment-gated features.
48. Contextual session recovery, with Resume hidden when there is nothing real to restore.
49. New Ghana-inspired AsantePDF identity using a restrained red, gold/yellow, green and black document-based mark.

If any future document, comment or agent plan says the project has only 45 master requirements, it is stale.

## Current stabilization override

Hands-on testing of the RC49 installed candidate demonstrated that the application was not ready for acceptance even though the source audit reported all 49 requirements implemented.

The failed candidate showed, among other things:

- Light-mode contrast failures;
- a visually mixed/incorrect Dark mode;
- Recent controls such as Resume/Grid/List/Compact becoming effectively invisible;
- a real PDF-open path that could close the application on the user’s Windows machine;
- prior CI that was too synthetic to catch the real installed-use failure.

Therefore:

- the candidate itself is failed acceptance evidence;
- `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md` controls the immediate work order;
- no stable `1.0.0` declaration is allowed until stabilization and installed/manual acceptance are complete;
- green compile/smoke output alone must never be described as product acceptance;
- the next installer must pass the expanded whole-shell Light/Dark runtime probe and realistic PDF-open stress test before it is handed to the user.

## Non-negotiable product rules

Do not treat RC10 as the intended final UI. RC10 proved the Windows build/release path and many PDF operations, but the 49-item contract defines the target product.

The product has three connected experiences:

- Home / Launcher
- Document Workspace
- Task System

Home mode and Document mode must genuinely behave differently. Avoid bolting isolated controls onto one giant window.

AsantePDF is completely free. Do not add premium gates, subscription prompts, upgrade advertising, artificial payment limits or locked tools.

## Tracking rule

Every numbered item in the 49-item contract is an acceptance item. Keep `IMPLEMENTATION_MATRIX.md`, `docs/PROJECT_STATE.md`, `docs/RC49_UX_ACCEPTANCE_DEFECTS.md` and the stabilization plan current.

Allowed working states are:

- NOT STARTED
- REVIEW REQUIRED
- IN PROGRESS
- IMPLEMENTED, NOT ACCEPTED
- ACCEPTED

Do not mark an item ACCEPTED merely because code exists. Acceptance requires the relevant behaviour to be visibly exercised or otherwise concretely verified. UI items require visual/runtime verification. Release-critical changes must also survive the Windows gate.

During stabilization, evidence should distinguish:

- source implemented;
- automated validation passed;
- installed-build validation passed;
- visual/manual acceptance passed.

Only the final stage may justify `ACCEPTED` when the master requirement’s other evidence is also satisfied.

## Design rule

The target images remain canonical visual references, but requirement 49 supersedes the old generic blue identity. Preserve the product language:

- modern desktop UI
- proper Light and Dark themes
- visible theme switching
- clear Home and Document modes
- substantial grouped command ribbon
- professional icon family, never emoji
- clear tab hierarchy
- useful left navigation
- contextual right-side Inspector / PDF Doctor
- generous spacing
- strong disabled, active, hover, focus and pressed states
- tasteful Ghana-inspired product identity without flooding the UI with flag colours
- no legacy wall of identical grey buttons

Function wins if a visual reference conflicts with a master requirement.

For theme work, a control that technically has `Visibility=Visible` but is visually indistinguishable from its background is considered failed, not present. Whole-shell theme consistency matters more than the title bar or a few correctly recoloured controls.

## Engineering rule

Keep the release-quality standard:

- static checks
- real Windows compilation
- automated functionality tests
- whole-shell Light/Dark runtime verification
- realistic multi-page PDF-open stress
- process-wide PDFium safety rules where required
- self-contained Windows publish
- bundled required engines
- production `AsantePDF Setup.exe`
- silent install of that exact installer
- launch the installed Program Files copy
- installed-copy verification
- retained screenshots/logs/checksums/evidence
- downloadable installer only after the release gate passes

For coherent development batches, use the established Windows gate. Prefer ordinary source changes after validation. Temporary patch carriers are staging mechanisms only and must not become the permanent architecture.

Do not weaken regression tests by disabling Recent files, thumbnails, recovery/session behaviour or other normal-user features just to make the PDF-open test easier to pass.

## Continuation rule for future chats and agents

When asked to continue AsantePDF, do not invent a new roadmap and do not stop at item 45. Read the files above, starting with `docs/RC49_STABILIZATION_AND_ACCEPTANCE_FIX_PLAN.md`.

Continue stabilization in this priority order until the failed acceptance evidence is resolved:

**theme correctness → PDF opening stability → error containment → visual/layout audit → installed-build verification → remaining functionality**

Validate each coherent batch on Windows, promote clean ordinary source, remove consumed carriers, run a clean no-patch gate, then deliberately run the installed-copy release gate when the source is ready.

Do not declare AsantePDF 1.0 final while any material requirement among all 49 remains unaccepted, while a known release blocker remains open, or while the user’s installed build still disagrees with CI evidence.