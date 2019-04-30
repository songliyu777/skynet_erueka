local skynet = require "skynet"
require "skynet.manager"

local max_client = skynet.getenv("max_client")
local tcp_port = skynet.getenv("tcp_port")
local udp_port = skynet.getenv("udp_port")
local debug_port = skynet.getenv("debug_port")

---@class game
local game = {}
local cmd = {}

game.init = function()
    local address = skynet.self()
    skynet.name(".main", address)

    skynet.uniqueservice("debug_console", debug_port)
    skynet.name(".debug_console", address)

    address = skynet.uniqueservice("httpservice")
    skynet.name(".httpservice", address)

    address = skynet.uniqueservice("eureka")
    skynet.name(".eureka", address)

    address = skynet.uniqueservice("watchdog")
    skynet.name(".watchdog", address)
    skynet.call(
        address,
        "lua",
        "start",
        {
            port = tcp_port,
            maxclient = max_client,
            nodelay = true
        }
    )
end

game.start = function()
    skynet.dispatch(
        "lua",
        function(session, source, cmd, subcmd, ...)
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    )
end

return game
