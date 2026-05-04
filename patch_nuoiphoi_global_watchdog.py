from pathlib import Path
from datetime import datetime
base=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\lua')

# --- TikTok normal ---
p=base/'Group3_NuoiPhoi_tiktok.lua'
s=p.read_text(encoding='utf-8')
backup=p.with_suffix(p.suffix + '.bak_20260505_global_watchdog')
backup.write_text(s, encoding='utf-8')

s=s.replace('''local SCRIPT_VERSION = "3.5"
local STAGE3_TIMEOUT_SEC = 3600
local stage3_started_at = nil
local restart_from_stage1 = false
''','''local SCRIPT_VERSION = "3.6"
local STAGE3_TIMEOUT_SEC = 3600
local stage3_started_at = nil
local restart_from_stage1 = false
local ACTIVE_APP = ""
local ACTIVE_URL = ""
local APPSTORE_BUNDLE = "com.apple.AppStore"
local WATCHDOG_ENABLED = true
local __watchdog_busy = false
''')

s=s.replace('''local function sleep(ms)
 sys.msleep(ms)
end
''','''local function sleep(ms)
 local remain = ms or 0
 while remain > 0 do
  local step = remain
  if step > 500 then step = 500 end
  sys.msleep(step)
  remain = remain - step
  if WATCHDOG_ENABLED and (not __watchdog_busy) and type(backgroundWatchdog) == "function" then
   backgroundWatchdog()
  end
 end
end
''')

s=s.replace('''function openTikTok() phase("Mở TikTok") app.run(TIKTOK_BUNDLE) waitPhase(10000) end
function closeTikTok() phase("Đóng TikTok") app.quit(TIKTOK_BUNDLE) waitPhase(1500) end
function closeAppManager() phase("Đóng AppManager") app.quit(APPMANAGER_BUNDLE) waitPhase(1500) end
function openAppManager() phase("Mở AppManager") app.run(APPMANAGER_BUNDLE) waitPhase(4000) end
''','''function setActiveApp(kind, url)
 ACTIVE_APP = kind or ""
 ACTIVE_URL = url or ACTIVE_URL or ""
end
function clearActiveApp(kind)
 if kind == nil or ACTIVE_APP == kind then ACTIVE_APP = "" end
end
function ensureActiveApp()
 if ACTIVE_APP == "tiktok" then
  if app.front_bid() ~= TIKTOK_BUNDLE then app.run(TIKTOK_BUNDLE) sys.msleep(2500) end
 elseif ACTIVE_APP == "appmanager" then
  if app.front_bid() ~= APPMANAGER_BUNDLE then app.run(APPMANAGER_BUNDLE) sys.msleep(2500) end
 elseif ACTIVE_APP == "appstore" then
  if app.front_bid() ~= APPSTORE_BUNDLE then
   if ACTIVE_URL and ACTIVE_URL ~= "" then app.open_url(ACTIVE_URL) else app.run(APPSTORE_BUNDLE) end
   sys.msleep(4000)
  end
 end
end
function openTikTok() phase("Mở TikTok") setActiveApp("tiktok") app.run(TIKTOK_BUNDLE) waitPhase(10000) end
function closeTikTok() phase("Đóng TikTok") clearActiveApp("tiktok") app.quit(TIKTOK_BUNDLE) waitPhase(1500) end
function closeAppManager() phase("Đóng AppManager") clearActiveApp("appmanager") app.quit(APPMANAGER_BUNDLE) waitPhase(1500) end
function openAppManager() phase("Mở AppManager") setActiveApp("appmanager") app.run(APPMANAGER_BUNDLE) waitPhase(4000) end
''')

s=s.replace('''function runTikTokPopupFlow(maxSeconds)
''','''function backgroundWatchdog()
 if __watchdog_busy then return false end
 __watchdog_busy = true
 local old_status = __last_status
 local ok = false
 pcall(function()
  ensureActiveApp()
  if hasPopupActive() then
   waitPopupStableFast()
   ok = handleOnePopup() or false
   if ok then sys.msleep(400) end
  end
 end)
 __last_status = old_status
 __watchdog_busy = false
 return ok
end

function runTikTokPopupFlow(maxSeconds)
''')

s=s.replace('''local function openStoreTikTok() phase("Mở AppStore") app.quit("com.apple.AppStore") waitPhase(1500) app.open_url(tiktok_store_url) waitPhase(6000) end
''','''local function openStoreTikTok() phase("Mở AppStore") setActiveApp("appstore", tiktok_store_url) app.quit("com.apple.AppStore") waitPhase(1500) app.open_url(tiktok_store_url) waitPhase(6000) end
''')

p.write_text(s, encoding='utf-8')

# --- TikTok Lite ---
p=base/'Group3_NuoiPhoi_tiktok_lite.lua'
s=p.read_text(encoding='utf-8')
backup=p.with_suffix(p.suffix + '.bak_20260505_global_watchdog')
backup.write_text(s, encoding='utf-8')

