---@module "faster-oj"

---@type table
local http_server = require("faster-oj.server.http.server")

---@type table
local ws_server = require("faster-oj.server.websocket.server")

---@type table
local module = require("faster-oj.module.init")

---@type table
local solve = require("faster-oj.module.solve")

---@type table
local default_config = require("faster-oj.default")

---@class FOJ
---@field config FOJ.Config 当前生效的全局配置
---@field setup fun(opts?:FOJ.Config) 初始化插件
---@field start fun(mod?:"http"|"ws"|"all") 启动服务器
---@field stop fun(mod?:"http"|"ws"|"all") 停止服务器
local M = {}

---@type FOJ.Config
M.config = default_config.config

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ]", ...)
	end
end

---@param opts? FOJ.Config 用户自定义配置（会与默认配置深度合并）
function M.setup(opts)
	---@type FOJ.Config
	M.config = vim.tbl_deep_extend("force", M.config or {}, opts or {})

	solve.setup(M.config)
	module.setup(M.config)
	ws_server.setup(M.config)
	http_server.setup(M.config)

	vim.api.nvim_create_user_command("FOJ", function(params)
		---@type string
		local raw = params.args or ""

		-- 没有任何参数
		if raw == "" then
			if M.config and M.config.work_dir then
				vim.fn.chdir(M.config.work_dir)
			end
			M.start()
			return
		end

		---@type string[]
		local args = vim.split(raw, "%s+", { trimempty = true })

		local cmd = args[1] and args[1]:lower()
		local sub_cmd = nil

		if #args > 1 then
			sub_cmd = table.concat(vim.list_slice(args, 2), " ")
		end

		if cmd == "start" then
			M.start(sub_cmd)
		elseif cmd == "stop" then
			M.stop(sub_cmd)
		elseif cmd == "submit" then
			module.submit({
				wait_for_connection = ws_server.wait_for_connection,
				send = ws_server.send,
			})
		elseif cmd == "run" then
			module.run()
		elseif cmd == "show" then
			module.show()
		elseif cmd == "close" then
			module.close()
		elseif cmd == "edit" then
			module.edit()
		elseif cmd == "solve" then
			if not sub_cmd then
				solve.solve()
			elseif sub_cmd == "back" then
				solve.solve_back()
			else
				print("[FOJ] Unknown solve command:", sub_cmd)
			end
		else
			print("[FOJ] Unknown command:", cmd)
		end
	end, { nargs = "*" })
end

---@param mod? "http"|"ws"|"all"
function M.start(mod)
	mod = mod or M.config.server_mod

	log("Starting server mode:", mod)

	if mod == "http" then
		http_server.start()
		log("The HTTP server has been turned ON")
	elseif mod == "ws" then
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

---@param mod? "http"|"ws"|"all"
function M.stop(mod)
	mod = mod or M.config.server_mod

	log("Stopping server mode:", mod)

	if mod == "http" then
		http_server.stop()
		log("The HTTP server has been turned OFF")
	elseif mod == "ws" then
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
