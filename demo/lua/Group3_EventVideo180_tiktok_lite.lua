device = require("device")
sys = require("sys")
app = require("app")
file = require("file")

local links = {
 "https://lite.tiktok.com/t/ZSHoJkxP6/",
 "https://lite.tiktok.com/t/ZSHoJvPdS",
 "https://lite.tiktok.com/t/ZSHodvDhG",
 "https://lite.tiktok.com/t/ZSHodCJUU/",
 "https://lite.tiktok.com/t/ZSHodXPJh/",
 "https://lite.tiktok.com/t/ZSHodwDAy/",
 "https://lite.tiktok.com/t/ZSHodquAk/",
 "https://lite.tiktok.com/t/ZSHo64x5h/",
 "https://lite.tiktok.com/t/ZSHo6yxet/",
 "https://lite.tiktok.com/t/ZSHoksvp6/",
}

local repeat_count = 3
local interval_ms = 60 * 60 * 1000

local function status(text)
 text = tostring(text or "")
 if type(__oc_write_status) == "function" then pcall(__oc_write_status, text) end
 sys.toast(text, 0)
 return true
end

local function failStatus(text)
 status("ERROR: " .. tostring(text or "Lỗi script"))
 error(tostring(text or "Lỗi script"))
end

local function wait_countdown(ms, label)
 local remain = ms
 local lastShown = -1
 while remain > 0 do
  local sec = math.ceil(remain / 1000)
  if sec ~= lastShown then
   status((label or "Chờ lần tiếp theo") .. " " .. tostring(sec) .. "s")
   lastShown = sec
  end
  local step = remain < 1000 and remain or 1000
  sys.msleep(step)
  remain = remain - step
 end
end

math.randomseed(os.time())
math.random()
math.random()

local function swipe_vertical(y1, y2)
 touch.down(1, 375, y1)
 sys.msleep(120)
 local current = y1
 local step = y2 < y1 and -60 or 60
 while (step < 0 and current > y2) or (step > 0 and current < y2) do
  current = current + step
  if step < 0 and current < y2 then current = y2 end
  if step > 0 and current > y2 then current = y2 end
  touch.move(1, 375, current)
  sys.msleep(30)
 end
 touch.up(1)
end

local function run_once(round)
 while (device.is_screen_locked()) do
  device.unlock_screen()
  sys.msleep(1000)
 end

 status("EventVideo180 TikTok lần " .. tostring(round) .. " đang chạy")

 status("Đóng TikTok/Safari cũ")
 pcall(app.quit, "com.ss.iphone.ugc.Ame")
 pcall(app.quit, "com.apple.mobilesafari")
 sys.msleep(1200)

 local pick = links[math.random(1, #links)]
 status("Mở link video")
 local ok_open = pcall(app.open_url, pick)
 if not ok_open then failStatus("Không mở được link video") end
 status("Chờ video 60s")
 sys.msleep(60000)
 status("Vuốt lên xem video kế tiếp")
 swipe_vertical(1080, 260)
 status("Chờ video sau 10s")
 sys.msleep(10000)
 status("Vuốt xuống quay về video trước đó")
 swipe_vertical(320, 1120)
end

for i = 1, repeat_count do
 run_once(i)
 wait_countdown(interval_ms, "Chờ lần tiếp theo")
end

status("Bắt đầu chạy nội dung claim video")
local claim_code = file.reads("/var/mobile/Media/1ferver/lib/Group3_ClaimVideo.lua")
if claim_code and #tostring(claim_code) > 0 then
 local fn, err = load(claim_code)
 if fn then
  local ok, run_err = pcall(fn)
  if ok then
   status("EventVideo180 TikTok Lite chạy xong")
   return true
  end
  failStatus("claim video lỗi: " .. tostring(run_err))
 else
  failStatus("load claim lỗi: " .. tostring(err))
 end
end

failStatus("không thấy Group3_ClaimVideo.lua")
