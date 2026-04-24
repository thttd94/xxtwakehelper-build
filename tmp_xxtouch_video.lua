device = require("device")
sys = require("sys")
app = require("app")

while (device.is_screen_locked()) do
 device.unlock_screen()
 sys.msleep(1000)
end

sys.toast("Screen unlocked, script starting")

pcall(app.quit, "com.ss.iphone.ugc.tiktok.www")
pcall(app.quit, "com.apple.mobilesafari")
sys.msleep(1200)

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

math.randomseed(os.time())
math.random()
math.random()
math.random()

local pick = links[math.random(1, #links)]
sys.toast('Open video')
app.open_url(pick)
return true
