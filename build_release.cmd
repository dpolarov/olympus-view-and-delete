@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
set "FLUTTER=C:\flutter\bin\flutter.bat"
set "RELEASES=%PROJECT%\releases"
set "BUILT_APK=%PROJECT%\build\app\outputs\flutter-apk\app-github-release.apk"
set "RELEASE_APK=%RELEASES%\OlympusView-Android.apk"
set "KEY_PROPERTIES=%PROJECT%\android\key.properties"
set "DEFAULT_KEYSTORE=%USERPROFILE%\.android\debug.keystore"
set "EXPECTED_CERT_SHA256=3786A41C932C63183FC36DD388CB6BE397775392D3BF6E7F4FB16DC28CAE841E"
set "TEMP_KEY_PROPERTIES=0"

cd /d "%PROJECT%" || goto :failed

if not exist "%FLUTTER%" (
  where flutter >nul 2>nul
  if errorlevel 1 (
    echo ERROR: Flutter was not found at C:\flutter\bin\flutter.bat or in PATH.
    goto :failed
  )
  set "FLUTTER=flutter"
)

where git >nul 2>nul
if errorlevel 1 (
  echo ERROR: git.exe was not found in PATH.
  goto :failed
)

set "GIT_BRANCH="
for /f "delims=" %%A in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "GIT_BRANCH=%%A"
if not defined GIT_BRANCH (
  echo ERROR: Could not determine the current Git branch.
  goto :failed
)
if /I not "!GIT_BRANCH!"=="master" (
  echo ERROR: build_release.cmd only builds the repository master branch.
  echo Current branch: !GIT_BRANCH!
  echo.
  echo Run:
  echo   git switch master
  echo   git pull --ff-only
  echo   build_release.cmd
  goto :failed
)

set "GIT_COMMIT="
for /f "delims=" %%A in ('git rev-parse --short HEAD 2^>nul') do set "GIT_COMMIT=%%A"

set "BUILD_TIME_UTC="
for /f "delims=" %%A in ('powershell -NoProfile -Command "[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')" 2^>nul') do set "BUILD_TIME_UTC=%%A"
if not defined BUILD_TIME_UTC set "BUILD_TIME_UTC=unknown"

set "BUILD_FLUTTER_VERSION=unknown"
for /f "tokens=2" %%A in ('call "%FLUTTER%" --version 2^>nul ^| findstr /B /C:"Flutter "') do set "BUILD_FLUTTER_VERSION=%%A"

set "PUBSPEC_VERSION="
for /f "tokens=2" %%A in ('findstr /B /C:"version:" "%PROJECT%\pubspec.yaml"') do set "PUBSPEC_VERSION=%%A"
if not defined PUBSPEC_VERSION (
  echo ERROR: Could not read the version from pubspec.yaml.
  goto :failed
)

set "BUILD_NAME="
set "BUILD_NUMBER="
for /f "tokens=1,2 delims=+" %%A in ("!PUBSPEC_VERSION!") do (
  set "BUILD_NAME=%%A"
  set "BUILD_NUMBER=%%B"
)
if not defined BUILD_NAME goto :bad_version
if not defined BUILD_NUMBER goto :bad_version

goto :version_ok

:bad_version
echo ERROR: Invalid pubspec version: !PUBSPEC_VERSION!
echo Expected format: 1.2.3+4
goto :failed

:version_ok
if not exist "%RELEASES%" mkdir "%RELEASES%"

echo ========================================
echo  Olympus View - GitHub Android Release
echo ========================================
echo Source branch : !GIT_BRANCH!
echo Source commit : !GIT_COMMIT!
echo App version   : !BUILD_NAME! (build !BUILD_NUMBER!)
echo Build time UTC: !BUILD_TIME_UTC!
echo Flutter       : !BUILD_FLUTTER_VERSION!
echo.

