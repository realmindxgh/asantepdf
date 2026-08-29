# AsantePDF RC49 Stabilization and Acceptance Fix Plan

This document is the durable engineering and acceptance plan created after hands-on testing of the RC49 Windows installer exposed theme inconsistency, low-contrast controls and an application-closing failure while opening a PDF.

It is not a cosmetic punch list. It is the blocking stabilization plan for the installed product.

The current candidate is **not accepted**. A green compile, smoke suite or release pipeline is insufficient evidence when the installed desktop UI does not behave correctly on the user’s actual Windows machine.

---

# Part I — Verbatim Fix Plan

The section below preserves the fix plan exactly as stated in the acceptance discussion. No wording from the plan has been omitted.

The fix plan is to stop treating this as “three broken controls” and do a proper stabilization pass over the installed application. Your screenshots have shown that the current weakness is architectural.

I’d tackle it in this order:

1. Rebuild the Light/Dark theme path properly.

The second screenshot is the giveaway. Dark mode is not simply using a few wrong colours. Different parts of the visual tree are living in different themes.

I will eliminate the remaining runtime colour-swapping hacks and move all ordinary UI surfaces to semantic theme resources. That means window backgrounds, sidebar, cards, buttons, text, secondary text, borders, inputs, dropdowns, tabs, ribbons, Recent controls, dialogs and hover/pressed states all derive from one palette.

The important rule will be:

`Light palette → entire UI`
`Dark palette → entire UI`

No component should remember what colour it had before a switch.

I’ll also audit hard-coded colours. Brand colours such as Ghana red/gold/green and meaningful status colours can remain fixed. Colours being used merely because the interface was originally dark cannot.

2. Fix Recent Files as a complete component.

The controls you pointed out are actually an excellent test case:

- Resume last session
- search field
- Last opened selector
- Grid
- List
- Compact
- recent filenames
- metadata
- thumbnail cards

In the Light screenshot, several of those appear to exist but have almost no contrast. So I need to separate two concepts that have been getting muddled: whether something is visible and whether something is legible.

`Resume last session` will follow the intended rule:

- valid recoverable session → visible and enabled
- no valid session → genuinely hidden
- never merely “white text on white background”

Grid/List/Compact must always remain visible regardless of theme. The active mode will have an obvious selected state instead of depending on faint colour differences.

3. Make theme switching atomic.

Pressing the sun/moon control should not progressively recolour pieces of the window.

The switch should:

- resolve the new theme
- replace the semantic palette
- refresh the entire window
- refresh dynamically created views
- refresh popups/context menus
- refresh open dialogs
- update the theme icon
- persist the preference

All in one UI-dispatch operation.

Then I’ll specifically test:

Light → Dark → Light → Dark

without restarting AsantePDF. That matters because the current bug can hide if we only test startup in a particular theme.

4. Fix PDF opening as a separate reliability problem.

I do not want to attribute your crash to the theme bug just because they occurred around the same time.

The PDF-open pipeline will be audited independently.

The opening sequence will become controlled:

`validate file`
→ `open PDFium document`
→ `render foreground page`
→ `show usable document`
→ `load expensive secondary services safely`

Things such as thumbnails, search indexing, text geometry, outlines, annotations and metadata should not all pile onto PDFium at once while the first page is opening.

The new process-wide PDFium gate is part of that fix, but I also want to reduce unnecessary work at open time rather than merely queue everything behind a lock.

A PDF should become usable quickly. Secondary features can populate afterward.

5. Harden failure containment.

A bad secondary feature should never kill the app.

For example:

- thumbnail generation fails → PDF stays open
- outline parser fails → Bookmarks unavailable, PDF stays open
- text extraction fails → selection/search may degrade, PDF stays open
- annotation inventory fails → annotations unavailable, PDF stays open

A foreground rendering failure is different and should produce a proper error dialog rather than terminate AsantePDF.

This also means replacing any remaining raw exception paths.

6. Test with realistic PDFs, not toy fixtures.

This is one of the biggest changes.

The old one-page generated PDF proved almost nothing about real use.

The regression set should include several document shapes:

- ordinary text PDF
- multi-page research paper
- image-heavy PDF
- scanned PDF
- PDF containing bookmarks
- PDF with forms/annotations where available
- relatively large document
- awkward but valid PDF
- multiple PDFs opened consecutively
- multiple PDF tabs
- reopen from Recent
- resume previous session

