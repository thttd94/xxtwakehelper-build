screen.init(0)

local app = require("app")
local sys = require("sys")

local SCRIPT_VERSION = "STAGE7_TIKTOK_V1"
local TIKTOK_BUNDLE = "com.ss.iphone.ugc.Ame"
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

local function sleep(ms)
 sys.msleep(ms)
end

local function toast(msg)
 -- Không hiển thị status mô tả bước, chỉ hiển thị countdown thời gian.
end

local function countdown(label, sec)
 while sec > 0 do
  sys.toast(tostring(label or "Đếm ngược") .. " " .. tostring(sec) .. "s", 0)
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

local function tapImageCenter(img, sim, timeoutSec, label)
 local startAt = os.time()
 while os.time() - startAt < timeoutSec do
  local ok, x, y = findImage(img, sim or 82, 0, 0, 750, 1334)
  if ok then
   local cx, cy = imageCenter(img, x, y)
   touch.tap(cx, cy)
   sleep(1000)
   return true, cx, cy
  end
  sleep(500)
 end
 return false, -1, -1
end

local function waitImage(img, timeoutSec, label)
 local startAt = os.time()
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  local ok, x, y = findImage(img, 82, 0, 0, 750, 1334)
  if ok then return true, x, y end
  sleep(500)
 end
 return false, -1, -1
end

local function waitAnyImage(imgList, timeoutSec, label)
 local startAt = os.time()
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  for i = 1, #imgList do
   local ok, x, y = findImage(imgList[i], 82, 0, 0, 750, 1334)
   if ok then return true, x, y, imgList[i] end
  end
  sleep(500)
 end
 return false, -1, -1, nil
end

local function tapAnyImageCenter(imgList, timeoutSec, label)
 local ok, x, y, img = waitAnyImage(imgList, timeoutSec, label)
 if ok then
  local cx, cy = imageCenter(img, x, y)
  touch.tap(cx, cy)
  sleep(1000)
  return true, cx, cy, img
 end
 return false, -1, -1, nil
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
  sys.toast("Random delay " .. tostring(sec) .. "s", 0)
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

local function tapLoop60s(x, y)
 local startAt = os.time()
 while os.time() - startAt < 60 do
  touch.tap(x, y)
  sleep(500)
 end
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

 waitAnyImage({LOGTTT_IMG, LOGTTT2_IMG}, 0, "")

 tapAnyImageCenter({COUNTWGG_IMG, COUNTWGG1_IMG}, 60, "Tìm Countwgg")

 local wantOk = waitImage(TIKTOKWANT_IMG, 30, "")
 if wantOk then
  touch.tap(502, 792)
  sleep(1000)
 end

 waitImage(CHOOSEAN_IMG, 0, "")
 touch.tap(254, 758)
 sleep(1000)

 waitAnyImage({SINTOTT_IMG, SINTOTT2_IMG}, 0, "")
 swipeUpOnce()
 tapImageCenter(COUNTT_IMG, 82, 60, "Tìm countt")
 countdown("Sau countt", 5)

 waitAnyImage({BIRTHDAY_IMG, BIRTHDAY1_IMG}, 0, "")
 swipeDownAt(427, 892)
 swipeDownAt(566, 913)
 countdown("Trước vuốt 153,898", 2)
 swipeDownAt(153, 898)

 randomDelayCountdown(1, 300)
 tapPinkOrSwipeDown()

 waitImage(CREATNAME_IMG, 0, "")
 touch.tap(425, 516)
 countdown("Sau tap ô tên", 1)
 inputText(createRandomName19())
 touch.tap(591, 819)
 countdown("Sau tap 591,819", 3)
 tapLoop60s(680, 1286)

 sys.toast("Stage 7 hoàn thành", 1)
 return true
end

runStage7()
return
