screen.init(0)

local app = require("app")
local file = require("file")
local sys = require("sys")

local SCRIPT_VERSION = "STAGE6_TIKTOK_V1"
local RES_DIR = "/var/mobile/Media/1ferver/lua/examples/"
local INPUT_PATH = RES_DIR .. "input.txt"
local SIGN_IMG = RES_DIR .. "sign.png"
local WELLCOM_IMG = RES_DIR .. "wellcom.png"
local INDERSTAND_IMG = RES_DIR .. "inderstand.png"

-- Link mở TikTok. Nếu anh có link cụ thể khác thì đổi đúng dòng này.
local TIKTOK_OPEN_URL = "https://accounts.google.com/signin"

local __last_status = ""
local __last_status_at = 0
local __phase = ""

local function sleep(ms)
 sys.msleep(ms)
end

local function shortText(t)
 t = tostring(t or "")
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
 __phase = tostring(t or "")
 __last_status = ""
 status(__phase)
end

function phaseProgress(sec)
 status(__phase .. " " .. tostring(sec) .. "s")
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

function handleBluePoint()
 local x, y = screen.find_color({
  {302,1252,0x007aff},
  {353,1256,0x007aff},
  {439,1257,0x007aff},
  {393,1268,0x007aff},
 }, 95, 0, 0, 0, 0)
 if x ~= -1 then
  phase("Tạm dừng bấm điểm xanh")
  touch.tap(x, y)
  sleep(1000)
  return true
 end
 return false
end

function waitPhase(ms)
 local remain = ms
 local lastShown = -1
 while remain > 0 do
  handleBluePoint()
  local sec = math.ceil(remain / 1000)
  if sec ~= lastShown then
   phaseProgress(sec)
   lastShown = sec
  end
  local step = 500
  if remain < step then step = remain end
  sleep(step)
  remain = remain - step
 end
end

function runActiveXXTE()
 phase("Active XXTE")

 local function find_cookie()
  local bases = {
   "/private/var/mobile/Containers/Shared/AppGroup",
   "/var/mobile/Containers/Shared/AppGroup"
  }

  local paths = {
   "File Provider Storage/Downloads",
   "Downloads",
   "Documents/Downloads"
  }

  for _, base in ipairs(bases) do
   local groups = file.list(base)

   if type(groups) == "table" then
    for _, folder in pairs(groups) do
     for _, p in ipairs(paths) do
      local src = base .. "/" .. folder .. "/" .. p .. "/Cookies.binarycookies"
      if file.exists(src) then
       return src
      end
     end
    end
   end
  end

  return nil
 end

 local safariPath = app.data_path("com.apple.mobilesafari")
 local cookiePath = safariPath .. "/Library/Cookies/Cookies.binarycookies"
 local backupPath = safariPath .. "/Library/Cookies/Cookies_backup.binarycookies"

 -- backup file cũ
 if file.exists(cookiePath) then
  local old = file.reads(cookiePath)
  if old then
   file.writes(backupPath, old)
  end
 end

 -- load cookie mới
 local src = find_cookie()
 if src then
  local data = file.reads(src)
  if data then
   file.writes(cookiePath, data)
  end
 end

 sys.toast("Load cookies xong", 1)
 waitPhase(1000)
 return true
end

function readInputParts()
 local data = file.reads(INPUT_PATH)
 if type(data) ~= "string" then
  return nil, nil, "Không đọc được input.txt"
 end
 data = string.gsub(data, "\r", "")
 local line = string.match(data, "([^\n]+)")
 if not line or line == "" then
  return nil, nil, "input.txt rỗng"
 end
 local left, right = string.match(line, "^(.-)|(.*)$")
 if not left then
  return nil, nil, "input.txt thiếu dấu |"
 end
 return left, right, nil
end

function pasteText(text)
 text = tostring(text or "")
 pasteboard.write(text)
 sleep(300)
 key.send_text(text)
end

