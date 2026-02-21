---@module "faster-oj.module.submit"

---@type table
local utils = require("faster-oj.module.utils")

---@class FOJ.SubmitModule
---@field config FOJ.Config 当前生效配置
---@field setup fun(cfg:FOJ.Config) 初始化 Submit 模块
---@field submit fun(ws:any) 提交当前文件到服务器
local M = {}

---@param cfg FOJ.Config 用户传入的配置
function M.setup(cfg)
	---@type FOJ.Config
	M.config = cfg
	utils.setup(cfg)
end

---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ][submit]", ...)
	end
end

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

	local json_path = utils.get_json_path()
	local origin = utils.read_json(json_path)
	if not origin or not origin.url then
		log("Missing url in problem json:", json_path)
		return
	end

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

	ws.wait_for_connection(M.config.max_time_out, function()
		ws.send("broadcast " .. tmp_path)
	end)
end

return M
