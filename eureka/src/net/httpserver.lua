local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local logger = require "logger"
local table = table
local string = string

local httpserver = {}

function httpserver.newagent(protocol, handler)
    local function response(id, write, ...)
        local ok, err = httpd.write_response(write, ...)
        if not ok then
            -- if err == sockethelper.socket_error , that means socket closed.
            skynet.error(string.format("fd = %d, %s", id, err))
        end
    end

    local SSLCTX_SERVER = nil
    local function gen_interface(protocol, fd)
        if protocol == "http" then
            return {
                init = nil,
                close = nil,
                read = sockethelper.readfunc(fd),
                write = sockethelper.writefunc(fd)
            }
        elseif protocol == "https" then
            local tls = require "http.tlshelper"
            if not SSLCTX_SERVER then
                SSLCTX_SERVER = tls.newctx()
                -- gen cert and key
                -- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
                local certfile = skynet.getenv("certfile") or "./server-cert.pem"
                local keyfile = skynet.getenv("keyfile") or "./server-key.pem"
                print(certfile, keyfile)
                SSLCTX_SERVER:set_cert(certfile, keyfile)
            end
            local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
            return {
                init = tls.init_responsefunc(fd, tls_ctx),
                close = tls.closefunc(tls_ctx),
                read = tls.readfunc(fd, tls_ctx),
                write = tls.writefunc(fd, tls_ctx)
            }
        else
            error(string.format("Invalid protocol: %s", protocol))
        end
    end

    skynet.start(
        function()
            skynet.dispatch(
                "lua",
                function(_, _, id)
                    socket.start(id)
                    local interface = gen_interface(protocol, id)
                    if interface.init then
                        interface.init()
                    end
                    -- limit request body size to 8192 (you can pass nil to unlimit)
                    local code, url, method, headers, body = httpd.read_request(interface.read, 8192)
                    if code then
                        if code ~= 200 then
                            response(id, interface.write, code)
                        else
                            local path, query = urllib.parse(url)
                            if query then
                                query = urllib.parse_query(query)
                            end
                            code, body, headers = handler.dispatch(id, path, method, headers, query, body)
                            response(id, interface.write, code, body, headers)
                        end
                    else
                        if url == sockethelper.socket_error then
                            skynet.error("socket closed")
                        else
                            skynet.error(url)
                        end
                    end
                    socket.close(id)
                    if interface.close then
                        interface.close()
                    end
                end
            )
        end
    )
end

function httpserver.start(conf)
    skynet.start(
        function()
            local agent = {}
            local protocol = "http"
            for i = 1, 20 do
                agent[i] = skynet.newservice(SERVICE_NAME, "agent", conf.protocol)
            end
            local balance = 1
            local id = socket.listen(conf.ip, conf.port)
            logger.info(string.format("Httpserver Listen %s port %d protocol:%s", conf.ip, conf.port, conf.protocol))
            socket.start(
                id,
                function(id, addr)
                    logger.debug(string.format("%s connected, pass it to agent :%08x %s", addr, agent[balance], id))
                    skynet.send(agent[balance], "lua", id)
                    balance = balance + 1
                    if balance > #agent then
                        balance = 1
                    end
                end
            )
        end
    )
end

return httpserver
