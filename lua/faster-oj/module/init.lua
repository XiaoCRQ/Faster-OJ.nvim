---@module "faster-oj.module.init"

---@type table
local ui = require("faster-oj.module.tests_ui")

---@type table
local utils = require("faster-oj.module.utils")

---@type table
local runner = require("faster-oj.module.run")

---@type table
local submit = require("faster-oj.module.submit")

---@type table
local manage = require("faster-oj.module.tests_manage_ui")

---@class FOJ.moduleModule
---@field config FOJ.Config 当前生效配置
---@field setup fun(cfg:FOJ.Config) 初始化 module 模块
---@field submit fun(send:any) 提交当前代码
---@field run fun() 编译并运行当前文件
---@field show fun() 打开 UI
---@field close fun() 关闭 UI
local M = {}

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ][module]", ...)
	end
end

---@param cfg FOJ.Config 用户传入配置
function M.setup(cfg)
	---@type FOJ.Config
	M.config = cfg or {}

	ui.setup(cfg)
	utils.setup(cfg)
	runner.setup(cfg)
	submit.setup(cfg)
	manage.setup(cfg)
end

---@param send any WebSocket 对象，直接传给 submit 模块
function M.submit(send)
	submit.submit(send)
end

function M.run()
	---@type string
	local file_path = utils.get_file_path()

	---@type table|nil
	local json = utils.get_json_file()

	---@type table
	local tests = {}

	vim.cmd("write") -- 保存当前缓冲区

	if json == nil then
		log("No problem data ...")
		return
	end

	ui.update(#json.tests, tests)

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
			ui.update(#json.tests, tests)
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

---关闭 UI
function M.close()
	ui.close()
end

function M.manage()
	if manage.is_open() then
		manage.close()
		return
	end
	manage.manage()
end

return M
