local skynet = require "skynet"
local stringtool = require "tools.stringtool"
--local sprotoloader = require "sprotoloader"
local max_client = 1024

skynet.start(function()
	skynet.error("Server start pid:".. skynet.getpid())
	--skynet.uniqueservice("protoloader")
	-- if not skynet.getenv "daemon" then
	-- 	local console = skynet.newservice("console")
	-- end
	skynet.newservice("debug_console",8888)
	-- skynet.newservice("simpledb")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 6000,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.error("Watchdog listen on", 6000)
	local httpservice = skynet.newservice("httpservice")
	local eureka = skynet.newservice("eureka")
	skynet.exit()
end)
