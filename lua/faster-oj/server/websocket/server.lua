local uv = vim.uv or vim.loop
local M = {}
M.handle = nil
M.pipe = {
	stdin = nil,
	stdout = nil,
	stderr = nil,
}

local function log(...)
	if M.config and M.config.server_debug then
		print("[FOJ][ws]", ...)
	end
end

function M.setup(cfg)
	M.config = cfg or {}
end

function M.is_open()
	if M.handle then
		return true
	end
	return false
end

-- 启动 WebSocket 服务
function M.start()
	if M.is_open() then
		log("WebSocket server already running")
		return
	end

	local host = M.config.ws_host or "127.0.0.1"
	local port = M.config.ws_port or 10044

	-- 创建管道
	M.pipe.stdin = uv.new_pipe(false)
	M.pipe.stdout = uv.new_pipe(false)
	M.pipe.stderr = uv.new_pipe(false)

	-- 启动进程
	M.handle = uv.spawn("mini-wsbroad", {
		args = { host, tostring(port) },
		stdio = { M.pipe.stdin, M.pipe.stdout, M.pipe.stderr },
	}, function(code, signal)
		log("WebSocket server exited with code:", code, "signal:", signal)
		-- 清理
		if M.handle then
			M.handle:close()
		end
		M.handle = nil
		if M.pipe.stdin then
			M.pipe.stdin:close()
		end
		if M.pipe.stdout then
			M.pipe.stdout:close()
		end
		if M.pipe.stderr then
			M.pipe.stderr:close()
		end
		M.pipe.stdin, M.pipe.stdout, M.pipe.stderr = nil, nil, nil
	end)

	if not M.handle then
		error("Failed to start WebSocket server process")
	end

	M.pipe.stdout:read_start(function(err, data)
		if data then
			log("[stdout]", data:gsub("\n$", ""))
			M.on_message(data)
		end
	end)

	M.pipe.stderr:read_start(function(err, data)
		if data then
			log("[stderr]", data:gsub("\n$", ""))
			M.on_err(data)
		end
	end)

	-- 启动服务器
	M.send("server on\n")
	log(string.format("WebSocket server starting at ws://%s:%d", host, port))
end

-- 停止 WebSocket 服务
function M.stop()
	if not M.is_open() then
		log("WebSocket server not running")
		return
	end

	local exited = false
	local timer = uv.new_timer()
	timer:start(3000, 0, function()
		if M.handle and not exited then
			log("WebSocket server did not exit in 3s, force kill")
			M.handle:kill("sigterm")
			exited = true
		end
		timer:stop()
		timer:close()
	end)

	if M.pipe.stdin then
		M.pipe.stdin:write("exit\n")
	end
end

function M.send(text)
	if not M.pipe or not M.pipe.stdin then
		log("Cannot send, stdin_pipe not ready")
		return
	end
	M.pipe.stdin:write(text .. "\n")
	log("Sent to server:", text)
end

function M.on_message(msg)
	log("Received message:", msg)
	-- TODO: 在这里解析并处理消息
end

function M.on_err(msg)
	log("Received message:", msg)
	-- TODO: 在这里解析并处理消息
end

return M
