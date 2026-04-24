local sys = require("sys")
local app = require("app")
local file = require("file")
local webview = require("webview")

local BID_TIKTOK = "com.ss.iphone.ugc.Ame"
local BID_TIKTOK_LITE = "com.ss.iphone.ugc.tiktok.lite"

local html = [[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,sans-serif}
#dock{width:100%;height:100%;display:flex;flex-direction:column;gap:8px;align-items:center;justify-content:center}
.badge{width:66px;min-height:24px;border-radius:12px;background:rgba(15,23,42,.92);color:#fff;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;text-align:center;padding:2px 4px;box-sizing:border-box}
.state{background:rgba(30,41,59,.96);color:#93c5fd}
.btn{width:66px;height:46px;border:0;border-radius:16px;color:#fff;font-size:12px;font-weight:700;box-shadow:0 8px 22px rgba(0,0,0,.28);opacity:.92;transition:all .12s ease}
.btn.active{transform:scale(1.06);opacity:1;box-shadow:0 0 0 3px rgba(255,255,255,.22),0 10px 24px rgba(0,0,0,.35)}
.home{background:#2f80ed}.video{background:#e74c3c}.p20{background:#27ae60}.claim{background:#f2994a}.clear{background:#9b51e0}
</style>
<script>
window.__xxt_action = '';
function pickAction(name){ window.__xxt_action = name; return name; }
function setFrontApp(name){ var el=document.getElementById('frontapp'); if(el){ el.textContent=name; } }
function setActionLabels(p20, claim){
  var a=document.getElementById('btn20p');
  var b=document.getElementById('btnclaim');
  if(a){ a.textContent=p20; }
  if(b){ b.textContent=claim; }
}
function setState(name){ var el=document.getElementById('runstate'); if(el){ el.textContent=name; } }
function setActive(name){
  var ids=['home','video','20p','claim','clear'];
  for(var i=0;i<ids.length;i++){
    var el=document.getElementById('btn_'+ids[i]);
    if(el){ el.classList.remove('active'); }
  }
  var target=document.getElementById('btn_'+name);
  if(target){ target.classList.add('active'); }
}
function clearActive(){ setActive(''); }
</script>
</head>
<body>
<div id="dock">
  <div class="badge" id="frontapp">APP ?</div>
  <div class="badge state" id="runstate">IDLE</div>
  <button class="btn home" id="btn_home" onclick="pickAction('home')">HOME</button>
  <button class="btn video" id="btn_video" onclick="pickAction('video')">VIDEO</button>
  <button class="btn p20" id="btn_20p" onclick="pickAction('20p')">20P</button>
  <button class="btn claim" id="btn_claim" onclick="pickAction('claim')">CLAIM</button>
  <button class="btn clear" id="btn_clear" onclick="pickAction('clear')">CLEAR</button>
</div>
</body>
</html>
]]

local function show_menu()
  webview.show({
    html = html,
    x = 8,
    y = 90,
    width = 78,
    height = 410,
    alpha = 1.0,
    corner_radius = 18,
    opaque = false,
    can_drag = true,
    ignores_hit = false,
  })
end

local function set_state(label, active)
  webview.eval(string.format("setState(%q);", label or 'IDLE'))
  if active and active ~= '' then
    webview.eval(string.format("setActive(%q);", active))
  else
    webview.eval("clearActive();")
  end
end

local function finish_state()
  set_state('IDLE', '')
end

local function run_lua_file(path)
  local code = file.reads(path)
  if code and #tostring(code) > 0 then
    local fn, err = load(code)
    if fn then
      return pcall(fn)
    else
      sys.toast('load lỗi')
      return false, err
    end
  end
  sys.toast('không thấy file')
  return false
end

local function unlock_if_needed()
  local device = require("device")
  while device.is_screen_locked() do
    device.unlock_screen()
    sys.msleep(1000)
  end
end

local function run_home()
  set_state('RUN HOME', 'home')
  app.run('com.apple.springboard')
  sys.toast('HOME')
  sys.msleep(500)
  finish_state()
end

local function run_video()
  set_state('RUN VIDEO', 'video')
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/video_test.lua')
  sys.msleep(700)
  finish_state()
  return ok
end

local function current_front_mode()
  local bid = tostring(app.front_bid() or '')
  if bid == BID_TIKTOK then
    return 'TikTok', '20P TT', 'CLAIM TT'
  elseif bid == BID_TIKTOK_LITE then
    return 'Lite', '20P LITE', 'CLAIM LITE'
  end
  return 'Other', '20P', 'CLAIM'
end

local function run_20p()
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  if bid == BID_TIKTOK then
    set_state('RUN 20P TT', '20p')
    local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_EventDD20p_tiktok.lua')
    sys.msleep(700)
    finish_state()
    return ok
  elseif bid == BID_TIKTOK_LITE then
    set_state('RUN 20P LITE', '20p')
    local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_EventDD20p_tiktok_lite.lua')
    sys.msleep(700)
    finish_state()
    return ok
  end
  set_state('NO APP', '20p')
  sys.toast('Không phải TikTok/Lite')
  sys.msleep(700)
  finish_state()
  return false
end

local function run_claim()
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  if bid == BID_TIKTOK then
    set_state('RUN CLAIM TT', 'claim')
    app.open_url('aweme://webview?url=https%3A%2F%2Fwww.tiktok.com')
    sys.toast('CLAIM TikTok')
    sys.msleep(700)
    finish_state()
    return true
  elseif bid == BID_TIKTOK_LITE then
    set_state('RUN CLAIM LITE', 'claim')
    app.open_url('tiktoklite://')
    sys.toast('CLAIM Lite')
    sys.msleep(700)
    finish_state()
    return true
  end
  set_state('NO APP', 'claim')
  sys.toast('Không phải TikTok/Lite')
  sys.msleep(700)
  finish_state()
  return false
end

local function run_clear()
  set_state('RUN CLEAR', 'clear')
  unlock_if_needed()
  local ids = {
    'com.apple.mobilesafari',
    'com.apple.Preferences',
    'com.apple.AppStore',
    BID_TIKTOK,
    BID_TIKTOK_LITE,
    'ch.xxtou.XXTExplorer'
  }
  for i = 1, #ids do
    pcall(app.quit, ids[i])
    sys.msleep(250)
  end
  sys.toast('Đã đóng app')
  sys.msleep(700)
  finish_state()
  return true
end

show_menu()
set_state('IDLE', '')
local last_action = ''
local last_front = ''
while true do
  local front_name, label_20p, label_claim = current_front_mode()
  if front_name ~= last_front then
    last_front = front_name
    webview.eval(string.format("setFrontApp(%q);", front_name))
    webview.eval(string.format("setActionLabels(%q, %q);", label_20p, label_claim))
  end

  local action = tostring(webview.eval('window.__xxt_action || "";') or '')
  if action ~= '' and action ~= last_action then
    last_action = action
    webview.eval('window.__xxt_action = "";')
    if action == 'home' then
      run_home()
    elseif action == 'video' then
      run_video()
    elseif action == '20p' then
      run_20p()
    elseif action == 'claim' then
      run_claim()
    elseif action == 'clear' then
      run_clear()
    end
  elseif action == '' then
    last_action = ''
  end
  sys.msleep(180)
end
