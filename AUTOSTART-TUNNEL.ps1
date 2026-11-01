#requires -Version 5.1
# Windows per-user, visible logon autostart for the first-party OpenAI tunnel.
# IMPORTANT: No administrator rights, hidden service, or third-party Desktop Commander.
[CmdletBinding()]
param(
  [ValidateSet('Enable','Disable','Status','Run')][string]$Action = 'Status',
  [string]$ConfigPath,
  [string]$StartupDirectory,
  [switch]$TestSkipConsent,
  [switch]$TestNoNetwork
)
$ErrorActionPreference = 'Stop'
$homeDir = Join-Path $env:LOCALAPPDATA 'ChatGPTLocalPCBridge'
$scriptPath = Join-Path $homeDir 'AUTOSTART-TUNNEL.ps1'
$secretPath = Join-Path $homeDir 'runtime-key.dpapi'
$clientPath = Join-Path $homeDir 'tunnel-client.exe'
$mcpPath = Join-Path $homeDir 'local-pc-mcp.cjs'
$profilePath = Join-Path $env:APPDATA 'tunnel-client\chatgpt-local-pc.yaml'
$profileName = 'chatgpt-local-pc'
if ([string]::IsNullOrWhiteSpace($StartupDirectory)) {
  $StartupDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
}
$shortcutPath = Join-Path $StartupDirectory 'ChatGPT Local PC Bridge Tunnel.lnk'
function Note([string]$s) { Write-Host ('[AUTO TUNNEL] ' + $s) }
function Require([bool]$ok,[string]$reason) { if (-not $ok) { throw $reason } }
function KeyFilePath {
  if ($ConfigPath) { return $ConfigPath }
  $desktopName = 'codex_' + [char]0xC138 + [char]0xD305 + [char]0xC5F0 + [char]0xACB0 + '.txt'
  return (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) $desktopName)
}
function ReadConfig([string]$file) {
  Require (Test-Path -LiteralPath $file -PathType Leaf) 'Desktop credential TXT not found. Put codex_[Korean filename].txt on the Windows Desktop.'
  Require ((Get-Item -LiteralPath $file).Length -le 8192) 'Config TXT too large.'
  $raw = Get-Content -LiteralPath $file -Raw -Encoding UTF8
  $fields = @{}
  foreach ($part in @($raw -split '[,\r\n]+' | Where-Object { $_.Trim() })) {
    if ($part -match '^\s*(TunnelId|ApiKey)\s*:\s*(.*?)\s*$') {
      $k = $Matches[1].ToLowerInvariant()
      Require (-not $fields.ContainsKey($k)) ('Duplicate config field: ' + $k)
      $fields[$k] = $Matches[2].Trim()
    } else { throw 'Invalid config syntax. Expected TunnelId:tunnel_...,ApiKey:sk-... . No secrets were logged.' }
  }
  Require ($fields.Count -eq 2 -and $fields.ContainsKey('tunnelid') -and $fields.ContainsKey('apikey')) 'TXT must have exactly TunnelId and ApiKey.'
  Require ($fields['tunnelid'] -match '^tunnel_[A-Za-z0-9_-]{8,}$') 'Invalid Tunnel ID.'
  Require ($fields['apikey'].Length -ge 12 -and $fields['apikey'].Length -le 512 -and $fields['apikey'] -notmatch '\s') 'Invalid runtime key.'
  return $fields
}
function RequireProfile([string]$tunnelId) {
  Require (Test-Path -LiteralPath $profilePath -PathType Leaf) 'No tunnel-client profile. First run the second pairing command (init/doctor/run).'
  $yaml = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
  $id = [regex]::Match($yaml, '(?m)^\s*tunnel_id:\s*"?([^"\s]+)"?')
  Require $id.Success 'Could not find Tunnel ID in tunnel-client profile.'
  Require ($id.Groups[1].Value -eq $tunnelId) 'Desktop TXT Tunnel ID does not match existing tunnel-client profile.'
}
function CurrentStatus {
  Note ('Login shortcut: ' + (Test-Path -LiteralPath $shortcutPath))
  Note ('DPAPI runtime key file: ' + (Test-Path -LiteralPath $secretPath))
  Note ('Tunnel profile: ' + (Test-Path -LiteralPath $profilePath))
  Note ('Tunnel executable: ' + (Test-Path -LiteralPath $clientPath))
}
Require ($env:OS -eq 'Windows_NT') 'This is a Windows-only script.'
switch ($Action) {
  'Status' { CurrentStatus; exit 0 }
  'Enable' {
    Note 'This enables automatic tunnel access every time THIS Windows account logs in.'
    Note 'The tunnel can access the configured ChatGPTLocalFiles workspace whenever your account is logged in, even when ChatGPT is closed.'
    Note 'A visible PowerShell console will appear. Closing it stops the tunnel.'
    if (-not $TestSkipConsent) {
      $answer = Read-Host 'PC owner explicitly approves logon auto-start? [Y/N]'
      if ($answer -notmatch '^(Y|y)$') { Note 'Cancelled; nothing changed.'; exit 2 }
    }
    Require (Test-Path -LiteralPath $clientPath -PathType Leaf) 'Tunnel client not installed.'
    Require (Test-Path -LiteralPath $mcpPath -PathType Leaf) 'Local MCP not installed.'
    $file = KeyFilePath
    $config = ReadConfig $file
    RequireProfile $config['tunnelid']
    Require (Test-Path -LiteralPath $scriptPath -PathType Leaf) 'Installed autostart script missing. Download/copy it to local bridge folder first.'
    $secure = ConvertTo-SecureString -String $config['apikey'] -AsPlainText -Force
    $protected = ConvertFrom-SecureString -SecureString $secure
    if (-not (Test-Path -LiteralPath $homeDir)) { New-Item -ItemType Directory -Path $homeDir -Force | Out-Null }
    [IO.File]::WriteAllText($secretPath, $protected, [Text.Encoding]::ASCII)
    $protected = $null
    # The encrypted file is bound to the Windows user profile by DPAPI. It is not portable to other users or PCs.
    $check = Get-Content -LiteralPath $secretPath -Raw -Encoding ASCII | ConvertTo-SecureString
    Require ($check.Length -gt 0) 'DPAPI credential self-check failed.'
    if (-not (Test-Path -LiteralPath $StartupDirectory)) {
      New-Item -ItemType Directory -Path $StartupDirectory -Force | Out-Null
    }
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($shortcutPath)
    $lnk.TargetPath = (Join-Path $PSHOME 'powershell.exe')
    $lnk.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Action Run'
    $lnk.WorkingDirectory = $homeDir
    $lnk.WindowStyle = 1
    $lnk.Description = 'Visible OpenAI local MCP tunnel; close the console to stop it'
    $lnk.Save()
    Require (Test-Path -LiteralPath $shortcutPath -PathType Leaf) 'Failed to save Windows Startup shortcut.'
    Note 'Login auto-start enabled (for the current Windows user only).'
    Note 'Runtime key is stored encrypted with Windows CurrentUser DPAPI.'
    Note ('Shortcut: ' + $shortcutPath)
    Note 'Existing running tunnel is left unchanged. Next Windows login starts a new visible console.'
    if (-not $TestSkipConsent) {
      $remove = Read-Host 'Delete PLAINTEXT credential TXT now? Recommended [Y/N]'
      if ($remove -match '^(Y|y)$') {
        Remove-Item -LiteralPath $file -Force
        Note 'Plaintext TXT deleted (not a secure erase; backups/OneDrive may retain copies).'
      } else {
        Write-Warning 'Your desktop TXT still contains a plaintext API key. Delete/protect it promptly.'
      }
    }
    CurrentStatus
    exit 0
  }
  'Disable' {
    if (-not $TestSkipConsent) {
      $answer = Read-Host 'Remove this Windows login startup entry and DPAPI key? [Y/N]'
      if ($answer -notmatch '^(Y|y)$') { Note 'Cancelled.'; exit 2 }
    }
    if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force }
    if (Test-Path -LiteralPath $secretPath) { Remove-Item -LiteralPath $secretPath -Force }
    Note 'Windows login auto-start disabled. Close any currently running tunnel window separately.'
    CurrentStatus
    exit 0
  }
  'Run' {
    Require (Test-Path -LiteralPath $clientPath -PathType Leaf) 'Tunnel client missing.'
    Require (Test-Path -LiteralPath $mcpPath -PathType Leaf) 'Local MCP missing.'
    Require (Test-Path -LiteralPath $secretPath -PathType Leaf) 'DPAPI key missing. Re-enable login auto-start.'
    Require (Test-Path -LiteralPath $profilePath -PathType Leaf) 'Tunnel profile missing.'
    $key = Get-Content -LiteralPath $secretPath -Raw -Encoding ASCII | ConvertTo-SecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($key)
    try { $env:CONTROL_PLANE_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); Remove-Variable key,ptr -ErrorAction SilentlyContinue }
    $env:LOCAL_PC_ROOT = Join-Path $env:USERPROFILE 'ChatGPTLocalFiles'
    if ($TestNoNetwork) { Note 'Offline test: decrypted DPAPI key and verified local paths. Skipping network.'; Remove-Item Env:CONTROL_PLANE_API_KEY; exit 0 }
    try {
      Note 'Windows login detected. Starting first-party OpenAI tunnel (visible window).'
      for ($attempt = 1; $attempt -le 12; $attempt++) {
        & $clientPath doctor --profile $profileName --explain
        if ($LASTEXITCODE -eq 0) { break }
        if ($attempt -eq 12) { throw 'Tunnel doctor failed 12 times. Check network, API key, tunnel and permissions.' }
        Note ('Network/client not ready, retrying in 20 seconds (attempt ' + $attempt + '/12).')
        Start-Sleep -Seconds 20
      }
      Note 'Doctor passed. Tunnel is ready; close this window to stop.'
      & $clientPath run --profile $profileName
      if ($LASTEXITCODE -ne 0) { throw 'Tunnel client run stopped with an error.' }
    } finally { Remove-Item Env:CONTROL_PLANE_API_KEY -ErrorAction SilentlyContinue }
  }
}
