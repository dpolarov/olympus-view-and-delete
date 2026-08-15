@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "FLUTTER=C:\flutter\bin\flutter.bat"
set "PROJECT=C:\tmp\olympus_flutter"
set "RELEASES=%PROJECT%\releases"
set "KEY_PROPERTIES=%PROJECT%\android\key.properties"
set "DEFAULT_KEYSTORE=%USERPROFILE%\.android\debug.keystore"
set "EXPECTED_CERT_SHA256=3786A41C932C63183FC36DD388CB6BE397775392D3BF6E7F4FB16DC28CAE841E"
set "TEMP_KEY_PROPERTIES=0"

cd /d "%PROJECT%" || goto :failed

if not exist "%FLUTTER%" (
  echo ERROR: Flutter not found: %FLUTTER%
  goto :failed
)

if not exist "%RELEASES%" mkdir "%RELEASES%"

echo ========================================
echo  Olympus View - GitHub Android Release
echo ========================================
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
echo [1/4] Resolving dependencies...
call "%FLUTTER%" pub get
if errorlevel 1 goto :failed

echo.
echo [2/4] Building signed GitHub APK...
call "%FLUTTER%" build apk --flavor github --release --obfuscate --split-debug-info=build/symbols
if errorlevel 1 goto :failed

echo.
echo [3/4] Copying APK...
copy /Y "%PROJECT%\build\app\outputs\flutter-apk\app-github-release.apk" "%RELEASES%\OlympusView-Android.apk" >nul
if errorlevel 1 goto :failed

echo.
echo [4/4] Done.
echo ========================================
echo  Android release file
echo ========================================
echo APK: %RELEASES%\OlympusView-Android.apk
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