s=s.replace('''local TIKTOK_LITE_STORE_URL = "https://apps.apple.com/jp/app/tiktok-lite/id6447160980?l=en-US"
''','''local TIKTOK_LITE_STORE_URL = "https://apps.apple.com/jp/app/tiktok-lite/id6447160980?l=en-US"
local APPSTORE_BUNDLE = "com.apple.AppStore"
local ACTIVE_APP = ""
local ACTIVE_URL = ""
local WATCHDOG_ENABLED = true
local __watchdog_busy = false
''')

s=s.replace('''local SCRIPT_VERSION = "Lite 2.3"
''','''local SCRIPT_VERSION = "Lite 2.4"
''')

s=s.replace('''local function sleep(ms)
 sys.msleep(ms)
end
''','''local function sleep(ms)
 local remain = ms or 0
 while remain > 0 do
  local step = remain
  if step > 500 then step = 500 end
  sys.msleep(step)
  remain = remain - step
  if WATCHDOG_ENABLED and (not __watchdog_busy) and type(backgroundWatchdog) == "function" then
   backgroundWatchdog()
  end
 end
end
''')

s=s.replace('''function quitApp(bundleId, label)
 phase("Đóng " .. label)
 app.quit(bundleId)
 waitPhase(1500)
end

function openApp(bundleId, label, waitMs)
 phase("Mở " .. label)
 app.run(bundleId)
 waitPhase(waitMs or 4000)
end
''','''function setActiveApp(kind, url)
 ACTIVE_APP = kind or ""
 ACTIVE_URL = url or ACTIVE_URL or ""
end
function clearActiveApp(kind)
 if kind == nil or ACTIVE_APP == kind then ACTIVE_APP = "" end
end
function ensureActiveApp()
 if ACTIVE_APP == "tiktok_lite" then
  if app.front_bid() ~= TIKTOK_LITE_BUNDLE then app.run(TIKTOK_LITE_BUNDLE) sys.msleep(2500) end
 elseif ACTIVE_APP == "appmanager" then
  if app.front_bid() ~= APPMANAGER_BUNDLE then app.run(APPMANAGER_BUNDLE) sys.msleep(2500) end
 elseif ACTIVE_APP == "appstore" then
  if app.front_bid() ~= APPSTORE_BUNDLE then
   if ACTIVE_URL and ACTIVE_URL ~= "" then app.open_url(ACTIVE_URL) else app.run(APPSTORE_BUNDLE) end
   sys.msleep(4000)
  end
 end
end
function quitApp(bundleId, label)
 phase("Đóng " .. label)
 if bundleId == TIKTOK_LITE_BUNDLE then clearActiveApp("tiktok_lite") end
 if bundleId == APPMANAGER_BUNDLE then clearActiveApp("appmanager") end
 app.quit(bundleId)
 waitPhase(1500)
end

function openApp(bundleId, label, waitMs)
 phase("Mở " .. label)
 if bundleId == APPMANAGER_BUNDLE then setActiveApp("appmanager") end
 if bundleId == TIKTOK_LITE_BUNDLE then setActiveApp("tiktok_lite") end
 app.run(bundleId)
 waitPhase(waitMs or 4000)
end
''')

s=s.replace('''function openTikTokLiteStore()
 phase("Mở AppStore")
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(5000)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(10000)
end
''','''function openTikTokLiteStore()
 phase("Mở AppStore")
 setActiveApp("appstore", TIKTOK_LITE_STORE_URL)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(5000)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(10000)
end
''')

s=s.replace('''function openTikTokLite()
 phase("Mở TikTok Lite")
 app.run(TIKTOK_LITE_BUNDLE)
 waitPhase(30000)
end
''','''function openTikTokLite()
 phase("Mở TikTok Lite")
 setActiveApp("tiktok_lite")
 app.run(TIKTOK_LITE_BUNDLE)
 waitPhase(30000)
end
''')

insert='''
function backgroundWatchdog()
 if __watchdog_busy then return false end
 __watchdog_busy = true
 local old_status = __last_status
 local ok = false
 pcall(function()
  ensureActiveApp()
  if handleError1UntilClear() then ok = true return end
  if handleError2Tap() then ok = true return end
  if handlePopupByImage("Popup welcome", CHECK_POPUP_WELLCOME, TAP_POPUP_WELLCOME) then ok = true return end
  if handlePopupPermiss() then ok = true return end
  if handlePopupByImage("Popup allow", CHECK_POPUP_ALLOW, TAP_POPUP_ALLOW) then ok = true return end
  if handlePopupByImage("Popup tapping", CHECK_POPUP_TAPPING, TAP_POPUP_TAPPING) then ok = true return end
  if handlePopupTrack() then ok = true return end
  if handlePopupChoose() then ok = true return end
  if handlePopupSwipe() then ok = true return end
 end)
 __last_status = old_status
 __watchdog_busy = false
 return ok
end
'''
s=s.replace('''function runStage2()
 phase("Stage 2")
''', insert + '''
function runStage2()
 phase("Stage 2")
''')

p.write_text(s, encoding='utf-8')
print('patched global watchdog lua files')
