$ErrorActionPreference = 'SilentlyContinue'
$script = 'C:\Users\Administrator\.openclaw\workspace\9router_ghost_overlay.py'

# Kill older overlay windows/processes so the live polling overlay is not duplicated.
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*9router_ghost_overlay.py*' -or $_.CommandLine -like '*9router-quota-overlay.html*' -or $_.CommandLine -like '*dashboard/quota*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

$python = @('pythonw.exe', 'pyw.exe', 'python.exe', 'py.exe') | Where-Object {
  $cmd = Get-Command $_ -ErrorAction SilentlyContinue
  $null -ne $cmd
} | Select-Object -First 1

if (-not $python) {
  [System.Windows.Forms.MessageBox]::Show('Không tìm thấy Python để chạy 9Router live overlay.', '9Router Overlay') | Out-Null
  exit 1
}

Start-Process -FilePath $python -ArgumentList @($script) -WindowStyle Hidden