rem Local GitHub APK updates must use the same certificate as the APKs that
rem are already installed by users. Prefer an explicit android\key.properties.
rem If it is absent, use the known legacy key only after verifying its SHA-256.
if exist "%KEY_PROPERTIES%" (
  echo [signing] Using existing android\key.properties
) else (
  if not exist "%DEFAULT_KEYSTORE%" (
    echo ERROR: Release signing key was not found.
    echo Expected either:
    echo   %KEY_PROPERTIES%
    echo or the compatible existing key:
    echo   %DEFAULT_KEYSTORE%
    goto :failed
  )

  where keytool >nul 2>nul
  if errorlevel 1 (
    echo ERROR: keytool is not available in PATH.
    echo Run flutter doctor -v and use the JDK bundled with Android Studio/Flutter.
    goto :failed
  )

  set "CERT_LINE="
  for /f "delims=" %%A in ('keytool -list -v -keystore "%DEFAULT_KEYSTORE%" -alias androiddebugkey -storepass android -keypass android 2^>nul ^| findstr /C:"SHA256:"') do (
    set "CERT_LINE=%%A"
  )
  set "ACTUAL_CERT_SHA256=!CERT_LINE:*SHA256: =!"
  set "ACTUAL_CERT_SHA256=!ACTUAL_CERT_SHA256::=!"
  set "ACTUAL_CERT_SHA256=!ACTUAL_CERT_SHA256: =!"

  if /I not "!ACTUAL_CERT_SHA256!"=="%EXPECTED_CERT_SHA256%" (
    echo ERROR: The certificate in %DEFAULT_KEYSTORE% does not match the published app.
    echo Expected: %EXPECTED_CERT_SHA256%
    echo Actual:   !ACTUAL_CERT_SHA256!
    echo Refusing to build an incompatible update.
    goto :failed
  )

  echo [signing] Compatible signing certificate verified.
  set "KEYSTORE_FORWARD=%DEFAULT_KEYSTORE:\=/%"
  > "%KEY_PROPERTIES%" echo storePassword=android
  >>"%KEY_PROPERTIES%" echo keyPassword=android
  >>"%KEY_PROPERTIES%" echo keyAlias=androiddebugkey
  >>"%KEY_PROPERTIES%" echo storeFile=!KEYSTORE_FORWARD!
  set "TEMP_KEY_PROPERTIES=1"
)

echo.
echo [1/7] Cleaning Flutter build cache...
rem This is intentional for release builds. A stale incremental AOT artifact can
rem otherwise produce a new Android manifest around an older libapp.so.
call "%FLUTTER%" clean
if errorlevel 1 goto :failed

echo.
echo [2/7] Resolving dependencies...
call "%FLUTTER%" pub get
if errorlevel 1 goto :failed

echo.
echo [3/7] Removing stale release copy...
if exist "%RELEASE_APK%" del /Q "%RELEASE_APK%"

echo.
echo [4/7] Building signed GitHub APK !BUILD_NAME! build !BUILD_NUMBER!...
call "%FLUTTER%" build apk --flavor github --release --build-name !BUILD_NAME! --build-number !BUILD_NUMBER! --dart-define=OLYMPUS_BUILD_TIME_UTC=!BUILD_TIME_UTC! --dart-define=OLYMPUS_GIT_COMMIT=!GIT_COMMIT! --dart-define=OLYMPUS_FLUTTER_VERSION=!BUILD_FLUTTER_VERSION! --obfuscate --split-debug-info=build/symbols
if errorlevel 1 goto :failed
if not exist "%BUILT_APK%" (
  echo ERROR: Flutter reported success but the expected APK was not created:
  echo   %BUILT_APK%
  goto :failed
)

echo.
echo [5/7] Verifying packaged Dart AOT metadata...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT%\scripts\verify_apk_dart_metadata.ps1" -ApkPath "%BUILT_APK%" -ExpectedCommit "!GIT_COMMIT!" -ExpectedBuildTime "!BUILD_TIME_UTC!"
if errorlevel 1 (
  echo ERROR: Packaged Dart code does not match this build.
  echo        Refusing to copy a potentially stale APK.
  goto :failed
)

