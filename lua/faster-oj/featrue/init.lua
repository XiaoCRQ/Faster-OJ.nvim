local M = {}
local ui = require("lua.faster-oj.featrue.ui")
local run = require("lua.faster-oj.featrue.run")
local file = require("faster-oj.featrue.file")

local function log(...)
	if M.config.server_debug then
		print("[FOJ][featrue]", ...)
	end
end

function M.init(cfg)
	M.config = cfg
	ui.init(cfg)
	run.init(cfg)
	file.init(cfg)
end

function M.submit(send)
	file.submit(send)
end

function M.run() end

return M
