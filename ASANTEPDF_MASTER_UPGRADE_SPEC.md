## AsantePDF Master Upgrade Specification

1. **Rename and fully rebrand PDF Rescue as AsantePDF** 
   - Product name: **AsantePDF** 
   - Descriptor where appropriate: **PDF Toolkit** 
   - Rename application title, installer, Start Menu shortcut, desktop shortcut and Windows Open With entry. 
   - Update executable metadata, About screen, installer metadata, release filenames and internal user-facing references. 
   - Remove remaining “PDF Rescue” branding. 
   - Develop a clean visual identity for AsantePDF that works in both light and dark mode. 
   - Keep branding professional and restrained rather than plastering the name everywhere. 

2. **Redesign the Windows installer** 
   - Windows PDF integration must happen automatically. 
   - Remove the checkbox asking whether to add AsantePDF to Windows Open With. 
   - Register AsantePDF for PDFs during every normal installation. 
   - Desktop shortcut can remain optional if desired. 
   - Investigate the current restart request. 
   - Avoid requesting a Windows restart unless genuinely unavoidable. 
   - Handle VC++ runtime installation intelligently so an already suitable runtime is not unnecessarily disturbed. 
   - Application should normally be usable immediately after setup completes. 
   - Update installer branding to AsantePDF. 
   - Preserve proper uninstall behaviour and remove the relevant AsantePDF registrations cleanly during uninstall. 

3. **Replace the current empty screen with a proper Home experience** 
   - Do not show a giant blank document workspace when nothing is open. 
   - Home screen should include: 
     - Recent files 
     - Pinned files 
     - Resume previous session 
     - Open PDF 
     - Merge PDFs 
     - Split PDF 
     - Compress PDF 
     - OCR PDF 
     - Convert PDF 
     - Images to PDF 
     - PDF Doctor 
     - Other important standalone tools 
   - Recent files should appear as polished cards/grid items with thumbnails where practical. 
   - Show useful metadata such as filename, last opened date and possibly location. 
   - Allow removing an individual item from Recent. 
   - Allow pinning important documents. 
   - Dragging files onto Home should work. 

4. **Add proper session persistence** 
   - Closing AsantePDF must not reset the application to a blank state. 
   - Remember recently opened PDFs. 
   - Remember last page for each PDF. 
   - Remember zoom level and sensible viewing state. 
   - Restore open tabs from the previous session when enabled. 
   - Preserve sidebar/view state where sensible. 
   - Offer **Resume previous session**. 
   - Add crash/session recovery. 
   - Recover unsaved working state where technically possible without risking the original document. 
   - Keep autosave/recovery files separate from originals. 

5. **Implement a real multi-document tab system** 
   - Multiple PDFs can be open simultaneously. 
   - Each PDF gets its own tab. 
   - Tabs show filenames. 
   - Active tab must be visually obvious. 
   - Tabs have proper close buttons. 
   - Modified/unsaved documents show an unsaved indicator. 
   - Tabs can be reordered. 
   - `Ctrl+Tab` switches tabs. 
   - `Ctrl+W` closes the active tab. 
   - Middle-click closing where appropriate. 
   - Tab overflow UI when too many documents are open. 
   - Reopen last closed tab. 
   - Opening the result of an operation can create a new tab. 
   - Preserve each tab's page, zoom and scroll position independently. 

6. **Add split-view PDF comparison** 
   - Any two PDF tabs should be viewable side by side within the same window. 
   - Each side can scroll independently. 
   - Each side can zoom independently. 
   - Optional linked scrolling. 
   - Optional synchronized zoom. 
   - Easy swap left/right. 
   - Allow aligning equivalent page numbers when comparing two versions. 
   - Exit split view without closing either document. 
   - This should work particularly well for comparing an original PDF against an OCR, compressed, repaired or edited version. 

