screen.init(0)

device = require("device")
sys = require("sys")
app = require("app")

local IMG_DIR = "/var/mobile/Media/1ferver/lua/examples/"
local CHECK_IMG_1 = IMG_DIR .. "checkvideo48_1.PNG"
local CHECK_IMG_2 = IMG_DIR .. "checkvideo48_2.PNG"
local CHECK_IMG_3 = IMG_DIR .. "checkvideo48_3.PNG"
local CLAIM_IMG = IMG_DIR .. "ClaimVd48.PNG"

local SCRIPT_VERSION = "3.5"
local MAX_RUNTIME_SEC = 3 * 60 * 60
local SCRIPT_START_AT = os.time()
local CLAIM_RETRY_SEC = 30 * 60

local GOOD_Y_MIN = 360
local GOOD_Y_MAX = 620
local TARGET_Y = 500

local __last_status = ""
local __last_status_at = 0

local function shortText(t)
 if #t > 26 then
  return string.sub(t, 1, 23) .. "..."
 end
 return t
end

local function status(t)
 t = shortText(t)
 local text = "Ver " .. SCRIPT_VERSION .. " : " .. t
 local now = os.time()
 if text ~= __last_status or now - __last_status_at >= 1 then
  sys.toast(text, 0)
  __last_status = text
  __last_status_at = now
 end
end

local function isTimeout()
 return (os.time() - SCRIPT_START_AT) >= MAX_RUNTIME_SEC
end

local function checkTimeout()
 if isTimeout() then
  status("Da qua 3h, dung script")
  return true
 end
 return false
end

local function findImage(img, sim, x1, y1, x2, y2)
 sim = sim or 85
 x1 = x1 or 0
 y1 = y1 or 0
 x2 = x2 or 750
 y2 = y2 or 1334

 local x, y = screen.find_image(img, sim, x1, y1, x2, y2)
 if x ~= -1 then
  return true, x, y
 end
 return false, -1, -1
end

local function getEventEntryState()
 local color = screen.get_color(130, 84)
 if color == 0xffd452 then
  return "ready", color
 end
 if color == 0xffffff then
  return "not_ready", color
 end
 return "unknown", color
end

local function findClaimButton()
 return findImage(CLAIM_IMG, 85, 0, 120, 750, 1230)
end

local function findCheckByAnyImage()
 local ok, x, y = findImage(CHECK_IMG_1, 85, 0, 120, 750, 1230)
 if ok then return true, x, y, 1 end
 ok, x, y = findImage(CHECK_IMG_2, 85, 0, 120, 750, 1230)
 if ok then return true, x, y, 2 end
 ok, x, y = findImage(CHECK_IMG_3, 85, 0, 120, 750, 1230)
 if ok then return true, x, y, 3 end
 return false, -1, -1, 0
end

local function isCheckInGoodZone(y)
 return y >= GOOD_Y_MIN and y <= GOOD_Y_MAX
end

local function adjustCheckToBetterPosition(x, y)
 if not x or not y or x < 0 or y < 0 then
  local ok
  ok, x, y = findCheckByAnyImage()
  if not ok then
   return false, -1, -1
  end
 end

 if isCheckInGoodZone(y) then
  status("Khung claim video dang o vi tri dep, khong can keo")
  return true, x, y
 end

 local holdX = x + 18
 local holdY = y + 18
 local endY = TARGET_Y
 local direction = "up"

 if y < GOOD_Y_MIN then
  direction = "down"
  endY = TARGET_Y + 40
 elseif y > GOOD_Y_MAX then
  direction = "up"
  endY = TARGET_Y
 else
  return true, x, y
 end

 local distance = math.abs(holdY - endY)
 if distance < 80 then
  return true, x, y
 end

 if distance > 220 then
  if direction == "up" then
   endY = holdY - 220
  else
   endY = holdY + 220
  end
 end

 if endY < 260 then endY = 260 end
 if endY > 980 then endY = 980 end

 status("Dang giu va keo khung claim video ve vung giua")
 touch.down(1, holdX, holdY)
 sys.msleep(140)

 local currentY = holdY
 local step = 18
 while math.abs(currentY - endY) > step do
  if checkTimeout() then
   touch.up(1)
   return false, -1, -1
  end
  if direction == "up" then
   currentY = currentY - step
   if currentY < endY then currentY = endY end
  else
   currentY = currentY + step
   if currentY > endY then currentY = endY end
  end
  touch.move(1, holdX, currentY)
  sys.msleep(28)
 end

 touch.move(1, holdX, endY)
 sys.msleep(180)
 touch.up(1)
 sys.msleep(450)

 local okAfter, xAfter, yAfter = findCheckByAnyImage()
 if okAfter then
  if isCheckInGoodZone(yAfter) then
   status("Da dua khung claim video vao vung giua")
  else
   status("Da keo dung huong, se canh tiep")
  end
  return true, xAfter, yAfter
 end

 return true, x, y
