# Android release signing

The GitHub release workflow signs Android APK/AAB files with the same certificate that was used by the previously published Olympus View APKs.

## Existing signing identity

The published `v1.3.1/OlympusView.apk` is signed with the Android debug certificate from this development machine. Its certificate fingerprint is:

```text
SHA-256: 3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e
DN: C=US, O=Android, CN=Android Debug
```

The matching keystore was confirmed at:

```text
C:\Users\us123\.android\debug.keystore
```

with alias:

```text
androiddebugkey
```

Because APKs are already distributed with this signing identity, do **not** generate a new signing key for normal updates. Android requires future APK updates to be signed with the same certificate.

Although this file is named `debug.keystore`, for this project it is now effectively the production app-signing key and must be preserved.

## 1. Make a dedicated protected copy

On Windows PowerShell:

```powershell
Copy-Item `
  "$env:USERPROFILE\.android\debug.keystore" `
  "$env:USERPROFILE\olympus-release.jks"
```

Verify the copy:

```powershell
keytool -list -v `
  -keystore "$env:USERPROFILE\olympus-release.jks" `
  -alias androiddebugkey `
  -storepass android `
  -keypass android
```

The SHA-256 fingerprint must be:

```text
37:86:A4:1C:93:2C:63:18:3F:C3:6D:D3:88:CB:6B:E3:97:77:53:92:D3:BF:6E:7F:4F:B1:6D:C2:8C:AE:84:1E
```

Keep at least two protected copies of `olympus-release.jks` in separate locations. Do not commit the JKS file to Git.

## 2. Convert the JKS to base64 for GitHub Actions

PowerShell:

```powershell
$path = "$env:USERPROFILE\olympus-release.jks"
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
Set-Content -NoNewline `
  -Path "$env:USERPROFILE\olympus-release.base64.txt" `
  -Value $b64
```

`olympus-release.base64.txt` contains the complete private keystore encoded as text. Treat it exactly like the JKS itself and delete it after adding the GitHub secret.

## 3. Add GitHub Actions repository secrets

Open:

`Repository` -> `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`

Create these four secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Entire contents of `C:\Users\us123\olympus-release.base64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | `android` |
| `ANDROID_KEY_ALIAS` | `androiddebugkey` |
| `ANDROID_KEY_PASSWORD` | `android` |

The passwords are the standard Android debug-keystore defaults. Security therefore depends primarily on keeping the keystore file/private base64 value secret.

## 4. What the GitHub workflow does

For a tagged release, `.github/workflows/release.yml`:

1. reads the four repository secrets;
2. restores the JKS only inside the ephemeral GitHub Actions runner;
3. checks that the alias exists;
4. verifies that the signing certificate SHA-256 is exactly:

   `3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e`;

5. creates `android/key.properties` temporarily;
6. builds the signed APK and AAB;
7. removes the restored JKS and `key.properties` at the end of the job.

If a different keystore is accidentally uploaded to the GitHub secret, the release workflow fails before building the Android release.

## 5. Optional local release signing

Create `android/key.properties` locally (the repository ignores this file):

```properties
storePassword=android
keyPassword=android
keyAlias=androiddebugkey
storeFile=C:\\Users\\us123\\olympus-release.jks
```

Then run:

```powershell
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

APK output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

AAB output:

```text
build\app\outputs\bundle\release\app-release.aab
```

Verify the resulting APK certificate with Android SDK Build Tools:

```powershell
$apksigner = Get-ChildItem `
  "$env:LOCALAPPDATA\Android\Sdk\build-tools\*\apksigner.bat" `
  | Sort-Object FullName -Descending `
  | Select-Object -First 1

& $apksigner.FullName verify --print-certs `
  .\build\app\outputs\flutter-apk\app-release.apk
```

The SHA-256 must remain:

```text
3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e
```

## 6. Publish a release

After the CI/PR is merged, update `version:` in `pubspec.yaml`, commit it, then push a matching tag, for example:

```powershell
git tag v1.3.2
git push origin v1.3.2
```

The `Release` workflow will create a GitHub Release containing the signed Android APK/AAB and Windows/Web archives.

## Important security note

A standard Android debug key is not ideal as a long-term production signing key because its alias/password are conventional and well known. However, changing the signing certificate now would break direct APK upgrade compatibility with existing installations. Preserve this keystore carefully for the lifetime of the direct-distribution app.