7. **Redesign the entire command toolbar/ribbon** 
   - Remove the current long wall of identical grey buttons. 
   - Build a proper substantial command surface. 
   - Buttons should have: 
     - large clickable areas 
     - professional icons 
     - clear labels 
     - themed backgrounds 
     - subtle borders 
     - generous spacing 
     - hover state 
     - pressed state 
     - active state 
     - disabled state 
     - focus state 
   - Do not use emoji as interface icons. 
   - Use one coherent professional icon family. 
   - Major command groups could include: 
     - Open 
     - Save 
     - Undo/Redo 
     - Pages 
     - Edit 
     - Annotate 
     - Convert 
     - Protect 
     - Optimize 
     - PDF Doctor 
   - Important everyday commands stay immediately accessible. 
   - Less common commands can live inside grouped dropdown buttons. 
   - Dangerous operations such as Delete and permanent Redaction need appropriate visual distinction. 
   - Dropdown arrows should be integrated cleanly into buttons. 
   - The ribbon should have enough height to feel intentional rather than compressed. 
   - Traditional menus can remain, but menus and ribbon should complement each other rather than duplicate everything blindly. 

8. **Add a coherent colour system and complete dark mode** 
   - Proper application-wide light theme. 
   - Proper application-wide dark theme. 
   - Theme all: 
     - ribbon 
     - menus 
     - context menus 
     - tabs 
     - sidebars 
     - document background 
     - Inspector 
     - dialogs 
     - modals 
     - task progress UI 
     - Home screen 
     - recent cards 
     - buttons 
     - icons 
     - selections 
     - scrollbars where practical 
     - hover/focus/pressed states 
   - Accent colour should be used deliberately. 
   - Avoid random decorative colour. 
   - Maintain good contrast. 
   - Add theme preference to Settings. 
   - Optionally support Follow Windows Theme. 

9. **Upgrade PDF page navigation** 
   - Add visible Previous and Next page controls. 
   - Add editable page number field: 
     - `12 / 49` 
   - Typing a page number and pressing Enter jumps there. 
   - Page indicator updates automatically when scrolling. 
   - Keyboard navigation: 
     - Left Arrow 
     - Right Arrow 
     - Page Up 
     - Page Down 
     - Home for first page 
     - End for last page 
   - Preserve mouse wheel scrolling. 
   - Navigation should remain responsive even for large PDFs. 

10. **Upgrade zoom and document viewing** 
   - Keep zoom in/out. 
   - Add: 
     - Fit Page 
     - Fit Width 
     - Actual Size / 100% 
     - custom zoom percentage 
     - continuous scrolling 
     - single-page view 
     - optional two-page view 
   - Sensible zoom keyboard shortcuts. 
   - Remember preferred viewing mode. 
   - Better navigation experience for long PDFs. 

11. **Make PDF text genuinely interactive** 
   - Real text selection using click and drag. 
   - Selection should follow actual characters/words/lines. 
   - `Ctrl+C` copies selected text. 
   - Right-click > Copy. 
   - Highlight selected text directly. 
   - Searchable PDFs should work immediately. 
   - OCR-generated searchable PDFs should also become selectable/searchable. 
   - Text selection must coexist properly with scrolling and annotations. 

12. **Add first-class document search** 
   - `Ctrl+F`. 
   - Search inside the active PDF. 
   - Highlight all matches. 
   - Next/previous match. 
   - Show `current result / total results`. 
   - Search results pane with snippets where useful. 
   - OCR output should participate in search. 
   - Clear search without disturbing document position. 

13. **Upgrade the left navigation sidebar** 
   - Sidebar should support multiple modes rather than thumbnails only: 
     - Pages 
     - Bookmarks / Outline 
     - Search Results 
     - Comments / Annotations 
     - Attachments where supported 
   - Collapsible. 
   - Resizable. 
   - Selected page clearly highlighted. 
   - Thumbnail loading should remain responsive. 

14. **Implement proper multi-page selection and page management** 
   - `Ctrl+Click` page selection. 
   - `Shift+Click` ranges. 
   - Select All. 
   - Apply actions to multiple selected pages: 
     - Rotate 
     - Delete 
     - Extract 
     - Duplicate 
     - Reorder 
     - Crop where appropriate 
   - Drag thumbnails to reorder. 
   - Clearly show what pages an operation will affect. 
   - Support undo for page-management operations. 

