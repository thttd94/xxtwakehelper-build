import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd=r'''python3 - <<'PY'
import urllib.request, json
for u in ['http://127.0.0.1:9001/api/pm/router-info','http://127.0.0.1:9000/api/router/info']:
 print('\nURL',u)
 try:
  with urllib.request.urlopen(u, timeout=10) as r:
   raw=r.read().decode('utf-8','replace')
  print(raw[:2000])
 except Exception as e:
  print('ERR',repr(e))
PY'''
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=120)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