And I want repeated opening, not merely “opened once without crashing.”

For example, open/close/open a document ten or twenty times in both themes while thumbnail generation is active.

7. Add actual UI rendering acceptance.

This is where your screenshots changed my approach.

The CI should render screenshots of the actual app and retain them.

At minimum:

- Home Light
- Home Dark
- Home Light after Dark → Light switch
- Recent Grid Light/Dark
- Recent List Light/Dark
- Recent Compact Light/Dark
- Document workspace Light
- Document workspace Dark
- Settings Light/Dark
- Task Center Light/Dark
- major dialogs

The automated test can catch extreme contrast failures, but screenshots also let us see ugly results that technically satisfy contrast maths.

That would have caught this immediately:

> white page + nearly white “Get started with AsantePDF”

before you ever installed it.

8. Audit layout at real Windows sizes and scaling.

After colour is stable, I want another visual sweep for the problems you have repeatedly flagged in this project:

- tiny text
- overlaps
- clipped controls
- squeezed toolbars
- weak hierarchy
- excessive empty space
- strange alignment
- disappearing controls
- unusable narrow-window behaviour

Test matrix:

- 100%
- 125%
- 150%
- 175%
- 200%

and several window sizes.

The app should remain usable at its declared minimum window size.

9. Test the actual installed Program Files build.

This is crucial.

The development executable passing is insufficient.

The final test must:

build → publish → package installer → silent install → run the exact installed EXE.

Then the installed app must pass:

- first launch
- Light mode
- Dark mode
- live switching
- open real/multi-page PDF
- thumbnails complete
- Recent populated
- Grid/List/Compact switch
- session persistence
- restart
- Resume session
- settings persistence
- multiple PDFs
- clean uninstall

That closes the gap between “CI build works” and “the thing Shadrach actually installed works.”

10. Only then resume the remaining 49-item work.

I do not want to pile annotations, updates, extra viewer modes and remaining features onto an unstable shell.

The immediate priority order is therefore:

**theme correctness → PDF opening stability → error containment → visual/layout audit → installed-build verification → remaining functionality**

Then I return to the outstanding master items such as annotation editing, viewer modes, recovery completeness, About/diagnostics, updates and final installer polish.

There will also be stricter acceptance terminology from here. A feature will move through:

**Implemented → automated validation passed → installed-build validation passed → visual/manual acceptance**

not directly from “compiled” to “done.”

For the particular build you showed me, I currently consider **Light mode failed, Dark mode failed, PDF-open reliability failed, and therefore the candidate itself failed**. That is the baseline I’ll fix against.

---

# Part II — Expanded Engineering Plan

## 1. Purpose and release posture

The purpose of this stabilization pass is to make the installed Windows application trustworthy before any stable 1.0 declaration.

The failed acceptance build demonstrated three classes of problem:

1. **theme-state correctness failure** — parts of one visual tree could display Light resources while other parts displayed Dark resources;
2. **legibility/contrast failure** — controls existed but were effectively invisible because foreground and background combinations were too close;
3. **runtime reliability failure** — opening an ordinary PDF on the user’s machine could terminate the application even though synthetic CI fixtures passed.

These invalidate the candidate as a release candidate regardless of how many master requirements are implemented in source.

Until this plan is complete:

- do not promote `1.0.0-rc49` to stable `1.0.0`;
- do not mark theme-related, PDF-open, Home/Recent, accessibility or release-quality acceptance rows as `ACCEPTED`;
- do not describe a candidate as “final” merely because the installer gate is green;
- do not hand a new installer to the user until its exact Program Files copy has passed the expanded stabilization gate;
- preserve failed screenshots and failed run evidence as part of the acceptance history rather than overwriting the record with a later green run.

## 2. Confirmed acceptance defects to keep visible

The stabilization work must explicitly account for all defects discovered during hands-on testing, including the earlier UX defects already recorded in `docs/RC49_UX_ACCEPTANCE_DEFECTS.md` and the later architectural failures.

At minimum the current defect universe includes:

