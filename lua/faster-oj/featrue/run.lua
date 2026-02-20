--- @class FOJRunner
--- @field config table 用户配置表
local M = {}

local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1
local utils = require("faster-oj.featrue.utils")

-- 保存上一次编译的警告或错误信息
local last_compile_msg = nil

--------------------------------------------------------------------------------
-- [LOGGING] 调试日志系统
--------------------------------------------------------------------------------
local function log(...)
	if M.config and M.config.debug then
		print("[FOJ][run]", ...)
	end
end
--------------------------------------------------------------------------------
-- [CORE] 差异与二维高亮坐标计算
--------------------------------------------------------------------------------

--- 将字符串按行分割，计算每个 token 的 2D 高亮坐标 (0-based, 前闭后开)
local function get_tokens_with_coords(str, obscure)
	local tokens = {}
	local lines = vim.split(str, "\n", { plain = true })
	local pattern = obscure and "()(%S+)()" or "()(.)()"

	for l_idx, line in ipairs(lines) do
		for start_pos, text, end_pos in line:gmatch(pattern) do
			table.insert(tokens, {
				text = text,
				line = l_idx - 1,
				sc = start_pos - 1,
				ec = end_pos - 1,
			})
		end
	end
	return tokens
end

--- 计算并合并高亮区间
local function compute_diff_ranges(user_out, std_out, obscure)
	local u_toks = get_tokens_with_coords(user_out, obscure)
	local s_toks = get_tokens_with_coords(std_out, obscure)

	local u_flat, s_flat = {}, {}
	for _, t in ipairs(u_toks) do
		table.insert(u_flat, t.text)
	end
	for _, t in ipairs(s_toks) do
		table.insert(s_flat, t.text)
	end

	local u_str = table.concat(u_flat, "\n")
	local s_str = table.concat(s_flat, "\n")

	if u_str == s_str then
		return nil, true, nil
	end

	local indices = vim.diff(u_str, s_str, { result_type = "indices" })
	if not indices or #indices == 0 then
		return nil, true, nil
	end

	local diff_ranges = {}
	local first_msg = nil

	for i, d in ipairs(indices) do
		local ua, uc, sb = d[1], d[2], d[3]

		if uc > 0 then
			local last_range = nil
			for j = 0, uc - 1 do
				local t = u_toks[ua + j]
				if last_range and last_range.line == t.line and last_range.end_col == t.sc then
					last_range.end_col = t.ec
				else
					last_range = { line = t.line, start_col = t.sc, end_col = t.ec }
					table.insert(diff_ranges, last_range)
				end
			end
		else
			if ua > 0 and u_toks[ua] then
				local t = u_toks[ua]
				table.insert(diff_ranges, { line = t.line, start_col = t.ec, end_col = t.ec })
			else
				table.insert(diff_ranges, { line = 0, start_col = 0, end_col = 0 })
			end
		end

		if i == 1 then
			local exp = (s_toks[sb] or { text = "EOF" }).text
			local fnd = (uc > 0 and u_toks[ua].text) or "MISSING"
			first_msg = string.format(
				"wrong answer %dth %s differ - expected: '%s', found: '%s'",
				sb,
				obscure and "tokens" or "characters",
				exp:gsub("\n", "\\n"),
				fnd:gsub("\n", "\\n")
			)
		end
	end

	return diff_ranges, false, first_msg
end

--------------------------------------------------------------------------------
-- [COMPILATION] 异步编译模块
--------------------------------------------------------------------------------

