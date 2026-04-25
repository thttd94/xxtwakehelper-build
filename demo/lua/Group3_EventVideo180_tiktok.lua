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
local interval_ms = 45 * 60 * 1000

math.randomseed(os.time())
math.random()
math.random()

local function run_once(round)
 while (device.is_screen_locked()) do
  device.unlock_screen()
  sys.msleep(1000)
 end

 sys.toast("EventVideo180 TikTok lần " .. tostring(round) .. " đang chạy")

 pcall(app.quit, "com.ss.iphone.ugc.Ame")
 pcall(app.quit, "com.apple.mobilesafari")
 sys.msleep(1200)

 local pick = links[math.random(1, #links)]
 app.open_url(pick)
end

for i = 1, repeat_count do
 run_once(i)
 if i < repeat_count then
  sys.toast("Chờ 45 phút để chạy lần tiếp theo")
  sys.msleep(interval_ms)
 end
end

return true