- first-launch Welcome content clipped at the bottom;
- hover feedback initially too weak or absent;
- card surfaces requiring restrained visual lift on hover;
- multiple Light-mode contrast failures;
- disabled controls fading into the background;
- dark-mode dropdowns inheriting light popup styling;
- Edit & Annotate ribbon alignment irregularity;
- icon choices that do not clearly match their actions;
- maximize/full-screen behaviour previously covering the Windows taskbar;
- Task Center previously replacing/collapsing the whole application rather than behaving as a non-destructive task surface;
- fixed Home grids becoming crowded at DPI scaling;
- missing persistent selected states in left navigation;
- Recent controls visually disappearing in Light mode;
- `Resume session` appearing absent because its foreground/background state was broken;
- Grid/List/Compact becoming unreadable or apparently absent;
- Dark mode producing a dark title bar around a predominantly light application body with near-white headings;
- theme switching failing to recolour the whole tree consistently;
- PDF open terminating the application on a real installed machine;
- earlier CI opening only a trivial one-page fixture with recent/thumbnails disabled, which did not represent normal use.

No one should close these defects merely because a source diff exists. Closure requires the evidence defined later in this document.

## 3. Phase A — Theme architecture replacement

### 3.1 One semantic palette, no historical colour memory

The theme engine must have exactly one authoritative resolved theme at a time. Controls must not cache their previous foreground/background values and attempt to “restore” them on a later theme switch.

The application must expose semantic resources for at least:

- window background;
- sidebar background;
- base surface;
- raised/card surface;
- hover surface;
- pressed/selected surface;
- soft border;
- strong border/focus border where needed;
- primary text;
- secondary/muted text;
- disabled text;
- accent;
- accent hover;
- success;
- warning;
- danger;
- information;
- selection/highlight where appropriate.

All general-purpose UI components must consume these through `DynamicResource` or another live semantic binding mechanism.

### 3.2 Hard-coded colour policy

Hard-coded colours are permitted only when the colour itself carries product or semantic meaning. Examples:

- Ghana-inspired red/gold/green/black identity;
- PDF red where it is deliberately part of the document/PDF visual language;
- success/warning/error status colours;
- document-format brand marks such as Word/Excel/PowerPoint when intentionally used;
- annotation colours chosen by the user.

Hard-coded colours must not be used simply because a screen was designed first in Dark mode.

Every remaining literal colour in XAML/C# should be classified as one of:

1. semantic and move to palette;
2. brand/format colour and intentionally retain;
3. decorative illustration colour and verify in both themes;
4. obsolete literal to remove.

### 3.3 Existing control classes requiring explicit audit

At minimum audit:

- `Window`;
- `UserControl`;
- `Border`;
- `Grid`, `StackPanel`, `DockPanel`, `WrapPanel` backgrounds;
- `TextBlock`;
- `Run` elements with explicit foregrounds;
- `Button` and all derived button styles;
- `TextBox`;
- `ComboBox` and `ComboBoxItem`;
- `ContextMenu` and `MenuItem`;
- `ListBox` and `ListBoxItem`;
- `TabControl` / tab headers;
- ribbon groups/buttons;
- thumbnail cards;
- task cards;
- Inspector cards;
- PDF Doctor cards;
- status bar;
- custom title bar;
- dialogs created in code;
- popups and context menus whose visual trees are not normal children of the window;
- late-created views such as Recent Files and Task Center.

### 3.4 Theme switching transaction

The theme toggle must execute as one UI-thread transaction:

1. determine requested mode (`Light`, `Dark` or resolved `FollowWindows`);
2. replace/update all semantic resources;
3. ensure existing DynamicResource consumers receive the new resources;
4. refresh any legacy surfaces still requiring transitional mapping;
5. refresh late-created child views;
6. refresh open secondary windows/dialogs;
7. close or refresh open popups if WPF popup isolation prevents immediate resource propagation;
8. update the sun/moon glyph and tooltip;
9. save preference;
10. log the completed transition in diagnostic logs when debug/acceptance diagnostics are enabled.

The application must never spend visible time in a half-Light/half-Dark state.

### 3.5 Required switch-order tests

Automated and hands-on tests must cover:

- startup Light;
- startup Dark;
- startup Follow Windows with Windows Light;
- startup Follow Windows with Windows Dark where CI/environment permits;
- Light → Dark;
- Dark → Light;
- Light → Dark → Light → Dark without restart;
- switch while Recent view is visible;
- switch while document workspace is visible;
- switch while Task Center is open;
- switch while Settings is open;
- switch after opening a context menu/dropdown;
- switch after a PDF has opened and thumbnails are loading;
- restart after each explicit theme selection to confirm persistence.

## 4. Phase B — Recent Files as the theme canary

Recent Files is the primary canary component because the user directly observed disappearing controls there and because it is created dynamically after the main shell begins initialization.

