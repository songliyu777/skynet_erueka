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
        local call = function(app, instance)
            return eurekaclient:register(app, instance)
        end
        local ok, err = pcall(call, instance.instance.app, instance)
        if not ok then
            logger.error(("can not register instance %s : %s"):format(instance.instance.instanceId, err))
        else
            return skynet.timeout(timeval, _heartbeat)
        end
    end
    --skynet.timeout(500, _register)
end

_heartbeat = function()
    print("_heartbeat")
    local eurekaclient = eurekaclient
    local call = function(app, instanceId)
        return eurekaclient:heartBeat(app, instanceId)
    end
    local ok, err = pcall(call, instance.instance.app, instance.instance.instanceId)
    if not ok then
        logger.error(("failed to renew instance %s : %s"):format(instance.instance.instanceId, err))
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
