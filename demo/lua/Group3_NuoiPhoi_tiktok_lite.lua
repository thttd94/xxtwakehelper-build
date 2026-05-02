screen.init(0)

local TOUCH_ID_IMG = "/var/mobile/Media/1ferver/lua/examples/touchID.png"
local touch_id_x, touch_id_y = screen.find_image(TOUCH_ID_IMG, 82, 0, 0, 750, 1334)
if touch_id_x ~= -1 then
    touch.tap(381, 792)
    sys.toast("Tapped Touch ID", 1)
    sys.msleep(1000)
end

clear.app_data("com.ss.iphone.ugc.Ame")
clear.app_data("com.ss.iphone.ugc.tiktok.lite")
sys.toast("clear tiktok done", 1)
sys.msleep(1000)

local SCRIPT_VERSION = "TL_ALLIN1_V8"
local TIKTOK_BUNDLE = "com.ss.iphone.ugc.Ame"
local TIKTOK_LITE_BUNDLE = "com.ss.iphone.ugc.tiktok.lite"
local APPMANAGER_BUNDLE = "com.tigisoftware.ADManager"
local TIKTOK_LITE_STORE_URL = "https://apps.apple.com/jp/app/tiktok-lite/id6447160980?l=en-US"
local RES_DIR = "/var/mobile/Media/1ferver/lua/examples/"

local CLOUD_IMG = RES_DIR .. "cloudTTL.png"
local OPEN_IMG = RES_DIR .. "openTTL.png"
local CHECK_ERROR1_IMG = RES_DIR .. "check_error1.png"
local TAP_ERROR1_IMG = RES_DIR .. "tap_error1.png"
local CHECK_ERROR2_IMG = RES_DIR .. "check_error2.png"
local TAP_ERROR2_IMG = RES_DIR .. "tap_error2.png"

local CHECK_POPUP_WELLCOME = RES_DIR .. "check_popup_wellcome.png"
local TAP_POPUP_WELLCOME = RES_DIR .. "tap_popup_wellcome.png"
local CHECK_POPUP_PERMISS_LIST = {
 RES_DIR .. "check_popup_permiss.png",
 RES_DIR .. "check_popup_permis1.png",
 RES_DIR .. "check_popup_permis2.png",
 RES_DIR .. "check_popup_permis3.png"
}
local TAP_POPUP_PERMISS = RES_DIR .. "tap_popup_permiss.png"
local CHECK_POPUP_ALLOW = RES_DIR .. "check_popup_allow.png"
local TAP_POPUP_ALLOW = RES_DIR .. "tap_popup_allow.png"
local CHECK_POPUP_TAPPING = RES_DIR .. "check_popup_tapping.png"
local TAP_POPUP_TAPPING = RES_DIR .. "tap_popup_tapping.png"
local CHECK_POPUP_CHOOSE = RES_DIR .. "check_popup_choose.png"
local CHECK_POPUP_SWIPE = RES_DIR .. "check_popup_swipe.png"
local CHECK_POPUP_EVENT1 = RES_DIR .. "check_popup_Event1.png"
local CHECK_POPUP_EVENT2 = RES_DIR .. "check_popup_Event2.png"
local CHECK_POPUP_INTERNET = RES_DIR .. "check_popup_internet.png"

local CHECK_TTL = RES_DIR .. "check_TTL.png"
local CHECK_BACKUPTTL = RES_DIR .. "check_backupttl.png"
local TAP_BACKUPTTL = RES_DIR .. "tap_backupttl.png"
local TAP_BACKUP = RES_DIR .. "tap_backup.png"
local CHECK_BACKUPING = RES_DIR .. "check_backuping.png"
local CHECK_BACKUPDONE = RES_DIR .. "check_backupdone.png"

local CHECK_TRACK_PATTERN = {
 {181,470,0x000000},
 {402,455,0x000000},
 {449,605,0x000000},
 {567,515,0x000000},
 {523,799,0x007aff},
 {398,790,0x007aff},
 {403,881,0x007aff},
 {340,888,0x007aff},
}

local EVENT_COLOR_PATTERN = {
 {173,235,0xe83128},
 {172,204,0xe83128},
 {215,207,0xe83128},
 {215,235,0xe83128},
 {533,206,0xe83128},
 {532,237,0xe83128},
 {576,208,0xe83128},
 {482,297,0xffdf35},
 {243,237,0xffdf35},
 {599,856,0xe73129},
 {244,870,0xe93128},
 {645,197,0x000000},
}

local function sleep(ms)
 sys.msleep(ms)
end

local __last_status = ""
local __last_status_at = 0
local __phase = ""

