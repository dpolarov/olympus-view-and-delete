# Olympus View — WiFi File Manager for Olympus & OM System Cameras

> Manage, download, and delete photos on Olympus and OM System cameras over the camera's local WiFi network. Olympus View is an unofficial cross-platform alternative to OI.Share for Android, Windows, and Web.

**Current Android release:** v1.3.12+21 — September 28, 2026  
**Source:** https://github.com/dpolarov/olympus-view-and-delete  
**Latest release:** https://github.com/dpolarov/olympus-view-and-delete/releases/latest  
**Android APK:** https://github.com/dpolarov/olympus-view-and-delete/releases/latest/download/OlympusView-Android.apk

Olympus View is not affiliated with, endorsed by, or sponsored by OM Digital Solutions, Olympus Corporation, or OM System.

## Why Olympus View instead of OI.Share?

Olympus View focuses on camera file management:

- Delete files directly from a compatible camera over WiFi.
- Select and download groups of files instead of transferring them one by one.
- Keep Android downloads running in the background while the app is minimized or the screen is off.
- Remember successfully downloaded files with persistent green markers.
- Select all currently visible files carrying the downloaded marker, making it easy to remove already-copied photos from the camera in one batch.
- Choose whether the gallery shows **RAW only**, **JPG only**, or **RAW + JPG** when shooting paired files; camera video files remain visible in every still-photo filter mode.
- Run on Android, Windows, and in a browser.
- Inspect and build the source code yourself.

## Supported cameras

The project currently lists these WiFi-capable Olympus / OM System models:

- OM System OM-1
- OM System OM-1 Mark II
- OM System OM-5
- Olympus E-M1 Mark II
- Olympus E-M1 Mark III
- Olympus E-M5 Mark II
- Olympus E-M5 Mark III
- Olympus E-M10 Mark III
- Olympus E-M10 Mark IV
- Olympus TG-6
- Olympus TG-7
- Olympus E-PL10
- Olympus PEN E-P7

The implementation communicates with cameras using the Olympus OPC communication interface over local WiFi. Compatibility depends on the camera exposing the expected OPC endpoints and QR/connection format.

## Features

### QR-code connection

On Android, scan the QR code displayed by the camera. Olympus View decodes Olympus/OM System OIS1 and OIS3 QR formats and extracts the camera WiFi connection information.

### Browse photos and videos

Load the camera's file list with previews and browse in grid or list form. The app traverses camera folders and supports date filtering. Large grid tiles request a camera-supported 1024 px resized preview; the small thumbnail endpoint remains available as a fallback. Full-screen viewing prefers the camera's screennail preview and falls back to a 1920 px resize request. MOV, MP4, M4V, AVI, MTS and M2TS files remain visible independently of the RAW/JPG still-photo filter.

### Delete files from the camera

Long-press a file to enter selection mode, select one or more files, and delete them directly from the camera memory card over WiFi.

### Select by date

Select a file and use date-based selection to select files from the same date in one operation.

### RAW / JPG file-type filter

Choose **RAW only**, **JPG only**, or **RAW + JPG**. RAW includes ORF, DNG and generic RAW files; JPG includes JPG and JPEG. The selected mode is saved and restored the next time Olympus View starts. Video files are not hidden by this still-photo filter.

### Download files

Download selected photos and videos with progress information. On Android, downloaded photos are saved to user-accessible media storage and appear in the gallery. ORF, DNG and RAW files use the Android image MediaStore collection so they can be saved to `DCIM/OlympusView` like JPEG files.

### Background download on Android

Android transfers can continue while Olympus View is minimized or the screen is off. System notifications report progress and completion.

### Persistent downloaded markers and preview cache

Successfully transferred files receive a green downloaded marker that survives normal app restarts and updates. In selection mode, **Select downloaded** selects all currently visible green-marked files so they can be deleted from the camera after they have been safely copied. Gallery previews are cached persistently; v1.3.12 raises the cache from 150 to 1000 entries and makes background/Wi-Fi transitions retry interrupted preview requests instead of leaving broken tiles.

### In-app GitHub update flow

