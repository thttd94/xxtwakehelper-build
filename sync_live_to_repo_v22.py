import paramiko, sys, os
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
files=['/opt/proxy-manager-v1/app.py','/opt/proxy-manager-v1/static/index.html']
outdir=Path('GEN_NEW_9001')
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
sftp=client.open_sftp()
for remote in files:
    local=outdir / ('static/index.html' if remote.endswith('/static/index.html') else 'app.py')
    local.parent.mkdir(parents=True, exist_ok=True)
    sftp.get(remote, str(local))
    print('copied', remote, '->', local)
sftp.close(); client.close()
