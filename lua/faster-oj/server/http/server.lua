-- ================================================================
-- FOJ HTTP Server Module
-- ================================================================
-- 功能：
--   1. 启动一个 TCP HTTP 服务器
--   2. 接收客户端 JSON 请求并转发到 handler 模块
--   3. 自动管理客户端连接
-- ================================================================

---@module "faster-oj.server.http"

local uv = vim.uv or vim.loop
local handler = require("faster-oj.server.http.handler")
local M = {}

---@private
local server = nil -- uv_tcp 服务器实例
---@private
local clients = {} -- uv_tcp 客户端列表

-- ================================================================
-- 🔹 内部日志工具
-- ================================================================
---@private
local function log(...)
	if M.config.debug then
		print("[FOJ][http]", ...)
	end
end

-- ================================================================
-- 🔹 内部工具：移除客户端
-- ================================================================
---@private
---@param c uv_tcp 客户端句柄
local function remove_client(c)
	for i, v in ipairs(clients) do
		if v == c then
			table.remove(clients, i)
			return
		end
	end
end

-- ================================================================
-- 🔹 配置
-- ================================================================
---@param cfg table 配置表
---   cfg.http_host string HTTP 监听地址
---   cfg.http_port integer HTTP 监听端口
---   cfg.debug boolean 是否打印调试日志
function M.setup(cfg)
	M.config = cfg or {}
end

-- ================================================================
-- 🔹 状态查询
-- ================================================================
---@return boolean 是否服务器正在运行
function M.is_open()
	return server ~= nil
end

-- ================================================================
-- 🔹 启动 HTTP Server
-- ================================================================
function M.start()
	if M.is_open() then
		log("HTTP server already running")
		return
	end

	local host = M.config.http_host
	local port = M.config.http_port

	server = uv.new_tcp()
	server:bind(host, port)

	server:listen(128, function(err)
		if err then
			log("Listen error:", err)
			return
		end

		local client = uv.new_tcp()
		server:accept(client)
		table.insert(clients, client)

		local buffer = ""

		client:read_start(function(err, data)
			if err then
				log("Read error:", err)
				return
			end

			if data then
				buffer = buffer .. data
				return
			end

			-- EOF
			local body = buffer:match("\r\n\r\n(.*)")

			if body then
				vim.schedule(function()
					local ok, decoded = pcall(vim.json.decode, body)
					if ok and decoded then
						handler.handle(decoded, M.config)
					else
						log("Failed to decode JSON")
					end
				end)
			else
				log("No body found")
			end

			local response = "HTTP/1.1 200 OK\r\nContent-Length:0\r\n\r\n"

			client:write(response, function()
				if not client:is_closing() then
					client:shutdown(function()
						client:close()
					end)
				end
				remove_client(client)
			end)
		end)
	end)

	log("HTTP server listening on " .. host .. ":" .. port)
end

-- ================================================================
-- 🔹 启动 HTTP Server
-- ================================================================
function M.stop()
	if not M.is_open() then
		return
	end

	for _, c in ipairs(clients) do
		if not c:is_closing() then
			c:shutdown()
			c:close()
		end
	end

	clients = {}

	if not server:is_closing() then
		server:close()
	end

	server = nil
	log("HTTP server stopped")
end

return M