end

local function swipeUpSearchOneRound()
 if checkTimeout() then return "timeout", -1, -1 end

 local x = 375
 local yStart = 1180
 local yEnd = 180
 local step = 54
 local delay = 54

 touch.down(1, x, yStart)
 sys.msleep(120)

 local y = yStart
 local tick = 0
 while y > yEnd do
  if checkTimeout() then
   touch.up(1)
   return "timeout", -1, -1
  end

  y = y - step
  touch.move(1, x, y)
  tick = tick + 1

  if tick % 4 == 0 then
   local ok, fx, fy = findCheckByAnyImage()
   if ok then
    touch.up(1)
    status("Da thay khung claim video")
    return true, fx, fy
   end
  end

  sys.msleep(delay)
 end

 touch.up(1)
 sys.msleep(120)
 return false, -1, -1
end

local function swipeDownSearchOneRound()
 if checkTimeout() then return "timeout", -1, -1 end

 local x = 375
 local yStart = 260
 local yEnd = 1220
 local step = 54
 local delay = 34

 touch.down(1, x, yStart)
 sys.msleep(120)

 local y = yStart
 local tick = 0
 while y < yEnd do
  if checkTimeout() then
   touch.up(1)
   return "timeout", -1, -1
  end

  y = y + step
  touch.move(1, x, y)
  tick = tick + 1

  if tick % 4 == 0 then
   local ok, fx, fy = findCheckByAnyImage()
   if ok then
    touch.up(1)
    status("Da thay khung claim video")
    return true, fx, fy
   end
  end

  sys.msleep(delay)
 end

 touch.up(1)
 sys.msleep(120)
 return false, -1, -1
end

local function localRecoverSwipeUp()
 if checkTimeout() then return false end

 touch.down(1, 375, 1020)
 sys.msleep(70)
 local y = 1020
 while y > 760 do
  if checkTimeout() then
   touch.up(1)
   return false
  end
  y = y - 12
  touch.move(1, 375, y)
  sys.msleep(12)
 end
 touch.up(1)
 sys.msleep(180)
 return true
end

local function localRecoverSwipeDown()
 if checkTimeout() then return false end

 touch.down(1, 375, 760)
 sys.msleep(70)
 local y = 760
 while y < 1020 do
  if checkTimeout() then
   touch.up(1)
   return false
  end
  y = y + 12
  touch.move(1, 375, y)
  sys.msleep(12)
 end
 touch.up(1)
 sys.msleep(180)
 return true
end

local function recoverCheckNearby()
 if checkTimeout() then return "timeout", -1, -1 end

 status("Mat khung claim video, dang tim lai quanh vi tri hien tai")
 for round = 1, 4 do
  if checkTimeout() then return "timeout", -1, -1 end

  local ok, x, y = findCheckByAnyImage()
  if ok then
   status("Da tim lai khung claim video")
   return true, x, y
  end

  if not localRecoverSwipeUp() then
   return "timeout", -1, -1
  end
  ok, x, y = findCheckByAnyImage()
  if ok then
   status("Da tim lai khung claim video")
   return true, x, y
  end

  if not localRecoverSwipeDown() then
   return "timeout", -1, -1
  end
  ok, x, y = findCheckByAnyImage()
  if ok then
   status("Da tim lai khung claim video")
   return true, x, y
  end
 end

 return false, -1, -1