local function shortText(t)
 if #t > 40 then
  return string.sub(t, 1, 37) .. "..."
 end
 return t
end

function status(t)
 t = shortText(t)
 local text = "Ver " .. SCRIPT_VERSION .. " : " .. t
 local now = os.time()
 if text ~= __last_status or now - __last_status_at >= 1 then
  sys.toast(text, 0)
  __last_status = text
  __last_status_at = now
 end
end

function phase(t)
 __phase = t
 __last_status = ""
 status(t)
end

function phaseProgress(sec)
 status(__phase .. " " .. sec .. "s")
end

function statusScan(img)
 local name = tostring(img or "")
 local simple = string.match(name, "([^/]+)$") or name
 status("Scan " .. simple)
end

function waitPhase(ms)
 local remain = ms
 local lastShown = -1

 while remain > 0 do
  local sec = math.ceil(remain / 1000)
  if sec ~= lastShown then
   phaseProgress(sec)
   lastShown = sec
  end

  local step = 1000
  if remain < 1000 then
   step = remain
  end

  sleep(step)
  remain = remain - step
 end
end

function findImage(img, sim, x1, y1, x2, y2)
 statusScan(img)
 sim = sim or 82
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334

 local x, y = screen.find_image(img, sim, x1, y1, x2, y2)
 if x ~= -1 then
  status("Hit " .. (string.match(img, "([^/]+)$") or img))
  return true, x, y
 end

  return false, -1, -1
end

function findAnyImage(imgList, sim, x1, y1, x2, y2)
 for i = 1, #imgList do
  local ok, x, y = findImage(imgList[i], sim, x1, y1, x2, y2)
  if ok then
   return true, x, y, imgList[i]
  end
 end

 return false, -1, -1, nil
end

function findTrackPopup()
 status("Scan check track")
 local x, y = screen.find_color(CHECK_TRACK_PATTERN, 95, 0, 0, 0, 0)
 if x ~= -1 then
  status("Hit check track")
  return true, x, y
 end
  return false, -1, -1
end

function findEventByColor()
 status("Scan event color")
 local x, y = screen.find_color(EVENT_COLOR_PATTERN, 95, 0, 0, 0, 0)
 if x ~= -1 then
  status("Hit event color")
  return true, x, y
 end
 return false, -1, -1
end

function getImageCenter(path, x, y)
 local img = image.load_file(path)
 if not img then
  return x, y
 end

 local w, h = img:size()
 if not w or not h then
  return x, y
 end

 local cx = math.floor(x + (w / 2))
 local cy = math.floor(y + (h / 2))
 return cx, cy
end

function tapByImageCenter(img, sim, x1, y1, x2, y2)
 local ok, x, y = findImage(img, sim, x1, y1, x2, y2)
 if ok then
  local cx, cy = getImageCenter(img, x, y)
  status("Tap " .. (string.match(img, "([^/]+)$") or img))
  touch.tap(cx, cy)
  return true, cx, cy
 end

 return false, -1, -1
end

function hasBundle(bundleId)
 local bundles = app.bundles()
 if type(bundles) ~= "table" then
  return nil
 end

 for _, bid in ipairs(bundles) do
  if bid == bundleId then
   return true
  end
 end

 return false
end

function swipeUpOnce()
 status("Swipe up")
 touch.down(1, 360, 1050)
 sleep(30)
 touch.move(1, 360, 860)
 sleep(30)
 touch.up(1)
end

function quitApp(bundleId, label)
 phase("Quit " .. label)
 app.quit(bundleId)
 waitPhase(1500)
end

function openApp(bundleId, label, waitMs)
 phase("Mở " .. label)
 app.run(bundleId)
 waitPhase(waitMs or 4000)
end

function waitUninstallGone(bundleId, label, timeoutSec)
 local start_wait = os.time()
 local lastShown = -1
 phase("Chờ gỡ " .. label)

 while os.time() - start_wait < timeoutSec do
  local remain = timeoutSec - (os.time() - start_wait)
  if remain ~= lastShown then
   phaseProgress(remain)
   lastShown = remain
  end

  local installed_now = hasBundle(bundleId)
  if installed_now == false then
   phase(label .. " đã gỡ")
   waitPhase(1200)
   return true
  end

  sleep(1000)
 end

 return false
end

function uninstallIfPresent(bundleId, label)
 local installed_before = hasBundle(bundleId)
 if installed_before == false then
  phase(label .. " không có")
  waitPhase(800)
  return true
 end

 phase("Gỡ " .. label)
 app.uninstall(bundleId)
 waitPhase(2500)

 if waitUninstallGone(bundleId, label, 120) then return true end

 phase("Gỡ lại " .. label)
 app.uninstall(bundleId)
 waitPhase(2500)

 if waitUninstallGone(bundleId, label, 90) then return true end

 phase("Gỡ lỗi " .. label)
 return false
