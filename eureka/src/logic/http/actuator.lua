local skynet = require "skynet"

local dispatch = {}

dispatch["GET/actuator/info"] = function (fd, path, method, headers, query, body)
    return 200, nil
end

return dispatch
