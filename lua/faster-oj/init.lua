local M = {}

-- 默认配置
M.config = {
	http_host = "127.0.0.1",
	http_port = 10043,
	ws_host = "127.0.0.1",
	ws_port = 10044,
	server_debug = false,
	server_mod = "only_ws", -- only_http | only_ws | all
	json_dir = "Problem",
}

local function log(...)
	if M.config.server_debug then
		print("[faster-oj]", ...)
	end
end

-- -------------------------------
-- 加载子模块
-- -------------------------------
local http_server = require("faster-oj.server.http.server")
local ws_server = require("faster-oj.server.websocket.server")

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
			else
				M.start(sub_cmd)
			end
		elseif cmd == "websocket" or cmd == "ws" then
			if #args > 1 then
				-- 去掉首尾空格和多余引号
				local sub_cmd = table.concat(vim.list_slice(args, 2), " ")
				sub_cmd = sub_cmd:gsub("^[\"']+", ""):gsub("[\"']+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
				ws_server.send(sub_cmd)
			else
				print("[FOJ] Missing websocket command")
			end
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
	elseif mod == "only_ws" then
		ws_server.start(M.config)
	elseif mod == "all" then
		http_server.start(M.config)
		ws_server.start(M.config)
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
	elseif mod == "only_ws" then
		ws_server.stop()
	elseif mod == "all" then
		http_server.stop()
		ws_server.stop()
	else
		error("Invalid server_mod: " .. tostring(mod))
	end
end

return M
