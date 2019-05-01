local skynet = require "skynet"

local requestwebservice

---@type serviceinvoke
local serviceinvoke = {}

serviceinvoke.requestwebservice = function(service_name, method, api, cmd, session, protobuf)
    local webclient, ipAdr, port = skynet.call(".eureka", "lua", "getwebclient", "server-logic")
    if webclient ~= nil then
        local host = ("http://%s:%d/%s"):format(ipAdr, port, api)
        --local isok, response, info = skynet.call(webclient, "lua", "request", method, host, headers, nil, body)
    end
end

return serviceinvoke
