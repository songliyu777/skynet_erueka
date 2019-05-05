local skynet = require "skynet"
local netpack = require "net.netpack"
require "tools/stringtool"

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec)
        return {}
    end
end

---@type invoke
local invoke = {}

invoke.__VERSION = "1.0.0"

local useragent = "skynet-eureka-client/v1.0.0" .. invoke.__VERSION

invoke.requestwebservice = function(method, service_name, api, cmd, session, protobuf)
    local webclient, ipAdr, port = skynet.call(".eureka", "lua", "getwebclient", service_name)
    if webclient ~= nil then
        local host = ("http://%s:%d%s"):format(ipAdr, port, api)
        local send_pack
        local headers = new_tab(0, 5)
        headers["User-Agent"] = useragent
        headers["host"] = ipAdr .. ":" .. port
        headers["accept"] = "*/*"
        headers["Content-Type"] = "application/octet-stream"
        if protobuf then
            headers["Content-Length"] = 22 + #protobuf
            send_pack = netpack.pack(1, 1, session, protobuf)
        else
            headers["Content-Length"] = 22
            send_pack = netpack.pack(1, 1, session)
        end
        local isok, response, info = skynet.call(webclient, "lua", "request", method, host, headers, nil, send_pack)
        if isok then
            return info.response_code, response
        end
    end
    return nil, "no web client: " .. service_name
end

return invoke
