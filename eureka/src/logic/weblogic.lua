local skynet = require "skynet"
local actuator = require "logic.http.actuator"
local logger = require "logger"

local dispatch = {}
for key, value in pairs(actuator) do
    if dispatch[key] ~= nil then
        logger.error(string.format("dispatch[%s] ~= nil : ", key))
    end
    dispatch[key] = value
end
return actuator