function tapReturn(label)
 phase(label or "Bấm return")
 touch.tap(658, 1289)
 waitPhase(3000)
 return true
end

function tapFieldAndPaste(x, y, text, label)
 phase(label)
 touch.tap(x, y)
 waitPhase(1000)
 pasteText(text)
 waitPhase(1500)
 return true
end

function swipeDownFrom614119()
 phase("Vuốt xuống trước sign")
 touch.down(1, 614, 119)
 sleep(800)
 touch.move(1, 614, 720)
 sleep(800)
 touch.up(1)
 waitPhase(1000)
end

-- Chỉ dùng trước lúc nhập input lần đầu.
-- Sau khi thấy sign.png và bắt đầu nhập input thì không check/vuốt xuống sign nữa.
function waitSign()
 phase("Đợi sign.png trước input 1")
 local lastSwipeAt = os.time()
 while true do
  handleBluePoint()
  local ok, x, y = findImage(SIGN_IMG, 82, 0, 0, 750, 1334)
  if ok then
   phase("Thấy sign.png")
   return true, x, y
  end
  if os.time() - lastSwipeAt >= 60 then
   swipeDownFrom614119()
   lastSwipeAt = os.time()
  else
   status("Đợi sign.png")
   sleep(500)
  end
 end
end

function waitWellcom()
 phase("Đợi wellcom.png")
 while true do
  handleBluePoint()
  local ok, x, y = findImage(WELLCOM_IMG, 82, 0, 0, 750, 1334)
  if ok then
   phase("Thấy wellcom.png")
   return true, x, y
  end
  status("Đợi wellcom.png")
  sleep(500)
 end
end

function slowSwipeUpOnce()
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

function swipeUpUntilInderstand()
 phase("Tìm inderstand.png")
 while true do
  handleBluePoint()
  local ok, x, y = findImage(INDERSTAND_IMG, 82, 0, 0, 750, 1334)
  if ok then
   phase("Thấy inderstand.png")
   return true, x, y
  end
  slowSwipeUpOnce()
 end
end

function runStage6()
 phase("Stage 6")

 -- Chạy nội dung trong E:\\Phoi\\tool\\XXTE\\Active XXTE.lua đầu tiên
 if not runActiveXXTE() then
  phase("Lỗi Active XXTE")
  return false
 end

 local beforePipe, afterPipe, err = readInputParts()
 if err then
  phase(err)
  return false
 end

 phase("Mở TikTok bằng link")
 app.open_url(TIKTOK_OPEN_URL)
 waitPhase(5000)

 -- Bước 1: chỉ ở đoạn này mới đợi sign.png và 60s vuốt xuống một lần nếu chưa thấy.
 -- Qua tới nhập input lần đầu thì tuyệt đối không check/vuốt xuống sign nữa.
 phase("Bước 1: chờ sign")
 waitSign()
 tapFieldAndPaste(356, 527, beforePipe, "Bước 1: dán trước dấu |")
 tapReturn("Bước 1: bấm return lần 1")
 waitPhase(2000)

 -- Bước 2: đợi wellcom.png, dán nội dung sau dấu |, bắt buộc bấm return xong mới sang bước 3.
 phase("Bước 2: chờ wellcom")
 waitWellcom()
 tapFieldAndPaste(445, 638, afterPipe, "Bước 2: dán sau dấu |")
 tapReturn("Bước 2: bấm return lần 2")
 phase("Bước 2: đã bấm return lần 2")
 waitPhase(5000)

 -- Bước 3: chỉ bắt đầu sau khi bước 2 đã dán input lần 2 và bấm return lần 2 xong.
 phase("Bước 3: tìm inderstand")
 swipeUpUntilInderstand()

 phase("Stage 6 xong")
 return true
end

phase("Khởi động " .. SCRIPT_VERSION)
waitPhase(1000)
if not runStage6() then
 phase("Lỗi Stage 6")
 return
end
phase("ALL DONE")
return
