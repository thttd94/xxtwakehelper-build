import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd=r'''printf 'Live VERSION: '; cat /opt/proxy-manager-v1/VERSION.txt 2>/dev/null || true
printf '\nSet VERSION V2.2 on live...\n'; printf 'V2.2\n' > /opt/proxy-manager-v1/VERSION.txt
/etc/init.d/proxy-manager-v1 restart 2>/dev/null || true
sleep 1
printf 'Live VERSION now: '; cat /opt/proxy-manager-v1/VERSION.txt
printf '\nLive GUI checks:\n'
python3 - <<'PY'
from pathlib import Path
s=Path('/opt/proxy-manager-v1/static/index.html').read_text(encoding='utf-8', errors='replace')
checks={
 'routerModal': 'id="routerModal"' in s,
 'sessionManagerModal': 'id="sessionManagerModal"' in s,
 'saveButtonRemoved': 'onclick="saveCurrent()">SAVE</button>' not in s,
 'noteMachineOnly': 'Máy ${String(r.machine' in s,
 'gearManager': 'id="manageSessionBtn"' in s and 'onclick="openSessionManager()"' in s,
}
print(checks)
PY
'''
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=180)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
