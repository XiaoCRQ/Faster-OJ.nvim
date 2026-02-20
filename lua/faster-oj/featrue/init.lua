local M = {}
local ui = require("faster-oj.featrue.ui")
local utils = require("faster-oj.featrue.utils")
local runner = require("faster-oj.featrue.run")
local file = require("faster-oj.featrue.file")

local function log(...)
	if M.config.debug then
		print("[FOJ][featrue]", ...)
	end
end

function M.setup(cfg)
	M.config = cfg or {}
	ui.setup(cfg)
	utils.setup(cfg)
	runner.setup(cfg)
	file.setup(cfg)
end

function M.submit(send)
	file.submit(send)
end

function M.run()
	local file_path = utils.get_file_path()
	local json = utils.get_json_file()
	local tests = {}

	vim.cmd("write")

	if json == nil then
		log("No problem data ...")
		return
	end

	ui.updata(#json.tests, tests)

	log("Commencing code testing...")

	runner.compile(file_path, function(success, msg, need)
		if not success then
			print("[FOJ] Compilation Failed:\n" .. msg)
			return
		end
		if need then
			log("Compilation Success!")
		end
		if not ui.is_open() then
			ui.show()
		end
		runner.run(file_path, json, function(res)
			tests[res.test_index] = res
			ui.updata(#json.tests, tests)
		end)
	end)
end

function M.show()
	if ui.is_open() then
		ui.close()
		return
	end
	ui.show()
end

function M.close()
	ui.close()
end

return M
