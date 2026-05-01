import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd=r'''printf 'root v2.2: '; test -f /root/genrouter_backups/versions/2.2/package/VERSION.txt && cat /root/genrouter_backups/versions/2.2/package/VERSION.txt || echo missing
printf 'data v2.2: '; test -f /data/genrouter_backups/versions/2.2/package/VERSION.txt && cat /data/genrouter_backups/versions/2.2/package/VERSION.txt || echo missing
printf 'root v1.1: '; test -f /root/genrouter_backups/versions/1.1/package/VERSION.txt && cat /root/genrouter_backups/versions/1.1/package/VERSION.txt || echo missing
printf 'data v1.1: '; test -f /data/genrouter_backups/versions/1.1/package/VERSION.txt && cat /data/genrouter_backups/versions/1.1/package/VERSION.txt || echo missing
printf '\nrollback script head:\n'; sed -n '1,45p' /opt/proxy-manager-v1/rollback_version.sh
'''
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=120)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
