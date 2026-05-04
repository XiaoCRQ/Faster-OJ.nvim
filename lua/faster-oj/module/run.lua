---@module "faster-oj.module.run"

local M = {}

local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1
local utils = require("faster-oj.module.utils")

local last_compile_msg = nil
local MAX_OUTPUT_SIZE = 10 * 1024 * 1024 -- 10MB

---@type boolean /usr/bin/time 是否可用 (非 Windows 平台)
local has_time_bin = not is_win and vim.fn.executable("/usr/bin/time") == 1

---@param level string 日志级别 (INFO/WARN/ERROR)
---@param func string 函数名
---@param msg string 日志消息
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][run][%s] %s: %s", level, func, msg))
	end
end

---安全关闭 Libuv 句柄
---@param handle uv_handle_t|nil
local function safe_close(handle)
	if handle and not handle:is_closing() then
		handle:close()
	end
end

---词法 Token 提取 (含坐标)
---@param str string
---@return table[] tokens
local function get_tokens_with_coords(str)
	local tokens = {}
	for l_idx, line in ipairs(vim.split(str, "\n", { plain = true })) do
		for start_pos, text, end_pos in line:gmatch("()(%S+)()") do
			table.insert(tokens, { text = text, line = l_idx - 1, sc = start_pos - 1, ec = end_pos - 1 })
		end
	end
	return tokens
end

