import paramiko, sys, os, posixpath
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
local_root=Path('GEN_NEW_9001/gen_backup/versions/2.2/package')
remote_root='/root/genrouter_backups/versions/2.2/package'
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
# clear and create remote package
cmd=f"rm -rf {remote_root!r}; mkdir -p {remote_root!r}"
stdin,stdout,stderr=client.exec_command(cmd,timeout=120); stdout.read(); err=stderr.read().decode('utf-8','ignore')
if err: print('prep stderr',err)
sftp=client.open_sftp()
def mkdirp(path):
    parts=[]; p=path
    while p not in ('','/'):
        parts.append(p); p=posixpath.dirname(p)
    for d in reversed(parts):
        try: sftp.mkdir(d)
        except IOError: pass
for path in local_root.rglob('*'):
    rel=path.relative_to(local_root).as_posix()
    rp=remote_root+'/'+rel
    if path.is_dir():
        mkdirp(rp)
    else:
        mkdirp(posixpath.dirname(rp))
        sftp.put(str(path), rp)
sftp.close()
cmd=r'''chmod +x /root/genrouter_backups/versions/2.2/package/*.sh 2>/dev/null || true
mkdir -p /data/genrouter_backups/versions 2>/dev/null || true
if [ -d /data/genrouter_backups/versions ]; then
  rm -rf /data/genrouter_backups/versions/2.2
  mkdir -p /data/genrouter_backups/versions/2.2
  cp -a /root/genrouter_backups/versions/2.2/package /data/genrouter_backups/versions/2.2/
  chmod +x /data/genrouter_backups/versions/2.2/package/*.sh 2>/dev/null || true
fi
cp /root/genrouter_backups/versions/2.2/package/rollback_version.sh /opt/proxy-manager-v1/rollback_version.sh
chmod +x /opt/proxy-manager-v1/rollback_version.sh
printf 'root package: '; cat /root/genrouter_backups/versions/2.2/package/VERSION.txt
printf 'data package: '; cat /data/genrouter_backups/versions/2.2/package/VERSION.txt 2>/dev/null || true
printf 'live rollback exists: '; ls -l /opt/proxy-manager-v1/rollback_version.sh
'''
stdin,stdout,stderr=client.exec_command(cmd,timeout=180)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
print('uploaded v2.2 package')
