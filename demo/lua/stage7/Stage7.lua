screen.init(0)

local app = require("app")
local sys = require("sys")
local file = require("file")

local SCRIPT_VERSION = "STAGE7_TIKTOK_V1"
local TIKTOK_BUNDLE = "com.ss.iphone.ugc.Ame"
local APPMANAGER_BUNDLE = "com.tigisoftware.ADManager"
local RES_DIR = "/var/mobile/Media/1ferver/lua/examples/"

local ADDACC_IMG = RES_DIR .. "addacc.png"
local LOGTTT_IMG = RES_DIR .. "LogTTT.png"
local LOGTTT2_IMG = RES_DIR .. "LogTTT2.png"
local COUNTWGG_IMG = RES_DIR .. "Countwgg.png"
local COUNTWGG1_IMG = RES_DIR .. "Countwgg1.png"
local TIKTOKWANT_IMG = RES_DIR .. "tiktokwant.png"
local CHOOSEAN_IMG = RES_DIR .. "choosean.png"
local SINTOTT_IMG = RES_DIR .. "sintott.png"
local SINTOTT2_IMG = RES_DIR .. "sintott2.png"
local COUNTT_IMG = RES_DIR .. "countt.png"
local BIRTHDAY_IMG = RES_DIR .. "birthday.png"
local BIRTHDAY1_IMG = RES_DIR .. "birthday1.png"
local CREATNAME_IMG = RES_DIR .. "creatname.png"
local BACKUPSAPP_IMG = RES_DIR .. "Backupsapp.png"
local TIKTOKBUP_IMG = RES_DIR .. "tiktokbup.png"
local SETNAME_IMG = RES_DIR .. "setname.png"
local PASTE_IMG = RES_DIR .. "paste.png"
local TIKTOK_ROW_IMG = RES_DIR .. "tiktok_row.png"
local TIKTOK_BACKUP_IMG = RES_DIR .. "tiktok_backup.png"
local TIKTOK_BACKUPDATA_IMG = RES_DIR .. "tiktok_backupData.png"
local TIKTOK_BACKUPING_IMG = RES_DIR .. "tiktok_backuping.png"

local function sleep(ms)
 sys.msleep(ms)
end

local function toast(msg)
 -- Không hiển thị status mô tả bước, chỉ hiển thị countdown thời gian.
end

local function showProgress(label, sec)
 sys.toast(tostring(label or "Tiến trình") .. " " .. tostring(sec) .. "s", 0)
end

local function countdown(label, sec)
 while sec > 0 do
  showProgress(label, sec)
  sleep(1000)
  sec = sec - 1
 end
end

local function findImage(img, sim, x1, y1, x2, y2)
 sim = sim or 82
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334
 local x, y = screen.find_image(img, sim, x1, y1, x2, y2)
 if x ~= -1 then return true, x, y end
 return false, -1, -1
end

local function imageCenter(imgPath, x, y)
 local img = image.load_file(imgPath)
 if not img then return x, y end
 local w, h = img:size()
 if not w or not h then return x, y end
 return math.floor(x + (w / 2)), math.floor(y + (h / 2))
end

local waitImageDisappear

local function tapImageCenter(img, sim, timeoutSec, label, x1, y1, x2, y2, offsetX, offsetY)
 if not file.exists(img) then return false, -1, -1 end
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334
 offsetX = offsetX or 0
 offsetY = offsetY or 0
 local startAt = os.time()
 local lastShown = -1
 while os.time() - startAt < timeoutSec do
  local remain = timeoutSec - (os.time() - startAt)
  if remain ~= lastShown then
   showProgress(label or "Quét ảnh", remain)
   lastShown = remain
  end
  local ok, x, y = findImage(img, sim or 82, x1, y1, x2, y2)
  if ok then
   countdown("Thấy ảnh, chờ tap", 2)
   touch.tap(x + offsetX, y + offsetY)
   waitImageDisappear(img, 30, label or "Đợi ảnh mất", x1, y1, x2, y2)
   return true, x, y
  end
  sleep(300)
 end
 return false, -1, -1
end

local function waitImage(img, timeoutSec, label, x1, y1, x2, y2)
 if not file.exists(img) then return false, -1, -1 end
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334
 local startAt = os.time()
 local lastShown = -1
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  local elapsed = os.time() - startAt
  local shown = elapsed
  if timeoutSec > 0 then shown = timeoutSec - elapsed end
  if shown ~= lastShown then
   showProgress(label or "Chờ ảnh", shown)
   lastShown = shown
  end
  local ok, x, y = findImage(img, 82, x1, y1, x2, y2)
  if ok then return true, x, y end
  sleep(300)
 end
 return false, -1, -1
