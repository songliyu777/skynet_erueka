local skynet = require "skynet"
local logger = require "logger"
local json = require 'cjson.safe'
local stringtool = require "tools.stringtool"

-- 类似spring的ribbon功能用于负载均衡
local service_name = ...
local cmd = {}

function cmd.update(data)
    local t = json.decode(data)
    print(string.coventable(t))
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = cmd[command]
        if f ~= nil then
            f(...)
        else
            logger.error("no command: ", command)
        end
    end)
end)