local M = {}
local uv = vim.uv or vim.loop
local IS_WINDOWS = uv.os_uname().version:match("Windows") ~= nil
local COLOR = { red = "\27[31m", green = "\27[32m", reset = "\27[0m" }

--------------------------------------------------
-- 日志
--------------------------------------------------
local function log(...)
	if M.config.server_debug then
		print("[FOJ][run]", ...)
	end
end

--------------------------------------------------
-- 扩展名 → 语言
--------------------------------------------------
local ext_map = {
	c = "c",
	cpp = "cpp",
	cc = "cpp",
	cxx = "cpp",
	py = "python",
	lua = "lua",
	js = "javascript",
	ts = "typescript",
	java = "java",
	rs = "rust",
	go = "go",
}

--------------------------------------------------
-- 工具函数
--------------------------------------------------
local function trim_line(line)
	if #line > M.config.output_max_chars then
		return line:sub(1, M.config.output_max_chars) .. "..."
	end
	return line
end

local function normalize_obscure(str)
	str = str:gsub("[%s]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return str
end

local function char_diff(u, s)
	local res, first_col = {}, nil
	local correct = true
	for i = 1, math.max(#u, #s) do
		local uc, sc = u:sub(i, i), s:sub(i, i)
		if uc == sc then
			table.insert(res, "\27[32m" .. uc .. "\27[0m")
		else
			correct = false
			if not first_col then
				first_col = i
			end
			if uc ~= "" then
				table.insert(res, "\27[31m" .. uc .. "\27[0m")
			end
		end
	end
	return table.concat(res), correct, first_col
end

local function stream_diff(user_lines, std_lines, obscure)
	local res, correct, fl, fc = {}, true, nil, nil
	for i = 1, math.max(#user_lines, #std_lines) do
		if i > M.config.output_max_lines then
			table.insert(res, "...(truncated)")
			break
		end
		local u, user_s = user_lines[i] or "", std_lines[i] or ""
		if obscure then
			u, user_s = normalize_obscure(u), normalize_obscure(user_s)
		end
		if u == user_s then
			table.insert(res, "\27[32m" .. trim_line(u) .. "\27[0m")
		else
			local diff, _, col = char_diff(trim_line(u), trim_line(user_s))
			table.insert(res, diff)
			if correct then
				correct = false
				fl, fc = i, col or 1
			end
		end
	end
	return res, correct, fl, fc
end

--------------------------------------------------
-- 路径安全
--------------------------------------------------
local function path_safe(p)
	return p or ""
end

local function fill_command(cmd, file_path)
	if not cmd then
		return nil
	end
	local fname = vim.fn.fnamemodify(file_path, ":t")
	local fnoext = vim.fn.fnamemodify(file_path, ":t:r")
	local fabspath = vim.fn.fnamemodify(file_path, ":p")
	local dir = vim.fn.fnamemodify(file_path, ":h")

	-- 对 exec 也进行占位符展开
	local exec = cmd.exec or ""
	exec = exec:gsub("%%%(FNAME%%%)", path_safe(fname))
		:gsub("%%%(FNOEXT%%%)", path_safe(fnoext))
		:gsub("%%%(FABSPATH%%%)", path_safe(fabspath))
		:gsub("%%%(DIR%%%)", path_safe(dir))
		:gsub("%$%(FNAME%)", path_safe(fname))
		:gsub("%$%(FNOEXT%)", path_safe(fnoext))
		:gsub("%$%(FABSPATH%)", path_safe(fabspath))
		:gsub("%$%(DIR%)", path_safe(dir))

	local args = {}
	for _, a in ipairs(cmd.args or {}) do
		a = a:gsub("%%%(FNAME%%%)", path_safe(fname))
			:gsub("%%%(FNOEXT%%%)", path_safe(fnoext))
			:gsub("%%%(FABSPATH%%%)", path_safe(fabspath))
			:gsub("%%%(DIR%%%)", path_safe(dir))
			:gsub("%$%(FNAME%)", path_safe(fname))
			:gsub("%$%(FNOEXT%)", path_safe(fnoext))
			:gsub("%$%(FABSPATH%)", path_safe(fabspath))
			:gsub("%$%(DIR%)", path_safe(dir))
		table.insert(args, a)
	end

	return { exec = path_safe(exec), args = args, cwd = dir }
end

--------------------------------------------------
-- 编译
--------------------------------------------------
local function compile(cmd, file_path, cb)
	if not cmd then
		cb({ success = true })
		return
	end
	local c = fill_command(cmd, file_path)
	log("Compile start:", c.exec, table.concat(c.args, " "))
	local stdout, stderr = uv.new_pipe(false), uv.new_pipe(false)
	local output = ""
	local handle
	handle = uv.spawn(
		c.exec,
		{ args = c.args, cwd = c.cwd, stdio = { nil, stdout, stderr }, hide = IS_WINDOWS },
		function(code)
			log("Compile finished, code=", code)
			if handle and not handle:is_closing() then
				handle:close()
			end
			stdout:close()
			stderr:close()
			cb({ success = code == 0, err = code == 0 and nil or { { type = "compile_error", msg = output } } })
		end
	)
	stdout:read_start(function(_, d)
		if d then
			output = output .. d
		end
	end)
	stderr:read_start(function(_, d)
		if d then
			output = output .. d
		end
	end)
end

--------------------------------------------------
-- 单测试异步
--------------------------------------------------
local function run_case_async(run_cmd, file_path, input, std_output, tl, ml, cb)
	local cmd = fill_command(run_cmd, file_path)
	if not cmd then
		cb({ state = { type = "RE", msg = "No run command" } })
		return
	end
	log("Run start:", cmd.exec, table.concat(cmd.args, " "))
	local stdin, stdout, stderr = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
	local user_lines, buffer = {}, ""
	local peak_mem = 0
	local finished = false
	local handle
	local function finish(state_override)
		if finished then
			return
		end
		finished = true
		if #buffer > 0 then
			table.insert(user_lines, buffer)
		end
		local std_lines = vim.split(std_output or "", "\n", { plain = true })
		local diff_lines, correct, fl, fc = stream_diff(user_lines, std_lines, M.config.obscure)
		cb(state_override or {
			output = table.concat(diff_lines, "\n"),
			state = correct and { type = "AC" } or { type = "WA" },
			first_mismatch = correct and nil or { line = fl, column = fc },
			peak_mem = peak_mem,
		})
	end
	handle = uv.spawn(
		cmd.exec,
		{ args = cmd.args, cwd = cmd.cwd, stdio = { stdin, stdout, stderr }, hide = IS_WINDOWS },
		function()
			finish()
		end
	)
	stdin:write(input or "")
	stdin:close()
	stdout:read_start(function(_, d)
		if d then
			buffer = buffer .. d
			for line in (buffer .. "\n"):gmatch("(.-)\n") do
				table.insert(user_lines, line)
			end
			buffer = buffer:match("([^\n]*)$") or ""
		end
	end)
	stderr:read_start(function(_, d)
		if d then
			log("Runtime error:", d)
			finish({ state = { type = "RE", msg = d } })
		end
	end)
	-- 修复 timer nil，先声明 timer 变量
	local t = uv.new_timer()
	t:start(tl, 0, function()
		t:stop()
		t:close()
		if handle and not handle:is_closing() then
			if handle:is_active() then -- 仅在进程仍在运行时才 kill
				log("TLE, killing PID", handle:get_pid())
				if IS_WINDOWS then
					uv.spawn("taskkill", { args = { "/PID", handle:get_pid(), "/F", "/T" } })
				else
					handle:kill("sigkill")
				end
				finish({ state = { type = "TLE" } })
			end
		end
	end)
end

--------------------------------------------------
-- 获取命令
--------------------------------------------------
local function get_command(file)
	local ext = vim.fn.fnamemodify(file, ":e"):lower()
	local lang = ext_map[ext] or ext
	return {
		language = lang,
		compile_command = M.config.compile_command and M.config.compile_command[lang],
		run_command = M.config.run_command and M.config.run_command[lang],
	}
end

--------------------------------------------------
-- 主异步并发运行
--------------------------------------------------
function M.run(file_path, json, final_cb)
	log("Run invoked for", file_path)
	local command = get_command(file_path)
	compile(command.compile_command, file_path, function(comp)
		local results = {}
		for i = 1, #json.tests do
			results[i] = { state = { type = "UNKNOWN" } }
		end
		if not comp.success then
			log("Compile failed")
			for i = 1, #json.tests do
				results[i] = { err = comp.err, state = { type = "CE" } }
			end
			final_cb(results)
			return
		end
		local max_workers = M.config.max_workers
		local active, idx, pending = 0, 1, #json.tests
		local function try_start()
			while active < max_workers and idx <= #json.tests do
				local cur = idx
				idx = idx + 1
				active = active + 1
				log("Dispatch test", cur)
				local t = json.tests[cur]
				run_case_async(
					command.run_command,
					file_path,
					t.input,
					t.output,
					json.timeLimit,
					json.memoryLimit,
					function(res)
						results[cur] = res
						active = active - 1
						pending = pending - 1
						log("Test", cur, "finished")
						if pending == 0 then
							final_cb(results)
						end
						try_start()
					end
				)
			end
		end
		try_start()
	end)
end

--------------------------------------------------
function M.init(cfg)
	M.config = cfg
end

return M
