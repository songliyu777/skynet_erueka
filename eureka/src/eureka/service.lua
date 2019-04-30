local skynet = require "skynet"
local logger = require "logger"
local client = require "eureka.client"
local stringtools = require "tools.stringtool"

local eurekaclient, eurekaserver, instance, timeval
local _getapp, _register, _heartbeat
local remote_services = {} --{ service_name = ribben_instance}

_getapp = function(appid)
    local ok, err = eurekaclient:getApp(appid)
    if not ok then
        logger.error(("failed to _getapp %s : %s"):format(appid, err))
    else
        local ribbon = remote_services[appid]
        if (ribbon == nil) then
            logger.error(("no ribbon instance %s"):format(appid))
        end
        skynet.send(ribbon, "lua", "update", err)
    end
end

_heartbeat = function()
    local ok, err = eurekaclient:heartBeat(instance.instance.app, instance.instance.instanceId)
    if not ok then
        logger.error(("failed to _heartbeat instance %s : %s"):format(instance.instance.instanceId, err))
        --心跳失败，重新注册
        _register()
    else
        skynet.timeout(timeval, _heartbeat)
        for key, value in pairs(remote_services) do
            _getapp(key)
        end
    end
end

_register = function()
    if not eurekaclient then
        local eclient, err = client:new(eurekaserver.host, eurekaserver.port, eurekaserver.uri, eurekaserver.auth)
        eurekaclient = eclient
    end
    if not eurekaclient then
        logger.error(("can not create client instance %s : %s"):format(instance.instance.instanceId, err))
    else
        logger.info("eureka register : ", instance.instance.app)
        local ok, err = eurekaclient:register(instance.instance.app, instance)
        if not ok then
            logger.error(("can not register instance %s : %s"):format(instance.instance.instanceId, err))
        else
            return skynet.timeout(timeval, _heartbeat)
        end
    end
    skynet.timeout(500, _register)
end

local _M = {
    ["_VERSION"] = "1.0.0"
}

function _M.register_remote_services(self, service_name)
    if remote_services[service_name] == nil then
        logger.info("register remote service:", service_name)
        remote_services[service_name] = skynet.newservice("eureka/ribbon", service_name)
    end
end

function _M.run(self, _eurekaserver, _instance)
    instance = _instance
    eurekaserver = _eurekaserver
    timeval = tonumber(eurekaserver.timeval) or 3000
    skynet.start(
        function()
            local services = string.split(eurekaserver.services, ",")
            for index, value in ipairs(services) do
                self:register_remote_services(value)
            end
            _register()
            skynet.dispatch(
                "lua",
                function(session, source, cmd, subcmd, ...)
                    local f = assert(_M[cmd])
                    skynet.ret(skynet.pack(f(subcmd, ...)))
                end
            )
        end
    )
end

return _M
