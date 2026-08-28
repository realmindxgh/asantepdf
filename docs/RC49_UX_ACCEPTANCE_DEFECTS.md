# RC49 Hands-on UX Acceptance Defects

This document records defects discovered during real Windows hands-on acceptance of the `1.0.0-rc49` candidate. These are acceptance blockers even where the corresponding master item is implemented in source.

## Confirmed from the installed RC49 candidate

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

11. **Disabled controls are faded to 34% opacity**, which makes labels unnecessarily hard to read. Disabled state should remain legible.
12. **Theme color translation is brittle.** The code compares WPF `Color.ToString()` output against RGB-only strings, while WPF commonly produces ARGB values. This can prevent hard-coded dark colors from mapping to light equivalents.
13. **Theme resources are `StaticResource` brush instances that may be frozen/replaced.** Replacing a frozen resource does not recolor controls that already hold the old brush instance. Theme brushes must be mutable in place or consumed dynamically.
14. **The theme map is incomplete.** Numerous hard-coded dark colors across MainWindow, Task Center, page thumbnails, Inspector, status bar and Home are not guaranteed to translate.
15. **TextBox caret/background are dark-theme-specific.** A white caret and hard-coded dark input background are wrong in Light mode.
16. **Task Center summary layout is rigid.** Five equal statistic cards plus a fixed 190px filter in one row will compress badly at smaller widths or elevated DPI.
17. **Home Quick Tools is fixed to seven columns and More Tools to five columns.** This does not adapt to narrower windows or 125–200% scaling.
18. **Responsive layout currently only auto-collapses Inspector.** Home, ribbon, title search, navigation and the page/zoom/search strip need responsive behaviour too.
19. **Active primary navigation has no persistent visual selection.** Home, Recent, Starred, Tools, Document Doctor, Active Document and Task Center should make the current context obvious.
20. **Ribbon overflow is technically scrollable but visually clips groups.** Users should not discover commands only by noticing a thin horizontal scrollbar after a group is cut off.
21. **The document page-view ComboBox is visibly washed out in Dark mode.** The installed screenshot shows system-light popup rows with weak text.
22. **Secondary typography is too small in several high-information areas.** Inspector metadata, group captions and some status/task metadata should be audited for comfortable readability at 100% and high DPI.
23. **Hard-coded secondary text colors fragment the hierarchy.** Values such as `#6F8399`, `#71869D`, `#73879D`, `#7990A7`, `#53677C`, `#54708A` should largely become theme tokens.
24. **Page thumbnail cards use fixed dark colors.** They do not reliably participate in Light mode.
25. **Document search container uses a fixed dark background.** It must theme with the rest of the navigation strip.
26. **Status-bar separators and the “Processed locally” label are unnecessarily faint.** The status strip must remain readable without competing with primary content.
27. **The maximize button glyph does not change to Restore when maximized.** Custom window chrome should reflect the actual window state.
28. **First-launch uses a disabled Button as explanatory text.** That is visually and semantically confusing; explanatory copy should be text, while actionable controls should be buttons.
29. **Other fixed-size non-resizable lifecycle dialogs need DPI review.** Recovery, diagnostics, Settings, error and print surfaces must be checked for the same clipping pattern as onboarding.
30. **Popup-based controls are outside the main visual tree.** Recursive theme recoloring alone cannot be relied on to recolor ComboBox popups/context popups; their styles must be theme-aware by design.
31. **Hover/selected treatment must be verified for keyboard focus too.** Mouse improvements must not erase the visible keyboard focus required by the accessibility contract.
32. **The installed RC49 candidate is therefore not visually accepted.** The implementation matrix remains code-complete, but UI-facing requirements must stay `IMPLEMENTED, NOT ACCEPTED` until these defects and the subsequent Windows hands-on pass are cleared.
33. **Interactive cards should visibly lift on hover.** Home tool cards, Recent-file cards and Task Center task cards should rise subtly with a restrained shadow instead of relying on colour change alone.

## Code-fix checkpoint — 28 August 2026

All 33 known acceptance defects above have now been addressed in the ordinary source tree and passed the exact Windows x64 Release development gate plus the core smoke suite. This is a **code-fix checkpoint, not visual acceptance**. The corrected installed candidate still requires the hands-on retest below.

Implemented acceptance fixes include:

- DPI-safe, scrollable first-launch, recovery, diagnostics, Settings, error and print windows.
- Stronger hover, pressed, disabled and keyboard-focus states.
- 3 px card lift with restrained shadow for Home tool cards, Recent-file cards and Task Center task cards; ordinary ribbon/navigation controls remain stationary.
- Mutable theme resources, original-colour-aware hard-coded surface translation, immediate Light/Dark switching and themed popup ComboBoxes.
- Higher-contrast secondary/status text and larger task/recent metadata.
- Windows work-area-aware maximize behaviour plus correct Maximize/Restore glyph and accessibility name.
- Non-destructive Task Center drawer that leaves Home/document work alive underneath it.
- Responsive Task Center statistics, Home tool grids, Home hero art, title search, Inspector, page navigation, viewing-mode width and document search width.
- Persistent active state for Home, Recent, Starred, Tools, Document Doctor, Active Document and Task Center, including restoration when Task Center closes.
- Cleaner Edit & Annotate command alignment and corrected misleading annotation glyphs.
- Always-visible ribbon overflow affordance plus horizontal mouse-wheel scrolling over the ribbon.
- Theme-aware document search/input surfaces and status-strip contrast.
- Recent-file cards using theme tokens for metadata/borders instead of the weakest fixed secondary colours.

Windows validation evidence for the final two UX batches:

- Development gate `33155149086`: final UX polish/card-lift carrier applied, Release x64 compiled, core smoke tests passed, validated source promoted.
- Development gate `33155356571`: primary-navigation finish applied, Release x64 compiled, core smoke tests passed, validated source promoted.
- Clean promoted-source commit after those batches: `fd963c436e5df63851f97df8b031e212aa2f7864`.

## Acceptance pass required after fixes

Test Home, onboarding, document workspace, Task Center, Settings, PDF Doctor, Inspector, split view and representative operation dialogs in Light/Dark/Follow Windows at 100%, 125%, 150%, 175% and 200% scaling. Verify hover, card lift, pressed, focus and active states; maximize/restore on each monitor; Task Center while a PDF remains open; themed ComboBox/context popups; ribbon alignment/overflow and icon semantics; and no clipped or microscopic text.

Do not mark the UI-facing master requirements `ACCEPTED` until this corrected installed build has passed that hands-on review.