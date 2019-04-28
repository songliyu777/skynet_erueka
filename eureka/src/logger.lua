local skynet = require "skynet"

---@class logger
local logger = {}
local log_level_define = {debug = 0, info = 1, warning = 2, error = 3}
local log_level = tonumber(skynet.getenv "log_level")

-- 'n': fills in the field name and namewhat;
-- 'S': fills in the fields source, short_src, linedefined, lastlinedefined, and what;
-- 'l': fills in the field currentline;
-- 't': fills in the field istailcall;
-- 'u': fills in the fields nups, nparams, and isvararg;
-- 'f': pushes onto the stack the function that is running at the given level;
-- 'L': pushes onto the stack a table whose indices are the numbers of the lines that are valid on the function.

logger.log = function(level, tag, ...)
    if log_level > level then
        return;
    end
    local dm = debug.getinfo(3, "nSl")
    skynet.error(tag.."[" .. dm.short_src .. " " .. dm.lastlinedefined .. "]", ...)
end

logger.debug = function(...)
    logger.log(log_level_define.debug, "D", ...)
end

logger.info = function(...)
    logger.log(log_level_define.info, "I", ...)
end

logger.warning = function(...)
    logger.log(log_level_define.warning, "W", ...)
end

logger.error = function(...)
    logger.log(log_level_define.error, "E", ...)
end

return logger
