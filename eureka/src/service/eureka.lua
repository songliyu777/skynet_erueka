local skynet = require "skynet"
local instance = (require "eureka.instance"):new()
local service = require "eureka.service"

local host = "localhost"
local ip = "127.0.0.1"
local name = "skynet-eureka-client"
local port = 8001

local eureka_host = "localhost"
local eureka_port = 17000

instance:setInstanceId(("%s:%s:%s:%d"):format(ip, port, name:upper(), skynet.gethostid()))
instance:setHostName(host):setApp(name:upper()):setStatus("UP")
instance:setIpAddr(ip):setVipAddress(name):setSecureVipAddress(name)
instance:setPort(port, true):setSecurePort(443, false)
instance:setHomePageUrl("http://" .. host .. ":" .. port)
instance:setStatusPageUrl("http://" .. host .. ":" .. port .. "/actuator/info")
instance:setHealthCheckUrl("http://" .. host .. ":" .. port .. "/actuator/health")
instance:setDataCenterInfo("MyOwn", "com.netflix.appinfo.InstanceInfo$DefaultDataCenterInfo")
instance:setLeaseInfo({evictionDurationInSecs = 60})
instance:setMetadata({language = "skynet_lua"})

service:run(
    {
        host = eureka_host,
        port = eureka_port,
        uri = "/eureka",
        timeval = 3000,
        -- auth = {
        --     username = "",
        --     password = ""
        -- }
    },
    instance:export()
)
