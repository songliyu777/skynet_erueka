local skynet = require "skynet"
local logger = require "logger"
local client = require "eureka.client"

local _register, _renew
local eurekaclient, eurekaserver, instance, timeval

_register = function()
    if not eurekaclient then
        local eclient, err = client:new(eurekaserver.host, eurekaserver.port, eurekaserver.uri, eurekaserver.auth)
        eurekaclient = eclient
    end
    if not eurekaclient then
        logger.error(("can not create client instance %s : %s"):format(instance.instance.instanceId, err))
    else
        logger.info("eureka register : ", instance.instance.app)
        local ok, err = eurekaclient:register(instance.instance.app, instance);
        if not ok then
            logger.error(("can not register instance %s : %s"):format(instance.instance.instanceId, err))
        else
            return skynet.timeout(timeval, _heartbeat)
        end
    end
    skynet.timeout(500, _register)
end

_heartbeat = function()
    local eurekaclient = eurekaclient
    local ok, err = eurekaclient:heartBeat(instance.instance.app, instance.instance.instanceId)
    if not ok then
        logger.error(("failed to _heartbeat instance %s : %s"):format(instance.instance.instanceId, err))
        --心跳失败，重新注册
        _register()
    else
        skynet.timeout(timeval, _heartbeat)
    end
end

local _M = {
    ["_VERSION"] = "1.0.0"
}

function _M.run(self, _eurekaserver, _instance)
    instance = _instance
    eurekaserver = _eurekaserver
    timeval = tonumber(eurekaserver.timeval) or 30
    skynet.start(
        function()
            _register()
        end
    )
end

return _M