end

local function waitAndTapClaimLoop()
 local lastTapAt = 0
 local tapCount = 0
 local lastRetryLogAt = -1
 local seenClaimAtLeastOnce = false
 local missingClaimSince = nil

 status("Khung event da o giua, cho 5s truoc khi bat dau tap ClaimVd48")
 for remain = 5, 1, -1 do
  if checkTimeout() then return false end
  status("Con " .. tostring(remain) .. "s nua se bat dau tim va tap ClaimVd48")
  sys.msleep(1000)
 end

 while true do
  if checkTimeout() then return false end

  local okCheck, _, yCheck = findCheckByAnyImage()
  if not okCheck then
   status("Dang canh ClaimVd48 nhung da mat khung event")
   return "lost"
  end

  if not isCheckInGoodZone(yCheck) then
   status("Dang canh ClaimVd48 nhung khung event da lech khoi vung giua")
   return "bad_zone"
  end

  local okClaim, claimX, claimY = findClaimButton()
  if okClaim then
   seenClaimAtLeastOnce = true
   missingClaimSince = nil
   local nowTs = os.time()
   if lastTapAt == 0 or (nowTs - lastTapAt) >= CLAIM_RETRY_SEC then
    tapCount = tapCount + 1
    status("Da thay ClaimVd48 tai " .. tostring(claimX) .. "," .. tostring(claimY) .. " | bam lan " .. tostring(tapCount))
    touch.tap(claimX + 10, claimY + 10)
    lastTapAt = nowTs
    lastRetryLogAt = nowTs
    status("Da bam ClaimVd48 lan " .. tostring(tapCount) .. ", cho 10s roi quet lai ket qua")

    sys.msleep(10000)
    if checkTimeout() then return false end

    local okCheckAfter, _, yCheckAfter = findCheckByAnyImage()
    if not okCheckAfter then
      status("Sau khi bam ClaimVd48, da mat khung event")
      return "lost"
    end
    if not isCheckInGoodZone(yCheckAfter) then
      status("Sau khi bam ClaimVd48, khung event da lech khoi vung giua")
      return "bad_zone"
    end

    local okClaimAfter = findClaimButton()
    if okClaimAfter then
      status("Sau 10s, ClaimVd48 van con -> xem nhu bam chua thanh cong, se tiep tuc chu ky tap")
    else
      status("Sau 10s, khong con thay ClaimVd48 -> tam coi la da an, nhung se canh tiep de xac nhan")
      missingClaimSince = os.time()
    end
   else
    local remain = CLAIM_RETRY_SEC - (nowTs - lastTapAt)
    if nowTs ~= lastRetryLogAt then
     status("ClaimVd48 van con, cho " .. tostring(remain) .. "s de tap lai")
     lastRetryLogAt = nowTs
    end
   end
  else
   if not seenClaimAtLeastOnce then
    status("Chua tung thay ClaimVd48.PNG, tiep tuc quet lai")
   else
    if missingClaimSince == nil then
     missingClaimSince = os.time()
     status("ClaimVd48 dang mat, bat dau canh them de xac nhan")
    elseif (os.time() - missingClaimSince) >= 10 then
     status("ClaimVd48 da mat on dinh 10s -> xem nhu hoan thanh")
     return true
    else
     status("ClaimVd48 van dang mat, cho xac nhan them " .. tostring(10 - (os.time() - missingClaimSince)) .. "s")
    end
   end
  end

  sys.msleep(1000)
 end
end

