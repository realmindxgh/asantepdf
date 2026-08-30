# AsantePDF UX Improvement Guide

## Purpose

This document is the working UX guide for AsantePDF. It captures the recommended interaction, feedback, task-management, navigation, accessibility, and document-workspace improvements in implementation priority order.

The recommendations are intended to guide product and engineering decisions. Where a recommendation depends on technical feasibility, preserve the user-facing principle even if the exact implementation changes.

## UX improvement backlog

I’d create the UX improvement backlog in this order:

1. **Global operation/progress system**

   This is the biggest gap. Any operation lasting more than roughly half a second should acknowledge the click immediately.

   It should support:
   - `Preparing…`
   - `Processing…`
   - `34%`
   - `Finalising…`
   - `Completed`
   - `Failed`
   - `Cancelled`

   For long-running work such as OCR, Word conversion, PDF Doctor, compression, merging, splitting, export, etc., show a compact persistent activity indicator in the top-right area.

   Example:

   **Converting to Word · 42%**

   Clicking it opens Task Center.

   The user should never have to wonder, “Did I actually click it?”

2. **Per-button busy states**

   The button that initiated an operation should temporarily change state.

   `To Word` → spinner + `Converting…`

   `Run PDF Doctor` → spinner + `Analysing…`

   `Save` → spinner briefly → checkmark

   Disable repeat invocation while that exact operation is running.

3. **Prominent background-task notifications**

   I can see the status bar already says:
   > Word export queued in Task Center. You can keep working.

   That is good behaviour, but visually it is far too easy to miss.

   When a task moves to the background, show a toast such as:

   **Word export started**

   You can continue working.

   `View progress`

   Then let the toast disappear while the Task Center badge remains.

4. **Task Center badge**

   Task Center should show its state without opening it.

   For example:

   `Task Center  ● 2`

   Or while something is running, a tiny animated progress ring beside the icon.

   Then:
   - blue = processing
   - green/check = recently completed
   - red badge = failed
   - number = queued/running tasks

5. **Proper Task Center task cards**

   Every task should show:
   - operation
   - file
   - progress
   - elapsed time
   - current stage
   - cancel
   - retry
   - open output
   - show output folder
   - error details when failed

   Example:

   **Export to Word**

   `reference-guide.pdf`

   █████████░░ 76%

   Converting page 9 of 12

   `Cancel`

6. **Indeterminate progress where percentage is impossible**

   Don't fake percentages.

   If AsantePDF genuinely cannot determine progress, use an animated progress bar/ring and meaningful stage text:

   `Starting LibreOffice…`

   `Preparing document…`

   `Generating output…`

   Stage information is often more reassuring than a bogus “67%”.

7. **Immediate document-opening feedback**

   When a PDF is large, opening should show a document skeleton rather than temporarily appearing frozen.

   Something like:

   **Opening report.pdf**

   Reading document structure…

   The canvas can appear first, then thumbnails populate progressively.

8. **Progressive thumbnail rendering**

   Don't wait for every thumbnail before displaying anything.

   Render:
   - visible page first
   - surrounding pages second
   - remaining thumbnails in background

   Thumbnail placeholders should show while generating.

9. **Search feedback**

   The search field currently gives very little visual guidance about its purpose.

   When searching inside a document:
   - show `Searching…`
   - then `7 matches`
   - highlight the current result
   - show `3 of 7`
   - Escape clears search
   - Enter / Shift+Enter navigates results

10. **Unsaved-change visibility**

    The document tab should communicate dirty state.

    `reference-guide.pdf *`

    Once saved, the indicator disappears.

    Closing an altered document should produce a proper:

    `Save / Don't Save / Cancel` interaction.

11. **Better save acknowledgement**

    Saving is one of those operations where silence creates anxiety.

    On Ctrl+S:

    - brief spinner or status
    - then `Saved`
    - optionally timestamp in status bar

    Example: `Saved · 16:52`

12. **Autosave/recovery**

    For an editor this capable, recovery is important.

    If the app crashes:

    **We recovered changes from your previous session.**

    That would dramatically improve trust.

13. **Navigation-state correction**

    This stood out in both screenshots.

    **Home appears selected while a document workspace is clearly active.**

    That creates conflicting information. If the user is editing a document, `Active Document` should visually represent the current workspace, or Home should stop appearing selected.

    One screen should not claim two different locations at once.

14. **Stronger distinction between navigation and actions**

    The left rail mixes:

    - destinations
    - workspace states
    - tools
    - storage

    It works, but could communicate hierarchy better.

    `Home / Recent / Starred`

    then workspace

    then system/storage areas.

    Active Document deserves stronger treatment when a PDF is open.

