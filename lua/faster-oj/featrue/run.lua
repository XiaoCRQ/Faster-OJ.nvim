--- @class FOJRunner
--- @field config table 用户配置表
local M = {}

local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1

--------------------------------------------------------------------------------
-- [LOGGING] 调试日志系统
--------------------------------------------------------------------------------
local function log(...)
	if M.config.server_debug then
		print("[FOJ][run]", ...)
	end
end

--------------------------------------------------------------------------------
-- [DATA STRUCTURES] 回调数据结构说明
--------------------------------------------------------------------------------
-- 1. 编译回调 (M.compile):
--    success: boolean (是否成功)
--    msg: string (编译错误信息或空字符串)
--
-- 2. 运行回调 (M.run -> res):
--    {
--        test_index  = number,    -- 用例索引 (1-based)
--        input       = string,    -- 输入数据
--        expected    = string,    -- 预期标准输出
--        output      = string,    -- 实际程序输出
--        used_time   = number,    -- 运行耗时 (ms)
--        used_memory = number,    -- 峰值内存 (kb)
--        diff        = table|nil, -- 错误区间: {{start, end}, ...} (0-based)
--        state = {
--            type = string,       -- "AC", "WA", "TLE", "MLE", "RE"
--            msg  = string|nil    -- 错误简述
--        }
--    }
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- [INTERNAL UTILS] 内部工具函数
--------------------------------------------------------------------------------

--- 获取路径变量占位符
local function get_vars(file_path)
	return {
		FNAME = vim.fn.fnamemodify(file_path, ":t"),
		FNOEXT = vim.fn.fnamemodify(file_path, ":t:r"),
		FABSPATH = vim.fn.fnamemodify(file_path, ":p"),
		DIR = vim.fn.fnamemodify(file_path, ":h"),
	}
end

--- 安全扩展占位符，处理多返回值并支持带空格路径
local function expand(str, vars)
	if not str then
		return ""
	end
	-- 用括号包裹 gsub 确保只返回第一个结果，避免 table.insert 报错
	return (str:gsub("[%@%$%%]%(?([%w_]+)%)?", function(k)
		return vars[k] or ""
	end))
end

--- 差异区间计算
local function compute_diff_ranges(user_out, std_out, obscure)
	local function get_tokens(s)
		local t = {}
		local p = obscure and "()(%S+)()" or "()(.)()"
		for sp, txt, ep in s:gmatch(p) do
			table.insert(t, { text = txt, s = sp - 1, e = ep - 2 })
		end
		return t
	end

	local u_toks = get_tokens(user_out)
	local s_toks = get_tokens(std_out)

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

	local diff_ranges, first_msg = {}, nil
	for i, d in ipairs(indices) do
		local ua, uc, sb = d[1], d[2], d[3]
		if uc > 0 then
			table.insert(diff_ranges, { u_toks[ua].s, u_toks[ua + uc - 1].e })
		else
			local pos = (ua > 0 and u_toks[ua]) and (u_toks[ua].e + 1) or 0
			table.insert(diff_ranges, { pos, pos })
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

--- 异步编译接口
--- @param file_path string 文件绝对路径
--- @param on_compile_finish function 编译完成回调 (success, msg)
function M.compile(file_path, on_compile_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local vars = get_vars(file_path)
	local cmd_raw = M.config.compile_command[ext]

	-- 如果没有配置编译命令，视为自动成功（如 Python）
	if not cmd_raw or not cmd_raw.exec or cmd_raw.exec == "" then
		log("No compilation needed for extension: ." .. ext)
		return on_compile_finish(true, "", false)
	end

	local exec = expand(cmd_raw.exec, vars)
	local args = {}
	for _, a in ipairs(cmd_raw.args or {}) do
		table.insert(args, (expand(a, vars)))
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

		log("Compilation exited with code:", code)
		if code == 0 then
			on_compile_finish(true, "", true)
		else
			on_compile_finish(false, table.concat(err_chunks), true)
		end
	end)

	if not handle then
		log("Compile spawn error:", spawn_err)
		return on_compile_finish(false, "Spawn error: " .. tostring(spawn_err), true)
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
	local exec = expand(cmd_raw.exec, vars)
	local args = {}
	for _, a in ipairs(cmd_raw.args or {}) do
		table.insert(args, (expand(a, vars)))
	end

	local out_chunks, err_chunks = {}, {}
	local stdout, stderr, stdin = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
	local start_time = uv.hrtime()
	local is_killed = false
	local handle, timer, spawn_err

	local function safe_kill()
		if handle and not handle:is_closing() then
			log("Process TLE, killing...")
			is_killed = true
			handle:kill(is_win and 15 or 9)
		end
	end

	handle, spawn_err = uv.spawn(exec, {
		args = args,
		cwd = vars.DIR,
		stdio = { stdin, stdout, stderr },
		hide = true,
	}, function(code, signal)
		if timer then
			timer:stop()
			timer:close()
		end
		local duration = math.floor((uv.hrtime() - start_time) / 1e6)

		-- 内存统计兼容性处理
		local used_kb = 0
		if handle.get_rusage then
			local rusage = handle:get_rusage()
			used_kb = rusage and rusage.maxrss or 0
			if is_mac then
				used_kb = math.floor(used_kb / 1024)
			end
		end

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
		local res = {
			input = input,
			output = user_out,
			expected = std_out,
			used_time = duration,
			used_memory = used_kb,
			state = { type = "AC" },
		}

		if is_killed or signal ~= 0 or duration > tl then
			res.state = { type = "TLE" }
		elseif ml_mb > 0 and (used_kb / 1024) > ml_mb then
			res.state = { type = "MLE" }
		elseif code ~= 0 then
			res.state = { type = "RE", msg = table.concat(err_chunks) }
		else
			local diffs, ok, msg = compute_diff_ranges(user_out, std_out, M.config.obscure)
			if not ok then
				res.state = { type = "WA", msg = msg }
				res.diff = diffs
			end
		end
		cb(res)
	end)

	if not handle then
		return cb({ state = { type = "RE", msg = "Spawn error: " .. tostring(spawn_err) } })
	end

	timer = uv.new_timer()
	timer:start(tl + 50, 0, safe_kill)

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

--- 执行所有测试用例
--- @param file_path string 文件绝对路径
--- @param json table 包含 tests, timeLimit, memoryLimit
--- @param on_case_finish function 每个用例完成后的回调
function M.run(file_path, json, on_case_finish)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local vars = get_vars(file_path)
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

--- 初始化配置
--- @param cfg table
function M.setup(cfg)
	M.config = cfg
	log("Runner module initialized.")
end

return M