echo.
echo [6/7] Verifying APK manifest version...
set "AAPT="
where aapt >nul 2>nul
if not errorlevel 1 (
  for /f "delims=" %%A in ('where aapt') do if not defined AAPT set "AAPT=%%A"
)
if not defined AAPT (
  if defined ANDROID_HOME (
    for /f "delims=" %%A in ('dir /b /s /a-d "%ANDROID_HOME%\build-tools\aapt.exe" 2^>nul') do set "AAPT=%%A"
  )
)
if not defined AAPT (
  if defined ANDROID_SDK_ROOT (
    for /f "delims=" %%A in ('dir /b /s /a-d "%ANDROID_SDK_ROOT%\build-tools\aapt.exe" 2^>nul') do set "AAPT=%%A"
  )
)
if not defined AAPT (
  if exist "%LOCALAPPDATA%\Android\Sdk\build-tools" (
    for /f "delims=" %%A in ('dir /b /s /a-d "%LOCALAPPDATA%\Android\Sdk\build-tools\aapt.exe" 2^>nul') do set "AAPT=%%A"
  )
)

if defined AAPT (
  set "BADGING_FILE=%TEMP%\olympus-view-apk-badging.txt"
  "!AAPT!" dump badging "%BUILT_APK%" > "!BADGING_FILE!" 2>nul
  if errorlevel 1 (
    echo ERROR: aapt could not inspect the built APK.
    goto :failed
  )
  findstr /C:"versionCode='!BUILD_NUMBER!'" "!BADGING_FILE!" >nul
  if errorlevel 1 (
    echo ERROR: APK versionCode does not match pubspec build !BUILD_NUMBER!.
    type "!BADGING_FILE!" | findstr /B /C:"package:"
    del /Q "!BADGING_FILE!" >nul 2>nul
    goto :failed
  )
  findstr /C:"versionName='!BUILD_NAME!'" "!BADGING_FILE!" >nul
  if errorlevel 1 (
    echo ERROR: APK versionName does not match pubspec version !BUILD_NAME!.
    type "!BADGING_FILE!" | findstr /B /C:"package:"
    del /Q "!BADGING_FILE!" >nul 2>nul
    goto :failed
  )
  for /f "delims=" %%A in ('findstr /B /C:"package:" "!BADGING_FILE!"') do echo [verify] %%A
  del /Q "!BADGING_FILE!" >nul 2>nul
) else (
  echo WARNING: aapt.exe was not found; manifest version verification was skipped.
  echo          Flutter still receives explicit --build-name/--build-number values.
)

echo.
echo [7/7] Copying APK...
copy /Y "%BUILT_APK%" "%RELEASE_APK%" >nul
if errorlevel 1 goto :failed

echo.
echo ========================================
echo  Android release file
echo ========================================
echo Version: !BUILD_NAME! (build !BUILD_NUMBER!)
echo Build UTC: !BUILD_TIME_UTC!
echo Commit: !GIT_COMMIT!
echo Flutter: !BUILD_FLUTTER_VERSION!
echo APK: %RELEASE_APK%
echo Symbols: %PROJECT%\build\symbols
echo.
echo NOTE: Google Play AAB is intentionally not built by this script.
echo       It must use the separate Play upload key via the "Google Play AAB" workflow.
set "EXIT_CODE=0"
goto :cleanup

:failed
echo.
echo FAILED: Release build did not complete.
set "EXIT_CODE=1"

:cleanup
if "%TEMP_KEY_PROPERTIES%"=="1" (
  del /Q "%KEY_PROPERTIES%" >nul 2>nul
  echo [signing] Temporary android\key.properties removed.
)

echo.
pause
exit /b %EXIT_CODE%
