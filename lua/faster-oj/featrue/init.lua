local M = {}
local ui = require("faster-oj.featrue.ui")
local runner = require("faster-oj.featrue.run")
local file = require("faster-oj.featrue.file")

local function log(...)
	if M.config.server_debug then
		print("[FOJ][featrue]", ...)
	end
end

function M.setup(cfg)
	M.config = cfg or {}
	ui.setup(cfg)
	runner.setup(cfg)
	file.setup(cfg)
end

function M.submit(send)
	file.submit(send)
end

function M.run()
	local file_path = file.get_file_path()
	local json = file.get_json_file()
	local windowss = ui.new()
	local testcases = {}

	print("[FOJ] Commencing code testing...")

	runner.compile(file_path, function(success, msg, need)
		if not success then
			print("[FOJ] Compilation Failed:\n" .. msg)
			return
		end
		if need then
			print("[FOJ] Compilation Success!")
		end
		M.show()
		runner.run(file_path, json, function(res)
			testcases[res.test_index] = res
		end)
	end)
end

function M.show()
	ui.show()
end

function M.close()
	ui.close()
end

function M.renew()
	ui.erase()
	ui.new()
end

return M
