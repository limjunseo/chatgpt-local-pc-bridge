@echo off
setlocal EnableExtensions DisableDelayedExpansion
title ChatGPT Local Desktop Commander Setup
rem Local stdio MCP setup. Does NOT enable Remote Desktop Commander.
rem Verified target version matches the existing local environment (0.2.51).
set "PACKAGE=@wonderwhy-er/desktop-commander@0.2.51"
set "INSTALL_ROOT=%LOCALAPPDATA%\DesktopCommanderLocal"
set "SERVER_JS=%INSTALL_ROOT%\node_modules\@wonderwhy-er\desktop-commander\dist\index.js"
if not "%~2"=="" goto BAD_ARGUMENT
if /I "%~1"=="--help" goto HELP
if /I "%~1"=="--dry-run" goto DRY_RUN
if not "%~1"=="" goto BAD_ARGUMENT
echo.
echo ====================================================
echo    ChatGPT LOCAL Desktop Commander - Windows Setup
echo ====================================================
echo.
echo This installer:
echo   1. Checks Node.js 22.12+ and npm/npx.
echo   2. Offers Node.js LTS installation via winget if needed.
echo   3. Installs local stdio Desktop Commander version 0.2.51.
echo   4. Explains ChatGPT Desktop or Web Tunnel connection.
echo.
echo This does NOT connect or authenticate ChatGPT automatically.
echo The local MCP can read, edit files and run commands with
echo the current Windows user's rights when connected.
echo No 3389 port forwarding, secret collection, or auto-start.
echo.
choice /C YN /N /M "PC owner authorizes local MCP installation? [Y/N]: "
if errorlevel 2 goto CANCELLED
if not errorlevel 1 goto CANCELLED
call :CHECK_NODE
if not errorlevel 1 goto NODE_READY
echo.
echo Node.js 22.12+ not found. Node.js LTS is required.
where winget.exe >nul 2>&1
if errorlevel 1 goto NO_WINGET
choice /C YN /N /M "Install/upgrade official Node.js LTS via winget? [Y/N]: "
if errorlevel 2 goto CANCELLED
if not errorlevel 1 goto CANCELLED
winget install --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
  echo Initial install was not successful; trying upgrade.
  winget upgrade --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
  if errorlevel 1 goto NODE_INSTALL_FAILED
)
if exist "%ProgramFiles%\nodejs\node.exe" set "PATH=%ProgramFiles%\nodejs;%PATH%"
if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" set "PATH=%LOCALAPPDATA%\Programs\nodejs;%PATH%"
call :CHECK_NODE
if errorlevel 1 goto NODE_RECHECK_FAILED
:NODE_READY
where npm.cmd >nul 2>&1
if errorlevel 1 goto NO_NPM
where npx.cmd >nul 2>&1
if errorlevel 1 goto NO_NPX
echo.
echo Installing local Desktop Commander into:
echo   %INSTALL_ROOT%
echo Package: %PACKAGE%
call npm.cmd install --prefix "%INSTALL_ROOT%" --no-audit --no-fund --save-exact "%PACKAGE%"
if errorlevel 1 goto NPM_FAILED
if not exist "%SERVER_JS%" goto SERVER_MISSING
echo.
echo [READY] Local Desktop Commander installed successfully.
echo [NOT CONNECTED] ChatGPT account and tunnel still need setup.
echo.
echo CHATGPT DESKTOP APP:
echo   Settings - MCP servers - Add server - STDIO
echo   Command: node.exe
echo   Args: "%SERVER_JS%"
echo   Save and Restart, then test a read-only file listing.
echo.
echo CHATGPT WEB (same architecture as this operator PC):
echo   Requires OpenAI Secure MCP Tunnel, permitted Platform
echo   tunnel ID, restricted runtime API key, and ChatGPT access.
echo   Configure tunnel-client to run this local stdio command:
echo   node.exe "%SERVER_JS%"
echo   Do NOT use the public Remote Desktop Commander MCP URL.
echo.
echo Opening official instructions and ChatGPT...
start "" "https://learn.chatgpt.com/docs/extend/mcp"
start "" "https://developers.openai.com/api/docs/guides/secure-mcp-tunnels"
start "" "https://chatgpt.com/plugins"
echo.
echo To stop remote access, stop the tunnel-client process or
echo disable the local MCP server in ChatGPT. Do not enable
echo unattended startup without separate owner approval.
pause
exit /b 0
:DRY_RUN
echo [CHECK] Local prerequisites only - no installation or browser.
call :CHECK_NODE
if errorlevel 1 (echo [FAIL] Node.js 22.12+ required&exit /b 2)
where npm.cmd >nul 2>&1
if errorlevel 1 (echo [FAIL] npm.cmd missing&exit /b 3)
where npx.cmd >nul 2>&1
if errorlevel 1 (echo [FAIL] npx.cmd missing&exit /b 4)
where winget.exe >nul 2>&1
if errorlevel 1 (echo [INFO] winget unavailable) else (echo [PASS] winget available)
if exist "%SERVER_JS%" (echo [INFO] Local MCP already present) else (echo [INFO] Local MCP not yet installed in target directory)
echo [PASS] Node, npm and npx ready. This does NOT test MCP or ChatGPT.
exit /b 0
:CHECK_NODE
set "NODE_MAJOR="
set "NODE_MINOR="
where node.exe >nul 2>&1
if errorlevel 1 exit /b 1
for /f "tokens=1,2 delims=v." %%A in ('node.exe --version 2^>nul ^| findstr.exe /R /X "v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"') do (
  set "NODE_MAJOR=%%A"
  set "NODE_MINOR=%%B"
)
if not defined NODE_MAJOR exit /b 1
if not defined NODE_MINOR exit /b 1
set /a "NODE_MAJOR_NUM=%NODE_MAJOR%" >nul 2>&1
if errorlevel 1 exit /b 1
set /a "NODE_MINOR_NUM=%NODE_MINOR%" >nul 2>&1
if errorlevel 1 exit /b 1
echo [INFO] Node.js %NODE_MAJOR_NUM%.%NODE_MINOR_NUM%
if %NODE_MAJOR_NUM% GTR 22 exit /b 0
if %NODE_MAJOR_NUM% LSS 22 exit /b 1
if %NODE_MINOR_NUM% GEQ 12 exit /b 0
exit /b 1
:NO_WINGET
echo [ERROR] winget unavailable. Install official Node.js LTS manually.
start "" "https://nodejs.org/en/download"
pause
exit /b 5
:NODE_INSTALL_FAILED
echo [ERROR] Node.js install/upgrade failed or requires reboot.
pause
exit /b 6
:NODE_RECHECK_FAILED
echo [ERROR] Reopen CMD after Node.js installation and retry.
pause
exit /b 7
:NO_NPM
echo [ERROR] npm.cmd not found. Repair Node.js installation.
pause
exit /b 8
:NO_NPX
echo [ERROR] npx.cmd not found. Repair Node.js installation.
pause
exit /b 9
:NPM_FAILED
echo [ERROR] Local MCP npm install failed. Check the network or npm log.
pause
exit /b 10
:SERVER_MISSING
echo [ERROR] Installed package does not contain expected dist/index.js.
pause
exit /b 11
:CANCELLED
echo Installation cancelled by PC owner.
exit /b 12
:BAD_ARGUMENT
echo Usage: INSTALL.cmd [--dry-run ^| --help]
exit /b 13
:HELP
echo INSTALL.cmd - local Desktop Commander for ChatGPT
echo No args: install Node.js if needed, then LOCAL stdio MCP package.
echo --dry-run: checks only. Does not download or connect accounts.
echo Note: ChatGPT Desktop MCP setup and Web Tunnel authorization
echo       still require actions by the account owner.
exit /b 0