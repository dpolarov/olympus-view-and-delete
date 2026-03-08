@echo off
echo ========================================
echo  Olympus Flutter - Build All Releases
echo ========================================
echo.

set FLUTTER=C:\flutter\bin\flutter.bat
set PROJECT=C:\tmp\olympus_flutter
set RELEASES=%PROJECT%\releases

echo [1/6] Building Android APK...
call %FLUTTER% build apk --release
if errorlevel 1 (echo FAILED: APK build & goto :end)

echo [2/6] Copying APK to releases...
if not exist "%RELEASES%" mkdir "%RELEASES%"
copy /Y "%PROJECT%\build\app\outputs\flutter-apk\app-release.apk" "%RELEASES%\OlympusView.apk"

echo [3/6] Building Web...
call %FLUTTER% build web --release
if errorlevel 1 (echo FAILED: Web build & goto :end)

echo [4/6] Copying Web to releases...
if exist "%RELEASES%\web" rmdir /S /Q "%RELEASES%\web"
xcopy "%PROJECT%\build\web" "%RELEASES%\web\" /E /I /Q

echo [5/6] Building Windows...
call %FLUTTER% build windows --release
if errorlevel 1 (echo FAILED: Windows build & goto :end)

echo [6/6] Copying Windows to releases...
if exist "%RELEASES%\windows" rmdir /S /Q "%RELEASES%\windows"
xcopy "%PROJECT%\build\windows\x64\runner\Release" "%RELEASES%\windows\" /E /I /Q

echo.
echo ========================================
echo  Done! Files in releases:
echo ========================================
dir /S /B "%RELEASES%\OlympusView.apk"
dir /S /B "%RELEASES%\windows\olympus_flutter.exe"
echo Web: %RELEASES%\web\index.html
echo.

:end
pause