---对比用户输出与标准输出，计算差异范围
---@param user_out string
---@param std_out string
---@param obscure boolean 是否启用词法模糊匹配
---@return table|nil diff_ranges
---@return boolean accepted
---@return string|nil first_msg
local function compute_diff_ranges(user_out, std_out, obscure)
	if user_out == std_out then
		return nil, true, nil
	end

	local diff_ranges = {}
	local first_msg = nil
	local is_wa = false

	local function record(line, col, end_col, expected, found)
		is_wa = true
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

	local function escape(s)
		return s == "" and "EOF" or s:gsub("\n", "\\n"):gsub("\r", "\\r")
	end

	if obscure then
		local u_toks, s_toks = get_tokens_with_coords(user_out), get_tokens_with_coords(std_out)
		for i = 1, math.max(#u_toks, #s_toks) do
			local ut, st = u_toks[i], s_toks[i]
			if not ut then
				local last = u_toks[#u_toks] or { line = 0, ec = 0 }
				record(last.line, last.ec, last.ec + 1, st.text, "EOF")
			elseif not st then
				record(ut.line, ut.sc, ut.ec, "EOF", ut.text)
			elseif ut.text ~= st.text then
				record(ut.line, ut.sc, ut.ec, st.text, ut.text)
			end
		end
	else
		local u_lines = vim.split(user_out, "\n", { plain = true })
		local s_lines = vim.split(std_out, "\n", { plain = true })
		for i = 1, math.max(#u_lines, #s_lines) do
			local ul, sl = u_lines[i], s_lines[i]
			if not ul then
				record(math.max(0, #u_lines - 1), 0, 1, escape(sl), "EOF")
			elseif not sl then
				record(i - 1, 0, #ul > 0 and #ul or 1, "EOF", escape(ul))
			elseif ul ~= sl then
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

---构建平台相关的执行命令
---
---Linux:   timeout -s 9 (硬墙钟限制) + /usr/bin/time -v (内存测量)
---macOS:   /usr/bin/time -l (内存测量) + uv timer (超时), 因 macOS 无 timeout 命令
---Windows: PowerShell (内存测量，带内置超时) 或直接 uv.spawn
---
---@param cmd_raw FOJ.Command 用户命令配置
---@param vars table 占位符变量
---@param tl_ms integer 时间限制 (ms)
---@return string exec
---@return string[] args
local function build_exec_cmd(cmd_raw, vars, tl_ms)
	local user_exec = utils.expand(cmd_raw.exec, vars)
	local user_args = vim.tbl_map(function(a)
		return utils.expand(a, vars)
	end, cmd_raw.args or {})

	if is_win then
		-- PowerShell: Start-Process + WaitForExit(timeout) + PeakWorkingSet64
		local arg_str_parts = {}
		for _, a in ipairs(user_args) do
			table.insert(arg_str_parts, "'" .. a:gsub("'", "''") .. "'")
		end
		local joined_args = table.concat(arg_str_parts, ", ")
		local tl_sec = math.floor(tl_ms / 1000) + 1
		local ps_script = string.format(
			"$p = Start-Process -FilePath '%s' -ArgumentList %s -NoNewWindow -PassThru; "
				.. "$p.WaitForExit(%d); "
				.. "if (!$p.HasExited) { $p.Kill(); [Console]::Error.WriteLine('TIME_LIMIT_EXCEEDED') }; "
				.. "[Console]::Error.WriteLine('MEM_PEAK:' + $p.PeakWorkingSet64); "
				.. "exit $p.ExitCode",
			user_exec:gsub("'", "''"),
			joined_args ~= "" and joined_args or "''",
			tl_sec * 1000
		)
		log("INFO", "build_exec_cmd", "Windows PowerShell wrapper")
		return "powershell", { "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script }
	end

	if is_mac then
		-- macOS: /usr/bin/time -l 测量内存, uv timer 做超时
		if has_time_bin then
			log("INFO", "build_exec_cmd", "macOS with /usr/bin/time -l")
			local args = { "-l", user_exec }
			vim.list_extend(args, user_args)
			return "/usr/bin/time", args
		end
		log("WARN", "build_exec_cmd", "/usr/bin/time not found, memory tracking disabled")
		return user_exec, user_args
	end

	-- Linux: timeout -s 9 (硬超时) + /usr/bin/time -v (内存)
	local tl_sec = math.ceil(tl_ms / 1000)
	if has_time_bin then
		log("INFO", "build_exec_cmd", string.format("Linux timeout=%ds + /usr/bin/time -v", tl_sec))
		local args = { "-s", "9", tostring(tl_sec), "/usr/bin/time", "-v", user_exec }
		vim.list_extend(args, user_args)
		return "timeout", args
	end

	log("WARN", "build_exec_cmd", "/usr/bin/time not found, memory tracking disabled")
	local args = { "-s", "9", tostring(tl_sec), user_exec }
	vim.list_extend(args, user_args)
	return "timeout", args
end

---解析 stderr 输出中的内存峰值信息
---@param raw_err string 原始 stderr
---@return integer max_rss_kb 峰值 RSS (KB)
---@return string clean_err 清理后的错误信息
local function parse_memory_and_err(raw_err)
	local max_rss_kb, clean_err = 0, raw_err

	if is_win then
		local val = raw_err:match("MEM_PEAK:(%d+)")
		if val then
			max_rss_kb = math.floor(tonumber(val) / 1024)
			clean_err = raw_err:gsub("MEM_PEAK:%d+[\r\n]*", "")
		end
		if raw_err:find("TIME_LIMIT_EXCEEDED") then
			clean_err = clean_err:gsub("TIME_LIMIT_EXCEEDED[\r\n]*", "")
		end
	elseif is_mac then
		local val = raw_err:match("(%d+)%s+maximum resident set size")
		if val then
			max_rss_kb = math.floor(tonumber(val) / 1024)
			clean_err = raw_err:gsub("%d+%s+maximum resident set size.*", "")
		end
	else
		local val = raw_err:match("Maximum resident set size %(kbytes%): (%d+)")
		if val then
			max_rss_kb = tonumber(val)
			clean_err = raw_err:gsub("Command exited with non%-zero status.*", "")
				:gsub("\tMaximum resident set size.*", "")
		end
	end

	return max_rss_kb, clean_err:match("^%s*(.-)%s*$") or ""
end

---编译单个源文件
---@param file_path string 源文件路径
---@param need_compile boolean 是否需要编译
---@param on_compile_finish fun(success:boolean, msg:string, need:boolean) 编译完成回调
function M.compile(file_path, need_compile, on_compile_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local cmd_raw = M.config.compile_command[ext]

	if not cmd_raw or not cmd_raw.exec or cmd_raw.exec == "" then
		last_compile_msg = nil
		return on_compile_finish(true, "", false)
	end
	if need_compile == false then
		return on_compile_finish(true, "", false)
	end

	last_compile_msg = nil

	local vars = utils.get_vars(file_path)
	local exec = utils.expand(cmd_raw.exec, vars)
	local args = vim.tbl_map(function(a)
		return utils.expand(a, vars)
	end, cmd_raw.args or {})

	-- 确保 .output/ 目录存在 (os.execute 安全于任何上下文, mkdir -p 幂等)
	os.execute('mkdir -p "' .. vars.DIR .. '/.output" 2>/dev/null')

	log("INFO", "compile", "Compiling " .. file_path)
	log("INFO", "compile", "Exec: " .. exec .. " Args: " .. vim.inspect(args))

	local stderr = uv.new_pipe(false)
	local err_chunks = {}
	local handle

	handle, _ = uv.spawn(
		exec,
		{ args = args, cwd = vars.DIR, stdio = { nil, nil, stderr }, hide = true },
		function(code)
			safe_close(stderr)
			safe_close(handle)

			last_compile_msg = table.concat(err_chunks):match("^%s*(.-)%s*$")
			if code ~= 0 then
				log("ERROR", "compile", string.format("FAILED (code=%d): %s", code, last_compile_msg or ""))
			else
				log("INFO", "compile", "OK")
			end
			on_compile_finish(code == 0, last_compile_msg or (code ~= 0 and "Compilation failed" or ""), true)
		end
	)

	if not handle then
		safe_close(stderr)
		log("ERROR", "compile", "Spawn failed")
		return on_compile_finish(false, "Spawn error")
	end

	stderr:read_start(function(_, d)
		if d then
			table.insert(err_chunks, d)
		end
	end)
end

---执行单次运行 (不比较输出，供判题和对拍复用)
---cb 接收 {output, used_time, used_memory, is_killed, is_ole, code, signal, clean_err}
---@param cmd_raw FOJ.Command
---@param vars table
---@param input string
---@param tl_ms integer
---@param ml_mb integer
---@param cb fun(res:table)
function M.run_single(cmd_raw, vars, input, tl_ms, ml_mb, cb)
	local final_exec, final_args = build_exec_cmd(cmd_raw, vars, tl_ms)
	local stdout, stderr, stdin = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)

	local out_chunks, err_chunks = {}, {}
	local out_len = 0
	local start_time = uv.hrtime()
	local is_killed, is_ole = false, false
	local handle, timer

	---强制杀死进程
	local function force_kill()
		is_killed = true
		if handle and not handle:is_closing() then
			-- Linux/macOS: SIGKILL; Windows: SIGTERM (uv 限制)
			handle:kill(is_win and 15 or 9)
		end
	end

	log("INFO", "run_single", string.format("Exec: %s Args: %s", final_exec, vim.inspect(final_args)))

	handle, _ = uv.spawn(
		final_exec,
		{ args = final_args, cwd = vars.DIR, stdio = { stdin, stdout, stderr }, hide = true },
		function(code, signal)
			safe_close(timer)
			safe_close(stdout)
			safe_close(stderr)
			safe_close(handle)

			local duration = math.floor((uv.hrtime() - start_time) / 1e6)
			local user_out = table.concat(out_chunks):gsub("\r\n", "\n")
			local max_rss_kb, clean_err = parse_memory_and_err(table.concat(err_chunks))

			-- 平台内存偏移
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

			-- 状态判定 (OLE > MLE > TLE > RE > OK)
			if is_ole then
				res.state = { type = "OLE", msg = "Output Limit Exceeded" }
			elseif ml_mb > 0 and (max_rss_kb / 1024) > ml_mb then
				res.state = { type = "MLE" }
			elseif is_killed or duration > tl_ms then
				res.state = { type = "TLE" }
			elseif code ~= 0 or signal ~= 0 then
				res.state = { type = "RE", msg = clean_err ~= "" and clean_err or "Runtime Error" }
			else
				res.state = { type = "OK" }
			end
			cb(res)
		end
	)

	-- uv timer 作为超时后备 (Linux 上 timeout 命令是主, timer 是后备)
	timer = uv.new_timer()
	timer:start(tl_ms + 500, 0, force_kill)

	if input and input ~= "" then
		stdin:write(input, function()
			safe_close(stdin)
		end)
	else
		safe_close(stdin)
	end

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

---执行单测 + 输出比较 (包装 M.run_single)
---@param cmd_raw FOJ.Command
---@param vars table
---@param input string
---@param std_out string
---@param tl_ms integer
---@param ml_mb integer
---@param cb fun(res:table)
local function run_single_task(cmd_raw, vars, input, std_out, tl_ms, ml_mb, cb)
	M.run_single(cmd_raw, vars, input, tl_ms, ml_mb, function(raw)
		if M.config.warning_msg and last_compile_msg then
			raw.state.msg = last_compile_msg
		end

		if raw.state.type == "OK" then
			local diffs, ok, msg = compute_diff_ranges(raw.output, std_out, M.config.obscure)
			if not ok then
				raw.state = { type = "WA", msg = msg }
				raw.diff = diffs
				log("INFO", "run_single_task", "Verdict: WA - " .. (msg or ""))
			else
				raw.state = { type = "AC" }
				log("INFO", "run_single_task", "Verdict: AC")
			end
		else
			log("WARN", "run_single_task", "Verdict: " .. raw.state.type)
		end
		cb(raw)
	end)
end

---并发判题入口
---@param file_path string 源文件路径
---@param json table 题目数据 (problem.json 内容: testCount, timeLimit, memoryLimit)
---@param on_case_finish fun(res:table) 每个测试用例完成时的回调
function M.run(file_path, json, on_case_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local cmd_raw = M.config.run_command[ext]
	local test_count = json.testCount or 0
	local problem_dir = utils.get_problem_dir_from(file_path)

	if not cmd_raw then
		log("ERROR", "run", "No run_command for extension: " .. ext)
		return
	end

	-- 从文件读取测试用例 (维持兼容现有 tests[i] 结构)
	local tests = {}
	for i = 0, test_count - 1 do
		tests[i + 1] = utils.read_test_case(problem_dir, i)
	end

	local vars = utils.get_vars(file_path)
	local active, idx = 0, 1

	log("INFO", "run", string.format("Starting %d test(s), max_workers=%d", #tests, M.config.max_workers or 4))

	local function fill_queue()
		while active < (M.config.max_workers or 4) and idx <= #tests do
			local i = idx
			idx, active = idx + 1, active + 1
			run_single_task(
				cmd_raw,
				vars,
				tests[i].input,
				tests[i].output,
				json.timeLimit or (M.config and M.config.default_time_limit) or 2000,
				json.memoryLimit or (M.config and M.config.default_memory_limit) or 256,
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
