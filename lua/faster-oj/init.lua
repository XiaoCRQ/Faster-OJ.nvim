local M = {}
local http_server_is_open = false
local ws_server_is_open = false

-- 默认配置
M.config = {
	http_host = "127.0.0.1",
	http_port = 10043,
	ws_host = "127.0.0.1",
	ws_port = 10044,
	server_debug = false,
	server_mod = "all", -- only_http | only_ws | all
	json_dir = ".problem/json",
	code_obfuscator = "",
}

local function log(...)
	if M.config.server_debug then
		print("[FOJ]", ...)
	end
end

-- -------------------------------
-- 加载子模块
-- -------------------------------
local http_server = require("faster-oj.server.http.server")
local ws_server = require("faster-oj.server.websocket.server")
local featrue = require("faster-oj.featrue.init")
-- -------------------------------
-- Setup 配置
-- -------------------------------
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config or {}, opts or {})

	vim.api.nvim_create_user_command("FOJ", function(params)
		local args = vim.split(params.args or "", "%s+")
		local cmd = args[1] and args[1]:lower() or ""
		local sub_cmd = nil
		if #args > 1 then
			sub_cmd = table.concat(vim.list_slice(args, 2), " ")
		end

		if cmd == "server" or cmd == "sv" then
			if sub_cmd and sub_cmd:lower() == "stop" then
				M.stop("all")
			elseif sub_cmd then
				M.start(sub_cmd)
			else
				M.start(nil)
			end
		elseif cmd == "submit" or cmd == "sb" then
			featrue.submit(M.config, ws_server.send)
		else
			print("[FOJ] Unknown command:", cmd)
		end
	end, { nargs = "*" })
end

-- -------------------------------
-- 启动服务器
-- -------------------------------
function M.start(mod)
	mod = mod or M.config.server_mod
	log("Starting server mode:", mod)

	if mod == "only_http" then
		http_server.start(M.config)
		http_server_is_open = true
		print("[FOJ] The HTTP server has been turned ON")
	elseif mod == "only_ws" then
		ws_server.start(M.config)
		ws_server_is_open = true
		print("[FOJ] The WS server has been turned ON")
	elseif mod == "all" then
		if http_server_is_open and ws_server_is_open then
			M.stop("all")
		else
			http_server.start(M.config)
			ws_server.start(M.config)
			http_server_is_open = true
			ws_server_is_open = true
			print("[FOJ] The ALL server has been turned ON")
		end
	else
		error("Invalid server_mod: " .. tostring(mod))
	end
end

-- -------------------------------
-- 停止服务器
-- -------------------------------
function M.stop(mod)
	mod = mod or M.config.server_mod
	log("Stopping server mode:", mod)

	if mod == "only_http" then
		http_server.stop()
		http_server_is_open = false
		print("[FOJ] The HTTP server has been turned OFF")
	elseif mod == "only_ws" then
		ws_server.stop()
		ws_server_is_open = false
		print("[FOJ] The WS server has been turned OFF")
	elseif mod == "all" then
		http_server.stop()
		ws_server.stop()
		http_server_is_open = false
		ws_server_is_open = false
		print("[FOJ] The ALL server has been turned OFF")
	else
		error("Invalid server_mod: " .. tostring(mod))
	end
end

return M