The direct GitHub APK build can check for newer GitHub releases. Download progress, waiting-for-network state, retry/cancel controls, and an Install action remain visible in the app. Camera auto-connect is paused while an application update needs internet so camera WiFi cannot silently stall the APK download.

The Google Play flavor disables external APK self-install/update behavior.

## How to use

1. Enable WiFi on the Olympus / OM System camera.
2. Android: open Olympus View and scan the QR code displayed by the camera.
3. Windows/Web: connect the computer to the camera's WiFi network and open Olympus View.
4. Wait for the file list and previews to load.
5. Long-press a file to enter file-selection mode.
6. Use selection tools for date-based selection or downloaded-file selection.
7. Download selected files, or delete selected files from the camera.
8. Open the file-type filter and choose **RAW only**, **JPG only**, or **RAW + JPG**. Olympus View remembers the choice for the next launch; video files remain visible.

## Downloads

### Android

Latest direct-install APK:

https://github.com/dpolarov/olympus-view-and-delete/releases/latest/download/OlympusView-Android.apk

### Windows

Latest portable Windows x64 build:

https://github.com/dpolarov/olympus-view-and-delete/releases/latest/download/OlympusView-Windows.zip

### Web

Latest Web build ZIP. Extract it, serve the directory over local HTTP (the ZIP includes a README), and connect the computer to the camera's WiFi network before using Olympus View.

https://github.com/dpolarov/olympus-view-and-delete/releases/latest/download/OlympusView-Web.zip

## Important signing migration in v1.3.6

Releases through v1.3.5 used a temporary legacy Android debug signing certificate. v1.3.6 introduced the permanent production signing identity.

Android does not allow an APK signed by an unrelated certificate to replace an installed application with the same package name. Therefore, users with direct APK versions **v1.3.5 or older must uninstall Olympus View and install v1.3.6 once**.

That uninstall clears Olympus View's local settings and downloaded-marker history. It does **not** delete photos already saved on the phone and does not delete files on the camera.

After v1.3.6 has been installed, later direct APK releases use the same permanent production signing identity and can update normally.

## Technical details

### Application

- Flutter 3.47.5 / Dart 3.13
- Material 3 UI
- Android package: `com.flynew.photomanager`
- Android build stack: Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20, Java/Kotlin 17, compileSdk 37, targetSdk 36.
- Android direct APK and Google Play flavors are built separately.

### Camera protocol

Olympus View communicates directly with the camera over HTTP on the local camera WiFi network. Compatible cameras normally expose the interface at `192.168.0.10`.

Common OPC endpoints used by the project include:

- File list: `GET /get_imglist.cgi?DIR=/DCIM`
- Thumbnail / compact list preview: `GET /get_thumbnail.cgi?DIR=<path>`
- Higher-quality grid preview: `GET /get_resizeimg.cgi?DIR=<path>&size=1024`
- Preferred full-screen preview: `GET /get_screennail.cgi?DIR=<path>`
- Full-screen fallback: `GET /get_resizeimg.cgi?DIR=<path>&size=1920`
- Delete: `GET /exec_erase.cgi?DIR=<path>`
- Download: `GET /<path>`
- Play mode: `GET /switch_cammode.cgi?mode=play`
- Camera info: `GET /get_caminfo.cgi`

### QR decoding

The app supports OIS1 and OIS3 camera QR formats. These contain encoded WiFi connection data and, on some cameras, Bluetooth information. Olympus View decodes the values locally on the device.

## Privacy summary

Olympus View has no user accounts, advertising, developer analytics backend, or developer-operated cloud photo storage. Camera photos and saved camera WiFi credentials are handled locally by the application. Android QR recognition uses Google ML Kit through Mobile Scanner; Google may receive technical diagnostics and usage metrics as described in the full policy.

Full privacy policy:

https://dpolarov.github.io/olympus-view-and-delete/privacy.md

## v1.3.12 highlights

