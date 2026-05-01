import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
HOST='192.14.0.1'; PORT=886; USER='root'; PASSWORD='123123@qq'
cmd = r"""
python3 - <<'PY'
from pathlib import Path
p=Path('/opt/proxy-manager-v1/static/index.html')
text=p.read_text(encoding='utf-8', errors='replace')
if 'id="routerModal"' in text and 'id="routerIp"' in text:
    print('ROUTER_MODAL_ALREADY_EXISTS')
else:
    marker='''<div class="modal" id="ipMacModal">'''
    modal='''  <div class="modal" id="routerModal">
    <div class="modal-card" style="width:min(520px, 92vw)">
      <div class="modal-head">
        <b>Set up Router</b>
        <button class="btn small" onclick="closeRouterModal()">Đóng</button>
      </div>
      <div class="modal-body">
        <div class="field">
          <label>LAN IP</label>
          <input id="routerIp" placeholder="192.168.1.1">
        </div>
        <div class="sub" id="routerInfo">Chỉ sửa LAN IP của router</div>
      </div>
      <div class="modal-foot">
        <button class="btn" onclick="closeRouterModal()">Hủy</button>
        <button class="btn apply" onclick="submitRouterSetup()">Lưu LAN IP</button>
      </div>
    </div>
  </div>

'''
    if marker not in text:
        raise SystemExit('IP_MAC_MODAL_MARKER_NOT_FOUND')
    text=text.replace(marker, modal+marker, 1)
    p.write_text(text, encoding='utf-8')
    print('ADDED_ROUTER_MODAL')
PY
/etc/init.d/proxy-manager-v1 restart 2>/dev/null || true
sleep 1
python3 - <<'PY'
from pathlib import Path
s=Path('/opt/proxy-manager-v1/static/index.html').read_text(encoding='utf-8', errors='replace')
print('routerModal', s.find('id="routerModal"'))
print('routerIp', s.find('id="routerIp"'))
print('openSetupRouter', s.find('openSetupRouter'))
PY
"""
client=paramiko.SSHClient(); client.set_missing_host_key_policy(paramiko.AutoAddPolicy()); client.connect(HOST,port=PORT,username=USER,password=PASSWORD,timeout=20,look_for_keys=False,allow_agent=False)
stdin,stdout,stderr=client.exec_command(cmd,timeout=180)
print(stdout.read().decode('utf-8','ignore'))
err=stderr.read().decode('utf-8','ignore')
if err: print('STDERR:\n'+err)
client.close()
