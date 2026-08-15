# Publishing Olympus View on Google Play

This document describes the Play-specific release path. It is intentionally separate from the GitHub APK release path.

## Important: two signing channels

Olympus View already has directly distributed APKs signed with the legacy Android debug certificate:

```text
SHA-256: 3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e
```

Keep that key only for GitHub/direct APK updates so existing sideloaded installations can continue to update.

Do **not** use that debug certificate to publish the app on Google Play. Google Play requires a proper release/upload key and Play App Signing.

### Recommended Play model

- GitHub APK: legacy key preserved for backward-compatible sideload updates.
- Google Play AAB: new strong **upload key** kept by the developer.
- Google Play installed APKs: signed by the **Play App Signing key** protected by Google.

Because the Play signing identity will differ from the legacy sideload identity, a user moving from the old GitHub APK to the Play version may need to uninstall the old APK once before installing the Play build.

## 1. Generate a dedicated Play upload key

PowerShell:

```powershell
keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\olympus-play-upload.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000 `
  -alias olympus-play-upload
```

Use a strong unique password and store it in a password manager. Do not reuse the legacy `android` debug-keystore password.

Verify it:

```powershell
keytool -list -v `
  -keystore "$env:USERPROFILE\olympus-play-upload.jks" `
  -alias olympus-play-upload
```

Keep at least two protected copies of this JKS.

## 2. Add the Play upload key to GitHub Actions

Convert the JKS to one-line Base64:

```powershell
$path = "$env:USERPROFILE\olympus-play-upload.jks"
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
Set-Content -NoNewline `
  -Path "$env:USERPROFILE\olympus-play-upload.base64.txt" `
  -Value $b64
```

Repository -> Settings -> Secrets and variables -> Actions -> New repository secret.

Create:

| Secret | Value |
| --- | --- |
| `PLAY_UPLOAD_KEYSTORE_BASE64` | Entire contents of `olympus-play-upload.base64.txt` |
| `PLAY_UPLOAD_KEYSTORE_PASSWORD` | Strong JKS password |
| `PLAY_UPLOAD_KEY_ALIAS` | `olympus-play-upload` |
| `PLAY_UPLOAD_KEY_PASSWORD` | Key password |

Delete the temporary Base64 text file after the secret has been saved. Keep the JKS backups.

## 3. Build the Google Play bundle

GitHub Actions -> `Google Play AAB` -> `Run workflow`.

The workflow:

1. restores the Play upload key only inside the ephemeral runner;
2. runs `flutter analyze`;
3. runs the test suite;
4. builds a release APK and checks 16 KB page-size compatibility;
5. builds the release Android App Bundle;
6. uploads `OlympusView-GooglePlay.aab` as a workflow artifact;
7. removes the temporary signing files.

Do not upload the GitHub-release APK to Play. Upload the AAB produced by `Google Play AAB`.

## 4. Android configuration already prepared

The project currently uses:

```text
targetSdk 36
compileSdk 36
AGP 8.10.1
Gradle 8.11.1
JDK 17
NDK 28.2.13676358
```

CI also checks native libraries for 16 KB page-size compatibility.

Android permissions are scoped for current Play requirements:

- `NEARBY_WIFI_DEVICES` on Android 13+ with `neverForLocation`;
- `ACCESS_FINE_LOCATION` only through Android 12L / API 32 for legacy Wi-Fi APIs;
- no broad storage permission on Android 10+;
- `WRITE_EXTERNAL_STORAGE` only through Android 9 / API 28;
- downloaded photos use Android MediaStore on Android 10+;
- application backup is disabled because locally stored camera credentials are sensitive.

## 5. Privacy Policy

Use this public URL in Play Console after GitHub Pages deploys the merged documentation:

```text
https://dpolarov.github.io/olympus-view-and-delete/privacy.html
```

The same Privacy Policy is linked from the application's About dialog.

## 6. Data Safety — important ML Kit disclosure

Do not answer the Data Safety form with a blanket "no data collected".

The app itself does not upload photos, QR contents, Wi-Fi passwords, SSIDs, or physical location to an Olympus View backend. However, Android QR scanning is implemented with Google ML Kit through `mobile_scanner`.

Google's ML Kit disclosure documentation says that ML Kit may collect technical data for diagnostics and usage analytics, including:

- device information;
- application/package and version information;
- per-installation/device-or-other identifiers;
- performance metrics;
- API configuration;
- feature events and error codes.

Google states that the QR/image input and recognition result are processed on-device and are not sent to Google. Google also states that the listed ML Kit telemetry is encrypted in transit and is not shared by ML Kit with third parties.

When completing the Play form, compare the current form categories with the current ML Kit disclosure documentation. At minimum, review the categories covering:

- **App info and performance / Diagnostics**;
- **Device or other IDs**;
- purposes related to diagnostics and usage analytics.

Do not declare physical location as collected by Olympus View: the legacy location permission exists only because Android <= 12L ties certain Wi-Fi APIs to location permission, and Olympus View does not derive or transmit physical location.

## 7. App content declarations

Review these in Play Console -> Policy and programs -> App content:

- Privacy Policy: provide the URL above.
- Ads: Olympus View contains no advertising SDK; answer according to the shipped build.
- App access: no account/login is required.
- Target audience: choose the age groups the app is actually intended for. Do not select child age groups unless the app is intentionally designed for children and you are prepared to meet Families requirements.
- Content rating: complete the IARC questionnaire accurately.
- Data Safety: complete it using the ML Kit notes above and the behavior of all dependencies in the final AAB.

## 8. Store listing materials

Prepare before production review:

- app name: `Olympus View`;
- short description;
- full description;
- 512x512 Play Store icon;
- feature graphic 1024x500;
- Android phone screenshots;
- support/contact email in the developer profile / store listing;
- privacy policy URL;
- category (Photography is the natural fit, but choose based on the final listing).

Be explicit in the listing that Olympus View is an **unofficial** application and is not affiliated with Olympus / OM System / OM Digital Solutions.

## 9. Versioning

The current Flutter version is read from `pubspec.yaml` in the form:

```text
version: major.minor.patch+versionCode
```

Every AAB uploaded to the same Play application must use a version code larger than every version code previously uploaded there.

Before the first Play production candidate, bump the version intentionally, for example:

```text
version: 1.4.0+6
```

Do not reuse a Play version code after it has been uploaded.

## 10. First Play Console upload

For a new Play application:

1. Create the application in Play Console using the existing Android package ID `com.flynew.photomanager` unless you intentionally decide to start a different package identity.
2. Configure Play App Signing and let Google protect the app-signing key.
3. Register/use the upload key created above.
4. Start with Internal testing.
5. Upload `OlympusView-GooglePlay.aab`.
6. Resolve all automated pre-launch / policy warnings.
7. Test install and core camera flows from the Play-delivered build.
8. Move to Closed/Open testing or Production when the Play build is verified.

## 11. Release checks before production

- `flutter analyze` is clean.
- all Flutter tests pass.
- Android APK/AAB builds pass on GitHub Actions.
- 16 KB page-size compatibility check passes.
- QR permission flow tested on Android 13+.
- camera reconnect tested on Android 13+.
- photo download tested on Android 10+ via MediaStore.
- Android 9 legacy storage permission path tested if Android 9 support matters.
- Privacy Policy URL is publicly reachable without login.
- Data Safety matches the actual final AAB and all bundled SDKs.
- Play pre-launch report has no blocking crash/ANR/accessibility issues.
