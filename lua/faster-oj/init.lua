---@module "faster-oj"

local http_server = require("faster-oj.server.http.server")
local ws_server = require("faster-oj.server.websocket.server")
local module = require("faster-oj.module.init")
local solve = require("faster-oj.module.solve")
local default_config = require("faster-oj.default")

---@class FOJ
---@field config FOJ.Config
---@field setup fun(opts?:FOJ.Config)
---@field start fun(mod?:"http"|"ws"|"all")
---@field stop fun(mod?:"http"|"ws"|"all")
local M = {}

---@type FOJ.Config
M.config = default_config.config

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config.debug then
		print(string.format("[FOJ][%s] %s: %s", level, func, msg))
	end
end

local SERVER_OPS = {
	http = { start = http_server.start, stop = http_server.stop, name = "HTTP" },
	ws = { start = ws_server.start, stop = ws_server.stop, name = "WS" },
}

---@param action "start"|"stop"
---@param mod? "http"|"ws"|"all"
local function handle_server_op(action, mod)
	mod = mod or M.config.server_mod
	log("INFO", "handle_server_op", action .. " server mode: " .. mod)

	local target_mods = mod == "all" and { "http", "ws" } or { mod }

	for _, m in ipairs(target_mods) do
		local op = SERVER_OPS[m]
		if op then
			op[action]()
		elseif mod ~= "all" then
			log("ERROR", "handle_server_op", "Invalid server_mod: " .. tostring(mod))
		end
	end
end

---@param opts? FOJ.Config 用户自定义配置
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	solve.setup(M.config)
	module.setup(M.config)
	ws_server.setup(M.config)
	http_server.setup(M.config)

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
			log("WARN", "FOJ command", "Unknown solve subcommand: " .. sub)
		end,
		erase = function()
			module.erase()
		end,
		find = function(sub)
			module.find(sub)
		end,
		stress = function(sub)
			if not sub or sub == "" then
				return module.stress()
			end
			-- 解析: correct=type:val test=type:val [data=type:raw...] [time=N] [mem=N]
			-- type: path | find | data
			-- data= 含 2 个捕获组 (type 和 raw_value), 值可含空格/\n
			local opts = {}
			-- 提取 data= (贪婪到行尾, 2 捕获组: type 和值)
			local dk, dv = sub:match("data=([%w_]+):(.+)$")
			if dk then
				dv = dv:gsub("\\n", "\n")
				opts.data = { type = dk, data = dv }
				sub = sub:gsub("%s*data=[%w_]+:.+$", "")
			end
			-- 解析 correct=/test= (值可为空, %S* 允许 find: 无后续字符)
			for key, tv, val in sub:gmatch("(%w+)=([%w_]+):(%S*)") do
				if key == "correct" or key == "test" then
					opts[key] = { type = tv, data = val }
				end
			end
			-- time=N, mem=N
			local tl = sub:match("time=(%d+)")
			local ml = sub:match("mem=(%d+)")
			if tl then
				opts.timeLimit = tonumber(tl)
			end
			if ml then
				opts.memoryLimit = tonumber(ml)
			end
			module.stress(opts)
		end,
	}

	vim.api.nvim_create_user_command("FOJ", function(params)
		local raw = params.args or ""

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
			log("WARN", "FOJ command", "Unknown command: " .. cmd)
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
