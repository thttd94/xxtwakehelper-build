screen.init(0)

local app = require("app")
local sys = require("sys")

local SCRIPT_VERSION = "STAGE7_TIKTOK_V1"
local TIKTOK_BUNDLE = "com.ss.iphone.ugc.Ame"
local RES_DIR = "/var/mobile/Media/1ferver/lua/examples/"

local ADDACC_IMG = RES_DIR .. "addacc.png"
local LOGTTT_IMG = RES_DIR .. "LogTTT.png"
local LOGTTT1_IMG = RES_DIR .. "LogTTT1.png"
local COUNTWGG_IMG = RES_DIR .. "Countwgg.png"
local TIKTOKWANT_IMG = RES_DIR .. "tiktokwant.png"
local CHOOSEAN_IMG = RES_DIR .. "choosean.png"
local SINTOTT_IMG = RES_DIR .. "sintott.png"
local COUNTT_IMG = RES_DIR .. "countt.png"
local BIRTHDAY_IMG = RES_DIR .. "birthday.png"
local CREATNAME_IMG = RES_DIR .. "creatname.png"

local function sleep(ms)
 sys.msleep(ms)
end

local function toast(msg)
 sys.toast("Ver " .. SCRIPT_VERSION .. " : " .. tostring(msg or ""), 0)
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
  if label then toast(label) end
  sleep(500)
 end
 return false, -1, -1
end

local function waitImage(img, timeoutSec, label)
 local startAt = os.time()
 while timeoutSec <= 0 or os.time() - startAt < timeoutSec do
  local ok, x, y = findImage(img, 82, 0, 0, 750, 1334)
  if ok then return true, x, y end
  if label then toast(label) end
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
  if label then toast(label) end
  sleep(500)
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

local function runStage7()
 toast("Stage 7 start")

 -- Đóng TikTok 2s
 app.quit(TIKTOK_BUNDLE)
 sleep(2000)

 -- Mở lại TikTok đợi 30s
 app.run(TIKTOK_BUNDLE)
 sleep(30000)

 -- Bấm 674,1281 đợi 5s
 touch.tap(674, 1281)
 sleep(5000)

 -- Nếu có addacc.png trong 5s thì bấm vào chính nó, không có thì bỏ qua
 tapImageCenter(ADDACC_IMG, 82, 5, "Quét addacc")

 -- Đợi LogTTT.png hoặc LogTTT1.png, thấy 1 trong 2 đều được
 waitAnyImage({LOGTTT_IMG, LOGTTT1_IMG}, 0, "Đợi LogTTT/LogTTT1")

 -- Tìm và bấm Countwgg.png
 tapImageCenter(COUNTWGG_IMG, 82, 60, "Tìm Countwgg")

 -- Nếu có tiktokwant.png thì tap 502,792
 local wantOk = waitImage(TIKTOKWANT_IMG, 30, "Quét tiktokwant")
 if wantOk then
  touch.tap(502, 792)
  sleep(1000)
 end

 -- Nếu thấy choosean.png thì bấm 254,758
 waitImage(CHOOSEAN_IMG, 0, "Đợi choosean")
 touch.tap(254, 758)
 sleep(1000)

 -- Nếu thấy sintott.png thì vuốt lên 1 cái rồi tìm và tap countt.png đợi 5s
 waitImage(SINTOTT_IMG, 0, "Đợi sintott")
 swipeUpOnce()
 tapImageCenter(COUNTT_IMG, 82, 60, "Tìm countt")
 sleep(5000)

 -- Nếu thấy birthday.png thì vuốt xuống lần lượt các vị trí
 waitImage(BIRTHDAY_IMG, 0, "Đợi birthday")
 swipeDownAt(427, 892)
 swipeDownAt(566, 913)
 sleep(2000)
 swipeDownAt(153, 898)

 -- Random 1s - 300s trước khi bấm 552,1206
 randomDelayCountdown(1, 300)
 touch.tap(552, 1206)
 sleep(1000)

 -- Nếu thấy creatname.png thì nhập tên 19 ký tự rồi tap 591,819
 waitImage(CREATNAME_IMG, 0, "Đợi creatname")
 touch.tap(425, 516)
 sleep(1000)
 inputText(createRandomName19())
 touch.tap(591, 819)
 sleep(3000)

 -- Tap liên tục 680,1286 trong 60s rồi dừng
 tapLoop60s(680, 1286)

 sys.toast("Stage 7 hoàn thành", 1)
 return true
end

runStage7()
return
