local sys = require("sys")
local app = require("app")
local file = require("file")
local webview = require("webview")

local BID_TIKTOK = "com.ss.iphone.ugc.Ame"
local BID_TIKTOK_LITE = "com.ss.iphone.ugc.tiktok.lite"
local BID_HOME = "com.apple.springboard"

local side_html = [[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,user-scalable=no">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,sans-serif;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}
*{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;box-sizing:border-box}
#dock{width:100%;height:100%;display:flex;flex-direction:column;gap:10px;align-items:center;justify-content:flex-start;padding:12px 8px}
.badge{width:96px;min-height:44px;border-radius:22px;background:rgba(15,23,42,.92);color:#fff;font-size:15px;font-weight:700;display:flex;align-items:center;justify-content:center;text-align:center;padding:8px 8px;border:0;box-shadow:0 10px 22px rgba(0,0,0,.24)}
.btn{width:58px;height:58px;border:0;border-radius:29px;color:#fff;font-size:10px;font-weight:700;box-shadow:0 8px 18px rgba(0,0,0,.24);opacity:.96;transition:all .12s ease;outline:none;padding:6px;line-height:1.0}
.btn.active{transform:scale(1.04);opacity:1;box-shadow:0 0 0 4px rgba(255,255,255,.22),0 14px 30px rgba(0,0,0,.35)}
.home{background:#2f80ed}.video{background:#e74c3c}.p20{background:#27ae60}.claim{background:#f2994a}.clear{background:#9b51e0}.app{background:#111827}
.compact .action-btn{display:none}
.compact #dock{justify-content:flex-start}
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
function setActionLabels(video, claim){ var a=document.getElementById('btn_video'); var b=document.getElementById('btn_claim'); if(a){ a.textContent=video; } if(b){ b.textContent=claim; } }
function setAppButtons(tt, lite){ var a=document.getElementById('btn_tiktok'); var b=document.getElementById('btn_lite'); if(a){ a.textContent=tt; } if(b){ b.textContent=lite; } }
function setClearLabel(text){ var el=document.getElementById('btn_clear'); if(el){ el.textContent=text; } }
function setActive(name){ var ids=['home','tiktok','lite','video','claim','clear']; for(var i=0;i<ids.length;i++){ var el=document.getElementById('btn_'+ids[i]); if(el){ el.classList.remove('active'); } } var target=document.getElementById('btn_'+name); if(target){ target.classList.add('active'); } }
function clearActive(){ var ids=['home','tiktok','lite','video','claim','clear']; for(var i=0;i<ids.length;i++){ var el=document.getElementById('btn_'+ids[i]); if(el){ el.classList.remove('active'); } } }
function setCompactMode(compact){
  window.__xxt_compact = !!compact;
  if(document.body){ document.body.classList.toggle('compact', window.__xxt_compact); }
}
function toggleCompact(){ markAction(); setCompactMode(!window.__xxt_compact); window.__xxt_action = window.__xxt_compact ? '__compact_on__' : '__compact_off__'; return false; }
function setMenuLayout(mode){
  var isHome = mode === 'home';
  var isTikTok = mode === 'tiktok';
  var isLite = mode === 'lite';
  var showHomeButtons = isHome;
  var showAppButtons = isHome;
  var showActionButtons = isTikTok || isLite;

  var btnHome = document.getElementById('btn_home');
  var btnTikTok = document.getElementById('btn_tiktok');
  var btnLite = document.getElementById('btn_lite');
  var btnVideo = document.getElementById('btn_video');
  var btnClaim = document.getElementById('btn_claim');
  var btnClear = document.getElementById('btn_clear');

  if(btnHome){ btnHome.classList.toggle('hidden', !showHomeButtons); }
  if(btnTikTok){ btnTikTok.classList.toggle('hidden', !showAppButtons); }
  if(btnLite){ btnLite.classList.toggle('hidden', !showAppButtons); }
  if(btnVideo){ btnVideo.classList.toggle('hidden', !showActionButtons); }
  if(btnClaim){ btnClaim.classList.toggle('hidden', !showActionButtons); }
  if(btnClear){ btnClear.classList.remove('hidden'); }
}
function autoHideLoop(){
  setInterval(function(){
    if(!window.__xxt_compact && (Date.now() - window.__xxt_last_action_at) >= 30000){
      setCompactMode(true);
    }
  }, 1000);
}
window.onload = function(){ lockUi(); setCompactMode(false); setMenuLayout('other'); autoHideLoop(); };
</script>
</head>
<body>
<div id="dock">
  <button class="badge" id="frontapp" onclick="return toggleCompact()">APP ?</button>
  <button class="btn home action-btn hidden" id="btn_home" onclick="return pickAction('home')">HOME</button>
  <button class="btn app action-btn hidden" id="btn_tiktok" onclick="return pickAction('tiktok')">TIKTOK</button>
  <button class="btn app action-btn hidden" id="btn_lite" onclick="return pickAction('lite')">LITE</button>
  <button class="btn video action-btn hidden" id="btn_video" onclick="return pickAction('video')">VIDEO</button>
  <button class="btn claim action-btn hidden" id="btn_claim" onclick="return pickAction('claim')">CLAIM</button>
  <button class="btn clear action-btn" id="btn_clear" onclick="return pickAction('clear')">CLEAR</button>
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
#status{width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:rgba(255,255,255,.97);color:#111827;border-radius:14px;font-size:18px;font-weight:700;padding:0 14px;box-sizing:border-box;text-align:center;white-space:nowrap;overflow:hidden}
</style>
<script>
function lockUi(){ document.addEventListener('selectstart', function(e){ e.preventDefault(); }); document.addEventListener('contextmenu', function(e){ e.preventDefault(); }); }
function setTopStatus(text){ var el=document.getElementById('status'); if(el){ el.textContent=text; } }
window.onload = lockUi;
</script>
</head>
<body>
<div id="status">TikTok: Video đang chạy</div>
</body>
</html>
]]

local MENU_X = 8
local MENU_Y = 96
local MENU_W = 150
local MENU_H_EXPANDED = 700
local MENU_H_COMPACT = 90

local function show_menu(height)
  webview.show({ id = 1, html = side_html, x = MENU_X, y = MENU_Y, width = MENU_W, height = height or MENU_H_EXPANDED, alpha = 1.0, corner_radius = 26, opaque = false, can_drag = true, ignores_hit = false })
  webview.show({ id = 2, html = top_html, x = 350, y = 18, width = 360, height = 34, alpha = 1.0, corner_radius = 12, opaque = false, can_drag = false, ignores_hit = true })
end

local function resize_menu(compact)
  local target_h = compact and MENU_H_COMPACT or MENU_H_EXPANDED
  webview.show({ id = 1, html = side_html, x = MENU_X, y = MENU_Y, width = MENU_W, height = target_h, alpha = 1.0, corner_radius = 26, opaque = false, can_drag = true, ignores_hit = false })
end

local function set_top_status(text)
  webview.eval(string.format("setTopStatus(%q);", text or 'TikTok: Video đang chạy'), 2)
end

local function set_active(active)
  if active and active ~= '' then
    webview.eval(string.format("setActive(%q);", active), 1)
  else
    webview.eval("clearActive();", 1)
  end
end

local function set_front_app(text)
  webview.eval(string.format("setFrontApp(%q);", text or 'APP ?'), 1)
end

local function set_menu_layout(mode)
  webview.eval(string.format("setMenuLayout(%q);", mode or 'other'), 1)
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
  set_active('video')
  set_top_status((front_name or 'App') .. ': Video đang chạy')
  local ok = run_lua_file('/var/mobile/Media/1ferver/lua/scripts/video_test.lua')
  sys.msleep(700)
  keep_state('video')
  return ok
end

local function run_claim(front_name)
  local bid = tostring(app.front_bid() or '')
  unlock_if_needed()
  set_active('claim')
  if bid == BID_TIKTOK then
    set_top_status('TikTok: Claim đang chạy')
    app.open_url('aweme://webview?url=https%3A%2F%2Fwww.tiktok.com')
    sys.toast('CLAIM TikTok')
    sys.msleep(700)
    keep_state('claim')
    return true
  elseif bid == BID_TIKTOK_LITE then
    set_top_status('TikTokLite: Claim đang chạy')
    app.open_url('tiktoklite://')
    sys.toast('CLAIM Lite')
    sys.msleep(700)
    keep_state('claim')
    return true
  end
  set_top_status('Other: Không đúng app')
  sys.toast('Không phải TikTok/Lite')
  sys.msleep(700)
  keep_state('claim')
  return false
end

local function run_clear(front_name)
  set_active('clear')
  set_top_status((front_name or 'App') .. ': Mở App Manager đang chạy')
  unlock_if_needed()
  app.run('com.tigisoftware.ADManager')
  sys.toast('Mở App Manager')
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

show_menu(MENU_H_EXPANDED)
local last_action = ''
local last_mode_refresh = ''
while true do
  local ctx = get_front_context()
  local mode_key = ctx.front_name .. '|' .. ctx.menu_mode .. '|' .. ctx.video_label .. '|' .. ctx.claim_label
  if mode_key ~= last_mode_refresh then
    last_mode_refresh = mode_key
    set_front_app(ctx.front_name)
    webview.eval(string.format("setActionLabels(%q, %q);", ctx.video_label, ctx.claim_label), 1)
    webview.eval(string.format("setAppButtons(%q, %q);", ctx.tiktok_label, ctx.lite_label), 1)
    webview.eval("setClearLabel('CLEAR');", 1)
    set_menu_layout(ctx.menu_mode)
  end

  local action = tostring(webview.eval('window.__xxt_action || "";', 1) or '')
  if action ~= '' and action ~= last_action then
    last_action = action
    webview.eval('window.__xxt_action = "";', 1)
    if action == '__compact_on__' then
      resize_menu(true)
    elseif action == '__compact_off__' then
      resize_menu(false)
    elseif action == 'home' then
      run_home(ctx.front_name)
    elseif action == 'tiktok' then
      run_open_tiktok()
    elseif action == 'lite' then
      run_open_lite()
    elseif action == 'video' then
      run_video(ctx.front_name)
    elseif action == 'claim' then
      run_claim(ctx.front_name)
    elseif action == 'clear' then
      run_clear(ctx.front_name)
    end
  elseif action == '' then
    last_action = ''
  end
  sys.msleep(180)
end