function M.compile(file_path, on_compile_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local vars = utils.get_vars(file_path)
	local cmd_raw = M.config.compile_command[ext]

	-- 每次编译前重置上次的信息
	last_compile_msg = nil

	if not cmd_raw or not cmd_raw.exec or cmd_raw.exec == "" then
		log("No compilation needed for extension: ." .. ext)
		return on_compile_finish(true, "", false)
	end

	local exec = utils.expand(cmd_raw.exec, vars)
	local args = {}
	for _, a in ipairs(cmd_raw.args or {}) do
		table.insert(args, (utils.expand(a, vars)))
	end

	log("Compiling:", exec, table.concat(args, " "))

	local stderr = uv.new_pipe(false)
	local err_chunks = {}

	local handle, spawn_err
	handle, spawn_err = uv.spawn(exec, {
		args = args,
		cwd = vars.DIR,
		stdio = { nil, nil, stderr },
		hide = true,
	}, function(code)
		if stderr and not stderr:is_closing() then
			stderr:close()
		end
		if handle and not handle:is_closing() then
			handle:close()
		end

		-- 处理编译器的输出并去除首尾空白
		local msg = table.concat(err_chunks):match("^%s*(.-)%s*$")
		if msg and msg ~= "" then
			last_compile_msg = msg
		end

		log("Compilation exited with code:", code)
		if code == 0 then
			-- 编译成功也返回保存的信息（比如编译器警告）
			on_compile_finish(true, last_compile_msg or "", true)
		else
			-- 编译失败
			on_compile_finish(false, last_compile_msg or "Compilation failed without output", true)
		end
	end)

	if not handle then
		log("Compile spawn error:", spawn_err)
		if stderr and not stderr:is_closing() then
			stderr:close()
		end
		return on_compile_finish(false, "Spawn error: " .. tostring(spawn_err))
	end

	stderr:read_start(function(_, d)
		if d then
			table.insert(err_chunks, d)
		end
	end)
end

--------------------------------------------------------------------------------
-- [EXECUTION] 异步执行模块
--------------------------------------------------------------------------------
local function run_single_task(cmd_raw, vars, input, std_out, tl, ml_mb, cb)
	local user_exec = utils.expand(cmd_raw.exec, vars)
	local user_args = {}
	for _, a in ipairs(cmd_raw.args or {}) do
		table.insert(user_args, (utils.expand(a, vars)))
	end

	local final_exec = user_exec
	local final_args = user_args

	if is_win then
		local joined_args = table.concat(user_args, " ")
		local ps_script = string.format(
			"$p = Start-Process -FilePath '%s' -ArgumentList '%s' -NoNewWindow -PassThru -Wait; "
				.. "[Console]::Error.WriteLine('MEM_PEAK:' + $p.PeakWorkingSet64); "
				.. "exit $p.ExitCode",
			user_exec,
			joined_args
		)
		final_exec = "powershell"
		final_args = { "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script }
	elseif is_mac or vim.fn.has("unix") == 1 then
		local time_cmd = "/usr/bin/time"
		local time_args = is_mac and { "-l" } or { "-v" }
		final_exec = time_cmd
		final_args = {}
		for _, v in ipairs(time_args) do
			table.insert(final_args, v)
		end
		table.insert(final_args, user_exec)
		for _, v in ipairs(user_args) do
			table.insert(final_args, v)
		end
	end

	local out_chunks, err_chunks = {}, {}
	local stdout, stderr, stdin = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
	local start_time = uv.hrtime()
	local is_killed = false
	local handle, timer, spawn_err

	local function safe_kill()
		if handle and not handle:is_closing() then
			is_killed = true
			handle:kill(is_win and 15 or 9)
		end
	end

	handle, spawn_err = uv.spawn(final_exec, {
		args = final_args,
		cwd = vars.DIR,
		stdio = { stdin, stdout, stderr },
		hide = true,
	}, function(code, signal)
		if timer then
			timer:stop()
			timer:close()
		end
		local duration = math.floor((uv.hrtime() - start_time) / 1e6)

		if stdout and not stdout:is_closing() then
			stdout:close()
		end
		if stderr and not stderr:is_closing() then
			stderr:close()
		end
		if handle and not handle:is_closing() then
			handle:close()
		end

		local user_out = table.concat(out_chunks):gsub("\r\n", "\n")
		local raw_err = table.concat(err_chunks)

		-- [PARSING] 解析内存峰值
		local max_rss_kb = 0
		local clean_err = raw_err

		if is_win then
			-- 解析 PowerShell 输出的 MEM_PEAK:数值 (单位 Bytes)
			local val = raw_err:match("MEM_PEAK:(%d+)")
			if val then
				max_rss_kb = math.floor(tonumber(val) / 1024)
				clean_err = raw_err:gsub("MEM_PEAK:%d+[\r\n]*", "")
			end
		elseif is_mac then
			local val = raw_err:match("(%d+)%s+maximum resident set size")
			if val then
				max_rss_kb = math.floor(tonumber(val) / 1024)
				clean_err = raw_err:gsub("%d+%s+maximum resident set size.*", "")
			end
		else -- Linux
			local val = raw_err:match("Maximum resident set size %(kbytes%): (%d+)")
			if val then
				max_rss_kb = tonumber(val)
				clean_err =
					raw_err:gsub("Command exited with non%-zero status.*", ""):gsub("\tMaximum resident set size.*", "")
			end
		end

		local res = {
			input = input,
			output = user_out,
			expected = std_out,
			used_time = duration,
			used_memory = max_rss_kb,
			state = { type = "AC" },
		}
		if is_mac then
			res.used_memory = res.used_memory + M.config.macos_mem_offset
		elseif not is_win then
			res.used_memory = res.used_memory + M.config.linux_mem_offset
		end

		-- 判定逻辑
		if ml_mb > 0 and (max_rss_kb / 1024) > ml_mb then
			res.state = { type = "MLE" }
		elseif is_killed or duration > tl then
			res.state = { type = "TLE" }
		elseif code ~= 0 or signal ~= 0 then
			res.state = { type = "RE", msg = clean_err:match("^%s*(.-)%s*$") or "Runtime Error" }
		else
			local diffs, ok, msg = compute_diff_ranges(user_out, std_out, M.config.obscure)
			if not ok then
				res.state = { type = "WA", msg = msg }
				res.diff = diffs
			end
		end
		cb(res)
	end)

	-- TLE 定时器
	timer = uv.new_timer()
	timer:start(tl + 200, 0, safe_kill) -- 略微放宽，因为 PowerShell 启动慢

	-- 输入流处理
	if input and input ~= "" then
		stdin:write(input, function()
			if not stdin:is_closing() then
				stdin:close()
			end
		end)
	else
		stdin:close()
	end

	stdout:read_start(function(_, d)
		if d then
			table.insert(out_chunks, d)
		end
	end)
	stderr:read_start(function(_, d)
		if d then
			table.insert(err_chunks, d)
		end
	end)
end

--------------------------------------------------------------------------------
-- [PUBLIC API] 公开接口
--------------------------------------------------------------------------------

function M.run(file_path, json, on_case_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local vars = utils.get_vars(file_path)
	local run_cmd = M.config.run_command[ext]
	local tests = json.tests or {}

	if not run_cmd then
		log("No run command for extension: ." .. ext)
		return
	end

	log("Run started. Workers:", M.config.max_workers)

	local active, idx = 0, 1
	local function fill_queue()
		while active < (M.config.max_workers or 4) and idx <= #tests do
			local i = idx
			idx, active = idx + 1, active + 1
			run_single_task(
				run_cmd,
				vars,
				tests[i].input,
				tests[i].output,
				json.timeLimit or 2000,
				json.memoryLimit or 256,
				function(res)
					res.test_index = i
					active = active - 1
					on_case_finish(res)
					fill_queue()
				end
			)
		end
	end
	fill_queue()
end

function M.setup(cfg)
	M.config = cfg
	utils.setup(cfg)
	log("Runner module initialized.")
end

return M
