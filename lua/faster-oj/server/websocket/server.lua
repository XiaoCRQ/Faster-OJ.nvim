local uv = vim.loop
local handler = require("faster-oj.server.websocket.handler")
local M = {}

-- 内部进程和管道句柄
local ws_handle = nil
local stdin_pipe = nil
local stdout_pipe = nil
local stderr_pipe = nil

local function log(...)
	if M.config and M.config.server_debug then
		print("[faster-oj][ws]", ...)
	end
end

-- 启动 WebSocket 服务
function M.start(cfg)
	if ws_handle then
		log("WebSocket server already running")
		return
	end

	M.config = cfg or {}
	local host = M.config.ws_host or "127.0.0.1"
	local port = M.config.ws_port or 10044

	-- 创建管道
	stdin_pipe = uv.new_pipe(false)
	stdout_pipe = uv.new_pipe(false)
	stderr_pipe = uv.new_pipe(false)
	M.stdin_pipe = stdin_pipe
	M.stdout_pipe = stdout_pipe
	M.stderr_pipe = stderr_pipe

	-- 初始化 handler
	handler.init(M, M.config)

	-- 启动进程
	ws_handle = uv.spawn("mini-wsbroad", {
		args = { host, tostring(port) },
		stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
	}, function(code, signal)
		log("WebSocket server exited with code:", code, "signal:", signal)
		-- 清理
		if ws_handle then
			ws_handle:close()
		end
		ws_handle = nil
		if stdin_pipe then
			stdin_pipe:close()
		end
		if stdout_pipe then
			stdout_pipe:close()
		end
		if stderr_pipe then
			stderr_pipe:close()
		end
		stdin_pipe, stdout_pipe, stderr_pipe = nil, nil, nil
	end)

	if not ws_handle then
		error("Failed to start WebSocket server process")
	end

	-- 读取 stdout / stderr 并分发给 handler
	stdout_pipe:read_start(function(err, data)
		if data then
			log("[stdout]", data:gsub("\n$", ""))
			handler.on_message(data)
		end
	end)

	stderr_pipe:read_start(function(err, data)
		if data then
			log("[stderr]", data:gsub("\n$", ""))
		end
	end)

	-- 启动服务器
	handler.send("sv on")
	log(string.format("WebSocket server starting at ws://%s:%d", host, port))
end

function M.send(text)
	handler.send(text)
end

-- 停止 WebSocket 服务
function M.stop()
	if not ws_handle then
		log("WebSocket server not running")
		return
	end

	local exited = false
	local timer = uv.new_timer()
	timer:start(3000, 0, function()
		if ws_handle and not exited then
			log("WebSocket server did not exit in 3s, force kill")
			ws_handle:kill("sigterm")
			exited = true
		end
		timer:stop()
		timer:close()
	end)

	if stdin_pipe then
		handler.send("exit")
	end
end

return M
