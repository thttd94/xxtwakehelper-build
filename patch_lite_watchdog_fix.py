from pathlib import Path
p=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\lua\Group3_NuoiPhoi_tiktok_lite.lua')
s=p.read_text(encoding='utf-8')
s=s.replace('''function quitApp(bundleId, label)
 phase("Quit " .. label)
 app.quit(bundleId)
 waitPhase(1500)
end

function openApp(bundleId, label, waitMs)
 phase("Mở " .. label)
 app.run(bundleId)
 waitPhase(waitMs or 4000)
end
''','''function setActiveApp(kind, url)
 ACTIVE_APP = kind or ""
 ACTIVE_URL = url or ACTIVE_URL or ""
end
function clearActiveApp(kind)
 if kind == nil or ACTIVE_APP == kind then ACTIVE_APP = "" end
end
function ensureActiveApp()
 if ACTIVE_APP == "tiktok_lite" then
  if app.front_bid() ~= TIKTOK_LITE_BUNDLE then app.run(TIKTOK_LITE_BUNDLE) sys.msleep(2500) end
 elseif ACTIVE_APP == "appmanager" then
  if app.front_bid() ~= APPMANAGER_BUNDLE then app.run(APPMANAGER_BUNDLE) sys.msleep(2500) end
 elseif ACTIVE_APP == "appstore" then
  if app.front_bid() ~= APPSTORE_BUNDLE then
   if ACTIVE_URL and ACTIVE_URL ~= "" then app.open_url(ACTIVE_URL) else app.run(APPSTORE_BUNDLE) end
   sys.msleep(4000)
  end
 end
end
function quitApp(bundleId, label)
 phase("Quit " .. label)
 if bundleId == TIKTOK_LITE_BUNDLE then clearActiveApp("tiktok_lite") end
 if bundleId == APPMANAGER_BUNDLE then clearActiveApp("appmanager") end
 app.quit(bundleId)
 waitPhase(1500)
end

function openApp(bundleId, label, waitMs)
 phase("Mở " .. label)
 if bundleId == APPMANAGER_BUNDLE then setActiveApp("appmanager") end
 if bundleId == TIKTOK_LITE_BUNDLE then setActiveApp("tiktok_lite") end
 app.run(bundleId)
 waitPhase(waitMs or 4000)
end
''')
s=s.replace('''function openTikTokLiteStore()
 phase("Mở link TikTok Lite")
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(8000)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(5000)
end
''','''function openTikTokLiteStore()
 phase("Mở link TikTok Lite")
 setActiveApp("appstore", TIKTOK_LITE_STORE_URL)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(8000)
 app.open_url(TIKTOK_LITE_STORE_URL)
 waitPhase(5000)
end
''')
p.write_text(s,encoding='utf-8')
print('fixed lite active app hooks')