- Camera **video files** (MOV, MP4, M4V, AVI, MTS and M2TS) are visible independently of the RAW/JPG still-photo filter.
- Gallery preview traffic pauses while the app is in the background and resumes only after the saved camera Wi-Fi and camera endpoint are available again; interrupted requests retry instead of becoming broken tiles.
- Successfully loaded previews are persisted before completion, and the persistent preview cache capacity is increased from **150 to 1000 entries**.
- Build stack updated to **Flutter 3.47.5 / Dart 3.13, Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20, Java/Kotlin 17 and compileSdk 37**.
- All direct Flutter/Dart dependencies were updated to current compatible stable versions and the dependency lock was refreshed.
- Full CI validates analyze/tests, Android APK/AAB, Windows, Web, Dart AOT metadata, Android 16 KB compatibility and Play-flavor policy checks.
- Users on **v1.3.6 or newer** can update normally through the built-in updater.
- Version: **1.3.12+21**.

## v1.3.11 highlights

- Fixed **OM-1 gallery preview compatibility**: v1.3.10 requested resize size 480, but OM-1 advertises 1024, 1600, 1920 and 2048. Grid tiles now use the supported **1024 px resize preview** with the small thumbnail as fallback.
- The grid cache identity is now `grid1024`, preventing old 160×120 thumbnails and failed/obsolete 480-preview entries from being reused.
- Full-screen viewing now prefers **`get_screennail.cgi`** and falls back to **`get_resizeimg.cgi?size=1920`** when needed.
- The compact 72×72 list continues to use the small thumbnail endpoint to minimize Wi-Fi traffic.
- Users on **v1.3.6 or newer** can update normally through the built-in updater.
- Version: **1.3.11+20**.

## v1.3.10 highlights

- The **About** dialog now shows the actual recent release changes instead of an old generic feature list.
- The in-app changelog mentions the Android RAW/ORF/DNG download fix and the persistent **RAW only / JPG only / RAW + JPG** file-type filter, including restoration of the last selected mode.
- The in-app changelog is localized for English, Russian and Ukrainian and must stay synchronized with the repository and website changelogs for future releases.
- Large gallery tiles request a **480 px resized preview** first, with the small thumbnail kept as a fallback.
- A fresh `grid480` cache identity prevents older low-resolution cached thumbnails from being reused after the update.
- Gallery scaling uses high-quality filtering.
- Users on **v1.3.6 or newer** can update normally through the built-in updater.
- Version: **1.3.10+19**.

## v1.3.9 highlights

- Added a persistent three-state gallery filter: **RAW only**, **JPG only**, or **RAW + JPG**.
- RAW mode recognizes ORF, DNG and RAW files; JPG mode recognizes JPG and JPEG files.
- The selected file-type mode is restored automatically after restarting the app.
- Existing installations with no saved filter value start in **JPG only**, preserving the previous default behavior.
- Added regression tests for file-extension filtering and saved-filter restoration.
- Users on **v1.3.6 or newer** can update normally through the built-in updater.
- Version: **1.3.9+18**.

## v1.3.8 highlights

- Fixed Android downloads of Olympus **ORF** RAW files to `DCIM/OlympusView`.
- ORF, DNG and RAW files now use the Android image MediaStore collection, matching the JPEG save path and avoiding the `Primary directory DCIM not allowed` error.
- Foreground and background RAW downloads use the same corrected storage path.
- Successful RAW downloads receive the same persistent green downloaded marker as JPEG files.
- Users on **v1.3.6 or newer** can update normally through the built-in updater.
- Version: **1.3.8+17**.

## v1.3.7 highlights

- Thumbnail disk-cache lookup now completes before consuming a camera-network slot, preventing cache hits from starving real camera transfers.
- Full-screen preview cache stays bounded during rapid paging, even when swiping faster than neighbor preloading.
- Non-200 camera download responses are rejected instead of being saved as files.
- Failed, invalid, or truncated transfers are prevented from poisoning persistent thumbnail and preview caches.
- New on-device Android integration tests exercise a fake Olympus camera over real TCP sockets, filesystem cache persistence, failure paths, and thumbnail concurrency.
- Users on **v1.3.6 or newer** can update normally; users on **v1.3.5 or older** still need the one-time reinstall introduced in v1.3.6.
- Version: **1.3.7+16**.

Detailed changelog:

https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/CHANGELOG.md

## Source and feedback

Source repository and issue tracker:

https://github.com/dpolarov/olympus-view-and-delete

Human-readable project website:

https://dpolarov.github.io/olympus-view-and-delete/
