device = require("device")
sys = require("sys")
app = require("app")

local links = {
 "https://www.tiktok.com/t/ZSHoJkxP6/",
 "https://www.tiktok.com/t/ZSHoJvPdS",
 "https://www.tiktok.com/t/ZSHodvDhG",
 "https://www.tiktok.com/t/ZSHodCJUU/",
 "https://www.tiktok.com/t/ZSHodXPJh/",
 "https://www.tiktok.com/t/ZSHodwDAy/",
 "https://www.tiktok.com/t/ZSHodquAk/",
 "https://www.tiktok.com/t/ZSHo64x5h/",
 "https://www.tiktok.com/t/ZSHo6yxet/",
 "https://www.tiktok.com/t/ZSHoksvp6/",
}

local repeat_count = 3
local interval_ms = 60 * 60 * 1000

local function status(text)
 sys.toast(tostring(text or ""), 0)
 return true
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

 pcall(app.quit, "com.ss.iphone.ugc.Ame")
 pcall(app.quit, "com.apple.mobilesafari")
 sys.msleep(1200)

 local pick = links[math.random(1, #links)]
 app.open_url(pick)
 sys.msleep(60000)
 status("Vuốt lên xem video kế tiếp")
 swipe_vertical(1080, 260)
 sys.msleep(1200)
 status("Vuốt xuống quay về video trước đó")
 swipe_vertical(320, 1120)
end

for i = 1, repeat_count do
 run_once(i)
 if i < repeat_count then
  wait_countdown(interval_ms, "Chờ lần tiếp theo")
 end
end

return true
