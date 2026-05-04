screen.init(0)

local app = require("app")
local file = require("file")
local sys = require("sys")


-- OpenClaw/PYW status sync: write readable status for GUI polling even when run directly on client.
local OC_STATUS_PATH = rawget(_G, "OC_STATUS_PATH") or "/var/mobile/Media/1ferver/lua/examples/oc_status.txt"
function oc_status(text)
    text = tostring(text or "")
    if type(__oc_write_status) == "function" then pcall(__oc_write_status, text) end
    pcall(function()
        local line = tostring(os.time()) .. "|" .. text
        local wrote = false
        local ok_file, file = pcall(require, "file")
        if ok_file and file then
            if type(file.writes) == "function" then local ok = pcall(file.writes, OC_STATUS_PATH, line); wrote = ok or wrote end
            if (not wrote) and type(file.write) == "function" then local ok = pcall(file.write, OC_STATUS_PATH, line); wrote = ok or wrote end
        end
        if not wrote then
            local f = io.open(OC_STATUS_PATH, "w")
            if f then f:write(line) f:close() end
        end
    end)
end
function oc_toast(text, ...)
    text = tostring(text or "")
    oc_status(text)
    if sys and type(sys.toast) == "function" then return sys.toast(text, ...) end
end


local SCRIPT_VERSION = "STAGE6_TIKTOK_V1"

app.quit("com.apple.mobilesafari")
sys.msleep(1000)

local function countdownStartDelay(sec)
 while sec > 0 do
  oc_toast("Delay start " .. tostring(sec) .. "s", 0)
  sys.msleep(1000)
  sec = sec - 1
 end
end

math.randomseed(os.time())
local START_DELAY_SEC = math.random(1, 500)
countdownStartDelay(START_DELAY_SEC)

local LOGIN_STATUS_BASE = "Quá trình login gg đang thực hiện "
local login_status_dots = 0
local login_status_last_at = 0

function showLoginStatus(force)
 local now = os.time()
 if force or now ~= login_status_last_at then
  login_status_last_at = now
  login_status_dots = login_status_dots + 1
  if login_status_dots > 7 then login_status_dots = 1 end
  oc_toast(LOGIN_STATUS_BASE .. string.rep(".", login_status_dots), 0)
 end
end

showLoginStatus(true)

local RES_DIR = "/var/mobile/Media/1ferver/lua/examples/"
local INPUT_PATH = RES_DIR .. "input.txt"
local SIGN_IMG = RES_DIR .. "sign.png"
local WELLCOM_IMG = RES_DIR .. "wellcom.png"
local INDERSTAND_IMG = RES_DIR .. "inderstand.png"
local NOTNOW_IMG = RES_DIR .. "notnow.png"

-- Link mở TikTok. Nếu anh có link cụ thể khác thì đổi đúng dòng này.
local TIKTOK_OPEN_URL = "https://accounts.google.com/signin"

local __last_status = ""
local __last_status_at = 0
local __phase = ""

local function sleep(ms)
 showLoginStatus(false)
 sys.msleep(ms)
 showLoginStatus(false)
end

local function shortText(t)
 t = tostring(t or "")
 if #t > 40 then
  return string.sub(t, 1, 37) .. "..."
 end
 return t
end

function status(t)
 showLoginStatus(false)
end

function phase(t)
 __phase = tostring(t or "")
 showLoginStatus(false)
end

function phaseProgress(sec)
 showLoginStatus(false)
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

function imageCenter(imgPath, x, y)
 local img = image.load_file(imgPath)
 if not img then return x, y end
 local w, h = img:size()
 if not w or not h then return x, y end
 return math.floor(x + (w / 2)), math.floor(y + (h / 2))
end

function handleNotNow()
 local ok, x, y = findImage(NOTNOW_IMG, 82, 0, 0, 750, 1334)
 if ok then
  phase("Tạm dừng bấm notnow")
  sleep(2000)
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
  handleNotNow()
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

 oc_toast("Load cookies xong", 0)
 waitPhase(5000)
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
  handleNotNow()
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
  handleNotNow()
  local ok, x, y = findImage(WELLCOM_IMG, 82, 0, 0, 750, 1334)
  if ok then
   phase("Thấy wellcom.png")
   return true, x, y
  end
  status("Đợi wellcom.png")
  sleep(500)
 end
end

function swipeUpOnceNormal()
 phase("Vuốt lên")
 touch.down(1, 360, 1050)
 sleep(30)
 touch.move(1, 360, 820)
 sleep(30)
 touch.up(1)
 waitPhase(1200)
end

function swipeUpUntilInderstand()
 phase("Tìm inderstand.png")
 local startAt = os.time()
 while os.time() - startAt < 300 do
  handleNotNow()
  local ok, x, y = findImage(INDERSTAND_IMG, 82, 0, 0, 750, 1334)
  if ok then
   phase("Thấy inderstand.png")
   sleep(2000)
   local cx, cy = imageCenter(INDERSTAND_IMG, x, y)
   touch.tap(cx, cy)
   sleep(1000)
   return true, cx, cy
  end
  swipeUpOnceNormal()
 end
 oc_toast("Không thấy inderstand.png sau 5 phút", 1)
 return false, -1, -1
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
 -- Đoạn này chỉ vuốt lên bình thường, không ấn giữ lâu. Ấn giữ chỉ dùng lúc vuốt xuống tìm sign.png ban đầu.
 phase("Bước 3: tìm inderstand")
 if not swipeUpUntilInderstand() then
  return false
 end

 oc_toast("Hoàn thành login gg", 1)
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