### 4.1 Required Recent controls

The following must be present and legible in every supported theme:

- section heading;
- explanatory subtitle;
- Resume session control when applicable;
- search field;
- sort ComboBox and popup items;
- Grid mode control;
- List mode control;
- Compact mode control;
- current selected-mode state;
- recent-file card title;
- metadata line;
- last-opened line;
- unavailable/moved-file status;
- pin/star state;
- thumbnails;
- empty state;
- context menu.

### 4.2 Resume session state contract

The visual state must be derived from actual recovery/session state, not colour tricks.

- no valid previous session: `Visibility.Collapsed` or equivalent true absence;
- valid previous session: visible;
- valid but temporarily unavailable for a clear reason: visible with explicit disabled state and explanatory tooltip only if such a state is meaningful;
- never place the control on screen with foreground approximately equal to background;
- never show a dead action on first launch.

### 4.3 Grid/List/Compact state contract

All three mode controls must always be visible when the Recent surface is visible.

The active mode must have at least two independent visual cues, for example:

- selected/pressed surface;
- accent border;
- stronger font weight;
- small selected glyph.

Do not rely on a tiny foreground-colour shift as the only selected-state cue.

### 4.4 Recent card interaction

The approved card-hover treatment remains:

- approximately 3 px upward translation;
- soft shadow increasing on hover;
- stronger border/accent response;
- no aggressive zoom;
- approximately 120–160 ms lift-in;
- approximately 150–200 ms settle-out;
- no layout reflow or card collision.

Apply this only to genuinely card-like interactive surfaces such as tool cards, Recent cards and task cards. Ribbon/nav controls remain visually stable and use simpler hover/pressed states.

## 5. Phase C — Contrast and legibility standard

### 5.1 Contrast goal

Although AsantePDF is a native desktop application rather than a website, use WCAG-style contrast thresholds as a practical engineering floor:

- normal text: target at least 4.5:1;
- large/bold text: target at least 3:1;
- important non-text UI boundaries/focus indicators: target at least 3:1 against adjacent surfaces where applicable.

Disabled controls may be lower contrast than enabled controls, but they must remain recognizable as controls and readable enough to understand what is disabled. Do not use opacity so low that controls appear missing.

### 5.2 Automated contrast probe

The theme runtime self-test should:

- instantiate the real MainWindow shell where feasible;
- render Light and Dark states;
- explicitly locate high-risk named controls;
- compute effective foreground/background for text-bearing controls;
- walk upward to find the nearest opaque background;
- flag severe contrast failures;
- write a machine-readable report listing element name/type, text, foreground, background and ratio;
- save screenshots for human review.

The test must include controls that previously failed visually:

- `ResumeSessionButton`;
- `GridViewButton`;
- `ListViewButton`;
- `CompactViewButton`;
- Recent sort control;
- Home major headings;
- sidebar navigation;
- Local-first processing card;
- status bar;
- title search;
- Open PDF button;
- disabled Active Document state when no document is open.

### 5.3 Screenshot evidence

Store CI artifacts for at least:

- `home-light.png`;
- `home-dark.png`;
- `home-light-after-dark-switch.png`;
- `recent-grid-light.png`;
- `recent-grid-dark.png`;
- `recent-list-light.png`;
- `recent-list-dark.png`;
- `recent-compact-light.png`;
- `recent-compact-dark.png`;
- `document-light.png`;
- `document-dark.png`;
- `settings-light.png`;
- `settings-dark.png`;
- `task-center-light.png`;
- `task-center-dark.png`;
- representative dialog screenshots.

CI screenshot generation is evidence, not acceptance by itself. Humans must still review them.

## 6. Phase D — PDF-open reliability redesign

### 6.1 Opening pipeline

The PDF-open path must become an explicit staged state machine rather than an uncontrolled burst of asynchronous work.

Recommended stages:

1. validate path and file existence;
2. validate extension/basic readability;
3. create/open foreground PDFium document/renderer;
4. read minimum document metadata required to establish page count;
5. create tab/session model;
6. populate page collection without triggering uncontrolled render callbacks;
7. render the foreground page;
8. display the usable document workspace;
9. mark the foreground open as successful;
10. start secondary tasks in controlled background order/queues;
11. populate thumbnails lazily;
12. populate outline/bookmarks;
13. populate annotations/comments;
14. populate attachments;
15. build text/search data lazily/on demand where practical;
16. persist recent/session state only after the document has reached a coherent state.

