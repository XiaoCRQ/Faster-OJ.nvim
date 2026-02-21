---@module "faster-oj.server.ws"

local uv = vim.uv or vim.loop
local M = {}

--- 可选回调函数，收到 stdout 输出时触发
---@type fun(data:string)?
M.on_message = nil
--- 可选回调函数，收到 stderr 输出时触发
---@type fun(data:string)?
M.on_err = nil

---@class FOJWSModule
---@field handle userdata|nil 运行的进程句柄
---@field pipe table 管道表，包含 stdin/stdout/stderr
---@field connections number 当前连接的客户端数量
M.handle = nil
M.pipe = { stdin = nil, stdout = nil, stderr = nil }
M.connections = 0 -- 存储当前连接数

---@private
local function log(...)
	if M.config and M.config.debug then
		print("[FOJ][ws]", ...)
	end
end

---@private
local function get_bin_path()
	-- 获取当前脚本所在目录
	local script_path = debug.getinfo(1).source:sub(2)
	local bin_dir = vim.fn.fnamemodify(script_path, ":p:h")
	local is_windows = vim.fn.has("win32") == 1
	local bin_name = is_windows and "mini-wsbroad.exe" or "mini-wsbroad"
	return bin_dir .. "/" .. bin_name
end

--- 初始化模块
---@param cfg table 配置项
---   cfg.ws_host string WebSocket 服务绑定地址（可选，默认 127.0.0.1）
---   cfg.ws_port number WebSocket 服务端口（可选，默认 10044）
---   cfg.debug boolean 是否打印调试信息
function M.setup(cfg)
	M.config = cfg or {}

	-- 注册自动清理逻辑
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("FOJ_WS_Cleanup", { clear = true }),
		callback = function()
			if M.is_open() then
				if M.pipe.stdin then
					M.pipe.stdin:write("exit\n")
				end
				if M.handle then
					M.handle:kill("sigterm")
				end
			end
		end,
	})
end

--- 检查 WebSocket 服务是否运行
---@return boolean
function M.is_open()
	return M.handle ~= nil
end

-- 启动 WebSocket 服务
function M.start()
	if M.is_open() then
		log("WebSocket server already running")
		return
	end

	local bin_path = get_bin_path()
	local host = M.config.ws_host or "127.0.0.1"
	local port = M.config.ws_port or 10044

	-- 创建管道
	M.pipe.stdin = uv.new_pipe(false)
	M.pipe.stdout = uv.new_pipe(false)
	M.pipe.stderr = uv.new_pipe(false)

	-- 启动进程
	M.handle = uv.spawn(bin_path, {
		args = { host, tostring(port) },
		stdio = { M.pipe.stdin, M.pipe.stdout, M.pipe.stderr },
	}, function(code, signal)
		log("WebSocket server exited", code, signal)
		M.cleanup()
	end)

	if not M.handle then
		error("Failed to start process at: " .. bin_path)
	end

	-- 监听输出流
	M.pipe.stdout:read_start(function(err, data)
		if data then
			-- 解析连接数: [WS] Connected clients: 0
			local count = data:match("%[WS%] Connected clients: (%d+)")
			if count then
				M.connections = tonumber(count)
				log("Updated connections:", M.connections)
			end

			log("[stdout]", data:gsub("\n$", ""))
			if M.on_message then
				M.on_message(data)
			end
		end
	end)

	M.pipe.stderr:read_start(function(err, data)
		if data then
			log("[stderr]", data:gsub("\n$", ""))
			if M.on_err then
				M.on_err(data)
			end
		end
	end)

	log(string.format("WebSocket server starting at ws://%s:%d", host, port))
end

-- 请求连接状态
function M.request_status()
	M.send("status")
end

--- 获取本地缓存的连接数
---@return number
function M.get_connection_count()
	return M.connections
end

-- 停止 WebSocket 服务
function M.stop()
	if not M.is_open() then
		return
	end

	if M.pipe.stdin then
		M.pipe.stdin:write("exit\n")
	end

	local timer = uv.new_timer()
	timer:start(500, 0, function()
		if M.handle then
			M.handle:kill("sigterm")
			M.cleanup()
		end
		timer:stop()
		timer:close()
	end)
end

--- 发送命令到 WebSocket 服务
---@param text string
function M.send(text)
	if M.pipe and M.pipe.stdin then
		M.pipe.stdin:write(text .. "\n")
		log("Sent command:", text)
	else
		log("Cannot send, process not running")
	end
end

function M.cleanup()
	if M.handle then
		M.handle:close()
	end
	M.handle = nil
	for k, p in pairs(M.pipe) do
		if p and not p:is_closing() then
			p:close()
		end
		M.pipe[k] = nil
	end
end

--- 异步等待连接
--- @param timeout_s number 超时时间（秒）
--- @param callback function 成功连接后的回调函数，参数为当前连接数
function M.wait_for_connection(timeout_s, callback)
	if not M.is_open() then
		log("WebSocket server is not running, cancel waiting.")
		return
	end

	local interval = 100 -- 0.1s = 100ms
	local elapsed_ms = 0
	local timeout_ms = timeout_s * 1000
	local timer = uv.new_timer()

	timer:start(0, interval, function()
		M.request_status()
		local count = M.get_connection_count()

		if count > 0 then
			timer:stop()
			timer:close()
			log(string.format("Connection detected: %d. Calling callback.", count))

			-- 使用 vim.schedule 确保回调在 Neovim 主事件循环中执行（安全操作 UI 或 Buffer）
			vim.schedule(function()
				callback(count)
			end)
			return
		end

		elapsed_ms = elapsed_ms + interval
		if elapsed_ms >= timeout_ms then
			timer:stop()
			timer:close()
			print("[FOJ][ws] Unable to connect to the browser.")
			log("Wait for connection timed out.")
		end
	end)
end

return M
