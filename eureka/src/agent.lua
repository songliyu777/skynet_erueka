local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local pb = require "pb"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd

assert(pb.loadfile "eureka/proto/test.pb") -- 载入刚才编译的pb文件

function REQUEST:get()
    print("get", self.what)
    local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
    return {result = r}
end

function REQUEST:set()
    print("set", self.what, self.value)
    local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:handshake()
    return {msg = "Welcome to skynet, I will send heartbeat every 5 sec."}
end

function REQUEST:quit()
    skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function request(name, args, response)
    local f = assert(REQUEST[name])
    local r = f(args)
    if response then
        return response(r)
    end
end

local function send_package(pack)
    local package = string.pack(">s2", pack)
    socket.write(client_fd, package)
end

-- <: sets little endian
-- >: sets big endian
-- =: sets native endian
-- ![n]: sets maximum alignment to n (default is native alignment)
-- b: a signed byte (char)
-- B: an unsigned byte (char)
-- h: a signed short (native size)
-- H: an unsigned short (native size)
-- l: a signed long (native size)
-- L: an unsigned long (native size)
-- j: a lua_Integer
-- J: a lua_Unsigned
-- T: a size_t (native size)
-- i[n]: a signed int with n bytes (default is native size)
-- I[n]: an unsigned int with n bytes (default is native size)
-- f: a float (native size)
-- d: a double (native size)
-- n: a lua_Number
-- cn: a fixed-sized string with n bytes
-- z: a zero-terminated string
-- s[n]: a string preceded by its length coded as an unsigned integer with n bytes (default is a size_t)
-- x: one byte of padding
-- Xop: an empty item that aligns according to option op (which is otherwise ignored)
-- ' ': (empty space) ignored

local Test = {
    name = nil,
    password = nil
}

function CMD.send_test(msg)
    local h, v, l, c, s, cmd, session = string.unpack(">BBI4HI4HL", msg)
    local send_pack = nil
    print(h, ":", v, ":", l, ":", c, ":", s, ":", cmd, ":", session)
    if l > 0 then
        --print(require "pb/serpent".block(protobuf))
        local protobuf = string.unpack(">c" .. l, msg, 23)
        local test_msg = assert(pb.decode("Test", protobuf))
		print(test_msg.name, ":", test_msg.password)
		send_pack = string.pack(">BBI4HI4HLc"..l, h, v, l, c, s, cmd, session, protobuf)
    else
        send_pack = string.pack(">BBI4HI4HL", h, v, l, c, s, cmd, session)
    end

    --local data = assert(pb.encode("test", test))

    -- 从二进制数据解析出实际消息
    --local msg = assert(pb.decode("test", data))

    -- 打印消息内容（使用了serpent开源库）

    socket.write(client_fd, send_pack)
end

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function(msg, sz)
        --这里是收到的消息进行处理
        return host:dispatch(msg, sz)
    end,
    dispatch = function(fd, _, type, ...)
        assert(fd == client_fd) -- You can use fd to reply message
        skynet.ignoreret() -- session is fd, don't call skynet.ret
        --skynet.trace()
        if type == "REQUEST" then
            local ok, result = pcall(request, ...)
            if ok then
                if result then
                    send_package(result)
                end
            else
                skynet.error(result)
            end
        else
            assert(type == "RESPONSE")
            error "This example doesn't support request client"
        end
    end
}

function CMD.start(conf)
    local fd = conf.client
    local server = conf.server
    WATCHDOG = conf.watchdog
    -- slot 1,2 set at main.lua
    host = sprotoloader.load(1):host "package"
    send_request = host:attach(sprotoloader.load(2))
    skynet.fork(
        function()
            while true do
                send_package(send_request "heartbeat")
                skynet.sleep(500)
            end
        end
    )

    client_fd = fd
    skynet.call(server, "lua", "forward", fd)
end

function CMD.disconnect()
    -- todo: do something before exit
    --skynet.trace("CMD.disconnect")
    skynet.exit()
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, _, command, ...)
                local f = CMD[command]
                skynet.ret(skynet.pack(f(...)))
            end
        )
    end
)
