local skynet = require "skynet"
local httpserver = require "net.httpserver"

local handler = {}

local mode, protocol = ...
local protocol = protocol or "http"
local ip = skynet.getenv("http_ip") or "0.0.0.0" 
local port = skynet.getenv("http_port") or 80

if mode == "agent" then
    httpserver.newagent(protocol, handler)
else
    httpserver.start({ip = ip, port = port, protocol = protocol})
end

function handler.message(fd, msg, sz)

end