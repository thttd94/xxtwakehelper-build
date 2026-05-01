import paramiko, sys, posixpath, shutil
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
local_root=Path('GEN_NEW_9001')
# upload latest full_system_backup + rollback to source router first
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
sftp=client.open_sftp()
for name in ['full_system_backup.sh','rollback_version.sh']:
    sftp.put(str(local_root/name), f'/opt/proxy-manager-v1/{name}')
cmd=r'''chmod +x /opt/proxy-manager-v1/full_system_backup.sh /opt/proxy-manager-v1/rollback_version.sh
# make sure package uses latest rollback/full backup scripts
mkdir -p /root/genrouter_backups/versions/2.2/package /data/genrouter_backups/versions/2.2/package 2>/dev/null || true
sh /opt/proxy-manager-v1/full_system_backup.sh 2.2
printf '\nSNAPSHOT ROOTS\n'
find /data/genrouter_backups/versions/2.2 -maxdepth 2 -type f 2>/dev/null | sort || true
find /root/genrouter_backups/versions/2.2 -maxdepth 2 -type f 2>/dev/null | sort || true
'''
stdin,stdout,stderr=client.exec_command(cmd,timeout=600)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
# download selected backup root (prefer data)
remote_base='/data/genrouter_backups/versions/2.2'
try:
    sftp.stat(remote_base+'/system/system_manifest.txt')
except Exception:
    remote_base='/root/genrouter_backups/versions/2.2'
local_ver=local_root/'gen_backup'/'versions'/'2.2'
if local_ver.exists(): shutil.rmtree(local_ver)
(local_ver/'package').mkdir(parents=True)
(local_ver/'system').mkdir(parents=True)
def download_dir(remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for item in sftp.listdir_attr(remote):
        rp=remote+'/'+item.filename; lp=local/item.filename
        if str(item.longname).startswith('d'):
            download_dir(rp, lp)
        else:
            sftp.get(rp, str(lp))
download_dir(remote_base+'/package', local_ver/'package')
download_dir(remote_base+'/system', local_ver/'system')
sftp.close(); client.close()
print('downloaded full V2.2 snapshot from', remote_base, 'to', local_ver)