end

function openTikTokLiteStore()
 phase("Mở link TikTok Lite")
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(8000)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(5000)
end

function handleError1UntilClear()
 local found = findImage(CHECK_ERROR1_IMG, 82, 0, 0, 750, 1334)
 if not found then return false end

 phase("Lỗi tải 1")
 while true do
  local stillThere = findImage(CHECK_ERROR1_IMG, 82, 0, 0, 750, 1334)
  if not stillThere then return true end

  local tapped = tapByImageCenter(TAP_ERROR1_IMG, 82, 0, 0, 750, 1334)
  if not tapped then
   touch.tap(375, 667)
   status("Tap lỗi 1 fb")
  else
   status("Tap lỗi 1")
  end
  waitPhase(1200)
 end
end

function hasError2()
 if findImage(CHECK_ERROR2_IMG, 82, 0, 0, 750, 1334) then return true end
 if findImage(CHECK_ERROR2_IMG, 80, 0, 0, 750, 1334) then return true end
 if findImage(CHECK_ERROR2_IMG, 78, 0, 0, 750, 1334) then return true end
 return false
end

function tapError2Button()
 local ok, x, y = findImage(TAP_ERROR2_IMG, 82, 0, 0, 750, 1334)
 if ok then local cx, cy = getImageCenter(TAP_ERROR2_IMG, x, y) status("Tap retry img82") touch.tap(cx, cy) return true end
 ok, x, y = findImage(TAP_ERROR2_IMG, 80, 0, 0, 750, 1334)
 if ok then local cx, cy = getImageCenter(TAP_ERROR2_IMG, x, y) status("Tap retry img80") touch.tap(cx, cy) return true end
 ok, x, y = findImage(TAP_ERROR2_IMG, 78, 0, 0, 750, 1334)
 if ok then local cx, cy = getImageCenter(TAP_ERROR2_IMG, x, y) status("Tap retry img78") touch.tap(cx, cy) return true end
 return false
end

function handleError2Tap()
 if not hasError2() then return false end
 phase("Lỗi mạng")
 if tapError2Button() then waitPhase(1200) return true end
 touch.tap(379, 750)
 status("Tap retry fb1")
 waitPhase(800)
 if hasError2() then
  if tapError2Button() then waitPhase(1200) return true end
  touch.tap(379, 750)
  status("Tap retry fb2")
  waitPhase(800)
 end
 return true
end

function waitError2Cycle(waitSec)
 phase("Chờ retry")
 local remain = waitSec
 local lastShown = -1
 while remain > 0 do
  if findImage(CLOUD_IMG, 82, 0, 0, 750, 1334) then return "cloud" end
  if handleError1UntilClear() then phase("Xong lỗi 1") end
  if remain ~= lastShown then phaseProgress(remain) lastShown = remain end
  sleep(1000)
  remain = remain - 1
 end
 return "timeout"
end

function runStage1()
 phase("Stage 1")
 local ok_tiktok = uninstallIfPresent(TIKTOK_BUNDLE, "TikTok")
 local ok_tiktok_lite = uninstallIfPresent(TIKTOK_LITE_BUNDLE, "TikTok Lite")
 if not (ok_tiktok and ok_tiktok_lite) then return false end

 openTikTokLiteStore()
 local retry_waits = {10, 30, 60, 300, 600, 1200, 2400}
 local idx = 1

 while true do
  if findImage(CLOUD_IMG, 82, 0, 0, 750, 1334) then
   tapByImageCenter(CLOUD_IMG, 82, 0, 0, 750, 1334)
   waitPhase(2000)
   break
  end

  if handleError1UntilClear() then phase("Xong lỗi 1") end

  if hasError2() then
    local waitSec = retry_waits[idx]
    handleError2Tap()
    local cycleResult = waitError2Cycle(waitSec)
    if cycleResult == "cloud" then
      tapByImageCenter(CLOUD_IMG, 82, 0, 0, 750, 1334)
      waitPhase(2000)
      break
    end
    if idx < #retry_waits then idx = idx + 1 else retry_waits[#retry_waits + 1] = retry_waits[#retry_waits] * 2 idx = idx + 1 end
  else
    waitPhase(1000)
  end
 end

 while true do
  if findImage(OPEN_IMG, 82, 0, 0, 750, 1334) then
   phase("Stage 1 xong")
   return true
  end
  if handleError1UntilClear() then phase("Xử lý lỗi 1 xong") else
   if findImage(CLOUD_IMG, 82, 0, 0, 750, 1334) then
    tapByImageCenter(CLOUD_IMG, 82, 0, 0, 750, 1334)
    waitPhase(2000)
   else
    phase("Đang tải")
    waitPhase(1000)
   end
  end
 end