### 6.2 Foreground vs secondary responsibilities

Only operations required to show the first usable page should block foreground open.

Secondary systems should be allowed to fail independently:

- thumbnails;
- bookmarks;
- annotation inventory;
- attachment inventory;
- search/text indexing;
- PDF Doctor signals;
- metadata enrichment;
- recent thumbnail caching.

### 6.3 PDFium concurrency rule

All direct PDFium native execution in the process must use one documented process-global synchronization gate unless a specific API has been proven safe for concurrent use and explicitly exempted with evidence.

The source-contract audit must fail when a service directly calls PDFium APIs without going through the approved native gate.

Services requiring audit include at least:

- foreground renderer;
- thumbnail renderer;
- text selection/text geometry;
- search/text extraction;
- bookmarks/outlines;
- annotations;
- attachments;
- metadata/security inspection;
- split view renderers;
- any PDFium-backed diagnostics.

### 6.4 Do not solve concurrency only by locking everything forever

The global gate is a safety mechanism, not a substitute for good scheduling.

Reduce work at open time:

- render only visible/near-visible pages;
- do not pre-render all pages;
- do not build full-document text geometry immediately unless required;
- defer annotation/attachment enumeration until its sidebar mode or Inspector needs it where practical;
- use cancellation when a tab closes before background work completes;
- cancel stale render requests when zoom/page/view mode changes;
- coalesce duplicate thumbnail requests;
- give foreground rendering priority over background thumbnails.

## 7. Phase E — Failure containment and diagnostics

### 7.1 Exception boundary requirements

Every secondary subsystem launched after PDF open must have an exception boundary that converts failure into degraded functionality rather than process termination.

Examples:

- thumbnail task exception → show thumbnail placeholder and log failure;
- outline exception → show “Bookmarks unavailable for this document” and preserve workspace;
- annotation enumeration exception → show annotation feature unavailable for this PDF and preserve workspace;
- attachment exception → show attachments unavailable and preserve workspace;
- search index exception → allow viewing and other editing, with search error state;
- PDF Doctor exception → Doctor-specific error, not application exit.

### 7.2 Fatal/open error UX

If the foreground page cannot render:

- keep the main application alive;
- show a professional error window;
- explain that the original file was not modified;
- state the likely operation that failed;
- offer Retry when meaningful;
- offer Open Logs;
- offer Copy Details;
- offer Close Document/return Home;
- never dump a raw stack trace as the primary user message.

### 7.3 Logging

For acceptance builds, logs should record ordered milestones such as:

- startup entered;
- resolved theme;
- main window ready;
- open requested path;
- PDFium foreground open began/completed;
- foreground render began/completed;
- document workspace became usable;
- thumbnail queue began/completed/cancelled;
- outline/annotation/attachment stages began/completed/failed;
- tab closed/cancellation requested;
- unhandled dispatcher/AppDomain/task exceptions.

Do not log sensitive passwords or document content.

## 8. Phase F — Realistic regression corpus

### 8.1 Fixture classes

Maintain a legally redistributable or generated test corpus covering:

1. small ordinary text PDF;
2. 10–30 page mixed text PDF;
3. 100+ page document;
4. image-heavy PDF;
5. scanned-image PDF;
6. document with bookmarks/outlines;
7. document with annotations;
8. document with AcroForm fields;
9. rotated pages;
10. mixed page sizes/orientations;
11. encrypted/password-protected PDF for unlock/security tests;
12. awkward but valid PDF that stresses parsing;
13. Unicode metadata/text;
14. high-resolution pages;
15. multiple simultaneous documents.

Where repository size makes checked-in binaries impractical, generate deterministic fixtures during CI or fetch only pinned public/test assets with checksums under an explicit release-test mechanism.

### 8.2 Repetition/stress protocol

The PDF-open gate should include repeated cycles, for example:

- open → foreground render → thumbnails begin → close;
- repeat 10–20 times;
- alternate Light/Dark between cycles;
- open a second PDF before first background work completes;
- switch tabs during thumbnail generation;
- close one tab while another remains open;
- reopen from Recent;
- restart app and Resume session;
- exercise Grid/List/Compact after recent history has populated.

The gate fails on any unexpected process exit, unhandled exception, deadlock or timeout.

## 9. Phase G — Layout and DPI acceptance

### 9.1 Scaling matrix

Validate at:

- 100%;
- 125%;
- 150%;
- 175%;
- 200%.

