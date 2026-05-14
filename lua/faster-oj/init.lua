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

	--- 解析引用值: 支持 "...", '...', R"(...)", R"delim(...)delim"
	---@param str string
	---@param pos number
	---@param opts table|nil { eol = boolean }
	---@return string value
	---@return number next_pos
	local function parse_quoted_value(str, pos, opts)
		opts = opts or {}
		if pos > #str then
			return "", pos
		end
		local ch = str:sub(pos, pos)

		if ch == '"' or ch == "'" then
			local close = str:find(ch, pos + 1)
			if close then
				return str:sub(pos + 1, close - 1), close + 1
			end
			return str:sub(pos + 1), #str + 1
		end

		if str:sub(pos, pos + 1) == 'R"' then
			local lparen = str:find("(", pos + 2, true)
			if not lparen then
				local sp = str:find("%s", pos)
				if sp then
					return str:sub(pos, sp - 1), sp
				end
				return str:sub(pos), #str + 1
			end
			local delim = str:sub(pos + 2, lparen - 1)
			local closer = ")" .. delim .. '"'
			local close = str:find(closer, lparen + 1, true)
			if close then
				return str:sub(lparen + 1, close - 1), close + #closer
			end
			return str:sub(lparen + 1), #str + 1
		end

		if opts.eol then
			return str:sub(pos), #str + 1
		else
			local sp = str:find("%s", pos)
			if sp then
				return str:sub(pos, sp - 1), sp
			end
			return str:sub(pos), #str + 1
		end
	end

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
		show = function(sub)
			module.show(sub)
		end,
		close = function(sub)
			module.close(sub)
		end,
		edit = function()
			module.show("edit")
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

			local opts = {}
			local i = 1
			while i <= #sub do
				i = sub:find("%S", i)
				if not i then break end

				local ks, key, typ, after_colon = sub:match("^()(%w+)=([%w_]+):()", i)
				if ks then
					i = after_colon
					if key == "correct" or key == "test" then
						local val, next_pos = parse_quoted_value(sub, i, { eol = false })
						opts[key] = { type = typ, data = val }
						i = next_pos
					elseif key == "data" then
						local val, next_pos = parse_quoted_value(sub, i, { eol = true })
						val = val:gsub("\\n", "\n"):gsub("\\t", "\t")
						opts.data = { type = typ, data = val }
						i = next_pos
					else
						local sp = sub:find("%s", i)
						i = sp or (#sub + 1)
					end
				else
					local tl = sub:match("^time=(%d+)", i)
					if tl then
						opts.timeLimit = tonumber(tl)
						i = i + 5 + #tl
					else
						local ml = sub:match("^mem=(%d+)", i)
						if ml then
							opts.memoryLimit = tonumber(ml)
							i = i + 4 + #ml
						else
							local sp = sub:find("%s", i)
							i = sp or (#sub + 1)
						end
					end
				end
			end
			module.stress(opts)
		end,
	}

	vim.api.nvim_create_user_command("FOJ", function(params)
		local raw = params.args or ""
		log("INFO", "FOJ", "raw args: [" .. raw .. "]")

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
