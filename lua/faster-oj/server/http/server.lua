local uv = vim.loop
local handler = require("faster-oj.server.http.handler")
local M = {}

local server = nil
local clients = {}

local function log(...)
	if M.config.server_debug then
		print("[faster-oj][http]", ...)
	end
end

function M.start(cfg)
	M.config = cfg

	if server then
		log("HTTP server already running")
		return
	end

	local host = M.config.http_host
	local port = M.config.http_port
	log(host .. port)

	server = uv.new_tcp()
	server:bind(host, port)
	server:listen(128, function(err)
		assert(not err, err)

		local client = uv.new_tcp()
		server:accept(client)
		table.insert(clients, client)

		local buffer = ""

		client:read_start(function(err, data)
			assert(not err, err)
			if data then
				buffer = buffer .. data
			else
				-- 客户端关闭，尝试解析完整请求
				local json_str = buffer:match("{.*}")
				if json_str then
					-- 使用异步安全的 vim.schedule
					vim.schedule(function()
						local ok, decoded = pcall(vim.json.decode, json_str)
						if ok and decoded then
							handler.handle(decoded, M.config)
						else
							log("Failed to decode JSON")
						end
					end)
				else
					log("No JSON found in request")
				end

				-- 返回 200 OK
				client:write("HTTP/1.1 200 OK\r\nContent-Length:0\r\n\r\n")
				client:shutdown()
				client:close()
			end
		end)
	end)

	print("[faster-oj][http] HTTP server listening on " .. host .. ":" .. port)
end

function M.stop()
	if server then
		for _, c in ipairs(clients) do
			c:shutdown()
			c:close()
		end
		clients = {}
		server:close()
		server = nil
		print("[faster-oj][http] stopped")
	end
end

return M
