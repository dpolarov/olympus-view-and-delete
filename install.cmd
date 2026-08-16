@echo off
setlocal EnableExtensions

set "PROJECT=%~dp0"
set "APK=%PROJECT%releases\OlympusView-Android.apk"
set "ADB=adb"
set "PACKAGE=com.flynew.photomanager"

if not exist "%APK%" (
  echo ========================================
  echo  Olympus View - Install APK to device
  echo ========================================
  echo.
  echo ERROR: APK not found:
  echo   %APK%
  echo.
  echo Run build_release.cmd first, or place the APK in releases.
  goto :end
)

where adb >nul 2>nul
if errorlevel 1 (
  if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
    set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
  ) else if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
    set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
  ) else if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  ) else (
    echo ERROR: adb.exe was not found.
    echo Install Android Platform Tools or add adb to PATH.
    goto :end
  )
)

echo ========================================
echo  Olympus View - Install APK to device
echo ========================================
echo.
echo APK:
echo   %APK%
echo.
echo Connected devices:
"%ADB%" devices
if errorlevel 1 (
  echo.
  echo ERROR: Failed to run adb.
  goto :end
)

echo.
echo Stopping any old Olympus View process...
"%ADB%" shell am force-stop %PACKAGE% >nul 2>nul

echo.
echo Installing existing APK...
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo.
  echo FAILED: APK installation failed.
  echo Check that the device is connected, USB debugging is enabled,
  echo and the installed app uses the same signing key.
  goto :end
)

echo.
echo Installed package version:
"%ADB%" shell dumpsys package %PACKAGE% | findstr /C:"versionCode=" /C:"versionName="
if errorlevel 1 (
  echo WARNING: Could not read installed version for %PACKAGE%.
)

echo.
echo Starting a fresh Olympus View process...
"%ADB%" shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>nul
if errorlevel 1 (
  echo WARNING: APK installed, but automatic launch failed.
  echo          Start Olympus View manually on the device.
) else (
  timeout /t 1 /nobreak >nul
  echo Running process:
  "%ADB%" shell pidof %PACKAGE%
)

echo.
echo ========================================
echo  Done! APK installed and restarted.
echo ========================================

:end
pause
endlocal
