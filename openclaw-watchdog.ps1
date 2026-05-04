$ErrorActionPreference = 'SilentlyContinue'
$port = 18789
$workspace = 'C:\Users\Administrator\.openclaw\workspace'
$starterVbs = Join-Path $workspace 'start-hidden.vbs'
$starterCmd = Join-Path $workspace 'start-openclaw-hidden.cmd'
$log = Join-Path $workspace 'openclaw-watchdog.log'

function Write-Log($msg) {
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -Encoding UTF8 -Path $log -Value "$ts $msg"
}

$listen = $false
try {
  $listen = [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
} catch {
  $netstat = netstat -ano | Select-String ":$port\s+.*LISTENING"
  $listen = [bool]$netstat
}

if ($listen) {
  exit 0
}

Write-Log "OpenClaw gateway port $port not listening; starting hidden gateway."
if ((Test-Path $starterVbs) -and (Test-Path $starterCmd)) {
  Start-Process -FilePath 'wscript.exe' -ArgumentList @('"' + $starterVbs + '"', '"' + $starterCmd + '"') -WorkingDirectory $workspace -WindowStyle Hidden
  exit 0
}

Write-Log "Missing starter files: $starterVbs or $starterCmd"
exit 1
