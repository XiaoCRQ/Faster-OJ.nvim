local uv = vim.uv or vim.loop
local handler = require("faster-oj.server.http.handler")
local M = {}

local server = nil
local clients = {}

local function log(...)
	if M.config.debug then
		print("[FOJ][http]", ...)
	end
end

local function remove_client(c)
	for i, v in ipairs(clients) do
		if v == c then
			table.remove(clients, i)
			return
		end
	end
end

function M.setup(cfg)
	M.config = cfg or {}
end

function M.is_open()
	return server ~= nil
end

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