15. **Make tools usable even when no PDF is already open** 
   - OCR must remain available from Home/toolbar. 
   - Compress must remain available. 
   - PDF Doctor must remain available. 
   - Merge must remain available. 
   - Split must remain available. 
   - Convert must remain available. 
   - Images to PDF must remain available. 
   - Repair/Optimize must remain available. 
   - Protect/Unlock should be launchable independently. 
   - Extract/export operations should be available through dedicated workflows where sensible. 
   - Clicking a standalone tool opens a file-selection/configuration workflow instead of simply being disabled. 
   - Only genuinely canvas-dependent editing operations should require an already-open PDF. 

16. **Create proper configuration dialogs for every significant operation** 
   - Do not trigger complex operations immediately after clicking them. 
   - OCR configuration should include relevant options such as: 
     - input PDF 
     - language 
     - page range 
     - searchable PDF output 
     - other supported OCR output options 
     - output location 
   - Compression should allow meaningful compression options. 
   - Conversion should allow output format/settings. 
   - Split should allow page/range rules. 
   - Merge should allow file ordering. 
   - Export should allow page and image options. 
   - Protect should allow password/security choices. 
   - Each tool gets options that actually apply to it. 
   - Use consistent modal styling across all tools. 

17. **Create an application-wide task/progress framework** 
   - Operations such as OCR, conversion and compression must show progress. 
   - Show: 
     - task name 
     - current stage 
     - percentage 
     - progress bar 
     - item/page count where useful 
     - elapsed time where useful 
   - Example: 
     - `Recognising page 18 of 64` 
   - Provide Cancel. 
   - Cancellation should be graceful. 
   - Clean up incomplete temporary output after cancellation. 
   - Never corrupt the source file. 
   - Long-running operations should not freeze the interface. 

18. **Add a Task Center** 
   - Users should not be trapped inside a modal throughout a ten-minute OCR operation. 
   - Allow progress dialog to minimize into a task indicator. 
   - Let the user continue working in other tabs. 
   - Task Center should show: 
     - Running 
     - Queued 
     - Completed 
     - Failed 
     - Cancelled 
   - Allow retrying failures. 
   - Allow opening successful outputs. 
   - Support multiple queued jobs. 
   - Build future batch operations on the same system. 

19. **Create proper completion workflows** 
   - Finishing an operation should not merely say “Done.” 
   - Completion screen/modal should offer: 
     - Open in new tab 
     - Replace/open in current context where appropriate 
     - Open containing folder 
     - Rename / Save As 
     - Run another operation 
     - Close 
   - Make original versus result obvious. 
   - Side-by-side comparison with the original should be easy. 

20. **Default to non-destructive processing** 
   - OCR, compression, repair, optimization and other transformations should preserve originals by default. 
   - Create new output files unless the user explicitly chooses otherwise. 
   - Make overwrite behaviour explicit. 
   - Never silently destroy the original. 
   - Allow results to open beside the original in a new tab. 

21. **Redesign PDF Doctor** 
   - When nothing has been inspected, do not show fake recommendations. 
   - Initial state: 
     - Not analysed yet 
     - proper **Run PDF Doctor** button with a professional icon 
   - After analysis show an understandable health status: 
     - Healthy 
     - Attention Needed 
     - Damaged 
   - Show actual findings. 
   - Group findings where useful: 
     - Structure 
     - Content 
     - Optimization 
     - Security 
   - Possible diagnostics: 
     - PDF version 
     - page tree 
     - xref integrity 
     - malformed objects 
     - encryption 
     - fonts 
     - images 
     - forms 
     - annotations 
     - OCR/searchability 
     - compression potential 
     - fast-web-view state 
   - Recommendations should only appear when supported by findings. 
   - Rename awkward commands: 
     - Repair Copy → Repair PDF 
     - Compress Copy → Compress PDF 
     - Optimize Web → Optimize for Web 
   - Preserve original behind the scenes by default. 
   - Inspector can show a concise status. 
   - Main Doctor command can open a richer diagnostics experience. 

