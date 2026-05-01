import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd = r"""
python3 - <<'PY'
from pathlib import Path
p=Path('/opt/proxy-manager-v1/static/index.html')
text=p.read_text(encoding='utf-8', errors='replace')
# 1) Remove standalone SAVE button above CHECK ALL.
save_btn='''        <button class="btn save-strong" onclick="saveCurrent()">SAVE</button>\n'''
if save_btn in text:
    text=text.replace(save_btn, '', 1)
    print('REMOVED_SAVE_BUTTON')
elif 'onclick="saveCurrent()">SAVE</button>' in text:
    text=text.replace('        <button class="btn save-strong" onclick="saveCurrent()">SAVE</button>\n', '', 1)
    print('REMOVED_SAVE_BUTTON_FALLBACK')
else:
    print('SAVE_BUTTON_NOT_FOUND')
# 2) Ensure session manager modal exists (older good version functionality).
if 'id="sessionManagerModal"' in text and 'id="sessionManagerList"' in text:
    print('SESSION_MANAGER_MODAL_EXISTS')
else:
    marker='''<div class="modal" id="routerModal">'''
    if marker not in text:
        marker='''<div class="modal" id="ipMacModal">'''
    modal='''  <div class="modal" id="sessionManagerModal">
    <div class="modal-card" style="width:min(760px, 94vw)">
      <div class="modal-head">
        <b>QUẢN LÝ CẤU HÌNH</b>
        <button class="btn small" onclick="closeSessionManager()">Đóng</button>
      </div>
      <div class="modal-body">
        <div class="sub">Quản lý tất cả cấu hình ở một chỗ. Có thể ẩn/hiện hoặc xóa cấu hình phụ.</div>
        <div id="sessionManagerList" style="display:grid; gap:10px;"></div>
      </div>
    </div>
  </div>

'''
    if marker not in text:
        raise SystemExit('NO_MODAL_INSERT_MARKER')
    text=text.replace(marker, modal+marker, 1)
    print('ADDED_SESSION_MANAGER_MODAL')
# 3) Ensure gear calls session manager.
text=text.replace('id="manageSessionBtn" disabled', 'id="manageSessionBtn"')
if 'id="manageSessionBtn"' in text and 'onclick="openSessionManager()"' in text:
    print('GEAR_SESSION_MANAGER_OK')
else:
    print('GEAR_NEEDS_MANUAL_CHECK')
p.write_text(text, encoding='utf-8')
PY
/etc/init.d/proxy-manager-v1 restart 2>/dev/null || true
sleep 1
python3 - <<'PY'
from pathlib import Path
s=Path('/opt/proxy-manager-v1/static/index.html').read_text(encoding='utf-8', errors='replace')
print('SAVE button index', s.find('onclick="saveCurrent()">SAVE</button>'))
print('sessionManagerModal', s.find('id="sessionManagerModal"'))
print('sessionManagerList', s.find('id="sessionManagerList"'))
print('openSessionManager', s.find('openSessionManager'))
print('manageSessionBtn', s.find('manageSessionBtn'))
PY
"""
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=180)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