15. **Ribbon density reduction**

    The top ribbon is powerful but dense. At this resolution there are a lot of competing icons.

    I would keep the functionality but make groups more visually coherent:

    - File
    - History
    - Pages
    - Edit & Annotate
    - Convert

    The current group labels are already heading in that direction. Slightly stronger separation and spacing would make scanning easier.

16. **Adaptive ribbon**

    When the window gets narrower, don't squeeze labels until they become difficult to read.

    Collapse lower-priority commands into `More`.

    This would also improve laptop usability.

17. **Context-sensitive controls**

    Controls that cannot currently do anything should be disabled rather than appearing equally available.

    Examples:

    - undo when nothing can be undone
    - crop if no page selection is available
    - annotation properties when nothing is selected

    This reduces cognitive noise.

18. **Richer hover tooltips**

    Every ribbon action should have a good tooltip with shortcut where available.

    **Save As**

    Save the current PDF under a new filename.

    `Ctrl+Shift+S`

    This is especially useful because AsantePDF has many tools.

19. **Keyboard shortcut discovery**

    Ctrl+K is visible, which I like.

    Extend that philosophy. Show shortcuts in menus/tooltips and eventually add a keyboard shortcuts panel.

20. **Command palette**

    That large top search/control area could become extremely useful.

    Ctrl+K could search both commands and app destinations:

    `compress`

    → Compress PDF

    `dark`

    → Appearance: Dark

    `recent`

    → Go to Recent Documents

    That would be superb for power users.

21. **Right-click context menus**

    Page thumbnails should support:

    - rotate
    - duplicate
    - extract
    - delete
    - move
    - insert before/after
    - copy page
    - page properties

    Likewise document tabs should offer:

    - close
    - close others
    - close all
    - copy file path
    - show in Explorer

22. **Drag-and-drop page management**

    Users should be able to reorder pages by dragging thumbnails.

    Add a visible insertion line while dragging.

23. **Multi-page selection**

    Ctrl+click and Shift+click in thumbnails should enable bulk:

    - rotate
    - delete
    - extract
    - duplicate

24. **Sidebar resizing**

    Thumbnail and Inspector panels should be clearly resizable.

    The dividers exist visually, but the interaction affordance should become obvious when hovering.

25. **Remember panel sizes**

    If I make the thumbnail panel wider, AsantePDF should remember it.

    Same for Inspector visibility.

26. **Quick collapse controls**

    The Inspector has a collapse control, but it is visually understated.

    Make both left and right panels collapsible with obvious keyboard-accessible controls.

    This would be valuable for small screens.

27. **Focus/reading mode**

    Add a mode that hides:

    - left navigation
    - thumbnails
    - inspector
    - ribbon

    leaving almost the entire screen for the document.

    Something like `F11` or `Ctrl+Shift+F`.

28. **Better zoom interaction**

    The current zoom area is functional. I'd add:

    - Ctrl + mouse wheel
    - editable zoom field
    - presets
    - remembered per-document zoom if appropriate

29. **Fit Width / Fit Page state**

    Make whichever fit mode is active visually selected.

    At present they read mostly as normal buttons.

30. **Page navigation enhancement**

    Allow the page number field to accept:

    `17`

    Enter jumps straight to page 17.

    For large PDFs, that matters considerably.

31. **Document status strip**

    The bottom status bar could become more useful without getting noisy.

    Something like:

    `Ready | Page 2 of 2 | 100% | 214 KB | PDF 1.7 | Processed locally`

    During operations:

    `Converting to Word · 42% | Cancel`

32. **Use the status bar for secondary information, not primary feedback**

    This is important.

    Your current status-bar notification is useful, but users do not reliably look there after clicking a ribbon action. Primary action feedback belongs near the action or in a toast/activity indicator.

33. **Success feedback**

    Don't only design for loading and errors.

    After operations:

    - `PDF compressed`
    - `3 pages extracted`
    - `Saved`
    - `Word document ready`
    - `OCR complete`

    For generated files, include:

    `Open` and `Show in folder`.

34. **Actionable errors**

    Avoid generic:

    `Conversion failed.`

    Prefer:

    **Couldn't convert this PDF to Word**

    LibreOffice did not respond.

    `Retry` `View details`

35. **PDF Doctor progress**

    This is especially important because the Doctor appears prominently in the Inspector.

    After clicking it, the panel itself should transform into the analysis state:

    `Analysing structure…`

    spinner/progress

    then results gradually appear.

    That is much better than leaving the same “Run PDF Doctor” UI visible while something invisible happens.

36. **Document Doctor severity summary**

    Once analysis is complete, show something like:

    `Healthy`

    or

    `3 issues found`

    with severity counts:

    - 1 important
    - 2 advisory