22. **Redesign the Inspector** 
   - Inspector should be contextual rather than permanently showing mostly static information. 
   - When the document itself is selected, show document properties. 
   - When pages are selected, show page-related properties/actions. 
   - When text is selected, show text-related actions. 
   - When an annotation is selected, show annotation properties. 
   - When an image/object is selected, show relevant object information where supported. 
   - Inspector should be collapsible and resizable. 
   - Do not waste screen width when it has nothing useful to show. 

23. **Build a proper annotation system** 
   - Highlight. 
   - Underline. 
   - Strikeout. 
   - Notes/comments. 
   - Shapes. 
   - Freehand markup where practical. 
   - Choose colour. 
   - Choose opacity. 
   - Existing annotations can be selected, edited or deleted. 
   - Annotation behaviour should work naturally with text selection. 

24. **Implement proper Save behaviour** 
   - `Save` 
   - `Save As` 
   - `Save a Copy` where useful. 
   - `Ctrl+S`. 
   - `Ctrl+Shift+S`. 
   - Show modified-state indicator on tabs. 
   - Closing modified tabs prompts: 
     - Save 
     - Don’t Save 
     - Cancel 
   - Closing the entire application with several unsaved documents should handle them intelligently. 

25. **Strengthen Undo/Redo** 
   - Undo and Redo need predictable behaviour. 
   - Support relevant edits such as: 
     - page reorder 
     - rotation 
     - page deletion 
     - crop 
     - annotations 
     - text/markup changes where supported 
   - Buttons should show enabled/disabled state correctly. 
   - Keyboard: 
     - `Ctrl+Z` 
     - `Ctrl+Y` 
   - Consider an operation-history view if practical. 

26. **Add proper drag-and-drop support** 
   - Drop a PDF onto Home to open it. 
   - Drop multiple PDFs onto Merge. 
   - Drop images onto Images to PDF. 
   - Drop files onto compatible tool dialogs. 
   - Reorder pages by dragging thumbnails. 
   - Reorder tabs by dragging. 
   - Potentially drag a tab into split view. 

27. **Add robust context menus** 
   - Right-click selected text. 
   - Right-click a page thumbnail. 
   - Right-click a tab. 
   - Right-click a recent file. 
   - Right-click canvas where appropriate. 
   - Only show actions relevant to the clicked object. 
   - Use the same professional icons and themes as the rest of the app. 

28. **Create a coherent keyboard shortcut system** 
   - `Ctrl+O` Open 
   - `Ctrl+S` Save 
   - `Ctrl+Shift+S` Save As 
   - `Ctrl+F` Search 
   - `Ctrl+P` Print 
   - `Ctrl+W` Close tab 
   - `Ctrl+Tab` Next tab 
   - `Ctrl+Shift+Tab` Previous tab 
   - `Ctrl+Z` Undo 
   - `Ctrl+Y` Redo 
   - `Ctrl+C` Copy text 
   - Page navigation shortcuts 
   - Zoom shortcuts 
   - First/last page shortcuts 
   - Tooltips should display shortcuts. 

29. **Add proper printing** 
   - `Ctrl+P`. 
   - Printer selection. 
   - Page range. 
   - Current page. 
   - Selected pages. 
   - Number of copies. 
   - Orientation where relevant. 
   - Scale/Fit options. 
   - Print preview where practical. 
   - Respect document page sizes. 

30. **Improve conversion workflows** 
   - Office document → PDF 
   - PDF → Word 
   - PDF → Excel 
   - PDF → PowerPoint 
   - Images → PDF 
   - PDF pages → Images 
   - Each conversion should have a proper standalone UI. 
   - Select source without opening it first. 
   - Show progress. 
   - Show completion options. 
   - Open result in a new tab where the result is PDF. 
   - Open containing folder for non-PDF results. 
   - Expose sensible options before conversion. 

