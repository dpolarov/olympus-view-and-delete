@echo off
echo ========================================
echo  Olympus View — Install APK to device
echo ========================================
echo.

set FLUTTER=C:\flutter\bin\flutter.bat
set PROJECT=C:\tmp\olympus_flutter

echo Building APK...
call %FLUTTER% build apk --release
if errorlevel 1 (echo FAILED: APK build & goto :end)

echo.
echo Installing to device...
call %FLUTTER% install --release
if errorlevel 1 (echo FAILED: Install & goto :end)

echo.
echo Copying APK to releases...
if not exist "%PROJECT%\releases" mkdir "%PROJECT%\releases"
copy /Y "%PROJECT%\build\app\outputs\flutter-apk\app-release.apk" "%PROJECT%\releases\OlympusView.apk"

echo.
echo ========================================
echo  Done! APK installed on device.
echo ========================================

:end
pause
