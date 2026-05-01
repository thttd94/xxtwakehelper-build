import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd=r'''python3 - <<'PY'
from pathlib import Path
text=Path('/opt/proxy-manager-v1/app.py').read_text(encoding='utf-8', errors='replace')
for needle in ['setup router','setup_router','Setup Router','network','lan','ipaddr','/etc/config/network','api/router','reboot']:
 print('\n###',needle)
 low=text.lower(); n=needle.lower(); pos=0; c=0
 while True:
  i=low.find(n,pos)
  if i<0 or c>=10: break
  print('---pos',i,'---')
  print(text[max(0,i-500):i+900])
  pos=i+1; c+=1
PY
printf '\nSTATIC SETUP refs\n'
grep -R -n "Setup Router\|Set up Router\|setup router\|setupRouter\|routerSetup\|network\|ipaddr\|LAN" /opt/proxy-manager-v1/static /opt/proxy-manager-v1 2>/dev/null | head -200
'''
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=180)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
