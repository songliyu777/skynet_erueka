local skynet = require "skynet"

---@type invoke
local invoke = {}

invoke.requestwebservice = function(method, service_name, api, cmd, session, protobuf)
    local webclient, ipAdr, port = skynet.call(".eureka", "lua", "getwebclient", "server-logic")
    if webclient ~= nil then
        local host = ("http://%s:%d/%s"):format(ipAdr, port, api)
        local send_pack
        local head = 0x11
        local version = 0x1
        local checksum = 0
        local serial = 0xfffe
        if protobuf then
            send_pack = string.pack(">BBI4HI4HLc" .. #protobuf, head, version, #protobuf, checksum, serial, cmd, session, protobuf)
        else
            send_pack = string.pack(">BBI4HI4HL", head, version, 0, checksum, serial, cmd, session)
        end
        local isok, response, info = skynet.call(webclient, "lua", "request", method, host, headers, nil, body)
    end
end

return invoke