end

local function waitAnyImage(imgList, timeoutSec, label, x1, y1, x2, y2)
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334
 local startAt = os.time()
 local lastShown = -1
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  local elapsed = os.time() - startAt
  local shown = elapsed
  if timeoutSec > 0 then shown = timeoutSec - elapsed end
  if shown ~= lastShown then
   showProgress(label or "Chờ ảnh", shown)
   lastShown = shown
  end
  for i = 1, #imgList do
   local img = imgList[i]
   if file.exists(img) then
    local ok, x, y = findImage(img, 82, x1, y1, x2, y2)
    if ok then return true, x, y, img end
   end
  end
  sleep(500)
 end
 return false, -1, -1, nil
end

local function tapAnyImageCenter(imgList, timeoutSec, label)
 local ok, x, y, img = waitAnyImage(imgList, timeoutSec, label)
 if ok then
  local cx, cy = imageCenter(img, x, y)
  countdown("Thấy ảnh, chờ tap", 2)
  touch.tap(cx, cy)
  waitImageDisappear(img, 30, label or "Đợi ảnh mất")
  return true, cx, cy, img
 end
 return false, -1, -1, nil
end

waitImageDisappear = function(img, timeoutSec, label, x1, y1, x2, y2)
 if not file.exists(img) then return true end
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334
 local startAt = os.time()
 local lastShown = -1
 while os.time() - startAt < timeoutSec do
  local remain = timeoutSec - (os.time() - startAt)
  if remain ~= lastShown then
   showProgress(label or "Đợi ảnh biến mất", remain)
   lastShown = remain
  end
  local ok = findImage(img, 82, x1, y1, x2, y2)
  if not ok then return true end
  sleep(500)
 end
 return false
end

local function swipeUpOnce()
 touch.down(1, 360, 1050)
 sleep(30)
 touch.move(1, 360, 820)
 sleep(30)
 touch.up(1)
 sleep(1000)
end

local function swipeDownAt(x, y)
 touch.down(1, x, y)
 sleep(30)
 touch.move(1, x, y + 260)
 sleep(30)
 touch.up(1)
 sleep(1000)
end

local function randomDelayCountdown(minSec, maxSec)
 math.randomseed(os.time())
 local sec = math.random(minSec, maxSec)
 while sec > 0 do
  showProgress("Random delay", sec)
  sleep(1000)
  sec = sec - 1
 end
end

local function randomDigits(n)
 local out = ""
 for i = 1, n do
  out = out .. tostring(math.random(0, 9))
 end
 return out
end

