#requires -Version 5.1
# Local PC Bridge: install official openai/tunnel-client for Windows.
# No Desktop Commander package and no stored runtime API key.
[CmdletBinding()]
param([switch]$InstallOnly,[switch]$RunOnly,[switch]$DryRun,[string]$TunnelId)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$homeDir = Join-Path $env:LOCALAPPDATA 'ChatGPTLocalPCBridge'
$clientFile = Join-Path $homeDir 'tunnel-client.exe'
$mcpFile = Join-Path $homeDir 'local-pc-mcp.cjs'
$launcherFile = Join-Path $homeDir 'START-TUNNEL.cmd'
$profileName = 'chatgpt-local-pc'
function Info([string]$message) { Write-Host ('[TUNNEL] ' + $message) }
function Ensure([bool]$condition,[string]$message) { if (-not $condition) { throw $message } }
if ($DryRun) {
    Info ('Local MCP found: ' + (Test-Path -LiteralPath $mcpFile))
    Info ('Official client found: ' + (Test-Path -LiteralPath $clientFile))
    exit 0
}
Ensure ($env:OS -eq 'Windows_NT') 'Requires Windows.'
Ensure (-not ($InstallOnly -and $RunOnly)) 'Conflicting switches.'
Ensure (Test-Path -LiteralPath $mcpFile) 'Install the local MCP with INSTALL.cmd first.'
if (-not $RunOnly) {
    $headers = @{'Accept'='application/vnd.github+json';'User-Agent'='chatgpt-local-pc-bridge-installer'}
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/openai/tunnel-client/releases/latest' -Headers $headers
    Ensure (-not $release.draft -and -not $release.prerelease) 'Unstable release refused.'
    Ensure ($release.tag_name -match '^v[0-9]+\.[0-9]+\.[0-9]+$') 'Unexpected release tag.'
    $arch = switch ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
      'X64' {'amd64';break}
      'Arm64' {'arm64';break}
      default {throw 'Only Windows amd64/arm64 is supported.'}
    }
    $assetName = 'tunnel-client-' + $release.tag_name + '-windows-' + $arch + '.zip'
    $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
    Ensure ($assets.Count -eq 1) ('Missing official archive: ' + $assetName)
    $url = 'https://github.com/openai/tunnel-client/releases/download/' + $release.tag_name + '/' + $assetName
    Ensure ($assets[0].browser_download_url -eq $url) 'Unexpected download destination.'
    $digestMatch = [regex]::Match([string]$assets[0].digest, '^sha256:([a-fA-F0-9]{64})$')
    Ensure ($digestMatch.Success) 'No SHA-256 digest in official GitHub release; refusing install.'
    $expected = $digestMatch.Groups[1].Value.ToUpperInvariant()
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('openai-tunnel-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp $assetName
        Info ('Downloading official openai/tunnel-client ' + $release.tag_name)
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Ensure ((Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash -eq $expected) 'SHA-256 mismatch. Refusing install.'
        Info 'GitHub official SHA-256 digest verified.'
        $extract = Join-Path $tmp 'unpacked'
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $binary = @(Get-ChildItem -LiteralPath $extract -File -Recurse -Filter 'tunnel-client.exe')
        Ensure ($binary.Count -eq 1) 'Official ZIP did not contain exactly one tunnel-client.exe.'
        & $binary[0].FullName --version
        Ensure ($LASTEXITCODE -eq 0) 'Official executable version check failed.'
        Copy-Item -LiteralPath $binary[0].FullName -Destination $clientFile -Force
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    $newline = [Environment]::NewLine
    $launcher = '@echo off' + $newline +
       'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP-TUNNEL.ps1" -RunOnly' + $newline +
       'if errorlevel 1 pause' + $newline
    [IO.File]::WriteAllText($launcherFile,$launcher,[Text.Encoding]::ASCII)
    Info ('Official tunnel client installed: ' + $clientFile)
    Info ('Later restart: ' + $launcherFile)
    if ($InstallOnly) { Info 'Client-only install completed. Tunnel pairing remains separate.';exit 0 }
}
Ensure (Test-Path -LiteralPath $clientFile) 'Official tunnel-client executable missing.'
$env:LOCAL_PC_ROOT = Join-Path $env:USERPROFILE 'ChatGPTLocalFiles'
if (-not $RunOnly) {
    if (-not $TunnelId) { $TunnelId = Read-Host 'Existing Tunnel ID (blank to configure later)' }
    if ([string]::IsNullOrWhiteSpace($TunnelId)) {
        Info 'Tunnel ID not provided; installed client is ready for later configuration.'
        exit 0
    }
    Ensure ($TunnelId -match '^tunnel_[A-Za-z0-9_-]{8,}$') 'Invalid Tunnel ID.'
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    $cmd = '"' + $node + '" "' + $mcpFile + '"'
    & $clientFile init --sample sample_mcp_stdio_local --profile $profileName --tunnel-id $TunnelId --mcp-command $cmd
    Ensure ($LASTEXITCODE -eq 0) 'tunnel-client init failed.'
    Info 'Tunnel profile configured.'
}
Info 'Runtime API key is entered only in this terminal session and not saved.'
$secret = Read-Host 'Runtime API key (hidden; blank to finish without connecting)' -AsSecureString
if ($secret.Length -eq 0) { Info ('Run ' + $launcherFile + ' later.');exit 0 }
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try { $env:CONTROL_PLANE_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    Remove-Variable secret,ptr -ErrorAction SilentlyContinue
}
try {
    Info 'Running official doctor connection checks.'
    & $clientFile doctor --profile $profileName --explain
    Ensure ($LASTEXITCODE -eq 0) 'Doctor failed: check ID, runtime key and Platform permission.'
    Info 'Doctor passed. Keep this window open to keep ChatGPT connected.'
    Info 'Next: ChatGPT Plugins > Custom MCP server > Tunnel > Authentication None.'
    & $clientFile run --profile $profileName
    Ensure ($LASTEXITCODE -eq 0) 'Tunnel client stopped with an error.'
} finally { Remove-Item Env:CONTROL_PLANE_API_KEY -ErrorAction SilentlyContinue }
