local skynet = require "skynet"
local httpserver = require "net.httpserver"
local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec)
        return {}
    end
end

local handler = {}

local mode, protocol = ...
local protocol = protocol or "http"
local ip = skynet.getenv("http_ip") or "0.0.0.0" 
local port = skynet.getenv("http_port") or 80

local dispatch = require "logic.weblogic"
local retheaders = new_tab(0, 1)

if mode == "agent" then
    httpserver.newagent(protocol, handler)
else
    httpserver.start({ip = ip, port = port, protocol = protocol})
end

function handler.dispatch(fd, path, method, headers, query, body)
    local f = dispatch[method..path]
    local code = 404
    local response = "no method:"..method.." in path: "..path;
    if f then
        code, response = f(fd, path, method, headers, query, body)
    end
    retheaders["Content-Type"] = "application/octet-stream"
    return code, response, retheaders
end

return handler