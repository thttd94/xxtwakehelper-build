local sys = require("sys")
local app = require("app")
local file = require("file")
local webview = require("webview")

local BID_TIKTOK = "com.ss.iphone.ugc.Ame"
local BID_TIKTOK_LITE = "com.ss.iphone.ugc.tiktok.lite"
local BID_HOME = "com.apple.springboard"
local LUA_DIR = "/var/mobile/Media/1ferver/lib/"

local side_html = [[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,user-scalable=no">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,sans-serif;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}
*{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;box-sizing:border-box}
#dock{width:100%;height:100%;display:flex;flex-direction:row;gap:10px;align-items:center;justify-content:flex-start;padding:8px 10px;overflow:hidden}
#actions{display:flex;flex-direction:row;flex-wrap:nowrap;gap:8px;align-items:center;justify-content:flex-start;overflow:hidden;max-width:640px}
.badge{width:72px;height:72px;border-radius:20px;background:#ff3b30;color:#fff;font-size:14px;font-weight:700;display:flex;align-items:center;justify-content:center;text-align:center;padding:8px;border:0;box-shadow:0 10px 22px rgba(0,0,0,.24);flex:0 0 auto}
.btn{width:62px;height:62px;border:0;border-radius:24px;color:#fff;font-size:10px;font-weight:700;box-shadow:0 8px 18px rgba(0,0,0,.24);opacity:.96;transition:all .12s ease;outline:none;padding:6px;line-height:1.0;flex:0 0 auto}
.btn.active{transform:scale(1.04);opacity:1;box-shadow:0 0 0 4px rgba(255,255,255,.22),0 14px 30px rgba(0,0,0,.35)}
.home{background:#2f80ed}.video{background:#ff3b30}.p20{background:#27ae60}.claim{background:#f2994a}.clear{background:#9b51e0}.app{background:#111827}.home-tiktok{background:#f2c94c;color:#111827}
.compact #actions{display:none!important;width:0!important;max-width:0!important;opacity:0!important;pointer-events:none!important;overflow:hidden!important}
.compact #dock{justify-content:flex-start;padding-right:0!important}
.hidden{display:none!important}
</style>
<script>
window.__xxt_action = '';
window.__xxt_compact = false;
window.__xxt_last_action_at = Date.now();
function markAction(){ window.__xxt_last_action_at = Date.now(); }
function pickAction(name){ markAction(); window.__xxt_action = name; return false; }
function lockUi(){ document.addEventListener('selectstart', function(e){ e.preventDefault(); }); document.addEventListener('contextmenu', function(e){ e.preventDefault(); }); }
function setFrontApp(name){ var el=document.getElementById('frontapp'); if(el){ el.textContent=name; } }
window.__xxt_home_submenu = '';
window.__xxt_current_mode = 'other';
function setActionLabels(video, claim, p20){ var a=document.getElementById('btn_video'); var b=document.getElementById('btn_claim'); var c=document.getElementById('btn_20p'); if(a){ a.textContent=video; } if(b){ b.textContent=claim; } if(c){ c.textContent=p20 || '20P'; } }
function setAppButtons(tt, lite){ var a=document.getElementById('btn_tiktok'); var b=document.getElementById('btn_lite'); if(a){ a.textContent=tt; } if(b){ b.textContent=lite; } }
function setClearLabel(text){ var el=document.getElementById('btn_clear'); if(el){ el.textContent=text; } }
function setHomeSubmenuLabels(nurtureLabel, clearLabel, installLabel){ var a=document.getElementById('btn_video'); var b=document.getElementById('btn_claim'); var c=document.getElementById('btn_clear'); if(a){ a.textContent=nurtureLabel; } if(b){ b.textContent=clearLabel; } if(c){ c.textContent=installLabel; } }
function setActive(name){ var ids=['home','tiktok','lite','video','claim','clear','20p']; for(var i=0;i<ids.length;i++){ var el=document.getElementById('btn_'+ids[i]); if(el){ el.classList.remove('active'); } } var target=document.getElementById('btn_'+name); if(target){ target.classList.add('active'); } }
function clearActive(){ var ids=['home','tiktok','lite','video','claim','clear','20p']; for(var i=0;i<ids.length;i++){ var el=document.getElementById('btn_'+ids[i]); if(el){ el.classList.remove('active'); } } }
function setCompactMode(compact){
  window.__xxt_compact = !!compact;
  if(document.body){ document.body.classList.toggle('compact', window.__xxt_compact); }
}
function toggleCompact(){ markAction(); setCompactMode(!window.__xxt_compact); window.__xxt_action = window.__xxt_compact ? '__compact_on__' : '__compact_off__'; return false; }
function setMenuLayout(mode){
  window.__xxt_current_mode = mode || 'other';
  var isHome = mode === 'home';
  var isTikTok = mode === 'tiktok';
  var isLite = mode === 'lite';
  var homeSub = window.__xxt_home_submenu || '';
  var showHomeButtons = false;
  var showTikTokMain = isHome && (!homeSub || homeSub === 'tiktok');
  var showLiteMain = isHome && (!homeSub || homeSub === 'lite');
  var showActionButtons = isTikTok || isLite || (isHome && !!homeSub);

  var btnHome = document.getElementById('btn_home');
  var btnTikTok = document.getElementById('btn_tiktok');
  var btnLite = document.getElementById('btn_lite');
  var btnVideo = document.getElementById('btn_video');
  var btnClaim = document.getElementById('btn_claim');
  var btnClear = document.getElementById('btn_clear');
  var btn20p = document.getElementById('btn_20p');

  if(btnHome){ btnHome.classList.toggle('hidden', !showHomeButtons); }
  if(btnTikTok){
    btnTikTok.classList.toggle('hidden', !showTikTokMain);
    btnTikTok.classList.toggle('home-tiktok', isHome);
  }
  if(btnLite){ btnLite.classList.toggle('hidden', !showLiteMain); }
  if(btnVideo){ btnVideo.classList.toggle('hidden', !showActionButtons); }
  if(btnClaim){ btnClaim.classList.toggle('hidden', !showActionButtons); }
  if(btn20p){ btn20p.classList.toggle('hidden', !(isTikTok || isLite)); }
  if(btnClear){ btnClear.classList.toggle('hidden', false); }
}
function setHomeSubmenu(name){
  window.__xxt_home_submenu = name || '';
  if(window.__xxt_current_mode === 'home'){
    setMenuLayout('home');
  } else {
    setMenuLayout(window.__xxt_current_mode || 'other');
  }
}
function autoHideLoop(){
  setInterval(function(){
    if(!window.__xxt_compact && (Date.now() - window.__xxt_last_action_at) >= 30000){
      window.__xxt_action = '__compact_on__';
    }
  }, 1000);
}
window.onload = function(){ lockUi(); setCompactMode(false); setMenuLayout('other'); autoHideLoop(); };
</script>
</head>
<body>
<div id="dock">
  <button class="badge" id="frontapp" onclick="return toggleCompact()">APP ?</button>
  <div id="actions">
    <button class="btn home action-btn hidden" id="btn_home" onclick="return pickAction('home')">HOME</button>
    <button class="btn app action-btn hidden" id="btn_tiktok" onclick="return pickAction('tiktok')">TIKTOK</button>
    <button class="btn app action-btn hidden" id="btn_lite" onclick="return pickAction('lite')">LITE</button>
    <button class="btn video action-btn hidden" id="btn_video" onclick="return pickAction('video')">VIDEO</button>
    <button class="btn claim action-btn hidden" id="btn_claim" onclick="return pickAction('claim')">CLAIM</button>
    <button class="btn p20 action-btn hidden" id="btn_20p" onclick="return pickAction('20p')">20P</button>
    <button class="btn clear action-btn" id="btn_clear" onclick="return pickAction('clear')">CLEAR</button>
  </div>
</div>
</body>
</html>
]]

local top_html = [[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,user-scalable=no">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,sans-serif;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}
*{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent}
#status{width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:transparent;color:rgb(255,0,0);border-radius:10px;font-size:16px;font-weight:700;padding:0 14px;box-sizing:border-box;text-align:center;white-space:nowrap;overflow:hidden}
</style>
<script>
function lockUi(){ document.addEventListener('selectstart', function(e){ e.preventDefault(); }); document.addEventListener('contextmenu', function(e){ e.preventDefault(); }); }
function setTopStatus(text){ var el=document.getElementById('status'); if(el){ el.textContent=String(text || ''); } }
window.onload = lockUi;
</script>
</head>
<body>
<div id="status"></div>
</body>
</html>
]]

local MENU_X = 20
local MENU_Y = 1110
local MENU_W = 740
local MENU_W_COMPACT = 92
local MENU_H_EXPANDED = 88
local MENU_H_COMPACT = 88

local current_menu_x = MENU_X
local current_menu_y = MENU_Y

local function show_menu(height)
  local width = current_menu_compact and MENU_W_COMPACT or MENU_W
  webview.show({ id = 1, html = side_html, x = current_menu_x, y = current_menu_y, width = width, height = height or MENU_H_EXPANDED, alpha = 1.0, corner_radius = 26, opaque = false, can_drag = true, ignores_hit = false })
  webview.show({ id = 2, html = top_html, x = 1, y = 1, width = 783, height = 35, alpha = 1.0, corner_radius = 10, opaque = false, can_drag = false, ignores_hit = true })
end

local current_front_app_text = 'APP ?'

local current_menu_mode = 'other'
local current_menu_compact = false
local current_home_submenu = ''

local function sync_menu_view()
  local target_h = current_menu_compact and MENU_H_COMPACT or MENU_H_EXPANDED
  local target_w = current_menu_compact and MENU_W_COMPACT or MENU_W
  current_menu_x = MENU_X
  current_menu_y = MENU_Y
  webview.show({ id = 1, html = side_html, x = current_menu_x, y = current_menu_y, width = target_w, height = target_h, alpha = 1.0, corner_radius = 28, opaque = false, can_drag = true, ignores_hit = false })
  sys.msleep(120)
  webview.eval(string.format("setCompactMode(%s);", current_menu_compact and 'true' or 'false'), 1)
  webview.eval(string.format("setFrontApp(%q);", current_front_app_text or 'APP ?'), 1)
  webview.eval(string.format("setMenuLayout(%q);", current_menu_mode or 'other'), 1)
  webview.eval(string.format("setHomeSubmenu(%q);", current_home_submenu or ''), 1)
  if current_menu_compact then
    webview.show({ id = 1, html = side_html, x = current_menu_x, y = current_menu_y, width = MENU_W_COMPACT, height = MENU_H_COMPACT, alpha = 1.0, corner_radius = 28, opaque = false, can_drag = true, ignores_hit = false })
    sys.msleep(80)
    webview.eval("setCompactMode(true);", 1)
  end
end

local function resize_menu(compact)
  current_menu_compact = compact and true or false
  sync_menu_view()
end

local function set_top_status(text)
  webview.eval(string.format("setTopStatus(%q);", text or ''), 2)
end

local original_sys_toast = sys.toast
local original_nLog = nLog

local function push_status(text)
  local msg = tostring(text or '')
  if msg == '' then return end
  set_top_status(msg)
end

sys.toast = function(text, ...)
  push_status(text)
  if original_sys_toast then
    return original_sys_toast(text, ...)
  end
end

nLog = function(text, ...)
  push_status(text)
  if original_nLog then
    return original_nLog(text, ...)
  end
end

local function set_active(active)
  if active and active ~= '' then
    webview.eval(string.format("setActive(%q);", active), 1)
  else
    webview.eval("clearActive();", 1)
  end
end

local function set_front_app(text)
  current_front_app_text = text or 'APP ?'
  webview.eval(string.format("setFrontApp(%q);", current_front_app_text), 1)
end

local function set_menu_layout(mode)
  current_menu_mode = mode or 'other'
  if current_menu_mode ~= 'home' then
    current_home_submenu = ''
    webview.eval("setHomeSubmenu('');", 1)
  end
  webview.eval(string.format("setMenuLayout(%q);", current_menu_mode), 1)
end

local function set_home_submenu(name)
  current_home_submenu = name or ''
  webview.eval(string.format("setHomeSubmenu(%q);", current_home_submenu), 1)
end

local function keep_state(active)
  if active and active ~= '' then
    set_active(active)
  end
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

local function get_front_context()
  local bid = tostring(app.front_bid() or '')
  if bid == BID_TIKTOK then
    return {
      front_name = 'TikTok',
      menu_mode = 'tiktok',
      video_label = 'VIDEO',
      claim_label = 'CLAIM',
      tiktok_label = 'TIKTOK',
      lite_label = 'LITE',
    }
  elseif bid == BID_TIKTOK_LITE then
    return {
      front_name = 'TikTokLite',
      menu_mode = 'lite',
      video_label = 'VIDEO',
      claim_label = 'CLAIM',
      tiktok_label = 'TIKTOK',
      lite_label = 'LITE',
    }
  elseif bid == BID_HOME then
    return {
      front_name = 'HOME',
      menu_mode = 'home',
      video_label = 'VIDEO',
      claim_label = 'CLAIM',
      tiktok_label = 'TIKTOK',
      lite_label = 'LITE',
    }
  end
  return {
    front_name = 'Other',
    menu_mode = 'other',
    video_label = 'VIDEO',
    claim_label = 'CLAIM',
    tiktok_label = 'TIKTOK',
    lite_label = 'LITE',
  }
end

local function run_home(front_name)
  set_active('home')
  set_top_status((front_name or 'App') .. ': Home đang chạy')
  app.run(BID_HOME)
  sys.toast('HOME')
  sys.msleep(500)
  keep_state('home')
end

local function run_video(front_name)
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  set_active('video')
  if bid == BID_TIKTOK then
    set_top_status('TikTok: Video đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Group3_EventVideo180_tiktok.lua')
    sys.msleep(700)
    keep_state('video')
    return ok
  elseif bid == BID_TIKTOK_LITE then
    set_top_status('TikTokLite: Video đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Group3_EventVideo180_tiktok_lite.lua')
    sys.msleep(700)
    keep_state('video')
    return ok
  end
  set_top_status((front_name or 'App') .. ': Không đúng app cho Video')
  sys.toast('Không phải TikTok/Lite')
  sys.msleep(700)
  keep_state('video')
  return false
end

local function run_claim(front_name)
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  set_active('claim')
  if bid == BID_TIKTOK or bid == BID_TIKTOK_LITE then
    set_top_status((front_name or 'App') .. ': Claim đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Claimvideo48.lua')
    sys.msleep(700)
    keep_state('claim')
    return ok
  end
  set_top_status('Other: Không đúng app')
  sys.toast('Không phải TikTok/Lite')
  sys.msleep(700)
  keep_state('claim')
  return false
end

local function run_20p(front_name)
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  set_active('20p')
  if bid == BID_TIKTOK then
    set_top_status('TikTok: 20P đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Group3_EventDD20p_tiktok.lua')
    sys.msleep(700)
    keep_state('20p')
    return ok
  elseif bid == BID_TIKTOK_LITE then
    set_top_status('TikTokLite: 20P đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Group3_EventDD20p_tiktok_lite.lua')
    sys.msleep(700)
    keep_state('20p')
    return ok
  end
  set_top_status('Other: Không đúng app')
  sys.toast('Không phải TikTok/Lite')
  sys.msleep(700)
  keep_state('20p')
  return false
end

local function run_clear(front_name)
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  set_active('clear')
  if current_menu_mode == 'home' and current_home_submenu == 'tiktok' then
    set_top_status('HOME: Xóa app TikTok')
    pcall(app.uninstall, BID_TIKTOK)
    sys.toast('Đã xóa TikTok')
    sys.msleep(700)
    keep_state('clear')
    return true
  elseif current_menu_mode == 'home' and current_home_submenu == 'lite' then
    set_top_status('HOME: Xóa app TikTokLite')
    pcall(app.uninstall, BID_TIKTOK_LITE)
    sys.toast('Đã xóa TikTokLite')
    sys.msleep(700)
    keep_state('clear')
    return true
  elseif bid == BID_TIKTOK then
    set_top_status('TikTok: Đóng app')
    pcall(app.quit, BID_TIKTOK)
    sys.toast('Đã đóng TikTok')
    sys.msleep(700)
    keep_state('clear')
    return true
  elseif bid == BID_TIKTOK_LITE then
    set_top_status('TikTokLite: Đóng app')
    pcall(app.quit, BID_TIKTOK_LITE)
    sys.toast('Đã đóng TikTokLite')
    sys.msleep(700)
    keep_state('clear')
    return true
  end

  set_top_status((front_name or 'App') .. ': Đóng nhóm app')
  local ids = {
    'com.apple.mobilesafari',
    'com.apple.Preferences',
    'com.apple.AppStore',
    'com.ss.iphone.ugc.Ame',
    'com.ss.iphone.ugc.tiktok.lite',
    'com.apple.DocumentsApp',
    'com.apple.camera',
    'com.apple.mobiletimer',
    'com.tigisoftware.Filza',
    'com.tigisoftware.ADManager',
    'com.apple.findmy',
    'com.apple.Health',
    'com.apple.MobileSMS',
    'com.apple.mobilenotes',
    'com.apple.mobilephone',
    'com.apple.mobileslideshow',
    'com.apple.shortcuts',
    'com.apple.tips',
    'com.opa334.TrollStore',
    'ch.xxtou.XXTExplorer'
  }
  for i = 1, #ids do
    pcall(app.quit, ids[i])
    sys.msleep(300)
  end
  sys.toast('Đã đóng ứng dụng')
  sys.msleep(700)
  keep_state('clear')
  return true
end

local function run_open_tiktok()
  set_active('tiktok')
  set_top_status('HOME: mở TikTok')
  app.run(BID_TIKTOK)
  sys.toast('Mở TikTok')
  sys.msleep(700)
  keep_state('tiktok')
  return true
end

local function run_open_lite()
  set_active('lite')
  set_top_status('HOME: mở TikTokLite')
  app.run(BID_TIKTOK_LITE)
  sys.toast('Mở TikTokLite')
  sys.msleep(700)
  keep_state('lite')
  return true
end

local function run_home_nurture()
  unlock_if_needed()
  set_active('video')
  if current_home_submenu == 'tiktok' then
    set_top_status('HOME TikTok: Nuôi phôi đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Group3_NuoiPhoi_tiktok.lua')
    sys.msleep(700)
    keep_state('video')
    return ok
  elseif current_home_submenu == 'lite' then
    set_top_status('HOME Lite: Nuôi phôi đang chạy')
    local ok = run_lua_file(LUA_DIR .. 'Group3_NuoiPhoi_tiktok_lite.lua')
    sys.msleep(700)
    keep_state('video')
    return ok
  end
  return false
end

local function run_home_install()
  unlock_if_needed()
  if current_home_submenu == 'tiktok' then
    set_top_status('HOME TikTok: Tải app đang mở')
    app.open_url('https://apps.apple.com/jp/app/tiktok-%E3%83%86%E3%82%A3%E3%83%83%E3%82%AF%E3%83%88%E3%83%83%E3%82%AF/id1235601864')
    sys.toast('Mở link tải TikTok')
    sys.msleep(700)
    return true
  elseif current_home_submenu == 'lite' then
    set_top_status('HOME Lite: Tải app đang mở')
    app.open_url('https://apps.apple.com/jp/app/tiktok-lite/id6447160980?l=en-US')
    sys.toast('Mở link tải TikTokLite')
    sys.msleep(700)
    return true
  end
  return false
end

local function execute_action(action, ctx)
  if action == '__compact_on__' then
    resize_menu(true)
  elseif action == '__compact_off__' then
    resize_menu(false)
  elseif action == 'home' then
    run_home(ctx.front_name)
  elseif action == 'tiktok' then
    if current_menu_mode == 'home' then
      if current_home_submenu == 'tiktok' then
        set_home_submenu('')
      else
        set_home_submenu('tiktok')
        webview.eval("setHomeSubmenuLabels('NUOI PHOI', 'XOA APP', 'TAI APP');", 1)
      end
      set_menu_layout('home')
    else
      run_open_tiktok()
    end
  elseif action == 'lite' then
    if current_menu_mode == 'home' then
      if current_home_submenu == 'lite' then
        set_home_submenu('')
      else
        set_home_submenu('lite')
        webview.eval("setHomeSubmenuLabels('NUOI PHOI', 'XOA APP', 'TAI APP');", 1)
      end
      set_menu_layout('home')
    else
      run_open_lite()
    end
  elseif action == 'video' then
    if current_menu_mode == 'home' and current_home_submenu ~= '' then
      run_home_nurture()
    else
      run_video(ctx.front_name)
    end
  elseif action == 'claim' then
    if current_menu_mode == 'home' and current_home_submenu ~= '' then
      run_clear(ctx.front_name)
    else
      run_claim(ctx.front_name)
    end
  elseif action == 'clear' then
    if current_menu_mode == 'home' and current_home_submenu ~= '' then
      run_home_install()
    else
      run_clear(ctx.front_name)
    end
  elseif action == '20p' then
    run_20p(ctx.front_name)
  end
end

show_menu(MENU_H_EXPANDED)
set_top_status('')
local last_action = ''
local last_mode_refresh = ''
while true do
  local ctx = get_front_context()
  local mode_key = ctx.front_name .. '|' .. ctx.menu_mode .. '|' .. ctx.video_label .. '|' .. ctx.claim_label .. '|' .. current_home_submenu
  if mode_key ~= last_mode_refresh then
    last_mode_refresh = mode_key
    set_front_app(ctx.front_name)
    webview.eval(string.format("setActionLabels(%q, %q, %q);", ctx.video_label, ctx.claim_label, '20P'), 1)
    webview.eval(string.format("setAppButtons(%q, %q);", ctx.tiktok_label, ctx.lite_label), 1)
    if ctx.menu_mode == 'home' and current_home_submenu ~= '' then
      webview.eval("setHomeSubmenuLabels('NUOI PHOI', 'XOA APP', 'TAI APP');", 1)
    else
      webview.eval("setClearLabel('CLEAR');", 1)
    end
    set_menu_layout(ctx.menu_mode)
    if ctx.menu_mode == 'home' then
      set_home_submenu(current_home_submenu)
    end
    if current_menu_compact then
      resize_menu(true)
    end
  end

  local action = tostring(webview.eval('window.__xxt_action || "";', 1) or '')
  if action ~= '' and action ~= last_action then
    last_action = action
    webview.eval('window.__xxt_action = "";', 1)
    execute_action(action, ctx)
  elseif action == '' then
    last_action = ''
  end
  sys.msleep(180)
end
