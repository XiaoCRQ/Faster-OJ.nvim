---@module "faster-oj.module.run"

local M = {}

local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1
local utils = require("faster-oj.module.utils")

local last_compile_msg = nil
local MAX_OUTPUT_SIZE = 10 * 1024 * 1024 -- 10MB，防止死循环输出撑爆内存

local function log(...)
	if M.config and M.config.debug then
		print("[FOJ][run]", ...)
	end
end

---安全关闭 Libuv 句柄
local function safe_close(handle)
	if handle and not handle:is_closing() then
		handle:close()
	end
end

local function get_tokens_with_coords(str)
	local tokens = {}
	for l_idx, line in ipairs(vim.split(str, "\n", { plain = true })) do
		for start_pos, text, end_pos in line:gmatch("()(%S+)()") do
			table.insert(tokens, { text = text, line = l_idx - 1, sc = start_pos - 1, ec = end_pos - 1 })
		end
	end
	return tokens
end

local function compute_diff_ranges(user_out, std_out, obscure)
	if user_out == std_out then
		return nil, true, nil
	end

	local diff_ranges = {}
	local first_msg = nil
	local is_wa = false

	-- 统一记录函数：处理坐标、保存范围、生成标准格式消息
	local function record(line, col, end_col, expected, found)
		is_wa = true
		-- 统一格式: Wrong answer at line L col C - expected: 'E', found: 'F'
		-- 注意：line 和 col 在内部逻辑通常是 0-indexed，显示给用户时 +1
		local msg = string.format(
			"Wrong answer at line %d col %d - expected: '%s', found: '%s'",
			line + 1,
			col + 1,
			expected,
			found
		)
		first_msg = first_msg or msg
		table.insert(diff_ranges, { line = line, start_col = col, end_col = end_col })
	end

	-- 辅助函数：转义特殊字符
	local function escape(s)
		return s == "" and "EOF" or s:gsub("\n", "\\n"):gsub("\r", "\\r")
	end

	if obscure then
		local u_toks, s_toks = get_tokens_with_coords(user_out), get_tokens_with_coords(std_out)
		for i = 1, math.max(#u_toks, #s_toks) do
			local ut, st = u_toks[i], s_toks[i]
			if not ut then -- 用户输出提前结束
				local last = u_toks[#u_toks] or { line = 0, ec = 0 }
				record(last.line, last.ec, last.ec + 1, st.text, "EOF")
			elseif not st then -- 标准输出提前结束
				record(ut.line, ut.sc, ut.ec, "EOF", ut.text)
			elseif ut.text ~= st.text then -- Token 不匹配
				record(ut.line, ut.sc, ut.ec, st.text, ut.text)
			end
		end
	else
		local u_lines = vim.split(user_out, "\n", { plain = true })
		local s_lines = vim.split(std_out, "\n", { plain = true })
		for i = 1, math.max(#u_lines, #s_lines) do
			local ul, sl = u_lines[i], s_lines[i]
			if not ul then -- 用户行数不足
				record(math.max(0, #u_lines - 1), 0, 1, escape(sl), "EOF")
			elseif not sl then -- 用户行数过多
				record(i - 1, 0, #ul > 0 and #ul or 1, "EOF", escape(ul))
			elseif ul ~= sl then -- 行内容不匹配，找第一个差异点
				local d_idx, min_l = 1, math.min(#ul, #sl)
				while d_idx <= min_l and ul:sub(d_idx, d_idx) == sl:sub(d_idx, d_idx) do
					d_idx = d_idx + 1
				end
				local e_char = sl:sub(d_idx, d_idx)
				local f_char = ul:sub(d_idx, d_idx)
				record(i - 1, d_idx - 1, math.max(d_idx, #ul), escape(e_char), escape(f_char))
			end
		end
	end

	return is_wa and diff_ranges or nil, not is_wa, first_msg
end

local function build_exec_cmd(cmd_raw, vars)
	local user_exec = utils.expand(cmd_raw.exec, vars)
	local user_args = vim.tbl_map(function(a)
		return utils.expand(a, vars)
	end, cmd_raw.args or {})

	if is_win then
		local joined_args = table.concat(user_args, " ")
		local ps_script = string.format(
			"$p = Start-Process -FilePath '%s' -ArgumentList '%s' -NoNewWindow -PassThru -Wait; "
				.. "[Console]::Error.WriteLine('MEM_PEAK:' + $p.PeakWorkingSet64); exit $p.ExitCode",
			user_exec,
			joined_args
		)
		return "powershell", { "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script }
	end

	local final_args = is_mac and { "-l" } or { "-v" }
	table.insert(final_args, user_exec)
	vim.list_extend(final_args, user_args)
	return "/usr/bin/time", final_args
end

local function parse_memory_and_err(raw_err)
	local max_rss_kb, clean_err = 0, raw_err

	if is_win then
		local val = raw_err:match("MEM_PEAK:(%d+)")
		if val then
			max_rss_kb, clean_err = math.floor(tonumber(val) / 1024), raw_err:gsub("MEM_PEAK:%d+[\r\n]*", "")
		end
	elseif is_mac then
		local val = raw_err:match("(%d+)%s+maximum resident set size")
		if val then
			max_rss_kb, clean_err =
				math.floor(tonumber(val) / 1024), raw_err:gsub("%d+%s+maximum resident set size.*", "")
		end
	else
		local val = raw_err:match("Maximum resident set size %(kbytes%): (%d+)")
		if val then
			max_rss_kb = tonumber(val)
			clean_err =
				raw_err:gsub("Command exited with non%-zero status.*", ""):gsub("\tMaximum resident set size.*", "")
		end
	end

	return max_rss_kb, clean_err:match("^%s*(.-)%s*$") or ""
end

function M.compile(file_path, on_compile_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local cmd_raw = M.config.compile_command[ext]
	last_compile_msg = nil

	if not cmd_raw or not cmd_raw.exec or cmd_raw.exec == "" then
		return on_compile_finish(true, "", false)
	end

	local vars = utils.get_vars(file_path)
	local exec = utils.expand(cmd_raw.exec, vars)
	local args = vim.tbl_map(function(a)
		return utils.expand(a, vars)
	end, cmd_raw.args or {})

	local stderr = uv.new_pipe(false)
	local err_chunks = {}
	local handle

	handle, _ = uv.spawn(
		exec,
		{ args = args, cwd = vars.DIR, stdio = { nil, nil, stderr }, hide = true },
		function(code)
			if code ~= 0 then
				log("Compilation failed , compile_command is " .. exec .. vim.inspect(args))
			end
			safe_close(stderr)
			safe_close(handle)

			last_compile_msg = table.concat(err_chunks):match("^%s*(.-)%s*$")
			on_compile_finish(code == 0, last_compile_msg or (code ~= 0 and "Compilation failed" or ""), true)
		end
	)

	if not handle then
		safe_close(stderr)
		return on_compile_finish(false, "Spawn error")
	end

	stderr:read_start(function(_, d)
		if d then
			table.insert(err_chunks, d)
		end
	end)
end

local function run_single_task(cmd_raw, vars, input, std_out, tl, ml_mb, cb)
	local final_exec, final_args = build_exec_cmd(cmd_raw, vars)
	local stdout, stderr, stdin = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)

	local out_chunks, err_chunks = {}, {}
	local out_len = 0
	local start_time = uv.hrtime()
	local is_killed, is_ole = false, false
	local handle, timer

	local function force_kill()
		is_killed = true
		if handle and not handle:is_closing() then
			handle:kill(is_win and 15 or 9)
		end
	end
	log("Runing command is " .. final_exec .. vim.inspect(final_args))

	handle, _ = uv.spawn(
		final_exec,
		{ args = final_args, cwd = vars.DIR, stdio = { stdin, stdout, stderr }, hide = true },
		function(code, signal)
			if code ~= 0 then
				log("Runing failed")
			end

			safe_close(timer)
			safe_close(stdout)
			safe_close(stderr)
			safe_close(handle)

			local duration = math.floor((uv.hrtime() - start_time) / 1e6)
			local user_out = table.concat(out_chunks):gsub("\r\n", "\n")
			local max_rss_kb, clean_err = parse_memory_and_err(table.concat(err_chunks))

			-- 加上平台内存偏移量
			max_rss_kb = max_rss_kb
				+ (is_mac and M.config.macos_mem_offset or (not is_win and M.config.linux_mem_offset or 0))

			local res = {
				input = input,
				output = user_out,
				expected = std_out,
				used_time = duration,
				used_memory = max_rss_kb,
				state = { type = "AC" },
			}

			-- 状态判定 (优先级: OLE > MLE > TLE > RE > WA > AC)
			if is_ole then
				res.state = { type = "OLE", msg = "Output Limit Exceeded" }
			elseif ml_mb > 0 and (max_rss_kb / 1024) > ml_mb then
				res.state = { type = "MLE" }
			elseif is_killed or duration > tl then
				res.state = { type = "TLE" }
			elseif code ~= 0 or signal ~= 0 then
				res.state = { type = "RE", msg = clean_err ~= "" and clean_err or "Runtime Error" }
			else
				local diffs, ok, msg = compute_diff_ranges(user_out, std_out, M.config.obscure)
				if not ok then
					res.state = { type = "WA", msg = msg }
					res.diff = diffs
				end
			end
			cb(res)
		end
	)

	timer = uv.new_timer()
	timer:start(tl + 200, 0, force_kill)

	if input and input ~= "" then
		stdin:write(input, function()
			safe_close(stdin)
		end)
	else
		safe_close(stdin)
	end

	-- 读取输出，并限制最大缓冲区防止 OOM
	stdout:read_start(function(_, d)
		if d then
			out_len = out_len + #d
			if out_len > MAX_OUTPUT_SIZE and not is_ole then
				is_ole = true
				force_kill()
			else
				table.insert(out_chunks, d)
			end
		end
	end)

	stderr:read_start(function(_, d)
		if d then
			table.insert(err_chunks, d)
		end
	end)
end

function M.run(file_path, json, on_case_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local cmd_raw = M.config.run_command[ext]
	local tests = json.tests or {}

	if not cmd_raw then
		return
	end

	local vars = utils.get_vars(file_path)
	local active, idx = 0, 1

	local function fill_queue()
		while active < (M.config.max_workers or 4) and idx <= #tests do
			local i = idx
			idx, active = idx + 1, active + 1
			run_single_task(
				cmd_raw,
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
end

return M
