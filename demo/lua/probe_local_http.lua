local sys = require("sys")
local file = require("file")

local out = {}
local function log(s)
  out[#out + 1] = tostring(s)
end

log('probe start')

local function try_require(name)
  local ok, mod = pcall(require, name)
  log('require ' .. name .. ' => ' .. tostring(ok) .. ' / ' .. tostring(type(mod)))
  return ok, mod
end

local ok_http, http = try_require('http')
local ok_socket_http, socket_http = try_require('socket.http')
local ok_socket, socket = try_require('socket')
local ok_https, https = try_require('ssl.https')
local ok_json, json = try_require('json')

if ok_socket_http and socket_http then
  local ok, a, b, c = pcall(function()
    return socket_http.request('http://127.0.0.1:46952/deviceinfo')
  end)
  log('socket.http.request => ' .. tostring(ok) .. ' | ' .. tostring(a) .. ' | ' .. tostring(b) .. ' | ' .. tostring(c))
end

if ok_http and http and type(http.request) == 'function' then
  local ok, res = pcall(function()
    return http.request('http://127.0.0.1:46952/deviceinfo')
  end)
  log('http.request => ' .. tostring(ok) .. ' | ' .. tostring(res))
end

if ok_socket and socket and type(socket.tcp) == 'function' then
  local ok, res = pcall(function()
    local tcp = socket.tcp()
    tcp:settimeout(2)
    local c1, e1 = tcp:connect('127.0.0.1', 46952)
    if not c1 then return 'connect_fail:' .. tostring(e1) end
    local s1, e2 = tcp:send('POST /deviceinfo HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 2\r\nContent-Type: application/json\r\n\r\n{}')
    local body, e3 = tcp:receive('*a')
    tcp:close()
    return 'send=' .. tostring(s1) .. ' recv=' .. tostring(body or e3)
  end)
  log('raw socket => ' .. tostring(ok) .. ' | ' .. tostring(res))
end

local target = '/var/mobile/Media/1ferver/log/probe_local_http.txt'
local txt = table.concat(out, '\n')
local f = io.open(target, 'w')
if f then
  f:write(txt)
  f:close()
end
sys.toast('probe_local_http done')
return true
