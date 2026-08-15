# Android release signing

The GitHub release workflow signs Android APK/AAB files with a private JKS keystore restored from GitHub Actions secrets.

## Important: preserve the existing signing key

If an APK has already been distributed, Android updates must be signed with the same app-signing certificate. Do not generate a new key if you still have the key used for previous Olympus View releases.

The v1.3.1 build configuration used `android/key.properties` when present and otherwise fell back to the debug key. Before publishing the next Android release, identify which key was used for the APK you intend to update.

## 1. Create a keystore on Windows (only for a new signing identity)

Flutter's Android signing documentation recommends RSA 2048 and a long validity period. In PowerShell:

```powershell
keytool -genkey -v `
  -keystore "$env:USERPROFILE\olympus-upload.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias olympus-upload
```

If `keytool` is not in `PATH`, run `flutter doctor -v`, find the path shown after `Java binary at:`, and use `keytool.exe` from the same `bin` directory.

Use a strong unique password. The key password may be the same as the keystore password. Store the password in a password manager.

Verify the keystore:

```powershell
keytool -list -v `
  -keystore "$env:USERPROFILE\olympus-upload.jks" `
  -alias olympus-upload
```

Record the SHA-256 certificate fingerprint. It is useful for checking that future releases use the same signing identity.

## 2. Back up the keystore

Keep at least two protected copies of `olympus-upload.jks`, for example:

- the working copy on your development machine;
- an encrypted offline/backup copy in a separate location.

Do not commit the JKS file, `android/key.properties`, passwords, or the base64 representation to Git. The repository `.gitignore` excludes JKS/keystore files and `android/key.properties`.

If you manage APK signing yourself and lose the app-signing key, you cannot create normal updates for existing installations.

## 3. Convert the JKS to base64 for GitHub Actions

PowerShell:

```powershell
$path = "$env:USERPROFILE\olympus-upload.jks"
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
Set-Content -NoNewline `
  -Path "$env:USERPROFILE\olympus-upload.base64.txt" `
  -Value $b64
```

`olympus-upload.base64.txt` is still secret material. Delete it after adding the GitHub secret; keep the original JKS in your protected backup locations.

## 4. Add repository secrets

Open the repository on GitHub and go to:

`Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`

Create exactly these four secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Entire contents of `olympus-upload.base64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore/store password |
| `ANDROID_KEY_ALIAS` | `olympus-upload` (or the alias of your existing key) |
| `ANDROID_KEY_PASSWORD` | Password for that key alias |

GitHub Actions restores the JKS only inside the ephemeral runner, verifies the keystore/alias with `keytool`, creates `android/key.properties`, builds the APK and AAB, and removes the restored signing files at the end of the Android job.

## 5. Optional local release signing

To test the same key locally, create `android/key.properties` (it is ignored by Git):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=olympus-upload
storeFile=C:\\Users\\YOUR_USER\\olympus-upload.jks
```

Then run:

```powershell
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

## 6. Compare an existing APK with the keystore

If Android SDK Build Tools are installed, obtain the certificate fingerprint of an existing release APK:

```powershell
apksigner verify --print-certs .\OlympusView.apk
```

Then print the certificate fingerprint from the JKS:

```powershell
keytool -list -v `
  -keystore "$env:USERPROFILE\olympus-upload.jks" `
  -alias olympus-upload
```

The SHA-256 certificate fingerprints must match if the new APK is intended to update the existing installed app.

## 7. Publish a release

After the CI/PR is merged, update `version:` in `pubspec.yaml`, commit it, then push a matching tag, for example:

```powershell
git tag v1.3.2
git push origin v1.3.2
```

The `Release` workflow will create a GitHub Release containing the signed Android APK/AAB and Windows/Web archives.

## Google Play note

For Google Play, prefer Play App Signing: keep the upload key private and let Play protect the app-signing key. For direct APK distribution through GitHub Releases, the APK must continue to use the same app-signing certificate for seamless updates.
