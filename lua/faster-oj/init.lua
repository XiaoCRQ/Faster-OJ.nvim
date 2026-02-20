-- ================================================================
-- FOJ Main Entry Module
-- ================================================================
-- 负责：
--   1. 加载子模块（HTTP / WebSocket / Feature）
--   2. 管理全局配置
--   3. 提供 setup 初始化入口
--   4. 注册 :FOJ 用户命令
--   5. 控制服务器启动与停止
-- ================================================================

-- -------------------------------
-- 📦 Load Submodules
-- -------------------------------

---@module "faster-oj"

---@type table
local http_server = require("faster-oj.server.http.server")

---@type table
local ws_server = require("faster-oj.server.websocket.server")

---@type table
local featrue = require("faster-oj.featrue.init")

---@type table
local default_config = require("faster-oj.default")

---@class FOJ
---@field config FOJ.Config 当前生效的全局配置
---@field setup fun(opts?:FOJ.Config) 初始化插件
---@field start fun(mod?:"only_http"|"only_ws"|"all") 启动服务器
---@field stop fun(mod?:"only_http"|"only_ws"|"all") 停止服务器
local M = {}

-- ----------------------------------------------------------------
-- 🌐 Global Config
-- ----------------------------------------------------------------

---@type FOJ.Config
M.config = default_config.config

-- ----------------------------------------------------------------
-- 📝 Debug Logger
-- ----------------------------------------------------------------

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ]", ...)
	end
end

-- ----------------------------------------------------------------
-- ⚙️ Setup
-- ----------------------------------------------------------------

---初始化 FOJ 插件
---
---功能：
---  1. 合并用户配置
---  2. 初始化 feature 模块
---  3. 初始化服务器模块
---  4. 注册 :FOJ 用户命令
---
---@param opts? FOJ.Config 用户自定义配置（会与默认配置深度合并）
function M.setup(opts)
	---@type FOJ.Config
	M.config = vim.tbl_deep_extend("force", M.config or {}, opts or {})

	featrue.setup(M.config)
	ws_server.setup(M.config)
	http_server.setup(M.config)

	-- ------------------------------------------------------------
	-- :FOJ Command
	-- ------------------------------------------------------------
	-- 支持：
	--   :FOJ start [mode]
	--   :FOJ stop [mode]
	--   :FOJ submit | sb
	--   :FOJ test | run
	--   :FOJ show
	--   :FOJ close
	-- ------------------------------------------------------------

	vim.api.nvim_create_user_command("FOJ", function(params)
		---@type string[]
		local args = vim.split(params.args or "", "%s+")

		local cmd = args[1] and args[1]:lower() or ""
		local sub_cmd = nil

		if #args > 1 then
			sub_cmd = table.concat(vim.list_slice(args, 2), " ")
		end

		if cmd == "start" then
			M.start(sub_cmd)
		elseif cmd == "stop" then
			M.stop(sub_cmd)
		elseif cmd == "submit" or cmd == "sb" then
			featrue.submit({
				wait_for_connection = ws_server.wait_for_connection,
				send = ws_server.send,
			})
		elseif cmd == "test" or cmd == "run" then
			featrue.run()
		elseif cmd == "show" then
			featrue.show()
		elseif cmd == "close" then
			featrue.close()
		else
			print("[FOJ] Unknown command:", cmd)
		end
	end, { nargs = "*" })
end

-- ----------------------------------------------------------------
-- 🚀 Start Server
-- ----------------------------------------------------------------

---启动服务器
---
---默认模式取自 `config.server_mod`
---
---@param mod? "only_http"|"only_ws"|"all"
function M.start(mod)
	mod = mod or M.config.server_mod

	log("Starting server mode:", mod)

	if mod == "only_http" then
		http_server.start()
		log("The HTTP server has been turned ON")
	elseif mod == "only_ws" then
		ws_server.start()
		log("The WS server has been turned ON")
	elseif mod == "all" then
		http_server.start()
		ws_server.start()
		log("The ALL server has been turned ON")
	else
		error("Invalid server_mod: " .. tostring(mod))
	end
end

-- ----------------------------------------------------------------
-- 🛑 Stop Server
-- ----------------------------------------------------------------

---停止服务器
---
---默认模式取自 `config.server_mod`
---
---@param mod? "only_http"|"only_ws"|"all"
function M.stop(mod)
	mod = mod or M.config.server_mod

	log("Stopping server mode:", mod)

	if mod == "only_http" then
		http_server.stop()
		log("The HTTP server has been turned OFF")
	elseif mod == "only_ws" then
		ws_server.stop()
		log("The WS server has been turned OFF")
	elseif mod == "all" then
		http_server.stop()
		ws_server.stop()
		log("The ALL server has been turned OFF")
	else
		error("Invalid server_mod: " .. tostring(mod))
	end
end

return M
