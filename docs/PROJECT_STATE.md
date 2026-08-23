# AsantePDF Project State

Updated after the first fully successful RC10 Windows release gate and the subsequent product-specification reset.

## What RC10 proved

RC10 is the current working engineering baseline, not the finished product design.

The real Windows release pipeline reached a full green run on GitHub Actions run `32636807149`. That release path demonstrated:

- exact .NET SDK selection and Windows x64 compilation
- automated smoke tests
- self-contained Windows x64 publish
- staging and validation of qpdf, Tesseract OCR and LibreOffice
- published-app final candidate self-test
- production Inno Setup compilation
- silent installation of the exact generated `AsantePDF Setup.exe`
- installed Program Files copy verification
- release receipt, checksums and evidence generation

The RC10 installer produced by that gate had SHA256:

`16db141f34da837bfbe55e842c4aa7f93b2a6b1af83d6987514a07c0c2070802`

## What RC10 did NOT prove

RC10 must not be treated as product-complete. Hands-on inspection of the installed application showed that the existing shell is still the legacy-style functional interface. It does not satisfy the intended Home experience, Document Workspace, visual system, navigation architecture, context-awareness and other requirements in the master specification.

A passing backend or installer test is not evidence that a UI requirement is accepted.

## Product source of truth now

Future work is governed by:

1. `../ASANTEPDF_MASTER_UPGRADE_SPEC.md`
2. `../IMPLEMENTATION_MATRIX.md`
3. `ASANTEPDF-VISUAL-DIRECTION.md`
4. `design/target-home.svg`
5. `design/target-document-workspace.svg`
6. `../AGENTS.md`

The master specification contains **45 numbered requirements**, including the context-aware interface rules and the deeper Recent-files system added after RC10.

## Target architecture

The next generation of AsantePDF must be structured around three connected experiences:

- Home / Launcher
- Document Workspace
- Task System

The redesign should be coordinated rather than implemented as random isolated button patches.

## Next implementation phase

Before claiming individual requirements are complete, audit the current codebase against all 45 matrix rows. Then implement in architectural batches. The first major batch should establish the product shell that later features can safely plug into:

- application-wide design tokens and Light/Dark/Follow Windows theme infrastructure
- real Home / Launcher mode
- real Document Workspace mode
- multi-document document/session model
- substantial grouped ribbon/command surface
- context-aware command state calculation
- left navigation shell
- contextual right Inspector / PDF Doctor shell
- persistent Recent/session/settings foundation
- Task System/Task Center foundation

This batch must preserve the working PDF engines rather than rewrite them merely for visual reasons.

After each coherent batch:

- update `IMPLEMENTATION_MATRIX.md`
- add or extend automated tests
- visually inspect relevant UI requirements
- run the real Windows release gate when release-critical integration is reached

## Final-release rule

Do not promote RC10 directly to AsantePDF 1.0 final. A future final release requires material master-spec items to be accepted and the redesigned installed application to survive the full Windows release gate again.
