local skynet = require "skynet"

---@type invoke
local invoke = {}

invoke.requestwebservice = function(service_name, method, api, cmd, session, protobuf)
    local webclient, ipAdr, port = skynet.call(".eureka", "lua", "getwebclient", "server-logic")
    if webclient ~= nil then
        local host = ("http://%s:%d/%s"):format(ipAdr, port, api)
        --local isok, response, info = skynet.call(webclient, "lua", "request", method, host, headers, nil, body)
    end
end

return invoke
