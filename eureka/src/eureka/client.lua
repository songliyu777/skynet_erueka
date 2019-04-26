local skynet = require "skynet"
local crypt = require "skynet.crypt"
local httpc = require "http.httpc"
local json = require 'cjson.safe'
local setmetatable = setmetatable
local tonumber = tonumber
local byte = string.byte
local type = type
local null = nil


local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

---@class _M
local _M = new_tab(0, 16)

_M._VERSION = '0.3.1'

local mt = { __index = _M }

local useragent = 'ngx_lua-EurekaClient/v' .. _M._VERSION

local function request(eurekaclient, method, path, query, body)
    local host = ('http://%s:%s'):format(
        eurekaclient.host,
        eurekaclient.port
    )
    local path = eurekaclient.uri .. path

    local headers = new_tab(0, 5)
    headers['User-Agent'] = useragent
    headers['Connection'] = 'Keep-Alive'
    headers['Accept'] = 'application/json'

    local auth = eurekaclient.auth
    if auth then
        headers['Authorization'] = auth
    end

    if body and 'table' == type(body) then
        local err
        body, err = json.encode(body)
        if not body then
            return nil, 'invalid body : ' .. err
        end
        headers['Content-Type'] = 'application/json'
    end
    local httpc = eurekaclient.httpc
    if not httpc then
        return nil, 'not initialized'
    end

    local statuscode, body = httpc.request(method, host, path, false, headers, body)
	return statuscode, body
end

---@return _M|err
function _M.new(self, host, port, uri, auth)
    if not host or 'string' ~= type(host) or 1 > #host then
        return nil, 'host required'
    end
    local port = tonumber(port) or 80
    if not port or 1 > port or 65535 < port then
        return nil, 'wrong port number'
    end
    local uri = uri or '/eureka'
    if 'string' ~= type(uri) or byte(uri) ~= 47 then -- '/'
        return nil, 'wrong uri prefix'
    end
    local _auth
    if auth and 'table' == type(auth) and auth.username and auth.password then
        _auth = ('Basic %s'):format(
            crypt.base64encode(('%s:%s'):format(
                auth.username,
                auth.password
            ))
        )
    end
    -- local httpc = httpc
    -- if not httpc then
    --     return nil, 'failed to init http client instance : ' .. err
    -- end
    return setmetatable({
        host = host,
        port = port,
        uri = uri,
        auth = _auth,
        httpc = httpc,
    }, mt)
end

function _M.getAllApps(self)
    local res, err = request(self, 'GET', '/apps')
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.getApp(self, appid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    local res, err = request(self, 'GET', '/apps/' .. appid)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.getAppInstance(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'GET', '/apps/' .. appid .. '/' .. instanceid)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.getInstance(self, instanceid)
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'GET', '/instances/' .. instanceid)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.getInstanceByVipAddress(self, vipaddress)
    if not vipaddress or 'string' ~= type(vipaddress) or 1 > #vipaddress then
        return nil, 'vipaddress required'
    end
    local res, err = request(self, 'GET', '/vips/' .. vipaddress)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return res.body
    elseif 404 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.getInstancesBySecureVipAddress(self, vipaddress)
    if not vipaddress or 'string' ~= type(vipaddress) or 1 > #vipaddress then
        return nil, 'vipaddress required'
    end
    local res, err = request(self, 'GET', '/svips/' .. vipaddress)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return res.body
    elseif 404 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.takeInstanceOut(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'PUT', '/apps/' .. appid .. '/' .. instanceid .. '/status', {
        value = 'OUT_OF_SERVICE',
    })
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    elseif 500 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.heartBeat(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local statuscode, body = request(self, 'PUT', '/apps/' .. appid .. '/' .. instanceid)
    if not statuscode then
        return nil, body
    end
    if 200 == statuscode then
        return true, body
    elseif 404 == statuscode then
        return nil, body
    else
        return false, ('status is %d : %s'):format(statuscode, body)
    end
end

function _M.updateAppInstanceMetadata(self, appid, instanceid, metadata)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    if not metadata or 'table' ~= type(metadata) then
        return nil, 'metadata required'
    end
    local res, err = request(self, 'PUT', '/apps/' .. appid .. '/' .. instanceid .. '/metadata', metadata)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    elseif 500 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.deRegister(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'DELETE', '/apps/' .. appid .. '/' .. instanceid)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.putInstanceBack(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'DELETE', '/apps/' .. appid .. '/' .. instanceid .. '/status', {
        value = 'UP',
    })
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    elseif 500 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.removeOverriddenStatus(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'DELETE', '/apps/' .. appid .. '/' .. instanceid .. '/status')
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    elseif 500 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.register(self, appid, instancedata)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instancedata or 'table' ~= type(instancedata) then
        return nil, 'instancedata required'
    end
    local statuscode, body= request(self, 'POST', '/apps/' .. appid, nil, instancedata)
    if not statuscode then
        return nil, body
    end
    if 204 == statuscode then
        return true, body
    else
        return false, ('status is %d : %s'):format(statuscode, body)
    end
end

return _M