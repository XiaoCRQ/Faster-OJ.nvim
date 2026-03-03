---@module "faster-oj"

---@type table
local http_server = require("faster-oj.server.http.server")
---@type table
local ws_server = require("faster-oj.server.websocket.server")
---@type table
local module = require("faster-oj.module.init")
---@type table
local solve = require("faster-oj.module.solve")
---@type table
local default_config = require("faster-oj.default")

---@class FOJ
---@field config FOJ.Config 当前生效的全局配置
---@field setup fun(opts?:FOJ.Config) 初始化插件
---@field start fun(mod?:"http"|"ws"|"all") 启动服务器
---@field stop fun(mod?:"http"|"ws"|"all") 停止服务器
local M = {}

---@type FOJ.Config
M.config = default_config.config

---Debug 日志输出
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ]", ...)
	end
end

---服务器操作映射表，用于简化 start/stop 逻辑
local SERVER_OPS = {
	http = { start = http_server.start, stop = http_server.stop, name = "HTTP" },
	ws = { start = ws_server.start, stop = ws_server.stop, name = "WS" },
}

---执行服务器状态变更
---@param action "start"|"stop"
---@param mod? "http"|"ws"|"all"
local function handle_server_op(action, mod)
	mod = mod or M.config.server_mod
	log(action:gsub("^%l", string.upper) .. "ing server mode:", mod)

	local target_mods = mod == "all" and { "http", "ws" } or { mod }

	for _, m in ipairs(target_mods) do
		local op = SERVER_OPS[m]
		if op then
			op[action]()
			log(string.format("The %s server has been turned %s", op.name, action == "start" and "ON" or "OFF"))
		elseif mod ~= "all" then
			error("Invalid server_mod: " .. tostring(mod))
		end
	end
end

---@param opts? FOJ.Config 用户自定义配置
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config or {}, opts or {})

	solve.setup(M.config)
	module.setup(M.config)
	ws_server.setup(M.config)
	http_server.setup(M.config)

	---命令处理器映射
	local actions = {
		start = function(sub)
			M.start(sub)
		end,
		stop = function(sub)
			M.stop(sub)
		end,
		run = function()
			module.run(true)
		end,
		test = function()
			module.run(false)
		end,
		show = function()
			module.show()
		end,
		close = function()
			module.close()
		end,
		edit = function()
			module.edit()
		end,
		submit = function()
			module.submit({
				wait_for_connection = ws_server.wait_for_connection,
				send = ws_server.send,
			})
		end,
		solve = function(sub)
			if not sub then
				return solve.solve()
			end
			if sub == "back" then
				return solve.solve_back()
			end
			print("[FOJ] Unknown solve command:", sub)
		end,
	}

	vim.api.nvim_create_user_command("FOJ", function(params)
		local raw = params.args or ""

		-- 没有任何参数：切换工作目录并启动
		if raw == "" then
			if M.config.work_dir then
				vim.fn.chdir(M.config.work_dir)
			end
			return M.start()
		end

		local args = vim.split(raw, "%s+", { trimempty = true })
		local cmd = args[1]:lower()
		local sub_cmd = #args > 1 and table.concat(args, " ", 2) or nil

		if actions[cmd] then
			actions[cmd](sub_cmd)
		else
			print("[FOJ] Unknown command:", cmd)
		end
	end, { nargs = "*" })
end

---@param mod? "http"|"ws"|"all"
function M.start(mod)
	handle_server_op("start", mod)
end

---@param mod? "http"|"ws"|"all"
function M.stop(mod)
	handle_server_op("stop", mod)
end

return M