end

function openTikTokLite()
 phase("Mở TikTok Lite")
 app.run(TIKTOK_LITE_BUNDLE)
 waitPhase(30000)
end

function ensureTikTokLiteForeground()
 local front = app.front_bid()
 if front == TIKTOK_LITE_BUNDLE then
  return true
 end

 phase("Mở lại TikTok Lite")
 app.run(TIKTOK_LITE_BUNDLE)
 waitPhase(5000)
 return app.front_bid() == TIKTOK_LITE_BUNDLE
end

function hasEventPopup()
 if findImage(CHECK_POPUP_EVENT1, 82, 0, 0, 750, 1334) then return true end
 if findImage(CHECK_POPUP_EVENT2, 82, 0, 0, 750, 1334) then return true end
 if findEventByColor() then return true end
 return false
end

function handlePopupByImage(name, checkImg, tapImg)
 local ok = findImage(checkImg, 82, 0, 0, 750, 1334)
 if not ok then return false end
 phase(name)
 waitPhase(2000)
 local tapped = tapByImageCenter(tapImg, 82, 0, 0, 750, 1334)
 if tapped then waitPhase(1200) else status(name .. " fail tap") waitPhase(800) end
 return true
end

function handlePopupPermiss()
 local ok = findAnyImage(CHECK_POPUP_PERMISS_LIST, 82, 0, 0, 750, 1334)
 if not ok then
  return false
 end

 phase("Popup permiss")
 waitPhase(2000)

 local tapped = tapByImageCenter(TAP_POPUP_PERMISS, 82, 0, 0, 750, 1334)
 if tapped then
  waitPhase(1200)
 else
  status("Popup permiss fail tap")
  waitPhase(800)
 end

 return true
end

function handlePopupTrack()
 local ok = findTrackPopup()
 if not ok then
  return false
 end

 phase("Popup track")
 waitPhase(2000)
 touch.tap(399, 792)
 waitPhase(1200)
 return true
end

function handlePopupChoose()
 local ok = findImage(CHECK_POPUP_CHOOSE, 82, 0, 0, 750, 1334)
 if not ok then return false end
 phase("Popup choose")
 waitPhase(2000)
 local points = {{185,513},{119,645},{138,761},{163,879},{157,993},{178,1093},{540,1243}}
 for i = 1, #points do touch.tap(points[i][1], points[i][2]) waitPhase(500) end
 return true
end

function handlePopupSwipe()
 local ok = findImage(CHECK_POPUP_SWIPE, 82, 0, 0, 750, 1334)
 if not ok then return false end
 phase("Popup swipe")
 waitPhase(7000)
 swipeUpOnce()
 waitPhase(1000)
 return true
end

function finishByEventPopup()
 if not hasEventPopup() then return false end
 phase("Popup Event")
 touch.tap(644, 182)
 waitPhase(1200)
 local start = os.time()
 while os.time() - start < 15 do
  if not hasEventPopup() then break end
  touch.tap(644, 182)
  waitPhase(1000)
 end
 if hasEventPopup() then return false end
 waitPhase(5000)
 for i = 1, 3 do swipeUpOnce() if i < 3 then waitPhase(5000) end end
 phase("Stage 2 xong")
 return true
end

function handleNoInternetSpecial()
 local ok = findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334)
 if not ok then return false end
 phase("No internet")
 while findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334) do
  touch.tap(744, 182)
  waitPhase(10000)
 end
 phase("Đợi internet quay lại")
 local startClear = os.time()
 while os.time() - startClear < 30 do
  if findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334) then startClear = os.time() end
  waitPhase(1000)
 end
 app.quit(TIKTOK_LITE_BUNDLE)
 waitPhase(2000)
 while true do
  ensureTikTokLiteForeground()
  if handlePopupByImage("Popup welcome", CHECK_POPUP_WELLCOME, TAP_POPUP_WELLCOME) then goto continue_loop end
  if handlePopupPermiss() then goto continue_loop end
  if handlePopupByImage("Popup allow", CHECK_POPUP_ALLOW, TAP_POPUP_ALLOW) then goto continue_loop end
  if handlePopupByImage("Popup tapping", CHECK_POPUP_TAPPING, TAP_POPUP_TAPPING) then goto continue_loop end
  if handlePopupTrack() then goto continue_loop end
  if handlePopupChoose() then goto continue_loop end
  if handlePopupSwipe() then goto continue_loop end
  if finishByEventPopup() then return true end
  waitPhase(1000)
  ::continue_loop::
 end
