import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd=r'''python3 - <<'PY'
from pathlib import Path
p=Path('/opt/proxy-manager-v1/static/index.html')
s=p.read_text(encoding='utf-8', errors='replace')
old="""      const lines = getVisibleRows().filter(r => String(r.note || '').trim()).map(r => `${r.ip} | ${r.tag || '-'} | ${r.note.trim()}`);"""
new="""      const lines = getVisibleRows().filter(r => String(r.note || '').trim()).map(r => `Máy ${String(r.machine || '').trim() || '?'} : ${String(r.note || '').trim()}`);"""
if old not in s:
    i=s.find('const lines = getVisibleRows().filter')
    print(s[i-100:i+300] if i>=0 else 'NO lines')
    raise SystemExit('notes summary line not found')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('PATCHED_NOTE_SUMMARY_MACHINE_ONLY')
PY
/etc/init.d/proxy-manager-v1 restart 2>/dev/null || true
sleep 1
python3 - <<'PY'
from pathlib import Path
s=Path('/opt/proxy-manager-v1/static/index.html').read_text(encoding='utf-8', errors='replace')
i=s.find('function renderNotesSummary')
print(s[i:i+500])
PY
'''
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=180)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
