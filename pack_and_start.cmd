@echo off
setlocal EnableDelayedExpansion
rem Usage:
rem   pack_and_start.cmd              ^> flutter run ^(uses env\app.env^)
rem   pack_and_start.cmd build ...  ^> flutter build apk ... ^(same env\app.env^)
rem   pack_and_start.cmd apk ...    ^> same as build

set "SCRIPT_DIR=%~dp0"
set "FLUTTER_BIN=D:\flutter\bin\flutter.bat"
set "ADB_BIN="
set "ADB_DIR="
set "STEP=0"
set "PROXY_HOST=127.0.0.1"
set "PROXY_PORT=7897"

if not exist "%FLUTTER_BIN%" (
    echo [ERROR] Flutter not found: "%FLUTTER_BIN%"
    exit /b 1
)

cd /d "%SCRIPT_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot cd to project directory.
    exit /b 1
)

set "APP_ENV=%SCRIPT_DIR%env\app.env"
if not exist "%APP_ENV%" (
    echo [ERROR] Missing "%APP_ENV%".
    echo        Copy env\app.example.env to env\app.env and fill in values.
    exit /b 1
)
echo [INFO] dart-define-from-file: "%APP_ENV%"

set /a STEP+=1
echo [STEP !STEP!] Project dir: "%SCRIPT_DIR%"

rem Pub cache must not live inside the project folder: Windows often denies rename
rem from .pub-cache\_temp to hosted\..., causing endless retries. Dart default on Windows:
set "PUB_CACHE=%APPDATA%\Pub\Cache"
set /a STEP+=1
echo [STEP !STEP!] PUB_CACHE: "%PUB_CACHE%"

if not defined PUB_HOSTED_URL set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
if not defined FLUTTER_STORAGE_BASE_URL set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
if not defined HTTP_PROXY set "HTTP_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
if not defined HTTPS_PROXY set "HTTPS_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
if not defined NO_PROXY set "NO_PROXY=127.0.0.1,localhost"
set /a STEP+=1
echo [STEP !STEP!] PUB_HOSTED_URL=%PUB_HOSTED_URL%
echo [STEP !STEP!] FLUTTER_STORAGE_BASE_URL=%FLUTTER_STORAGE_BASE_URL%
echo [STEP !STEP!] HTTP_PROXY=%HTTP_PROXY%
echo [STEP !STEP!] HTTPS_PROXY=%HTTPS_PROXY%
echo [STEP !STEP!] NO_PROXY=%NO_PROXY%

rem Default to verbose pub logs so package download details are always visible.
set "PUB_GET_EXTRAS=--verbose"
set "RUN_EXTRAS="
if /I "%FLUTTER_VERBOSE%"=="1" (
    set "RUN_EXTRAS=--verbose"
    echo [INFO] FLUTTER_VERBOSE=1: verbose mode.
)

rem Daily runs: skip clean (fast). Set FULL_CLEAN=1 before running for a full wipe.
if /I "%FULL_CLEAN%"=="1" (
    set /a STEP+=1
    echo [STEP !STEP!] FULL_CLEAN=1: flutter clean...
    call "%FLUTTER_BIN%" clean
    if errorlevel 1 (
        echo [WARN] flutter clean failed, continue anyway.
    )
    set /a STEP+=1
    echo [STEP !STEP!] FULL_CLEAN=1: removing Gradle / build folders...
    if exist ".gradle" rmdir /s /q ".gradle" 2>nul
    if exist "android\.gradle" rmdir /s /q "android\.gradle" 2>nul
    if exist "android\build" rmdir /s /q "android\build" 2>nul
    if exist "build" rmdir /s /q "build" 2>nul
) else (
    echo [INFO] Skipping flutter clean ^(set FULL_CLEAN=1 to enable^).
)

set /a STEP+=1
echo [STEP !STEP!] Getting dependencies...
call "%FLUTTER_BIN%" pub get !PUB_GET_EXTRAS!
if errorlevel 1 (
    echo [ERROR] flutter pub get failed.
    exit /b 1
)

if /I "%~1"=="build" goto :flutter_build_apk_entry
if /I "%~1"=="apk" goto :flutter_build_apk_entry

