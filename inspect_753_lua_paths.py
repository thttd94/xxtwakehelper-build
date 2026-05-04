import sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / 'demo'))
from xxtouch_openapi_client import XXTouchOpenAPIClient
client=XXTouchOpenAPIClient('http://192.16.5.192:46952', connect_timeout=1.0, read_timeout=5)
script=r'''
local file = require("file")
local OUT = "/var/mobile/Media/1ferver/lua/examples/oc_path_probe.txt"
local function w(s)
  local old = ""
  pcall(function() old = file.reads(OUT) or "" end)
  pcall(function() file.writes(OUT, old .. tostring(s) .. "\n") end)
end
w("PWD_PROBE")
local dirs = {
 "/var/mobile/Media/1ferver/lua",
 "/var/mobile/Media/1ferver/lua/examples",
 "/var/mobile/Media/1ferver/lua/scripts",
 "/var/mobile/Media/1ferver/lua/lib",
 "/var/mobile/Media/1ferver/lua/libs",
}
for _,d in ipairs(dirs) do
 w("DIR="..d)
 local ok, list = pcall(file.list, d)
 if ok and type(list)=="table" then
  for _,n in pairs(list) do
   n=tostring(n)
   if string.find(n,"Group3") or string.find(n,"Nuoi") or string.find(n,"Event") or string.find(n,"Stage") or string.find(n,"floating") then
    w("  "..n)
   end
  end
 else
  w("  NO_LIST")
 end
end
return true
'''
try:
    print(client.spawn(script))
except Exception as e:
    print('spawn_err', repr(str(e)))
time.sleep(1)
try:
    raw=client.download_text_file('/var/mobile/Media/1ferver/lua/examples/oc_path_probe.txt')
    Path('inspect_753_lua_paths.txt').write_text(raw, encoding='utf-8', errors='replace')
    print(repr(raw[:1000]))
except Exception as e:
    print('read_err', repr(str(e)))
