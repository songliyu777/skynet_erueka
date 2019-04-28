local skynet = require "skynet"
local instance = (require "eureka.instance"):new()
local service = require "eureka.service"

local ip = skynet.getenv("http_ip") or "0.0.0.0" 
local name = skynet.getenv("register_name") or "skynet-eureka-client"
local port = skynet.getenv("http_port") or 80
local eureka_host = skynet.getenv("eureka_host") or "localhost"
local eureka_port = skynet.getenv("eureka_port") or 17000

instance:setInstanceId(("%s:%s:%s:%d"):format(ip, port, name:lower(), skynet.gethostid()))
instance:setHostName(ip):setApp(name:lower()):setStatus("UP")
instance:setIpAddr(ip):setVipAddress(name):setSecureVipAddress(name)
instance:setPort(port, true):setSecurePort(443, false)
instance:setHomePageUrl("http://" .. ip .. ":" .. port)
instance:setStatusPageUrl("http://" .. ip .. ":" .. port .. "/actuator/info")
instance:setHealthCheckUrl("http://" .. ip .. ":" .. port .. "/actuator/health")
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
