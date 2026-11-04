# Android design — camera-shell

This is a visual refinement of Olympus View for Android, aligned with the website's [Unslop redesign](UNSLOP_DESIGN.md) and the project-local [unslop skill](../.agents/skills/unslop/SKILL.md) by Damir Sokolovsky (CC BY 4.0).

## Direction

- **Product** — inspect, download and delete files from Olympus and OM System Wi-Fi cameras.
- **Character** — precise, tactile, understated.
- **World** — matte camera chassis, optical viewfinders, crisp photographs.
- **Moment** — real photo/video thumbnails take the color; screen controls remain neutral.
- **Signature** — muted coral for primary focus/selection, green only for downloaded/success, red for destructive/error actions.

## Implementation

- `lib/theme/olympus_theme.dart` defines the shared Material 3 dark theme and component styles.
- `lib/constants.dart` shares the primary, success, background, outline, button and error colors across existing widgets.
- `lib/main.dart` applies the theme globally (including dialogs, buttons, picker menus and progress bars).
- Gallery, file filter sheet, download progress indicators and file tiles no longer use old purple/navy literal colors.
- Full-screen image preview intentionally keeps a black canvas to avoid distracting from the photograph.
- No new packages and no changes to camera protocol, download queue, file operations or Wi-Fi behavior.

## Design checks

1. Flutter analyzer and complete widget/unit test suite.
2. Android APK/AAB builds in GitHub Actions.
3. Manual visual QA on an Android device for connection/QR, gallery grid/list, selected & downloaded states, date filter, photo/video preview, download/delete progress, dialog contrast and 3 localized languages.
4. Check light text on off-white buttons and the legibility of muted labels.
5. Test both phone portrait and a wide tablet display.

The design is a separate change from application release packaging. No release tag should be created without a synchronized version bump and changelog.
