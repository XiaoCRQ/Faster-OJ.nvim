---@module "faster-oj.server.ws"

local uv = vim.uv or vim.loop
local notify = require("faster-oj.module.notify")
local M = {}
local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1

---@type fun(data:string)?
M.on_message = nil
---@type fun(data:string)?
M.on_err = nil

M.handle = nil
M.pipe = { stdin = nil, stdout = nil, stderr = nil }
M.connections = 0

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][ws][%s] %s: %s", level, func, msg))
	end
end

---获取平台对应的 mini-wsbroad 二进制路径
local function get_bin_path()
	local script_path = debug.getinfo(1).source:sub(2)
	local bin_dir = vim.fn.fnamemodify(script_path, ":p:h")
	local bin_name
	if is_mac then
		bin_name = "mini-wsbroad-macos"
	elseif is_win then
		bin_name = "mini-wsbroad-windows.exe"
	else
		bin_name = "mini-wsbroad-linux"
	end
	return bin_dir .. "/" .. bin_name
end

function M.setup(cfg)
	M.config = cfg or {}

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

---@return boolean
function M.is_open()
	return M.handle ~= nil
end

function M.start()
	if M.is_open() then
		log("WARN", "start", "Already running")
		return
	end

	local bin_path = get_bin_path()
	local host = M.config.ws_host or "127.0.0.1"
	local port = M.config.ws_port or 10044

	M.pipe.stdin = uv.new_pipe(false)
	M.pipe.stdout = uv.new_pipe(false)
	M.pipe.stderr = uv.new_pipe(false)

	M.handle = uv.spawn(bin_path, {
		args = { host, tostring(port) },
		stdio = { M.pipe.stdin, M.pipe.stdout, M.pipe.stderr },
	}, function(code, signal)
		log("INFO", "spawn", string.format("Exited code=%d signal=%d", code, signal))
		M.cleanup()
	end)

	if not M.handle then
		log("ERROR", "start", "Spawn failed: " .. bin_path)
		return
	end

	M.pipe.stdout:read_start(function(_, data)
		if data then
			local count = data:match("%[WS%] Connected clients: (%d+)")
			if count then
				local new_count = tonumber(count)
				local old_count = M.connections
				M.connections = new_count
				log("INFO", "stdout", "Connected clients: " .. M.connections)

				if new_count > old_count then
					vim.schedule(function()
						notify.show("Browser connected", "DONE")
					end)
				elseif new_count < old_count then
					vim.schedule(function()
						notify.show("Browser disconnected", "WARN")
					end)
				end
			end
			if M.on_message then
				M.on_message(data)
			end
		end
	end)

	M.pipe.stderr:read_start(function(_, data)
		if data then
			log("WARN", "stderr", data:gsub("\n$", ""))
			if M.on_err then
				M.on_err(data)
			end
		end
	end)

	log("INFO", "start", string.format("ws://%s:%d", host, port))
end

function M.request_status()
	M.send("status")
end

---@return number
function M.get_connection_count()
	return M.connections
end

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

---@param text string
function M.send(text)
	if M.pipe and M.pipe.stdin then
		M.pipe.stdin:write(text .. "\n")
		log("INFO", "send", text)
	else
		log("WARN", "send", "Process not running")
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

---异步等待浏览器连接
---@param timeout_s number 超时 (秒)
---@param callback fun(count:number)
function M.wait_for_connection(timeout_s, callback)
	if not M.is_open() then
		log("WARN", "wait_for_connection", "Server not running")
		return
	end

	local interval = 100
	local elapsed_ms = 0
	local timeout_ms = timeout_s * 1000
	local timer = uv.new_timer()

	timer:start(0, interval, function()
		M.request_status()
		local count = M.get_connection_count()

		if count > 0 then
			timer:stop()
			timer:close()
			log("INFO", "wait_for_connection", "Detected " .. count .. " client(s)")
			vim.schedule(function()
				callback(count)
			end)
			return
		end

		elapsed_ms = elapsed_ms + interval
		if elapsed_ms >= timeout_ms then
			timer:stop()
			timer:close()
			log("WARN", "wait_for_connection", "Timed out")
		end
	end)
end

return M
