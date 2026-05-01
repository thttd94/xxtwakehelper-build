import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd=r'''python3 - <<'PY'
from pathlib import Path
p=Path('/opt/proxy-manager-v1/static/index.html')
s=p.read_text(encoding='utf-8', errors='replace')
for needle in ['noteSummary','NOTE TỔNG','NOTE TONG','renderNote','note tổng','noteTotal','bulkNote']:
 print('\n###',needle,s.find(needle))
 i=s.find(needle)
 if i>=0: print(s[max(0,i-800):i+1600])
PY'''
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=120)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