31. **Strengthen OCR as a proper feature** 
   - Launch independently or from an open PDF. 
   - Configuration dialog. 
   - Language selection. 
   - Page range. 
   - Searchable PDF output. 
   - Progress per page. 
   - Cancellation. 
   - Proper completion screen. 
   - Open OCR result as a new tab beside original. 
   - OCR result should be searchable and selectable. 
   - Remember preferred OCR language/defaults. 

32. **Add batch processing** 
   - Select multiple PDFs for supported operations. 
   - Configure operation once. 
   - Queue all files. 
   - Show individual progress. 
   - Show per-file success/failure. 
   - Retry failed items. 
   - Open output folder afterward. 
   - Use the same Task Center architecture. 

33. **Build proper PDF security workflows** 
   - Protect PDF. 
   - Password/open-password support where supported. 
   - Explain security options in plain language. 
   - Permission controls where technically supported. 
   - Unlock/decrypt when the user has the required password. 
   - Clearly explain what will happen to the output. 
   - Keep original safe by default. 
   - Integrate security state into PDF Doctor/Inspector. 

34. **Recent-files privacy controls** 
   - Remove a single item from Recent. 
   - Clear recent history. 
   - Disable recent-file tracking. 
   - Disable thumbnails if desired. 
   - Clear cached thumbnails. 
   - Settings option controlling whether previous session automatically reopens. 

35. **Create a real Settings experience** 
   - Theme: 
     - Light 
     - Dark 
     - Follow Windows 
   - Default zoom. 
   - Default page-view mode. 
   - Reopen last session. 
   - Recent-file behaviour. 
   - OCR language/defaults. 
   - Default output folder. 
   - Output naming rules. 
   - Overwrite behaviour. 
   - Recovery/autosave preferences. 
   - Update preferences. 
   - Other genuinely useful preferences as the app develops. 
   - Avoid turning Settings into a junk drawer. 

36. **Professional error and recovery UX** 
   - Do not show cryptic technical exceptions to ordinary users. 
   - Error screens should explain: 
     - what failed 
     - whether the original is safe 
     - what the user can do next 
   - Actions can include: 
     - Retry 
     - Change Settings 
     - Choose another file 
     - Show Details 
     - Copy Error Details 
     - Open Log Folder 
   - Keep detailed technical logs for troubleshooting. 
   - Failed operations should appear in Task Center. 

37. **Improve performance perception** 
   - Keep UI responsive while PDFs render. 
   - Load thumbnails progressively. 
   - Avoid blocking the main thread during OCR/conversion/compression. 
   - Show activity indicators where something is genuinely loading. 
   - Large documents should not make the application appear frozen. 
   - Cancel expensive background work when no longer needed. 

38. **Accessibility and high-DPI support** 
   - Keyboard-only navigation. 
   - Visible keyboard focus. 
   - Screen-reader labels for controls. 
   - Proper contrast in both themes. 
   - Scalable UI/text. 
   - High-DPI awareness. 
   - Proper behaviour at Windows scaling levels such as 125%, 150%, 175% and 200%. 
   - Do not make buttons/icons microscopic on high-resolution screens. 

39. **Create a tasteful first-launch experience** 
   - No giant tutorial. 
   - Brief introduction to: 
     - opening PDFs 
     - drag-and-drop 
     - quick tools 
     - recent/session recovery 
   - Make it easy to dismiss. 
   - Do not repeat it every launch. 
   - Home should remain useful after onboarding disappears. 

40. **Build a proper About and diagnostics section** 
   - AsantePDF version. 
   - Build number. 
   - Architecture. 
   - Bundled engine versions: 
     - PDFium 
     - qpdf 
     - Tesseract 
     - LibreOffice 
     - relevant runtimes 
   - Copyright/product information. 
   - Third-party notices/licenses. 
   - Update status. 
   - Copy system/build information for troubleshooting. 

