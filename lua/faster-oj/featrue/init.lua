local M = {}
local ui = require("faster-oj.featrue.ui")
local run = require("faster-oj.featrue.run")
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

function M.run()
	local file_path = file.get_file_path()
	local json = file.get_json_file()
	run.run(file_path, json, function(results)
		for i, res in ipairs(results) do
			print("Test " .. i, res.state.type)
			print(res.output or "")
		end
	end)
end

return M
