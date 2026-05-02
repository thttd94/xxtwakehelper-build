screen.init(0)

local SCRIPT_VERSION = "TL_STAGE456_V1"
local TIKTOK_LITE_BUNDLE = "com.ss.iphone.ugc.tiktok.lite"
local RES_DIR = "/var/mobile/Media/1ferver/lua/examples/"
local INPUT_PATH = RES_DIR .. "input.txt"
local STAGE4_TIMEOUT_SEC = 30

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

local CHECK_CREP = RES_DIR .. "check_creP.png"
local CHECK_CRETENA = RES_DIR .. "check_creteNa.png"
local SAVE_IMG = RES_DIR .. "save.png"
local NHAP_P_IMG = RES_DIR .. "nhapP.png"
local SIGN_IMG = RES_DIR .. "sign.png"
local WELLCOM_IMG = RES_DIR .. "wellcom.png"
local INDERSTAND_IMG = RES_DIR .. "inderstand.png"
local TIKTOK_OPEN_URL = "snssdk1233://"

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
  if remain < 1000 then step = remain end
  sleep(step)
  remain = remain - step
 end
end

function findImage(img, sim, x1, y1, x2, y2)
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
  if ok then return true, x, y, imgList[i] end
 end
 return false, -1, -1, nil
end

function findTrackPopup()
 local x, y = screen.find_color(CHECK_TRACK_PATTERN, 95, 0, 0, 0, 0)
 if x ~= -1 then
  status("Hit check track")
  return true, x, y
 end
 return false, -1, -1
end

function findEventByColor()
 local x, y = screen.find_color(EVENT_COLOR_PATTERN, 95, 0, 0, 0, 0)
 if x ~= -1 then
  status("Hit event color")
  return true, x, y
 end
 return false, -1, -1
end

function getImageCenter(path, x, y)
 local img = image.load_file(path)
 if not img then return x, y end
 local w, h = img:size()
 if not w or not h then return x, y end
 return math.floor(x + (w / 2)), math.floor(y + (h / 2))
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

function swipeUpOnce()
 status("Swipe up")
 touch.down(1, 360, 1050)
 sleep(30)
 touch.move(1, 360, 860)
 sleep(30)
 touch.up(1)
end

function swipeDownAt(x, y)
 status("Swipe down")
 touch.down(1, x, y)
 sleep(30)
 touch.move(1, x, y + 240)
 sleep(30)
 touch.up(1)
end

function finishStage4Flow()
 phase("Stage 4 step 1")
 touch.tap(679, 1285)
 waitPhase(3000)

 phase("Stage 4 step 2")
 touch.tap(541, 1263)
 waitPhase(3000)

 phase("Stage 4 step 3")
 touch.tap(354, 498)
 waitPhase(3000)

 phase("Stage 4 swipe 1")
 swipeDownAt(159, 907)
 waitPhase(5000)

 phase("Stage 4 swipe 2")
 swipeDownAt(421, 907)
 waitPhase(5000)

 phase("Stage 4 swipe 3")
 swipeDownAt(574, 894)
 waitPhase(5000)

 phase("Stage 4 swipe 4")
 swipeDownAt(159, 907)
 waitPhase(5000)

 phase("Stage 4 step 4")
 touch.tap(388, 1221)
 waitPhase(3000)

 phase("Stage 4 step 5")
 touch.tap(533, 170)
 waitPhase(1000)

 phase("Stage 4 xong")
 return true
end

function prepareTikTokLite()
 phase("Clear app data")
 clear.app_data(TIKTOK_LITE_BUNDLE)
 sys.toast("done", 1)
 waitPhase(1500)
end

function openTikTokLite()
 phase("Mở TikTok Lite")
 app.run(TIKTOK_LITE_BUNDLE)
 waitPhase(30000)
end

function ensureTikTokLiteForeground()
 local front = app.front_bid()
 if front == TIKTOK_LITE_BUNDLE then return true end
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
 if not ok then return false end
 phase("Popup permiss")
 waitPhase(2000)
 local tapped = tapByImageCenter(TAP_POPUP_PERMISS, 82, 0, 0, 750, 1334)
 if tapped then waitPhase(1200) else status("Popup permiss fail tap") waitPhase(800) end
 return true
end

function handlePopupTrack()
 local ok = findTrackPopup()
 if not ok then return false end
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
 waitPhase(1000)
 return true
end

