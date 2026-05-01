import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd="""python3 - <<'PY'\nfrom pathlib import Path\ns=Path('/opt/proxy-manager-v1/static/index.html').read_text(encoding='utf-8', errors='replace')\nfor needle in ['ipMacModal','modal','sessionManagerModal']:\n i=s.find(needle); print('NEEDLE',needle,i); print(s[max(0,i-200):i+300] if i>=0 else '')\nPY"""
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=120)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