For each scale, validate at least:

- maximized window;
- normal desktop-sized window;
- declared minimum window size;
- one intermediate narrow width.

### 9.2 Surfaces to inspect

At each representative scale inspect:

- Home hero;
- Quick Tools;
- standalone tools;
- Recent toolbar and cards;
- left navigation;
- title bar/search;
- document tabs;
- ribbon groups;
- Edit & Annotate group;
- page navigation/zoom controls;
- page sidebar;
- Inspector;
- PDF Doctor;
- Task Center drawer;
- Settings;
- Welcome/onboarding;
- About/Diagnostics;
- operation errors;
- print options;
- annotation dialogs;
- security/configuration dialogs.

### 9.3 Explicit visual rejection conditions

Reject a candidate if any of the following is visible:

- text clipping;
- overlapping text/icons;
- controls partially outside their container;
- controls hidden without an intentional responsive alternative;
- toolbar items compressed to unreadable widths;
- tiny text below the agreed readable baseline;
- selected state indistinguishable from unselected state;
- disabled state indistinguishable from missing content;
- Light/Dark mixed surfaces;
- foreground/background combinations that appear washed out;
- excessive unstructured empty space caused by broken responsive layout;
- taskbar covered by normal maximize;
- drawer/panel collapse changing the root application layout unexpectedly.

## 10. Phase H — Installed Program Files verification

### 10.1 Required sequence

The final release candidate gate must execute this exact family of operations against one frozen source commit:

1. clean-source assertion;
2. exact .NET SDK selection;
3. Release x64 compilation;
4. source-contract audits;
5. smoke tests;
6. self-contained Windows publish;
7. bundle pinned qpdf/Tesseract/LibreOffice/PDFium/runtime dependencies;
8. run published-copy functional tests;
9. build production Inno Setup installer;
10. silently install the exact generated installer;
11. launch the Program Files executable;
12. run Light/Dark theme runtime probe on installed executable;
13. open realistic multi-page PDF in installed executable;
14. require foreground render completion;
15. require controlled thumbnail completion or documented bounded progress;
16. keep application alive for a post-open soak period;
17. repeat in Dark mode;
18. verify Recent state;
19. verify Grid/List/Compact;
20. restart;
21. verify session persistence and Resume;
22. verify settings persistence;
23. verify multiple-document behaviour;
24. run final PDF operation self-tests;
25. verify PDF/Open With registration and Start Menu shortcut;
26. write checksums/release receipt;
27. silently uninstall;
28. verify application files and registration are removed;
29. package installer and evidence;
30. upload artifact.

### 10.2 Installed-build evidence

Retain:

- installer SHA-256;
- source commit SHA;
- workflow run ID;
- engine-version manifest;
- theme runtime report;
- contrast report;
- Light/Dark screenshots;
- PDF-open stress report/log;
- installed-copy functional-test pass flag;
- uninstall-cleanup evidence.

A candidate without this evidence is not release-ready.

## 11. Phase I — Acceptance state machine

The old binary distinction between “implemented” and “accepted” is not enough for active stabilization.

For every affected requirement use the following evidence progression:

1. **IMPLEMENTED** — source exists;
2. **AUTOMATED VALIDATION PASSED** — source audits/build/tests pass;
3. **INSTALLED-BUILD VALIDATION PASSED** — the Program Files copy passes the required automated scenarios;
4. **VISUAL/MANUAL ACCEPTANCE PASSED** — the user or designated reviewer has actually seen/used the feature on Windows and accepts it;
5. **ACCEPTED** — all evidence required by the master requirement exists.

The repository’s existing allowed matrix labels can remain, but notes/evidence must explicitly identify these intermediate milestones. Do not collapse them into `ACCEPTED` prematurely.

## 12. Phase J — Requirement-level impact

The failed candidate directly reopens or blocks acceptance for at least these master requirements:

- 3 Home experience;
- 4 Session persistence/recovery, because Resume must be visibly correct;
- 7 Professional ribbon, because alignment/icon/contrast acceptance remains relevant;
- 8 Coherent colour system and complete theming;
- 12 Search where themed search surfaces are affected;
- 13 Sidebar where selected/disabled/contrast states are affected;
- 17 task/progress visual behaviour;
- 18 Task Center;
- 22 Inspector;
- 23 annotations where ribbon/dialog visual acceptance is affected;
- 35 Settings;
- 36 error/recovery UX;
- 37 performance perception/responsiveness;
- 38 accessibility/high DPI;
- 39 first launch;
- 40 About/diagnostics;
- 42 Home/Workspace/Task architecture;
- 43 release-quality engineering standard;
- 44 context-aware UI;
- 45 Recent files Grid/List/Compact/thumbnails;
- 46 visible theme switching;
- 48 contextual Resume/session recovery;
- 49 identity where light/dark compatibility must be verified.

