# AsantePDF 49-Item Master Checklist

This file is an always-visible continuation index for the full AsantePDF product contract.

**There are 49 master requirements. Not 45.** Future agents must not stop at item 45.

For the complete sub-requirements of items 1-45, read `ASANTEPDF_MASTER_UPGRADE_SPEC.md` in full. Items 46-49 below extend that specification and are equally mandatory.

## Master requirements

1. Rename and fully rebrand PDF Rescue as AsantePDF.
2. Redesign the Windows installer.
3. Replace the empty screen with a proper Home experience.
4. Add proper session persistence.
5. Implement a real multi-document tab system.
6. Add split-view PDF comparison.
7. Redesign the entire command toolbar/ribbon.
8. Add a coherent colour system and complete dark mode.
9. Upgrade PDF page navigation.
10. Upgrade zoom and document viewing.
11. Make PDF text genuinely interactive.
12. Add first-class document search.
13. Upgrade the left navigation sidebar.
14. Implement proper multi-page selection and page management.
15. Make tools usable even when no PDF is already open.
16. Create proper configuration dialogs for every significant operation.
17. Create an application-wide task/progress framework.
18. Add a Task Center.
19. Create proper completion workflows.
20. Default to non-destructive processing.
21. Redesign PDF Doctor.
22. Redesign the Inspector.
23. Build a proper annotation system.
24. Implement proper Save behaviour.
25. Strengthen Undo/Redo.
26. Add proper drag-and-drop support.
27. Add robust context menus.
28. Create a coherent keyboard shortcut system.
29. Add proper printing.
30. Improve conversion workflows.
31. Strengthen OCR as a proper feature.
32. Add batch processing.
33. Build proper PDF security workflows.
34. Add recent-files privacy controls.
35. Create a real Settings experience.
36. Add professional error and recovery UX.
37. Improve performance perception.
38. Add accessibility and high-DPI support.
39. Create a tasteful first-launch experience.
40. Build a proper About and diagnostics section.
41. Plan and implement a proper application update mechanism.
42. Establish one coherent application architecture.
43. Maintain the release-quality engineering standard.
44. Make the entire interface context-aware.
45. Recent files must support multiple layouts with real PDF thumbnails.
46. Add visible theme switching.
47. Keep AsantePDF completely free.
48. Add contextual session recovery.
49. Introduce the new Ghana-inspired AsantePDF identity.

## 46. Visible theme switching

- Provide a top-right Light/Dark toggle.
- Use professional sun/moon icons.
- Switching must be immediate.
- Settings must expose Light, Dark and Follow Windows.
- Persist the user's preference.

## 47. AsantePDF is completely free

- Remove all Premium, Upgrade and Subscription UI.
- Do not lock features behind payment.
- Do not impose payment-driven usage limits.
- Every feature in the 49-item product contract is available to every user.

## 48. Contextual session recovery

- Do not show Resume Last Session unless a genuinely resumable session exists.
- Do not expose dead or meaningless session actions on first launch.
- When recovery is available, communicate what will be restored.
- Session and crash-recovery state must remain separate from original PDFs.

## 49. New Ghana-inspired AsantePDF identity

- Replace the generic blue mark.
- Use a professional document-based identity.
- Core identity colours are red, gold/yellow, green and black.
- Prefer a folded or stacked document concept that can subtly form an A.
- The identity must work as an app icon, installer icon, taskbar icon, title-bar mark and full logo.
- It must work in light and dark contexts.
- Keep the main product UI tasteful instead of painting the entire interface in flag colours.

## Completion rule

No agent may call AsantePDF 1.0 complete until all 49 requirements have either been accepted or explicitly documented as not applicable with evidence. Code presence alone is not acceptance. UI requirements require hands-on visual/runtime verification, and release-critical requirements require the Windows release gate.