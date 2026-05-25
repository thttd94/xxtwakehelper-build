-- Install LidCopy local IPA with TrollStore, then open and verify copy result.
-- Required files on device:
--   /var/mobile/Media/1ferver/ipa/LidCopy.ipa              -- real IPA, ZIP header PK
--   /var/mobile/Media/1ferver/ipa/Cookies.binarycookies    -- source file used by LidCopy v5.0

local IPA = "/var/mobile/Media/1ferver/ipa/LidCopy.ipa"
local SRC = "/var/mobile/Media/1ferver/ipa/Cookies.binarycookies"
local BUNDLE_ID = "com.local.lidcopy"
local OUT = "/var/mobile/Media/1ferver/lua/examples/install_lidcopy_local_trollstore.txt"

local roots = {
 "/var/containers/Bundle/Application",
 "/private/var/containers/Bundle/Application",
}

local lines = {}
local install_ok = false
local opened = false

local function add(s)
 lines[#lines + 1] = tostring(s or "")
end

local function exists(p)
 local f = io.open(p, "rb")
 if f then
  local len = f:seek("end") or -1
  f:close()
  return true, len
 end
 return false, -1
end

local function read_file(p, n)
 local f = io.open(p, "rb")
 if not f then return nil end
 local data = f:read(n or "*a") or ""
 f:close()
 return data
end

local ok_file, file = pcall(require, "file")
local ok_lfs, lfs = pcall(require, "lfs")

local function dirname(p)
 return tostring(p):match("^(.+)/[^/]+$")
end

local function mkdirp(p)
 if not p or p == "" then return end
 local cur = ""
 for part in tostring(p):gmatch("[^/]+") do
  cur = cur .. "/" .. part
  pcall(function()
   if ok_lfs and lfs and lfs.mkdir then lfs.mkdir(cur) end
  end)
  pcall(function()
   if ok_file and file and file.mkdir then file.mkdir(cur) end
  end)
 end
end

local function list(p)
 if ok_file and file and file.list then
  local ok, t = pcall(file.list, p)
  if ok and type(t) == "table" then return t end
 end
 return {}
end

local function shell_quote(s)
 return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function sh(cmd)
 add("$ " .. cmd)
 local f = io.popen(cmd .. " 2>&1")
 local o = ""
 local ok, why, code = nil, nil, nil
 if f then
  o = f:read("*a") or ""
  ok, why, code = f:close()
  o = o .. "\nCLOSE " .. tostring(ok) .. " " .. tostring(why) .. " " .. tostring(code)
 end
 add(o)
 return o, ok, why, code
end

local function find_trollstore_helper()
 for _, root in ipairs(roots) do
  for _, uuid in ipairs(list(root)) do
   local dir = root .. "/" .. tostring(uuid)
   for _, name in ipairs(list(dir)) do
    local appname = tostring(name)
    if appname == "TrollStore.app" then
     local helper = dir .. "/TrollStore.app/trollstorehelper"
     local ok = exists(helper)
     if ok then return dir .. "/TrollStore.app", helper end
    end
   end
  end
 end
 return nil, nil
end

local function plist_has_bundle_id(appdir)
 local data = read_file(appdir .. "/Info.plist")
 if not data then return false, false end
 local has_bid = data:find(BUNDLE_ID, 1, true) ~= nil
 local is_v5_or_newer = has_bid and (data:find("5.", 1, true) ~= nil)
 return has_bid, is_v5_or_newer
end

local function find_lidcopy()
 local found = nil
 local count = 0
 local has_v5 = false
 for _, root in ipairs(roots) do
  for _, uuid in ipairs(list(root)) do
   local dir = root .. "/" .. tostring(uuid)
   for _, name in ipairs(list(dir)) do
    local appname = tostring(name)
    if appname:match("%.app$") then
     local appdir = dir .. "/" .. appname
     local has_bid, is_v5 = plist_has_bundle_id(appdir)
     if appname == "LidCopy.app" or has_bid then
      count = count + 1
      found = appdir
      has_v5 = has_v5 or is_v5
      add("FOUND " .. found)
      add("INFO_HAS_5_OR_NEWER=" .. tostring(is_v5))
     end
    end
   end
  end
 end
 return found, count, has_v5
end

local function save_log()
 local text = table.concat(lines, "\n\n")
 mkdirp(dirname(OUT))
 local f = io.open(OUT, "w")
 if f then
  f:write(text)
  f:close()
 end
 print(text)
end

local function first4_text(p)
 local h = read_file(p, 4)
 if not h then return "nil" end
 local b1 = string.byte(h, 1) or -1
 local b2 = string.byte(h, 2) or -1
 local b3 = string.byte(h, 3) or -1
 local b4 = string.byte(h, 4) or -1
 return tostring(b1) .. "," .. tostring(b2) .. "," .. tostring(b3) .. "," .. tostring(b4)
end

local function is_zip_ipa(p)
 local h = read_file(p, 4)
 if not h then return false end
 return (string.byte(h, 1) or -1) == 80 and (string.byte(h, 2) or -1) == 75
end

local function verify_copy()
 local ok_app, app = pcall(require, "app")
 if not ok_app or not app or not app.data_path then
  add("VERIFY: require app/app.data_path failed")
  return false
 end
 local safari = app.data_path("com.apple.mobilesafari")
 add("SAFARI=" .. tostring(safari))
 if not safari or safari == "" then return false end
 local dst = safari .. "/Library/Cookies/Cookies.binarycookies"
 local bak = safari .. "/Library/Cookies/Cookies.binarycookies_backup"
 local src_ok, src_len = exists(SRC)
 local dst_ok, dst_len = exists(dst)
 local bak_ok, bak_len = exists(bak)
 add("SRC exists=" .. tostring(src_ok) .. " len=" .. tostring(src_len) .. " first4=" .. first4_text(SRC))
 add("DST exists=" .. tostring(dst_ok) .. " len=" .. tostring(dst_len) .. " first4=" .. first4_text(dst))
 add("BAK exists=" .. tostring(bak_ok) .. " len=" .. tostring(bak_len) .. " first4=" .. first4_text(bak))
 return src_ok and dst_ok and src_len == dst_len and src_len > 0
end

add("=== LidCopy v5 local install start ===")
add("IPA=" .. IPA)
add("SRC=" .. SRC)

local ipa_ok, ipa_len = exists(IPA)
add("IPA exists=" .. tostring(ipa_ok) .. " len=" .. tostring(ipa_len) .. " first4=" .. first4_text(IPA))
add("IPA_IS_ZIP=" .. tostring(is_zip_ipa(IPA)))

local src_ok, src_len = exists(SRC)
add("SRC exists=" .. tostring(src_ok) .. " len=" .. tostring(src_len) .. " first4=" .. first4_text(SRC))

local ts, helper = find_trollstore_helper()
add("TROLLSTORE=" .. tostring(ts))
add("HELPER=" .. tostring(helper))

if not ipa_ok or ipa_len <= 50 * 1024 then
 add("ERROR: IPA missing/too small")
elseif not is_zip_ipa(IPA) then
 add("ERROR: IPA invalid header. Expected PK/80,75. Replace LidCopy.ipa with real IPA.")
elseif not src_ok or src_len <= 0 then
 add("ERROR: source Cookies.binarycookies missing/empty")
elseif not helper then
 add("ERROR: TrollStore helper missing")
else
 local out = sh(helper .. " install " .. shell_quote(IPA))
 install_ok = (out and out:find("returning 0", 1, true) ~= nil)
 add("INSTALL_OK=" .. tostring(install_ok))
 sh(helper .. " refresh")
end

local app_path, count, has_v5 = find_lidcopy()
add("COUNT=" .. tostring(count))
add("APP_PATH=" .. tostring(app_path))
add("HAS_V5_OR_NEWER=" .. tostring(has_v5))

local ok_app, app = pcall(require, "app")
if ok_app and app and app.run then
 local ok, res = pcall(app.run, BUNDLE_ID)
 add("app.run " .. BUNDLE_ID .. " pcall=" .. tostring(ok) .. " res=" .. tostring(res))
 opened = ok and (res == 0 or res == true)
else
 add("ERROR: require app/app.run failed")
end
add("OPENED=" .. tostring(opened))

-- wait a moment for LidCopy to perform the copy, then verify destination.
pcall(function()
 local sys = require("sys")
 if sys and sys.msleep then sys.msleep(1500) end
end)

local copied_ok = verify_copy()
add("COPIED_OK=" .. tostring(copied_ok))

save_log()

-- Silent mode: no sys.toast/sys.alert. Check OUT log for result.
return true
