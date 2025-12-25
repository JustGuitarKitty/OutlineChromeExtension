@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo   Outline Proxy Native Host Installer
echo ==========================================
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run as Administrator!
    echo Right-click on install.bat and select "Run as administrator"
    pause
    exit /b 1
)

:: Set paths
set "INSTALL_DIR=%ProgramFiles%\OutlineProxy"
set "EXE_NAME=outline-proxy-host.exe"
set "MANIFEST_NAME=com.outline.proxy.json"

echo [1/4] Creating installation directory...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo [2/4] Copying files...
copy /Y "%~dp0%EXE_NAME%" "%INSTALL_DIR%\" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy executable
    pause
    exit /b 1
)

:: Get extension ID from user or use wildcard
set /p "EXT_ID=Enter Chrome extension ID (leave empty for development): "
if "%EXT_ID%"=="" (
    set "ALLOWED_ORIGIN=chrome-extension://*/"
) else (
    set "ALLOWED_ORIGIN=chrome-extension://%EXT_ID%/"
)

echo [3/4] Creating Native Messaging manifest...
(
echo {
echo   "name": "com.outline.proxy",
echo   "description": "Outline Proxy Native Host",
echo   "path": "%INSTALL_DIR:\=\\%\\%EXE_NAME%",
echo   "type": "stdio",
echo   "allowed_origins": [
echo     "%ALLOWED_ORIGIN%"
echo   ]
echo }
) > "%INSTALL_DIR%\%MANIFEST_NAME%"

echo [4/4] Registering in Windows Registry...
reg add "HKCU\Software\Google\Chrome\NativeMessagingHosts\com.outline.proxy" /ve /t REG_SZ /d "%INSTALL_DIR%\%MANIFEST_NAME%" /f >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to register in registry
    pause
    exit /b 1
)

:: Also register for Edge if present
reg add "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.outline.proxy" /ve /t REG_SZ /d "%INSTALL_DIR%\%MANIFEST_NAME%" /f >nul 2>&1

echo.
echo ==========================================
echo   Installation completed successfully!
echo ==========================================
echo.
echo Installed to: %INSTALL_DIR%
echo.
echo Please restart Chrome to apply changes.
echo.
pause