function handleNoInternetSpecial(stageDeadline)
 local ok = findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334)
 if not ok then return false end
 phase("No internet")
 while os.time() < stageDeadline and findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334) do
  touch.tap(744, 182)
  waitPhase(10000)
 end
 if os.time() >= stageDeadline then return false end
 phase("Đợi internet quay lại")
 local startClear = os.time()
 while os.time() - startClear < 30 and os.time() < stageDeadline do
  if findImage(CHECK_POPUP_INTERNET, 82, 0, 0, 750, 1334) then startClear = os.time() end
  waitPhase(1000)
 end
 if os.time() >= stageDeadline then return false end
 app.quit(TIKTOK_LITE_BUNDLE)
 waitPhase(2000)
 while os.time() < stageDeadline do
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
 return false
end

function runStage4()
 phase("Stage 4")
 prepareTikTokLite()
 openTikTokLite()
 local lastSwipeAt = os.time()
 local stageDeadline = os.time() + STAGE4_TIMEOUT_SEC
 while os.time() < stageDeadline do
  local remain = stageDeadline - os.time()
  if remain < 0 then remain = 0 end
  status("Stage4 còn " .. remain .. "s")
  ensureTikTokLiteForeground()
  handleNoInternetSpecial(stageDeadline)
  finishByEventPopup()
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
 phase("Stage 4 hết 30s")
 return finishStage4Flow()
end

function readInputLine()
 local data = file.reads(INPUT_PATH)
 if type(data) ~= "string" then
  return nil, nil, "read input fail"
 end
 data = string.gsub(data, "\r", "")
 local line = string.match(data, "([^\n]+)")
 if not line or line == "" then
  return nil, nil, "input empty"
 end
 local left, right = string.match(line, "^(.-)|(.*)$")
 if not left then
  return nil, nil, "missing |"
 end
 return left, right, nil
end

function pasteText(text)
 pasteboard.write(text)
 waitPhase(300)
 key.send_text(text)
end

function waitCheckCreP(timeoutSec)
 local startAt = os.time()
 while os.time() - startAt < timeoutSec do
  phase("Quét check_creP")
  local ok = findImage(CHECK_CREP, 82, 0, 0, 750, 1334)
  if ok then return true end
  waitPhase(1000)
 end
 return false
end

function waitCheckCreteNa(timeoutSec)
 local startAt = os.time()
 while os.time() - startAt < timeoutSec do
  phase("Quét check_creteNa")
  local ok = findImage(CHECK_CRETENA, 82, 0, 0, 750, 1334)
  if ok then return true end
  waitPhase(1000)
 end
 return false
end

function randomDigits(n)
 local out = ""
 for i = 1, n do
  out = out .. tostring(math.random(0, 9))
 end
 return out
end

