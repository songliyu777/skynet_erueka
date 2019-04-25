local skynet = require "skynet"
local logger = require "logger"
local client = require 'eureka.client'

local _register, _renew

local eurekaclient, eurekaserver, instance, timeval

_register = function(premature)
    if premature then
        return
    end
    local err
    eurekaclient, err = client:new(eurekaserver.host, eurekaserver.port, eurekaserver.uri, eurekaserver.auth)
    if not eurekaclient then
        logger.error(('can not create client instance %s : %s'):format(instance.instance.instanceId, err))
    else
        local ok, err = eurekaclient:register(instance.instance.app, instance)
        if not ok then
            logger.error(('can not register instance %s : %s'):format(instance.instance.instanceId, err))
        end
    end
end

_renew = function(premature)
    if premature then
        return eurekaclient:deRegister(instance.instance.app, instance.instance.instanceId)
    end
    local eurekaclient = eurekaclient
    local ok, err = eurekaclient:heartBeat(instance.instance.app, instance.instance.instanceId)
    if not ok or ngx.null == ok then
        ngx.log(ngx.ALERT, ('failed to renew instance %s : %s'):format(instance.instance.instanceId, err))
    else
        ngx.timer.at(timeval, _renew)
    end
end

local _M = {
    ['_VERSION'] = '0.3.1'
}

function _M.run(self, _eurekaserver, _instance)
    instance = _instance
    eurekaserver = _eurekaserver
    --print(_eurekaserver.uri)
    timeval = tonumber(eurekaserver.timeval) or 30
    skynet.start(function()
        _register(false)
        -- function idle()
        --     logger.debug("in 30", skynet.now())
        --     --print("in 30", skynet.now())
        --     skynet.timeout(100, idle)
        -- end
        -- idle()
    end)
    -- ngx.timer.at(0, _register)
    -- ngx.timer.at(timeval, _renew)
end

return _M