37. **First-use micro-onboarding**

    The UI has enough capability that a brand-new user could miss major features.

    A very lightweight onboarding could point out:

    - ribbon
    - thumbnails
    - Inspector
    - Task Center
    - Ctrl+K

    No lengthy tour.

38. **Empty-state improvement**

    Home, Recent, Starred and Task Center should all have deliberate empty states.

    Example:

    **No recent documents yet**

    PDFs you open will appear here.

    `Open PDF`

39. **Recent-document context**

    Recent should ideally show:

    - filename
    - last opened
    - location
    - number of pages
    - pinned/starred state
    - open folder

40. **Drag PDF anywhere to open**

    The entire main window should accept PDF drag-and-drop, with a large overlay:

    **Drop to open PDF**

41. **Multiple-file opening**

    Dragging several PDFs should open them as tabs rather than silently choosing one.

42. **Tab improvements**

    Add:

    - unsaved marker
    - tooltip with full path
    - middle-click close
    - reorder by drag
    - context menu
    - overflow menu when many documents are open

43. **Close-tab protection during running jobs**

    If an operation depends on the document, AsantePDF needs explicit behaviour.

    Either:

    - task continues independently, or
    - explain that closing will cancel it.

44. **Background operation resilience**

    Conversion/OCR should survive switching between documents.

    The screenshots already hint at this philosophy with Task Center. Lean into it. It could become one of AsantePDF's best UX features.

45. **Cancel long operations**

    Anything taking several seconds should support cancellation where technically safe.

46. **Retry failed operations**

    Don't make the user reconstruct the operation from scratch.

47. **Completion history**

    Task Center should retain recent operations for the session, possibly across sessions.

    This answers:

    “Where did that Word file go?”

48. **Output destination clarity**

    Before or after conversion, make it obvious where generated content goes.

49. **Accessibility pass**

    Check:

    - keyboard navigation
    - visible focus rings
    - screen-reader names
    - target sizes
    - contrast
    - high-contrast Windows mode
    - 125/150/175/200% scaling

    The dark version looks attractive, but accessibility should be measured rather than judged by eye.

50. **Reduce tiny text in high-density regions**

    Some ribbon labels and Inspector metadata are approaching the lower comfortable limit.

    You have room to make a few secondary labels slightly larger.

51. **Better selection feedback**

    The selected thumbnail works well. Apply similarly strong selection treatment to:

    - selected annotations
    - selected pages
    - current toolbar mode
    - active fit mode
    - active panel

52. **Annotation-mode escape**

    Once Draw, Highlight, Redact etc. are selected, Esc should reliably return to selection/pointer mode.

53. **Dangerous action confirmation**

    Page Delete, Redact Apply, destructive optimisation, etc. need clear undo or confirmation depending on reversibility.

54. **Undo/redo history clarity**

    A dropdown on Undo/Redo could eventually show several recent operations.

55. **Recovery from accidental page deletion**

    Page deletion should be undoable immediately.

56. **Network/offline communication**

    The “Local-first processing / PDFs stay on this computer” card is excellent positioning.

    I would reinforce this only where relevant, perhaps with a small privacy indicator rather than repeatedly occupying sidebar space forever.

57. **Make the Local-first card dismissible**

    Once the user understands it, that large bottom-left card permanently consumes useful space.

    Allow dismiss or collapse, perhaps remembering the choice.

58. **First-run vs everyday UI**

    Some explanatory elements can disappear after the user becomes familiar with the product. The mature UI can therefore become cleaner without removing functionality.

59. **Explorer integration**

    Useful additions:

    - Open containing folder
    - copy path
    - drag current PDF out
    - Windows “Open with AsantePDF”
    - recent files jump list

60. **Window title information**

    Consider showing the current document name in the Windows title/taskbar context, especially when multiple app windows eventually exist.

## Visual inconsistencies to fix

There are also three visual inconsistencies I would specifically fix from these screenshots.

First, **Home looks selected while the user is editing a PDF**. That is the clearest navigation-state bug.

Second, **the ribbon commands have much stronger visual prominence than current application state**. The UI tells me very clearly what I *could* click, but less clearly what AsantePDF is *currently doing*. That is exactly why the invisible processing bothers you.

Third, **Task Center is architecturally the right idea, but it needs to become a first-class piece of the UX rather than merely somewhere background work gets sent**. Once we add the task badge, global progress indicator, toasts, cancellation, retry, completion actions and detailed task cards, the whole app will suddenly feel much more alive and trustworthy.

## UX Phase 1 implementation sequence

If I were turning this into an implementation sequence, I’d do **UX Phase 1** as:

**global task/progress system → button busy states → toast notifications → Task Center badge/cards → save/unsaved feedback → document-opening skeletons → PDF Doctor inline progress → navigation-state fix**

That single phase would make an enormous difference before we touch any cosmetic redesign.