end

function runStage2()
 phase("Stage 2")
 openTikTokLite()
 local lastSwipeAt = os.time()
 while true do
  ensureTikTokLiteForeground()
  if handleNoInternetSpecial() then return true end
  if finishByEventPopup() then return true end
  if handlePopupByImage("Popup welcome", CHECK_POPUP_WELLCOME, TAP_POPUP_WELLCOME) then goto handled end
  if handlePopupPermiss() then goto handled end
  if handlePopupByImage("Popup allow", CHECK_POPUP_ALLOW, TAP_POPUP_ALLOW) then goto handled end
  if handlePopupByImage("Popup tapping", CHECK_POPUP_TAPPING, TAP_POPUP_TAPPING) then goto handled end
  if handlePopupTrack() then goto handled end
  if handlePopupChoose() then goto handled end
  if handlePopupSwipe() then goto handled end
  if not findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334) and not hasEventPopup() then
   if os.time() - lastSwipeAt >= 10 then
    phase("Vuốt định kỳ")
    swipeUpOnce()
    lastSwipeAt = os.time()
    waitPhase(1000)
   end
  end
  sleep(500)
  goto continue_main
  ::handled::
  waitPhase(600)
  ::continue_main::
 end
end

function waitTapImage(img, msg, timeoutSec, sim, x1, y1, x2, y2)
 local start = os.time()
 local lastShown = -1
 phase(msg)
 while os.time() - start < timeoutSec do
  local remain = timeoutSec - (os.time() - start)
  if remain ~= lastShown then phaseProgress(remain) lastShown = remain end
  local tapped = tapByImageCenter(img, sim or 82, x1, y1, x2, y2)
  if tapped then waitPhase(1200) return true end
  sleep(500)
 end
 return false
end

function waitImageAppear(img, msg, timeoutSec, sim, x1, y1, x2, y2)
 local start = os.time()
 local lastShown = -1
 phase(msg)
 while os.time() - start < timeoutSec do
  local remain = timeoutSec - (os.time() - start)
  if remain ~= lastShown then phaseProgress(remain) lastShown = remain end
  if findImage(img, sim or 82, x1, y1, x2, y2) then return true end
  sleep(500)
 end
 return false
end

function waitImageDisappear(img, msg, timeoutSec, sim, x1, y1, x2, y2)
 local start = os.time()
 local lastShown = -1
 phase(msg)
 while os.time() - start < timeoutSec do
  local remain = timeoutSec - (os.time() - start)
  local sec = math.ceil(remain)
  if sec ~= lastShown then status("Đang backup " .. sec .. "s") lastShown = sec end
  if not findImage(img, sim or 82, x1, y1, x2, y2) then return true end
  sleep(1000)
 end
 return false
end

function runStage3()
 phase("Stage 3")
 quitApp(APPMANAGER_BUNDLE, "AppManager")
 quitApp(TIKTOK_LITE_BUNDLE, "TikTok Lite")
 openApp(APPMANAGER_BUNDLE, "AppManager", 5000)
 if not waitTapImage(CHECK_TTL, "Chọn TTL", 30, 82, 0, 0, 750, 1334) then return false end
 if findImage(CHECK_BACKUPTTL, 82, 0, 0, 750, 1334) then
  phase("Vuốt trước BackupTTL")
  swipeUpOnce()
  waitPhase(1000)
  if not waitTapImage(TAP_BACKUPTTL, "Tap BackupTTL", 20, 82, 0, 0, 750, 1334) then return false end
 end
 if not waitTapImage(TAP_BACKUP, "Tap Backup", 30, 82, 0, 0, 750, 1334) then return false end
 if not waitImageAppear(CHECK_BACKUPING, "Chờ backuping", 30, 82, 0, 0, 750, 1334) then return false end
 if not waitImageDisappear(CHECK_BACKUPING, "Backup", 1800, 82, 0, 0, 750, 1334) then return false end
 if not waitTapImage(CHECK_BACKUPDONE, "Tap BackupDone", 30, 82, 0, 0, 750, 1334) then return false end
 phase("Stage 3 xong")
 return true
end

phase("Khởi động " .. SCRIPT_VERSION)
waitPhase(1200)
if not runStage1() then phase("Lỗi Stage 1") return end
if not runStage2() then phase("Lỗi Stage 2") return end
if not runStage3() then phase("Lỗi Stage 3") return end
phase("ALL DONE")
return