41. **Plan a proper application update mechanism** 
   - Check for updates. 
   - Show current and available version. 
   - Download/install update cleanly. 
   - Do not silently replace software without user knowledge. 
   - Maintain user settings/session data during upgrades. 
   - Future releases should continue through the Windows release gate before distribution. 

42. **Establish one coherent application architecture** 
   - Treat AsantePDF as three connected experiences: 
     - **Home / Launcher** 
     - **Document Workspace** 
     - **Task System** 
   - Home handles recent files and standalone tools. 
   - Document Workspace handles viewing, editing, tabs, split view and annotations. 
   - Task System handles OCR, conversion, repair, compression and other background jobs. 
   - Avoid continuing to bolt isolated buttons onto one giant window. 

43. **Maintain the release-quality engineering standard** 
   - Implement the accumulated changes as a coordinated batch rather than random one-off patches. 
   - Run static checks. 
   - Compile on actual Windows. 
   - Run automated functionality tests. 
   - Publish the real application. 
   - Bundle required local engines. 
   - Build the actual AsantePDF Setup.exe. 
   - Silently install that exact installer on Windows CI. 
   - Launch the installed Program Files copy. 
   - Test that installed copy. 
   - Verify new UI architecture does not break existing PDF operations. 
   - Produce a downloadable installer only after the release gate passes. 
   - Keep using an isolated CI branch/carrier if a dedicated repository is not yet available, rather than blocking the work or contaminating another project's main branch.

44. **Make the entire interface context-aware**
   - Document-specific controls must automatically disable when no PDF is active.
   - That includes zoom, page navigation, Fit Page/Width, page editing, annotations, Save, Print and similar commands.
   - Disabled controls should look clearly unavailable, with proper disabled icon/text states.
   - As soon as a document becomes active, the applicable controls become available.
   - Switching tabs should recalculate what commands are valid for that document.
   - Commands that do not require an open document, such as Open, Merge, OCR, Compress, Convert and PDF Doctor, remain available.
   - No clickable controls that lead nowhere or operate on nonexistent state.
   - Tooltips can explain why something is unavailable where useful.
   - Home mode and Document mode must genuinely behave differently rather than merely hiding the PDF canvas.

45. **Recent files must support multiple layouts with real PDF thumbnails**
   - Default can be a polished **Grid view**.
   - Every PDF card should display a generated thumbnail, preferably the first page unless a better representative page is available.
   - Thumbnail generation should happen asynchronously and be cached so Home does not become sluggish.
   - Give the user a view selector:
     - **Grid**
     - **List**
     - **Compact**
   - Remember the user's preferred view.
   - Grid view gives thumbnails visual priority.
   - List view can show a smaller thumbnail plus filename, location, page count, last opened and other useful metadata.
   - Compact view is for people who want to fit many documents on screen.
   - Broken/moved files should be identified gracefully rather than simply failing when clicked.
   - Right-click actions should support Open, Open in New Window if supported, Pin, Remove from Recent, Show in Folder and Remove Missing Entry.
   - Recent documents should support sorting by:
     - Last opened
     - Name
     - Date modified
   - Pinned documents should remain easy to reach.
   - Search/filter Recent becomes useful once the history grows.
   - Opening a Recent file should resume the stored page/zoom/view position when appropriate.

---

## Canonical visual targets

The following repository images are part of this specification and must be reviewed before UI work:

- `docs/design/target-document-workspace.jpg`
- `docs/design/target-home.jpg`

They define the intended product language for AsantePDF: a polished modern desktop PDF application with a deliberate dark theme, strong hierarchy, professional iconography, generous spacing, real Home and Document modes, substantial command surfaces, multi-document tabs, sidebars, contextual inspector/doctor information, and clear active/disabled/hover states.

The images are visual direction, not permission to omit functionality. Where a visual reference and a functional requirement appear to conflict, preserve the functionality while keeping the same design language.

## Completion rule

This specification is the product contract. A release is not "finished" because it compiles, installs, or passes backend smoke tests. It is finished only when the applicable requirements above have been implemented, visibly verified, recorded in the implementation matrix, and the resulting Windows installer has passed the full release gate.
