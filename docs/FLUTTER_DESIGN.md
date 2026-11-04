# Olympus View application — camera-shell design

The Android app now uses the same visual direction as the Olympus View website, following the project-local [unslop skill](../.agents/skills/unslop/SKILL.md) by Damir Sokolovsky (CC BY 4.0).

## Direction

- **Product:** a tool for transferring, reviewing and deleting files on Olympus / OM System cameras over local Wi-Fi.
- **Character:** precise, tactile, understated.
- **World:** matte graphite camera bodies, modest hardware status indicators and optical glass.
- **Rich moments:** the actual camera photos and video previews. The interface itself stays neutral.
- **Signature:** a restrained coral accent for the action or selection that matters, not for decoration.

## Flutter palette

The single source of truth is `lib/theme/olympus_theme.dart`, used by `lib/main.dart`. Legacy `k*Color` constants in `lib/constants.dart` refer to the same palette.

| Role | Color | Purpose |
| --- | --- | --- |
| Background | `#141719` | The app scaffold |
| Surface | `#191D1E` | App bars, connection status, bottom controls |
| Card | `#202425` | Photo labels, dialogs, sheets |
| Raised surface | `#292E30` | Popup menus, inputs, transient panels |
| Border | `#3A4041` | Quiet structural dividers |
| Main text | `#F2F1ED` | Camera names, actions and headings |
| Secondary text | `#B4BABB` | Status and metadata |
| Coral | `#EB7780` | Primary action, selected files and download progress |
| On coral | `#171819` | Legible text on primary controls |
| Sage | `#79C6A0` | Files already downloaded, successful connection |
| Danger | `#E58D85` | File deletion and errors |
| Preview canvas | `#0F1213` | Photo viewing; keeps the picture dominant |

**No purple or navy defaults:** every Material 3 surface container and surface tint is explicitly set. Future screens should prefer `Theme.of(context).colorScheme` and shared `OlympusPalette` rather than hard-coded color literals.

## UI design choices

- Phone toolbar exposes connection, download and delete actions; secondary commands move into the overflow menu (including RAW/JPG filter, list/grid view, language and About).
- Gallery entries use neutral borders, a quiet sage downloaded marker, coral selected state, and adaptive grids for phone/tablet/desktop widths.
- The bottom area offers **Select files** and **Select all**. Deleting occurs from the explicit toolbar action with the existing confirmation dialog.
- Full-screen photographs remain on a near-black canvas; toolbars and transfer progress match the surrounding app surfaces.
- Dialogs, date pickers, menus, text inputs and progress indicators are styled centrally. No animations or fake camera visuals are added.

## Functional constraints and verification

- Camera API traffic, preview preloading, download queues, background Android service, delete confirmations and download history are unaffected.
- Keep EN/RU/UK menu labels aligned with existing locale controls. Do not introduce a second theme framework.
- Run `flutter analyze` and `flutter test`; Android builds are verified by `.github/workflows/flutter-ci.yml`.
- UI changes can merge as development updates without changing the published Android version. The release checklist in `AGENTS.md` remains required when publishing a new APK.
