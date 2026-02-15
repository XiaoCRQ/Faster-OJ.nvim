-- lua/faster-oj/server/websocket/handler.lua
local M = {}

-- 内部日志函数
local function log(...)
	if M.config and M.config.server_debug then
		print("[faster-oj][handler]", ...)
	end
end

function M.init(ws_server, cfg)
	M.server = ws_server
	M.config = cfg or {}
	log("Handler initialized")
end

-- 收到服务器 stdout 消息
function M.on_message(msg)
	log("Received message:", msg)
	-- TODO: 在这里解析并处理消息
end

-- 向服务器 stdin 发送指令
function M.send(text)
	if not M.server or not M.server.stdin_pipe then
		log("Cannot send, stdin_pipe not ready")
		return
	end
	M.server.stdin_pipe:write(text .. "\n")
	log("Sent to server:", text)
end

return M
