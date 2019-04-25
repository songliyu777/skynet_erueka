local skynet = require "skynet"
local i = (require 'eureka.instance'):new()
local w = require 'eureka.workerservice'

local host = 'localhost'
local ip = '127.0.0.1'
local name = 'skynet-eureka-client'

i:setInstanceId(('%s:%s:%d'):format(ip, name:upper(), skynet.getpid()))
i:setHostName(host):setApp(name:upper()):setStatus('UP')
i:setIpAddr(ip):setVipAddress(name):setSecureVipAddress(name)
i:setPort(8001, true):setSecurePort(443, false)
i:setHomePageUrl('http://' .. host):setStatusPageUrl('http://' .. host .. '/status'):setHealthCheckUrl('http://' .. host .. '/check')
i:setDataCenterInfo('MyOwn', 'com.netflix.appinfo.InstanceInfo$DefaultDataCenterInfo')
i:setLeaseInfo({ evictionDurationInSecs = 60 })
i:setMetadata({ language = 'ngx_lua' })

w:run({
    host = '127.0.0.1',
    port = 17000,
    uri  = '/eureka/v2',
    timeval = 30,
    auth = {
        username = '',
        password = '',
    },
}, i:export())