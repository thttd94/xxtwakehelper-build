import subprocess, time
from pathlib import Path

PORT = 8899

# best-effort kill existing listener by checking netstat output
try:
    out = subprocess.check_output(['netstat', '-ano'], text=True, errors='ignore')
    pids = set()
    for line in out.splitlines():
        if f':{PORT} ' in line and 'LISTENING' in line:
            parts = line.split()
            if parts:
                pids.add(parts[-1])
    for pid in pids:
        try:
            subprocess.run(['taskkill', '/PID', pid, '/F'], check=False, capture_output=True, text=True)
        except Exception:
            pass
except Exception as e:
    print('kill-scan err', e)

time.sleep(1)
subprocess.run(['python', 'proxy_checker_server.py', '--host', '127.0.0.1', '--port', str(PORT)])
