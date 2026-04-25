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
#dock{width:100%;height:100%;display:flex;flex-direction:column;gap:12px;align-items:center;justify-content:flex-start;padding:12px 0;box-sizing:border-box}
.badge{width:132px;min-height:40px;border-radius:18px;background:rgba(15,23,42,.92);color:#fff;font-size:18px;font-weight:700;display:flex;align-items:center;justify-content:center;text-align:center;padding:4px 8px;box-sizing:border-box}
.state{background:rgba(30,41,59,.96);color:#93c5fd}
.btn{width:132px;height:78px;border:0;border-radius:24px;color:#fff;font-size:22px;font-weight:700;box-shadow:0 8px 22px rgba(0,0,0,.28);opacity:.96;transition:all .12s ease}
.btn.active{transform:scale(1.04);opacity:1;box-shadow:0 0 0 3px rgba(255,255,255,.22),0 10px 24px rgba(0,0,0,.35)}
.home{background:#2563eb}.tiktok{background:#111827}.lite{background:#16a34a}.close{background:#7c3aed}.lock{background:#dc2626}.sub{background:#ea580c;font-size:20px;height:74px}.back{background:#475569}
</style>
<script>
window.__xxt_action = '';
window.__xxt_mode = 'home';
function pickAction(name){ window.__xxt_action = name; return false; }
function setFrontApp(name){ var el=document.getElementById('frontapp'); if(el){ el.textContent=name; } }
function setState(name){ var el=document.getElementById('runstate'); if(el){ el.textContent=name; } }
function setMode(mode){
  window.__xxt_mode = mode || 'home';
  var homeRows = document.querySelectorAll('.home-row');
  var ttRows = document.querySelectorAll('.tt-row');
  var liteRows = document.querySelectorAll('.lite-row');
  for(var i=0;i<homeRows.length;i++){ homeRows[i].style.display = (window.__xxt_mode === 'home') ? 'block' : 'none'; }
  for(var j=0;j<ttRows.length;j++){ ttRows[j].style.display = (window.__xxt_mode === 'tiktok') ? 'block' : 'none'; }
  for(var k=0;k<liteRows.length;k++){ liteRows[k].style.display = (window.__xxt_mode === 'lite') ? 'block' : 'none'; }
}
function setActive(name){
  var nodes = document.querySelectorAll('.btn');
  for(var i=0;i<nodes.length;i++){ nodes[i].classList.remove('active'); }
  var target=document.getElementById('btn_'+name);
  if(target){ target.classList.add('active'); }
}
function clearActive(){
  var nodes = document.querySelectorAll('.btn');
  for(var i=0;i<nodes.length;i++){ nodes[i].classList.remove('active'); }
}
window.onload = function(){ setMode('home'); };
</script>
</head>
<body>
<div id="dock">
  <div class="badge" id="frontapp">HOME</div>
  <div class="badge state" id="runstate">IDLE</div>

  <div class="home-row"><button class="btn home" id="btn_home" onclick="return pickAction('home')">HOME</button></div>
  <div class="home-row"><button class="btn tiktok" id="btn_tiktok" onclick="setMode(window.__xxt_mode==='tiktok'?'home':'tiktok');return false;">TIKTOK</button></div>
  <div class="home-row"><button class="btn lite" id="btn_lite" onclick="setMode(window.__xxt_mode==='lite'?'home':'lite');return false;">TIKTOK LITE</button></div>
  <div class="home-row"><button class="btn close" id="btn_clear" onclick="return pickAction('clear')">ĐÓNG ỨNG DỤNG</button></div>
  <div class="home-row"><button class="btn lock" id="btn_lock" onclick="return pickAction('lock')">LOCK</button></div>

  <div class="tt-row" style="display:none"><button class="btn back" id="btn_tt_back" onclick="setMode('home');return false;">← TIKTOK</button></div>
  <div class="tt-row" style="display:none"><button class="btn sub" id="btn_tt_nurture" onclick="return pickAction('tt_nurture')">NUÔI PHÔI</button></div>
  <div class="tt-row" style="display:none"><button class="btn sub" id="btn_tt_ev180" onclick="return pickAction('tt_ev180')">EVENT 180P</button></div>
  <div class="tt-row" style="display:none"><button class="btn sub" id="btn_tt_dd20" onclick="return pickAction('tt_dd20')">EVENT DD 20P</button></div>

  <div class="lite-row" style="display:none"><button class="btn back" id="btn_lite_back" onclick="setMode('home');return false;">← TIKTOK LITE</button></div>
  <div class="lite-row" style="display:none"><button class="btn sub" id="btn_lite_nurture" onclick="return pickAction('lite_nurture')">NUÔI PHÔI</button></div>
  <div class="lite-row" style="display:none"><button class="btn sub" id="btn_lite_ev180" onclick="return pickAction('lite_ev180')">EVENT 180P</button></div>
  <div class="lite-row" style="display:none"><button class="btn sub" id="btn_lite_dd20" onclick="return pickAction('lite_dd20')">EVENT DD 20P</button></div>
</div>
</body>
</html>
]]

local function show_menu()
  webview.show({
    html = html,
    x = 8,
    y = 40,
    width = 154,
    height = 820,
    alpha = 1.0,
    corner_radius = 24,
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

local function finish_state(go_home)
  if go_home ~= false then
    webview.eval("setMode('home');")
  end
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

local function current_front_name()
  local bid = tostring(app.front_bid() or '')
  if bid == BID_TIKTOK then
    return 'TikTok'
  elseif bid == BID_TIKTOK_LITE then
    return 'TikTok Lite'
  elseif bid == 'com.apple.springboard' then
    return 'Home'
  end
  return 'Home'
end

local function update_front_badge()
  webview.eval(string.format("setFrontApp(%q);", current_front_name()))
end

local function run_home()
  set_state('RUN HOME', 'home')
  unlock_if_needed()
  app.run('com.apple.springboard')
  sys.toast('HOME')
  sys.msleep(500)
  update_front_badge()
  finish_state(true)
end

local function run_lock()
  set_state('RUN LOCK', 'lock')
  local device = require("device")
  device.lock_screen()
  sys.toast('LOCK')
  sys.msleep(500)
  finish_state(false)
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
  sys.toast('Đã đóng ứng dụng')
  sys.msleep(700)
  finish_state(false)
end

local function run_tiktok_nurture()
  set_state('TT NUÔI PHÔI', 'tt_nurture')
  unlock_if_needed()
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_NuoiPhoi_tiktok.lua')
  sys.msleep(700)
  finish_state(true)
  return ok
end

local function run_tiktok_ev180()
  set_state('TT EVENT 180P', 'tt_ev180')
  unlock_if_needed()
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_EventVideo180_tiktok.lua')
  sys.msleep(700)
  finish_state(true)
  return ok
end

local function run_tiktok_dd20()
  set_state('TT EVENT DD 20P', 'tt_dd20')
  unlock_if_needed()
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_EventDD20p_tiktok.lua')
  sys.msleep(700)
  finish_state(true)
  return ok
end

local function run_lite_nurture()
  set_state('LITE NUÔI PHÔI', 'lite_nurture')
  unlock_if_needed()
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_NuoiPhoi_tiktok_lite.lua')
  sys.msleep(700)
  finish_state(true)
  return ok
end

local function run_lite_ev180()
  set_state('LITE EVENT 180P', 'lite_ev180')
  unlock_if_needed()
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_EventVideo180_tiktok_lite.lua')
  sys.msleep(700)
  finish_state(true)
  return ok
end

local function run_lite_dd20()
  set_state('LITE EVENT DD 20P', 'lite_dd20')
  unlock_if_needed()
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/Group3_EventDD20p_tiktok_lite.lua')
  sys.msleep(700)
  finish_state(true)
  return ok
end

show_menu()
update_front_badge()
set_state('IDLE', '')
local last_action = ''
while true do
  update_front_badge()
  local action = tostring(webview.eval('window.__xxt_action || "";') or '')
  if action ~= '' and action ~= last_action then
    last_action = action
    webview.eval('window.__xxt_action = "";')
    if action == 'home' then
      run_home()
    elseif action == 'clear' then
      run_clear()
    elseif action == 'lock' then
      run_lock()
    elseif action == 'tt_nurture' then
      run_tiktok_nurture()
    elseif action == 'tt_ev180' then
      run_tiktok_ev180()
    elseif action == 'tt_dd20' then
      run_tiktok_dd20()
    elseif action == 'lite_nurture' then
      run_lite_nurture()
    elseif action == 'lite_ev180' then
      run_lite_ev180()
    elseif action == 'lite_dd20' then
      run_lite_dd20()
    end
  elseif action == '' then
    last_action = ''
  end
  sys.msleep(180)
end
