-- ================================================================
-- FOJ Feature Module
-- ================================================================
-- 负责：
--   1. 管理 UI 显示
--   2. 管理测试用例运行
--   3. 提交代码
--   4. 提供模块统一入口 setup
-- ================================================================

---@module "faster-oj.featrue.init"

---@type table
local ui = require("faster-oj.featrue.ui")

---@type table
local utils = require("faster-oj.featrue.utils")

---@type table
local runner = require("faster-oj.featrue.run")

---@type table
local submit = require("faster-oj.featrue.submit")

---@class FOJ.FeatureModule
---@field config FOJ.Config 当前生效配置
---@field setup fun(cfg:FOJ.Config) 初始化 Feature 模块
---@field submit fun(send:any) 提交当前代码
---@field run fun() 编译并运行当前文件
---@field show fun() 打开 UI
---@field close fun() 关闭 UI
local M = {}

-- ----------------------------------------------------------------
-- 📝 Debug Logger
-- ----------------------------------------------------------------

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ][featrue]", ...)
	end
end

-- ----------------------------------------------------------------
-- ⚙️ Setup
-- ----------------------------------------------------------------

---初始化 Feature 模块
---
---功能：
---  1. 保存全局配置
---  2. 初始化子模块（UI / Utils / Runner / Submit）
---
---@param cfg FOJ.Config 用户传入配置
function M.setup(cfg)
	---@type FOJ.Config
	M.config = cfg or {}

	ui.setup(cfg)
	utils.setup(cfg)
	runner.setup(cfg)
	submit.setup(cfg)
end

-- ----------------------------------------------------------------
-- 🚀 Submit
-- ----------------------------------------------------------------

---提交当前编辑文件
---
---@param send any WebSocket 对象，直接传给 submit 模块
function M.submit(send)
	submit.submit(send)
end

-- ----------------------------------------------------------------
-- ▶ Run / Test
-- ----------------------------------------------------------------

---编译并运行当前编辑文件
---
---功能：
---  1. 写入当前缓冲区
---  2. 获取题目 JSON 和测试用例
---  3. 调用 runner.compile 编译
---  4. 编译成功后调用 runner.run 运行测试用例
---  5. 更新 UI 测试结果
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

-- ----------------------------------------------------------------
-- 🖥 UI Control
-- ----------------------------------------------------------------

---切换 UI 显示状态
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

return M
