local skynet = require "skynet"
local logger = require "logger"
local json = require "cjson"
local util = require "cjson.util"
local stringtool = require "tools.stringtool"

-- 类似spring的ribbon功能用于负载均衡
local service_name = ...
local cmd = {}

local feignclients = {} --feignclients[server.instanceId] = client = { server = {}, service = {1,2,3}}
local max_client = 1
local balance_index = 1

function cmd.update(data)
    local root = json.decode(data)
    local instances = root.application.instance
    local servers = {}
    --更新现有的服务
    for index, value in ipairs(instances) do
        local server = {}
        server.instanceId = value.instanceId
        server.ipAddr = value.ipAddr
        server.port = tonumber(value.port["$"])
        servers[server.instanceId] = server
        local client = feignclients[server.instanceId]
        if client ~= nil then
            client.server = server
        else
            logger.debug(string.format("add:[%s][%s:%d]", server.instanceId, server.ipAddr, server.port))
            client = {}
            client.server = server
            client.service = {}
            for i = 1, max_client do
                client.service[i] = skynet.newservice("webclient")
            end
            feignclients[server.instanceId] = client
        end
    end
    --移除已经不存在的服务
    for key, value in pairs(feignclients) do
        if servers[key] == nil then
            logger.debug(string.format("remove:[%s][%s:%d]", key, value.server.ipAddr, value.server.port))
            local client = feignclients[key]
            feignclients[key] = nil
            for index, value in ipairs(client.service) do
                skynet.send(value, "lua", "close")
            end
        end
    end
end

function cmd.getwebclient()
    for key, value in pairs(feignclients) do
        local ipAddr = value.server.ipAddr
        local port = value.server.port
        local webclient = value.service[balance_index]
        return webclient, ipAddr, port
    end
    return nil
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(session, source, command, ...)
                local f = cmd[command]
                if f ~= nil then
                    skynet.ret(skynet.pack(f(...)))
                else
                    logger.error("no command: ", command)
                end
            end
        )
    end
)