set /a STEP+=1
echo [STEP !STEP!] Locating adb...
for /f "delims=" %%I in ('where.exe adb 2^>nul') do (
    if not defined ADB_BIN set "ADB_BIN=%%I"
)
if not defined ADB_BIN if exist "D:\Android\platform-tools\adb.exe" set "ADB_BIN=D:\Android\platform-tools\adb.exe"

if not defined ADB_BIN (
    echo [ERROR] adb not found. Please install Android platform-tools.
    exit /b 1
)

for %%I in ("%ADB_BIN%") do set "ADB_DIR=%%~dpI"
set "PATH=%ADB_DIR%;%PATH%"
echo [INFO] ADB_BIN=%ADB_BIN%
echo [INFO] ADB_DIR=%ADB_DIR%

set /a STEP+=1
echo [STEP !STEP!] Starting adb server...
call adb start-server >nul 2>nul

set "SAMSUNG_SERIAL="
set "FALLBACK_SERIAL="
set "TARGET_SERIAL="

for /l %%R in (1,1,3) do (
    echo [INFO] Device scan round %%R/3
    call :pick_target_serial
    if defined TARGET_SERIAL goto :device_found
    if %%R LSS 3 timeout /t 1 /nobreak >nul
)

echo [ERROR] No Android device detected. Check USB debugging and authorization.
exit /b 1

:device_found
if defined SAMSUNG_SERIAL (
    echo [INFO] Using Samsung device: !TARGET_SERIAL!
) else (
    echo [WARN] Samsung not found. Using first online device: !TARGET_SERIAL!
)

rem Dependencies already resolved above; avoid pub get again inside flutter run
set /a STEP+=1
echo [STEP !STEP!] Starting flutter run (--no-pub, --dart-define-from-file)...
call "%FLUTTER_BIN%" run --no-pub -d "!TARGET_SERIAL!" --dart-define-from-file="%APP_ENV%" !RUN_EXTRAS! %*
if errorlevel 1 (
    echo [ERROR] flutter run failed.
    exit /b 1
)

endlocal
exit /b 0

:flutter_build_apk_entry
set /a STEP+=1
echo [STEP !STEP!] Building APK (--dart-define-from-file)...
call :flutter_build_apk_sub %*
exit /b %errorlevel%

:flutter_build_apk_sub
shift
call "%FLUTTER_BIN%" build apk --no-pub --dart-define-from-file="%APP_ENV%" %*
exit /b %errorlevel%

:pick_target_serial
set "SAMSUNG_SERIAL="
set "FALLBACK_SERIAL="
set "TARGET_SERIAL="

rem Fast path: parse adb -l tags first.
for /f "tokens=1,*" %%A in ('adb devices -l 2^>nul ^| findstr /R /C:" device "') do (
    echo [ADB] candidate serial=%%A extra=%%B
    if not defined FALLBACK_SERIAL set "FALLBACK_SERIAL=%%A"
    if not defined SAMSUNG_SERIAL (
        set "LINE=%%A %%B"
        set "MANUFACTURER="
        echo(!LINE! | findstr /I /C:"manufacturer:samsung" /C:"model:SM-" /C:"model:SM_" >nul
        if !errorlevel! EQU 0 (
            set "SAMSUNG_SERIAL=%%A"
            echo [ADB] samsung matched: %%A
        ) else (
            for /f "delims=" %%M in ('adb -s %%A shell getprop ro.product.manufacturer 2^>nul') do (
                set "MANUFACTURER=%%M"
            )
            if /I "!MANUFACTURER!"=="samsung" (
                set "SAMSUNG_SERIAL=%%A"
                echo [ADB] samsung matched via getprop: %%A
            )
        )
    )
)

if defined SAMSUNG_SERIAL (
    set "TARGET_SERIAL=!SAMSUNG_SERIAL!"
    echo [ADB] picked samsung target=!TARGET_SERIAL!
    goto :eof
)
if defined FALLBACK_SERIAL (
    set "TARGET_SERIAL=!FALLBACK_SERIAL!"
    echo [ADB] picked fallback target=!TARGET_SERIAL!
) else (
    echo [ADB] no online devices in this round
)
goto :eof
