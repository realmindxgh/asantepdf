# RC49 Hands-on UX Acceptance Defects

This document records defects discovered during real Windows hands-on acceptance of the `1.0.0-rc49` candidate. These are acceptance blockers even where the corresponding master item is implemented in source.

## Confirmed from installed candidates

1. **First-launch onboarding clips its footer/content.** The fixed-height, non-resizable welcome window can hide the bottom action area at real Windows scaling.
2. **Interactive hover feedback is too weak to perceive.** Buttons, navigation items, tool cards, ribbon commands, and other clickable surfaces need an obvious but restrained hover state.
3. **Pressed and selected states are not distinct enough.** Interactive controls need a clear press response and persistent selected/active treatment where appropriate.
4. **Multiple contrast failures exist.** Secondary labels, group captions, status text, disabled controls, and some metadata are too faint against their backgrounds.
5. **Light mode does not visibly switch the application.** The theme engine must update all visible surfaces immediately and persist the choice.
6. **Dark-mode ComboBox popups use inappropriate light/system styling.** Dropdowns must be themed consistently and remain readable in Light, Dark, and Follow Windows modes.
7. **Maximizing the borderless window covers the Windows taskbar.** Maximized bounds must respect the current monitor work area, including multi-monitor taskbars.
8. **Task Center replaces/collapses the useful application workspace.** Opening Task Center must not make the document workspace disappear as though the whole app collapsed; background jobs must remain inspectable without trapping the user away from document work.
9. **Edit & Annotate ribbon commands do not align on a clean baseline.** Icons and labels vary in height/margins and make the group look crooked.
10. **Several icons are semantically wrong or duplicated.** Highlight and Draw reuse the same pencil glyph; Redact presents an unrelated glyph; Style is a literal dot; some page/optimize icons are ambiguous.

## Additional defects found during source + screenshot audit

11. **Disabled controls were faded too aggressively**, making labels unnecessarily hard to read. Disabled state must remain legible.
12. **Theme color translation was brittle.** RGB/ARGB handling could prevent hard-coded dark colours from mapping to light equivalents.
13. **Theme resource replacement could leave already-created controls using stale brushes.** Theme brushes need to remain live/mutable or be consumed dynamically.
14. **The theme map was incomplete.** Hard-coded colours across MainWindow, Task Center, page thumbnails, Inspector, status bar and Home were not guaranteed to translate.
15. **Text input appearance was dark-theme-specific.** Caret/background styling must be correct in Light mode too.
16. **Task Center summary layout was rigid.** Five statistic cards plus filtering controls compressed badly at smaller widths or elevated DPI.
17. **Home Quick Tools and More Tools used fixed column counts.** They need to adapt to narrower windows and 125–200% scaling.
18. **Responsive layout originally only auto-collapsed Inspector.** Home, ribbon, title search, navigation and document controls also need responsive behaviour.
19. **Active primary navigation had no persistent visual selection.** Home, Recent, Starred, Tools, Document Doctor, Active Document and Task Center should make the current context obvious.
20. **Ribbon overflow was technically scrollable but visually easy to miss.** Users need a clear overflow affordance when commands extend beyond the viewport.
21. **The document page-view ComboBox was washed out in Dark mode.** Popup rows and selected values must use the application theme.
22. **Secondary typography was too small in several high-information areas.** Inspector metadata, task metadata and recent-file metadata need comfortable readability.
23. **Hard-coded secondary text colours fragmented the hierarchy.** Weak values should generally map through theme-aware tokens/translation.
24. **Page thumbnail cards used fixed dark colours.** They must participate in Light mode.
25. **Document search container used a fixed dark background.** It must theme with the rest of the navigation strip.
26. **Status-bar separators and the “Processed locally” label were unnecessarily faint.** The status strip must remain readable without competing with primary content.
27. **The maximize button glyph did not change to Restore when maximized.** Custom window chrome should reflect the actual window state.
28. **First-launch used a disabled Button as explanatory text.** Explanatory copy should be text, while actionable controls should be buttons.
29. **Other fixed-size lifecycle dialogs needed DPI review.** Recovery, diagnostics, Settings, error and print surfaces must not clip like the original onboarding window.
30. **Popup-based controls are outside the main visual tree.** ComboBox/context popups need explicit theme-aware styling rather than depending only on recursive recolouring.
31. **Hover/selected treatment must preserve keyboard focus visibility.** Mouse improvements must not weaken the accessibility contract.
32. **The installed RC49 candidate is not visually accepted.** UI-facing requirements remain `IMPLEMENTED, NOT ACCEPTED` until hands-on review clears them.
33. **Interactive cards should visibly lift on hover.** Home tool cards, Recent-file cards and Task Center task cards should rise subtly with a restrained shadow instead of relying on colour change alone.

## Defects discovered during the second installed-candidate retest

34. **Light-mode contrast is still too washed out.** Light mode now switches correctly, but the real installed screenshot still shows secondary text, borders, disabled navigation and the local-processing card with insufficient visual weight. The Light palette needs stronger foreground/border contrast rather than merely being technically readable.
35. **Opening a PDF caused the installed application to exit.** This is a release-blocking regression. A release candidate must not be accepted unless the normal desktop UI can open a real PDF and remain alive. Engine/headless self-tests alone are insufficient evidence for this path.

## Code-fix checkpoint — 28 August 2026

The first 33 defects were addressed in ordinary source and Windows-validated. The second retest then exposed defects 34 and 35, so the earlier code-fix checkpoint is superseded.

The current repair adds:

- A stronger Light palette with darker muted text, stronger borders/surfaces and explicit Light mappings for previously pale blue/gray secondary labels.
- More legible disabled controls.
- A guarded document-loading transition so page-view collection reactions, selection persistence and secondary renders do not fire while the PDF page model is still being populated.
- One controlled foreground page-view refresh after the document model/tab state has settled, followed by background thumbnail rendering rather than starting both paths at once.
- More granular PDF-open logging around model creation and foreground rendering.
- A new normal-desktop-UI regression test in the Windows development gate that launches AsantePDF in Light mode with a real PDF, waits for a successful open log entry and fails if the process exits.
- The installed-copy release verification is also upgraded to open a real PDF in Light mode and verify that the Program Files copy remains alive after opening it.

Validation evidence for the second-retest repair so far:

- Windows development gate rerun on current branch: Release x64 compile passed, core smoke tests passed and the Light-contrast/PDF-open stability carrier was promoted.
- Promoted source commit: `48c5d742f4e2109b42ed09817e96b9f96306e2e4`.
- The staged carrier was removed after promotion.
- A clean synchronization run containing the new normal-UI PDF-open regression test is required next, followed by the heavyweight installed-copy gate.

## Acceptance pass required after fixes

Test Home, onboarding, document workspace, Task Center, Settings, PDF Doctor, Inspector, split view and representative operation dialogs in Light/Dark/Follow Windows at 100%, 125%, 150%, 175% and 200% scaling. Verify hover, card lift, pressed, focus and active states; maximize/restore on each monitor; Task Center while a PDF remains open; themed ComboBox/context popups; ribbon alignment/overflow and icon semantics; and no clipped or microscopic text.

For defect 35 specifically, open several ordinary PDFs from the Home button, Recent files, drag/drop and Windows Open With. The application must remain running and the document workspace must be usable after each open.

Do not mark the UI-facing master requirements `ACCEPTED` until the corrected installed build has passed that hands-on review.