local function randomMeaningText8()
 local words = {
  "thanhdat", "minhquan", "hoangnam", "quanghuy", "anhkhoa",
  "baokhanh", "ducthanh", "huyhoang", "namphong", "trunghieu"
 }
 local w = words[math.random(1, #words)]
 if #w > 8 then w = string.sub(w, 1, 8) end
 while #w < 8 do w = w .. "a" end
 return w
end

local function createRandomName19()
 return randomMeaningText8() .. randomDigits(11)
end

local function inputText(text)
 text = tostring(text or "")
 pasteboard.write(text)
 sleep(300)
 key.send_text(text)
 sleep(1000)
end

local function tapLoopSeconds(x, y, sec)
 while sec > 0 do
  sys.toast("Tap " .. tostring(x) .. "," .. tostring(y) .. " " .. tostring(sec) .. "s", 0)
  touch.tap(x, y)
  sleep(1000)
  sec = sec - 1
 end
end

local function closeAppManager()
 app.quit(APPMANAGER_BUNDLE)
 countdown("Đóng AppManager", 2)
end

local function openAppManager()
 app.run(APPMANAGER_BUNDLE)
 countdown("Mở AppManager", 4)
end

local function runGroup3AppManagerBackupFlow()
 app.quit(TIKTOK_BUNDLE)
 countdown("Đóng TikTok", 2)
 closeAppManager()
 openAppManager()
 tapImageCenter(TIKTOK_ROW_IMG, 82, 30, "Tìm TikTok", 0, 150, 750, 1100)
 swipeUpOnce()
 tapImageCenter(TIKTOK_BACKUP_IMG, 82, 30, "Tìm Backup", 0, 150, 750, 1334)
 tapImageCenter(TIKTOK_BACKUPDATA_IMG, 82, 30, "Xác nhận data", 0, 150, 750, 1334)
 waitImage(TIKTOK_BACKUPING_IMG, 30, "Đợi popup backup", 0, 150, 750, 1334)
 waitImageDisappear(TIKTOK_BACKUPING_IMG, 1800, "Backup", 0, 150, 750, 1334)
end

local function runBackupManagerTail()
 touch.tap(362, 398)
 countdown("Sau tap 362,398", 2)
 runGroup3AppManagerBackupFlow()
 touch.tap(371, 1279)
 countdown("Sau tap 371,1279", 2)
 waitImage(BACKUPSAPP_IMG, 0, "Đợi Backupsapp")
 tapImageCenter(TIKTOKBUP_IMG, 82, 60, "Tìm tiktokbup")
 countdown("Sau tap tiktokbup", 2)
 touch.tap(345, 477)
 countdown("Sau tap 345,477", 2)
 tapImageCenter(SETNAME_IMG, 82, 60, "Tìm setname")
 countdown("Sau setname", 3)
 touch.tap(521, 478)
 tapImageCenter(PASTE_IMG, 82, 60, "Tìm paste")
 countdown("Sau paste", 2)
 touch.tap(527, 574)
end

local function tapPinkOrSwipeDown()
 local color = screen.get_color(552, 1206)
 if color == 0xfe2c55 then
  touch.tap(552, 1206)
  sleep(1000)
  return true
 end
 countdown("Trước vuốt 153,898", 2)
 swipeDownAt(153, 898)
 return false
end

local function runStage7()
 app.quit(TIKTOK_BUNDLE)
 countdown("Đóng TikTok", 2)

 app.run(TIKTOK_BUNDLE)
 countdown("Mở TikTok", 30)

 touch.tap(674, 1281)
 countdown("Sau tap 674,1281", 20)

 tapImageCenter(ADDACC_IMG, 82, 5, "Quét addacc")

 waitAnyImage({LOGTTT_IMG, LOGTTT2_IMG}, 0, "Đợi LogTTT/LogTTT2")

 tapAnyImageCenter({COUNTWGG_IMG, COUNTWGG1_IMG}, 60, "Tìm Countwgg")
 randomDelayCountdown(10, 60)

 local wantOk = waitImage(TIKTOKWANT_IMG, 30, "Quét tiktokwant")
 if wantOk then
  touch.tap(502, 792)
  sleep(1000)
 end

 waitImage(CHOOSEAN_IMG, 0, "Đợi choosean")
 touch.tap(254, 758)
 sleep(1000)

 waitAnyImage({SINTOTT_IMG, SINTOTT2_IMG}, 0, "Đợi sintott/sintott2")
 swipeUpOnce()
 tapImageCenter(COUNTT_IMG, 82, 60, "Tìm countt")
 countdown("Sau countt", 5)

 local birthdayOk = waitAnyImage({BIRTHDAY_IMG, BIRTHDAY1_IMG}, 30, "Quét birthday/birthday1", 38, 473, 681, 632)
 if birthdayOk then
  swipeDownAt(427, 892)
  swipeDownAt(566, 913)
  countdown("Trước vuốt 153,898", 2)
  swipeDownAt(153, 898)
  randomDelayCountdown(1, 300)
  sys.toast("Tiếp: kiểm tra 552,1206", 0)
  tapPinkOrSwipeDown()
  sys.toast("Tiếp: đợi creatname", 0)
  waitImage(CREATNAME_IMG, 0, "Đợi creatname")
  sys.toast("Tiếp: tap ô tên", 0)
  touch.tap(425, 516)
  countdown("Sau tap ô tên", 1)
  sys.toast("Tiếp: nhập tên", 0)
  inputText(createRandomName19())
  sys.toast("Tiếp: tap 591,819", 0)
  touch.tap(591, 819)
  countdown("Sau tap 591,819", 3)
 end

 countdown("Trước tap 680,1286", 3)
 sys.toast("Tiếp: tap 680,1286", 0)
 tapLoopSeconds(680, 1286, 15)
 sys.toast("Tiếp: AppManager backup", 0)
 runBackupManagerTail()

 sys.toast("Stage 7 hoàn thành", 1)
 return true
end

runStage7()
return
