-- ================================================================
-- FOJ Feature: Submit Module
-- ================================================================
-- 负责：
--   1. 获取当前编辑文件
--   2. 检测语言类型
--   3. 读取题目 JSON 配置
--   4. 构建提交 JSON
--   5. 调用 WebSocket 发送提交数据
-- ================================================================

---@module "faster-oj.featrue.submit"

---@type table
local utils = require("faster-oj.featrue.utils")

---@class FOJ.SubmitModule
---@field config FOJ.Config 当前生效配置
---@field setup fun(cfg:FOJ.Config) 初始化 Submit 模块
---@field submit fun(ws:any) 提交当前文件到服务器
local M = {}

-- ----------------------------------------------------------------
-- ⚙️ Setup
-- ----------------------------------------------------------------

---初始化 Submit 模块
---
---功能：
---  1. 保存全局配置
---  2. 初始化 utils 模块
---
---@param cfg FOJ.Config 用户传入的配置
function M.setup(cfg)
	---@type FOJ.Config
	M.config = cfg
	utils.setup(cfg)
end

-- ----------------------------------------------------------------
-- 📝 Debug Logger
-- ----------------------------------------------------------------

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ][submit]", ...)
	end
end

-- ----------------------------------------------------------------
-- 🚀 Submit Function
-- ----------------------------------------------------------------

---提交当前编辑文件
---
---功能：
---  1. 获取当前文件路径
---  2. 检测文件语言
---  3. 读取题目 JSON 获取 URL
---  4. 生成提交 JSON 文件
---  5. 调用 WebSocket 广播提交
---
---@param ws table WebSocket 对象，需要提供：
---             - wait_for_connection(timeout:number, callback:fun())
---             - send(data:string)
function M.submit(ws)
	---@type string
	local file_path = utils.get_file_path()
	if file_path == "" then
		log("No active file")
		return
	end

	-- -------------------------------
	-- 代码混淆（可选）
	-- -------------------------------
	if M.config.code_obfuscator then
		local cmd = M.config.code_obfuscator
		-- TODO: 实现实际混淆逻辑
		-- local os_code = cmd.file_path
		-- local vars = utils.get_vars(file_path)
		-- local exec = utils.expand(cmd.exec, vars)
		-- local args = {}
		-- for _, a in ipairs(cmd.args or {}) do
		--     table.insert(args, utils.expand(a, vars))
		-- end
	end

	-- -------------------------------
	-- 读取源代码
	-- -------------------------------
	local code = utils.read_file(file_path)
	if not code then
		log("Failed to read current file:", file_path)
		return
	end

	local ext = vim.fn.fnamemodify(file_path, ":e")
	if ext == "" then
		log("No file extension:", file_path)
		return
	end

	---@type string
	local language = utils.detect_language(ext)

	-- -------------------------------
	-- 读取题目 JSON
	-- -------------------------------
	local json_path = utils.get_json_path()
	local origin = utils.read_json(json_path)
	if not origin or not origin.url then
		log("Missing url in problem json:", json_path)
		return
	end

	-- -------------------------------
	-- 构建提交数据
	-- -------------------------------
	local submit_data = {
		language = language,
		code = code,
		url = origin.url,
	}

	---@type string
	local tmp_path = M.config.json_dir .. "/tmp.json"
	if not utils.write_json(tmp_path, submit_data) then
		log("Failed to write tmp.json")
		return
	end

	log("Submit JSON generated:", tmp_path)

	-- -------------------------------
	-- 通过 WebSocket 提交
	-- -------------------------------
	ws.wait_for_connection(M.config.max_time_out, function()
		ws.send("broadcast " .. tmp_path)
	end)
end

return M