local function runSearchFlow(maxCycles)
 maxCycles = maxCycles or 30
 local lockedOnCheck = false
 local direction = "up"
 local roundsInDirection = 0
 local maxRoundsOneDirection = 12

 for cycle = 1, maxCycles do
  if checkTimeout() then
   return false
  end

  if not lockedOnCheck then
   local okCheck, xCheck, yCheck = findCheckByAnyImage()
   if okCheck then
    lockedOnCheck = true
    local adjusted = adjustCheckToBetterPosition(xCheck, yCheck)
    if not adjusted then
     lockedOnCheck = false
    else
     status("Da thay khung claim video, dung cuon")
    end
   else
    if direction == "up" then
     okCheck, xCheck, yCheck = swipeUpSearchOneRound()
    else
     okCheck, xCheck, yCheck = swipeDownSearchOneRound()
    end

    if okCheck == "timeout" then
     return false
    end

    roundsInDirection = roundsInDirection + 1

    if okCheck then
      lockedOnCheck = true
      local adjusted = adjustCheckToBetterPosition(xCheck, yCheck)
      if not adjusted then
       lockedOnCheck = false
      end
    else
      if roundsInDirection >= maxRoundsOneDirection then
       if direction == "up" then
        direction = "down"
        status("Da cuon het huong len, dao chieu tim xuong")
       else
        direction = "up"
        status("Da cuon het huong xuong, dao chieu tim len")
       end
       roundsInDirection = 0
      end
    end
   end
  end

  if lockedOnCheck then
   local result = waitAndTapClaimLoop()
   if result == true then
    return true
   elseif result == "lost" or result == "bad_zone" then
    local okRecover = recoverCheckNearby()
    if okRecover == "timeout" then
     return false
    elseif okRecover then
     local okAgain, xAgain, yAgain = findCheckByAnyImage()
     if okAgain then
      local adjusted = adjustCheckToBetterPosition(xAgain, yAgain)
      if adjusted then
       lockedOnCheck = true
      else
       lockedOnCheck = false
      end
     else
      lockedOnCheck = false
     end
    else
     lockedOnCheck = false
    end
   else
    return false
   end
  end
 end

 status("Khong hoan thanh duoc Claimvideo48")
 return false
end

while (device.is_screen_locked()) do
 device.unlock_screen()
 sys.msleep(1000)
end

status("Bat dau Claimvideo48")
status("Buoc 1: tat TikTok cu")
pcall(app.quit, "com.ss.iphone.ugc.Ame")
sys.msleep(1200)
status("Buoc 2: mo lai TikTok")
app.run("com.ss.iphone.ugc.Ame")
status("Buoc 3: cho 20s roi bam vi tri 674,1280")
sys.msleep(20000)
touch.tap(674, 1280)
status("Buoc 3 OK: da bam vi tri 674,1280")

status("Buoc 4: dang cho event o diem mau 130,84")
local eventWaitStart = os.time()
local tappedRetryAfter60 = false
local lastEventWaitLog = -1
while true do
 if checkTimeout() then return true end
 local state, color = getEventEntryState()
 if state == "ready" then
  status("Buoc 4: da co event tai 130,84 voi mau 0x" .. string.format("%06x", color))
  touch.tap(130, 84)
  status("Buoc 4 OK: da bam vi tri 130,84 de vao event")
  break
 end

 local waited = os.time() - eventWaitStart
 local waitBucket = math.floor(waited / 5)
 if waitBucket ~= lastEventWaitLog then
  lastEventWaitLog = waitBucket
  if state == "not_ready" then
   status("Buoc 4: chua co event, diem 130,84 dang la 0x" .. string.format("%06x", color) .. ", da cho " .. tostring(waited) .. "s")
  else
   status("Buoc 4: mau tai 130,84 hien la 0x" .. string.format("%06x", color) .. ", da cho " .. tostring(waited) .. "s")
  end
 end

 if not tappedRetryAfter60 and waited >= 60 then
  touch.tap(674, 1280)
  status("Buoc 4: sau 60s chua co event, bam lai vi tri 674,1280")
  tappedRetryAfter60 = true
 end

 sys.msleep(1000)
end

status("Buoc 5: cho 10s truoc khi tim khung claim video")
sys.msleep(10000)
status("Buoc 6: bat dau tim khung claim video")
runSearchFlow(30)
status("Claimvideo48 da chay xong")
return true
