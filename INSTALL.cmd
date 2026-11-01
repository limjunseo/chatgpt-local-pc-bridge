@echo off
setlocal EnableExtensions DisableDelayedExpansion
title ChatGPT Local PC Bridge - Setup
rem Installer for OWN self-contained local MCP server. No third-party MCP packages.
rem Requires owner approval. Does not connect accounts or enable persistence.
set "BRIDGE_HOME=%LOCALAPPDATA%\ChatGPTLocalPCBridge"
set "BRIDGE_SCRIPT=%BRIDGE_HOME%\local-pc-mcp.cjs"
set "WORK_ROOT=%USERPROFILE%\ChatGPTLocalFiles"
set "DOWNLOAD_URL=https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/main/local-pc-mcp.cjs"
set "EXPECTED_SHA256=5A13141F7615CC7C49659BC2BE70B149DFD7735EFF218ED9BAF661A676A313F7"
if not "%~2"=="" goto BAD_ARGUMENT
if /I "%~1"=="--help" goto HELP
if /I "%~1"=="--dry-run" goto DRY_RUN
if not "%~1"=="" goto BAD_ARGUMENT
echo.
echo ======================================================
echo       ChatGPT Local PC Bridge - Windows Setup
echo ======================================================
echo.
echo No third-party MCP provider or npm packages are used.
echo Installs our own small local stdio MCP tool, Node.js only.
echo Tools: hostname, list, read and write text files.
echo Restricted to: %WORK_ROOT%
echo No arbitrary command execution, open ports, or auto-start.
echo Installation does not authorize any ChatGPT account.
echo.
choice /C YN /N /M "PC owner approves this installation? [Y/N]: "
if errorlevel 2 goto CANCELLED
if not errorlevel 1 goto CANCELLED
call :CHECK_NODE
if not errorlevel 1 goto NODE_READY
echo.
echo Node.js 22.12+ missing or outdated.
where winget.exe >nul 2>&1
if errorlevel 1 goto NO_WINGET
choice /C YN /N /M "Install/upgrade official Node.js LTS via winget? [Y/N]: "
if errorlevel 2 goto CANCELLED
if not errorlevel 1 goto CANCELLED
winget install --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
  echo Node.js install failed. Trying winget upgrade...
  winget upgrade --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
  if errorlevel 1 goto NODE_INSTALL_FAILED
)
if exist "%ProgramFiles%\nodejs\node.exe" set "PATH=%ProgramFiles%\nodejs;%PATH%"
if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" set "PATH=%LOCALAPPDATA%\Programs\nodejs;%PATH%"
call :CHECK_NODE
if errorlevel 1 goto NODE_RECHECK_FAILED
:NODE_READY
if not exist "%BRIDGE_HOME%" mkdir "%BRIDGE_HOME%"
if errorlevel 1 goto FOLDER_FAILED
if not exist "%WORK_ROOT%" mkdir "%WORK_ROOT%"
if errorlevel 1 goto FOLDER_FAILED
set "CURRENT_HASH="
if exist "%BRIDGE_SCRIPT%" call :HASH_FILE "%BRIDGE_SCRIPT%"
if /I "%CURRENT_HASH%"=="%EXPECTED_SHA256%" goto VERIFIED
echo Downloading published bridge source from our GitHub...
set "TEMPFILE=%BRIDGE_HOME%\local-pc-mcp.cjs.download"
powershell.exe -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -Uri '%DOWNLOAD_URL%' -OutFile '%TEMPFILE%' -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 goto DOWNLOAD_FAILED
set "CURRENT_HASH="
call :HASH_FILE "%TEMPFILE%"
if /I not "%CURRENT_HASH%"=="%EXPECTED_SHA256%" goto HASH_FAILED
move /Y "%TEMPFILE%" "%BRIDGE_SCRIPT%" >nul
if errorlevel 1 goto FOLDER_FAILED
:VERIFIED
node.exe --check "%BRIDGE_SCRIPT%"
if errorlevel 1 goto NODE_CHECK_FAILED
echo.
echo [SUCCESS] Own local MCP bridge installed and syntax-checked.
echo [NOT CONNECTED] ChatGPT pairing still requires owner's approval.
echo.
echo Workspace: %WORK_ROOT%
echo Node command: node.exe
echo Node argument: "%BRIDGE_SCRIPT%"
echo Env LOCAL_PC_ROOT: "%WORK_ROOT%"
echo.
echo ChatGPT DESKTOP: Settings / MCP servers / Add server / STDIO
echo     Fill in the command, argument and LOCAL_PC_ROOT above.
echo     Save and restart the local MCP host, then test pc_info.
echo ChatGPT WEB: Set up the official OpenAI Secure MCP Tunnel.
echo     Connect this same stdio command to the owner's tunnel.
echo     Account permissions, tunnel ID and runtime key are separate.
echo     Never reuse the supporter's tunnel or keys.
echo.
echo Documentation:
echo https://github.com/limjunseo/chatgpt-local-pc-bridge
echo.
echo Press any key to finish. No service is running automatically.
pause >nul
exit /b 0
:DRY_RUN
echo [CHECK] Node.js and local bridge; no changes or network.
call :CHECK_NODE
if errorlevel 1 (echo [FAIL] Node.js 22.12+ required&exit /b 2)
if exist "%BRIDGE_SCRIPT%" (echo [INFO] Bridge file already present) else (echo [INFO] Bridge not installed)
where winget.exe >nul 2>&1
if errorlevel 1 (echo [INFO] winget unavailable) else (echo [PASS] winget available)
echo [PASS] Environment check. ChatGPT NOT verified.
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
:HASH_FILE
for /f "delims=" %%H in ('powershell.exe -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%~1').Hash"') do set "CURRENT_HASH=%%H"
exit /b 0
:NO_WINGET
echo [ERROR] winget not found. Install official Node.js LTS manually.
start "" "https://nodejs.org/en/download"
pause
exit /b 3
:NODE_INSTALL_FAILED
echo [ERROR] Node install failed, or Windows needs restart.
pause
exit /b 4
:NODE_RECHECK_FAILED
echo [ERROR] Reopen CMD after installing Node.js, then retry.
pause
exit /b 5
:FOLDER_FAILED
echo [ERROR] Could not write to the current user's local folder.
pause
exit /b 6
:DOWNLOAD_FAILED
echo [ERROR] Could not download from our GitHub repository.
pause
exit /b 7
:HASH_FAILED
echo [ERROR] SHA-256 does not match verified source. Refusing to run it.
if exist "%TEMPFILE%" del /q "%TEMPFILE%" >nul 2>&1
pause
exit /b 8
:NODE_CHECK_FAILED
echo [ERROR] Source failed node.exe syntax check.
pause
exit /b 9
:CANCELLED
echo PC owner declined installation.
exit /b 10
:BAD_ARGUMENT
echo Usage: INSTALL.cmd [--dry-run ^| --help]
exit /b 11
:HELP
echo ChatGPT Local PC Bridge - own stdio MCP, no Desktop Commander
echo No args: consent, install Node LTS if needed, download hash-pinned JS.
echo --dry-run: no changes. --help: display help.
echo ChatGPT desktop local MCP or OpenAI Secure MCP Tunnel separately.
exit /b 0