function randomNameText()
 local names = {"thanh","minhh","hoangh","quangh","anhnam","truong","phuocc","baokhan","huyhoan","ducthan"}
 return names[math.random(1, #names)]
end

function buildCreateName()
 local textPart = randomNameText()
 if #textPart > 6 then textPart = string.sub(textPart, 1, 6) end
 if #textPart < 6 then
  while #textPart < 6 do
   textPart = textPart .. "a"
  end
 end
 return textPart .. randomDigits(9)
end

function runStage5()
 phase("Stage 5")
 local leftText, rightText, err = readInputLine()
 if err then
  phase(err)
  return false
 end

 phase("Tách dữ liệu")
 waitPhase(1000)

 phase("Dán trước dấu |")
 pasteText(leftText)
 waitPhase(2000)

 phase("Tap 482 725")
 touch.tap(482, 725)
 waitPhase(2000)

 local hitCreP = waitCheckCreP(15)
 if hitCreP then
  phase("Hit check_creP")
  tapByImageCenter(SAVE_IMG, 82, 0, 0, 750, 1334)
  waitPhase(1500)

  phase("Tap nhapP")
  tapByImageCenter(NHAP_P_IMG, 82, 0, 0, 750, 1334)
  waitPhase(1000)

  phase("Dán sau dấu |")
  pasteText(rightText .. "@")
  waitPhase(1000)

  phase("Tap 460 739")
  touch.tap(460, 739)
  waitPhase(1000)

  if waitCheckCreteNa(15) then
   local createName = buildCreateName()
   phase("Tap 283 519")
   touch.tap(283, 519)
   waitPhase(1000)

   phase("Nhập create name")
   pasteText(createName)
   waitPhase(1000)

   phase("Tap 553 829")
   touch.tap(553, 829)
   waitPhase(1000)
  else
   phase("Không thấy check_creteNa")
   waitPhase(1000)
  end
 else
  phase("Không thấy check_creP")
  waitPhase(1000)
 end

 phase("Stage 5 xong")
 return true
end

function runActiveXXTE()
 phase("Active XXTE")
 local function find_cookie()
  local bases = {"/private/var/mobile/Containers/Shared/AppGroup", "/var/mobile/Containers/Shared/AppGroup"}
  local paths = {"File Provider Storage/Downloads", "Downloads", "Documents/Downloads"}
  for _, base in ipairs(bases) do
   local groups = file.list(base)
   if type(groups) == "table" then
    for _, folder in pairs(groups) do
     for _, p in ipairs(paths) do
      local src = base .. "/" .. folder .. "/" .. p .. "/Cookies.binarycookies"
      if file.exists(src) then return src end
     end
    end
   end
  end
  return nil
 end
 local safariPath = app.data_path("com.apple.mobilesafari")
 local cookiePath = safariPath .. "/Library/Cookies/Cookies.binarycookies"
 local backupPath = safariPath .. "/Library/Cookies/Cookies_backup.binarycookies"
 if file.exists(cookiePath) then
  local old = file.reads(cookiePath)
  if old then file.writes(backupPath, old) end
 end
 local src = find_cookie()
 if src then
  local data = file.reads(src)
  if data then file.writes(cookiePath, data) end
 end
 sys.toast("Load cookies xong", 1)
 waitPhase(1000)
 return true
end

function handleStage6BlueReturn()
 local x, y = screen.find_color({
  {302,1252,0x007aff},
  {353,1256,0x007aff},
  {439,1257,0x007aff},
  {393,1268,0x007aff},
 }, 95, 0, 0, 0, 0)
 if x ~= -1 then
  phase("Bấm nút xanh")
  touch.tap(x, y)
  waitPhase(1000)
  return true
 end
 return false
end

function waitImageStage6(img, label, timeoutSec, swipeDownEvery60)
 local startAt = os.time()
 local lastSwipeAt = os.time()
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  handleStage6BlueReturn()
  local ok, x, y = findImage(img, 82, 0, 0, 750, 1334)
  if ok then phase(label) return true, x, y end
  if swipeDownEvery60 and os.time() - lastSwipeAt >= 60 then
   phase("Vuốt xuống tìm sign")
   touch.down(1, 614, 119)
   sleep(800)
   touch.move(1, 614, 720)
   sleep(800)
   touch.up(1)
   lastSwipeAt = os.time()
   waitPhase(1000)
  else
   status(label)
   sleep(500)
  end
 end
 return false, -1, -1
end

function tapReturnStage6()
 touch.tap(658, 1289)
 waitPhase(1500)
end

function slowSwipeUpUntilInderstand(timeoutSec)
 local startAt = os.time()
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  handleStage6BlueReturn()
  local ok = findImage(INDERSTAND_IMG, 82, 0, 0, 750, 1334)
  if ok then phase("Thấy inderstand") return true end
  phase("Vuốt lên chậm")
  touch.down(1, 360, 1050)
  sleep(900)
  touch.move(1, 360, 930)
  sleep(900)
  touch.move(1, 360, 820)
  sleep(900)
  touch.up(1)
  waitPhase(1200)
 end
 return false
end

function runStage6()
 phase("Stage 6")
 runActiveXXTE()
 local leftText, rightText, err = readInputLine()
 if err then phase(err) return false end
 phase("Mở TikTok bằng link")
 app.open_url(TIKTOK_OPEN_URL)
 waitPhase(5000)
 local signOk = waitImageStage6(SIGN_IMG, "Thấy sign", 0, true)
 if not signOk then return false end
 phase("Dán trước dấu |")
 touch.tap(356, 527)
 waitPhase(500)
 pasteText(leftText)
 waitPhase(500)
 tapReturnStage6()
 local wellcomOk = waitImageStage6(WELLCOM_IMG, "Thấy wellcom", 0, false)
 if not wellcomOk then return false end
 phase("Dán sau dấu |")
 touch.tap(445, 638)
 waitPhase(500)
 pasteText(rightText)
 waitPhase(500)
 tapReturnStage6()
 if not slowSwipeUpUntilInderstand(0) then return false end
 phase("Stage 6 xong")
 return true
end

phase("Khởi động " .. SCRIPT_VERSION)
waitPhase(1200)
if not runStage4() then phase("Lỗi Stage 4") return end
if not runStage5() then phase("Lỗi Stage 5") return end
if not runStage6() then phase("Lỗi Stage 6") return end
phase("ALL DONE")
return