The PDF-open crash additionally blocks the overall 1.0 release even if it is not itself a standalone numbered requirement, because requirements 3, 5, 10–13, 22–29, 37, 42 and 43 depend on a stable open document workspace.

## 13. Phase K — Repository and CI cleanup required during stabilization

The stabilization pass must also remove engineering noise that can hide real failures.

### 13.1 Temporary carriers

`dev-patches/*.ps1` are staging carriers only. Once a coherent batch is validated and promoted:

- ordinary source must contain the actual changes;
- consumed carriers must be deleted;
- clean-source validation must run with no patch directory;
- the final release gate must refuse staged carriers.

### 13.2 Workflow permissions

Do not let a validation job fail after successful runtime tests merely because it attempted to push a workflow-file modification without the necessary GitHub workflow permission.

Promotion logic should avoid staging workflow files from bot-generated changes unless the workflow has the required permission. Workflow-definition changes should be made explicitly through an authorized repository write and validated separately.

### 13.3 Trigger hygiene

`FINAL_GATE_TRIGGER.txt` is a deliberate release-gate trigger, not a permanent source file whose incidental edits should launch expensive release builds. Use it intentionally and remove/reset it when appropriate after a final-gate run.

### 13.4 Old scratch branches

The previously-created unused `development/master-49-*` scratch branches contain no needed implementation and should be deleted when branch deletion is available, to reduce continuation confusion.

## 14. Phase L — Concrete acceptance checklist for the next installer

Before handing the next installer to the user, engineering must verify all items below.

### Theme

- [ ] startup Light is uniformly Light;
- [ ] startup Dark is uniformly Dark;
- [ ] Light → Dark is atomic;
- [ ] Dark → Light is atomic;
- [ ] repeated Light → Dark → Light → Dark works;
- [ ] late-created Recent view changes theme;
- [ ] Task Center changes theme;
- [ ] Settings changes theme;
- [ ] dialogs/popups/context menus are themed;
- [ ] no white-on-white or near-white-on-white headings;
- [ ] no dark-text-on-dark-surface failures;
- [ ] disabled controls remain understandable;
- [ ] brand colours remain restrained and intentional.

### Recent

- [ ] Resume visible only when a valid session exists;
- [ ] Resume legible in both themes;
- [ ] search legible in both themes;
- [ ] sort control and popup legible in both themes;
- [ ] Grid visible in both themes;
- [ ] List visible in both themes;
- [ ] Compact visible in both themes;
- [ ] active view unmistakable;
- [ ] thumbnails render;
- [ ] metadata legible;
- [ ] pin/star legible;
- [ ] card hover lift works without reflow.

### PDF opening

- [ ] ordinary text PDF opens;
- [ ] multi-page PDF opens;
- [ ] image-heavy PDF opens;
- [ ] scanned PDF opens;
- [ ] bookmark PDF opens;
- [ ] annotation/form PDF opens;
- [ ] 100+ page PDF opens;
- [ ] thumbnails cannot crash the process;
- [ ] bookmark failure cannot crash the process;
- [ ] annotation failure cannot crash the process;
- [ ] attachment failure cannot crash the process;
- [ ] search/text failure cannot crash the process;
- [ ] repeated open/close cycles survive;
- [ ] multiple tabs survive;
- [ ] tab close during background work survives;
- [ ] Recent reopen survives;
- [ ] Resume survives;
- [ ] Light and Dark both survive.

### Layout

- [ ] 100% scaling;
- [ ] 125% scaling;
- [ ] 150% scaling;
- [ ] 175% scaling;
- [ ] 200% scaling;
- [ ] maximized keeps Windows taskbar available;
- [ ] declared minimum size remains usable;
- [ ] ribbon overflow is discoverable;
- [ ] Edit & Annotate remains aligned;
- [ ] no clipped Welcome content;
- [ ] Task Center drawer does not replace/collapse root app;
- [ ] Inspector and page sidebar remain usable;
- [ ] no tiny or washed-out metadata.

### Installed build

- [ ] exact installer installed to Program Files;
- [ ] installed EXE passes theme runtime probe;
- [ ] installed EXE passes multi-page open stress;
- [ ] installed EXE stays alive after foreground open and thumbnail work;
- [ ] installed EXE passes core final self-test;
- [ ] Open With registration correct;
- [ ] Start Menu shortcut correct;
- [ ] settings/session persistence correct;
- [ ] uninstall removes registration/application;
- [ ] artifact and checksum retained.

### Human acceptance

- [ ] user reviews Home Light screenshot;
- [ ] user reviews Home Dark screenshot;
- [ ] user reviews document workspace Light screenshot;
- [ ] user reviews document workspace Dark screenshot;
- [ ] user reviews Recent controls;
- [ ] user verifies a real PDF opens on their machine;
- [ ] user verifies live theme switching on their machine;
- [ ] user reports no blocker-level visual defects in the reviewed surfaces;
- [ ] only then move relevant requirements to `ACCEPTED`.

## 15. Definition of stabilization complete

This stabilization plan is complete only when all of the following are true at the same time:

1. theme architecture uses one semantic palette and does not cache historical control colours;
2. Light and Dark whole-shell tests pass;
3. live switching works repeatedly without mixed-theme visual trees;
4. Recent Resume/Grid/List/Compact controls are visibly correct in both themes;
5. no known blocker-level contrast defects remain;
6. the process-global PDFium safety rule is enforced;
7. foreground PDF open is staged and responsive;
8. secondary PDF subsystems have failure containment;
9. realistic multi-page/repeated-open stress tests pass;
10. actual UI screenshots are retained and reviewed;
11. DPI/window-size acceptance matrix is completed;
12. the exact installed Program Files build passes the expanded gate;
13. the user verifies that a real PDF opens on their machine without AsantePDF closing;
14. the user verifies Light and Dark appearance on their machine;
15. the acceptance ledger is updated with evidence;
16. no affected master requirement is marked `ACCEPTED` without its required evidence;
17. the candidate is only then eligible to move toward stable `1.0.0`.

## 16. Immediate execution order from the current branch

From the current state, execute in this order:

1. finish and validate the semantic theme-resource refactor;
2. correct any compile/test defects in the new whole-shell theme probe;
3. run Light/Dark whole-shell screenshot/contrast tests;
4. validate Recent Resume/Grid/List/Compact explicitly;
5. complete the process-global PDFium serialization audit;
6. validate the staged foreground-open/background-secondary pipeline;
7. add/verify subsystem exception containment;
8. expand generated/test PDFs beyond a one-page fixture;
9. run repeated open/close/multi-tab stress in both themes;
10. promote only after the Windows development gate is green;
11. remove all consumed patch carriers;
12. run a clean no-patch Windows gate;
13. deliberately trigger the heavyweight installed-copy release gate;
14. require the installed copy to pass theme probe + realistic PDF-open stress + final functional self-test;
15. retain screenshots, logs, reports, checksums and artifact metadata;
16. give the user the GitHub Actions artifact link, not a large ChatGPT attachment;
17. have the user retest the actual installed build;
18. update the defect ledger and implementation matrix from that evidence;
19. repeat until no release blocker remains;
20. only after manual acceptance consider stable `1.0.0`.

---

# Part III — Non-negotiable continuation instructions

Any agent or developer continuing AsantePDF must read this file before declaring the RC49 stabilization work complete.

The hands-on screenshots that caused this plan are authoritative failed acceptance evidence. Do not dismiss them because later source inspection looks correct.

Do not reintroduce a testing shortcut that disables Recent tracking, thumbnails, recovery/session behaviour or other normal-user features merely to make PDF-open tests easier to pass. The release gate must resemble actual product use.

Do not use a one-page toy PDF as the sole PDF-open stability test.

Do not infer Dark-mode correctness from a dark title bar. Whole-shell consistency is required.

Do not infer control visibility from `Visibility=Visible` in XAML. A control that is visually indistinguishable from its background is functionally absent for acceptance purposes.

Do not infer PDF-open reliability from a successful PDFium unit call. The actual WPF document-open pipeline, background tasks and installed executable must survive together.

Do not call a release candidate “final” until the exact installed build and the user’s hands-on acceptance agree.

The controlling priority is:

**theme correctness → PDF opening stability → error containment → visual/layout audit → installed-build verification → remaining functionality**
