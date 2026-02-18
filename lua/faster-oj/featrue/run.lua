local M = {}

function M.init(cfg)
	M.config = cfg
end

-- ===============================
-- 工具函数
-- ===============================

local function expand(str, ctx)
	str = str:gsub("%$%(FABSPATH%)", ctx.abs_path)
	str = str:gsub("%$%(FNAME%)", ctx.fname)
	str = str:gsub("%$%(FNOEXT%)", ctx.fnoext)
	return str
end

local function build_cmd(cmd_tbl, ctx)
	if not cmd_tbl then
		return nil
	end

	local parts = {}
	table.insert(parts, expand(cmd_tbl.exec, ctx))

	if cmd_tbl.args then
		for _, a in ipairs(cmd_tbl.args) do
			table.insert(parts, expand(a, ctx))
		end
	end

	return table.concat(parts, " ")
end

local function run_shell(cmd, stdin_data)
	local output = vim.fn.system(cmd, stdin_data or "")

	if vim.v.shell_error ~= 0 then
		return nil, output
	end

	return output, nil
end

local function normalize(s)
	-- 去除行末空格 + 末尾换行差异
	s = s:gsub("\r\n", "\n")
	s = s:gsub("[ \t]+\n", "\n")
	s = s:gsub("\n+$", "\n")
	return s
end

-- ===============================
-- 编译函数
-- ===============================
function M.compile(file_path)
	if file_path == "" then
		return false, "No file path"
	end

	local abs_path = vim.fn.fnamemodify(file_path, ":p")
	local fname = vim.fn.fnamemodify(file_path, ":t")
	local fnoext = vim.fn.fnamemodify(file_path, ":t:r")
	local ext = vim.fn.fnamemodify(file_path, ":e"):lower()

	local ctx = {
		abs_path = abs_path,
		fname = fname,
		fnoext = fnoext,
	}

	local compile_tbl = M.config.compile_command[ext]

	-- 解释型语言无需编译
	if not compile_tbl then
		return true
	end

	local cmd = build_cmd(compile_tbl, ctx)

	if M.config.server_debug then
		print("[COMPILE]", cmd)
	end

	local _, err = run_shell(cmd)

	if err then
		return false, err
	end

	return true
end

-- ===============================
-- 运行 + 判题
-- ===============================
function M.run(file_path, json)
	if file_path == "" then
		return nil, "No file path"
	end

	if not json or not json.tests then
		return nil, "Invalid test json"
	end

	local abs_path = vim.fn.fnamemodify(file_path, ":p")
	local fname = vim.fn.fnamemodify(file_path, ":t")
	local fnoext = vim.fn.fnamemodify(file_path, ":t:r")
	local ext = vim.fn.fnamemodify(file_path, ":e"):lower()

	local ctx = {
		abs_path = abs_path,
		fname = fname,
		fnoext = fnoext,
	}

	local run_tbl = M.config.run_command[ext]
	if not run_tbl then
		return nil, "No run command for " .. ext
	end

	local base_cmd = build_cmd(run_tbl, ctx)

	local outputs = {}
	local diffs = {}

	-- time / memory（简单壳层限制，Linux）
	local time_limit = (json.timeLimit or 1000) / 1000 -- ms → s
	local mem_limit = json.memoryLimit or 256 -- MB

	for i, t in ipairs(json.tests) do
		local cmd = base_cmd

		-- Linux 限制封装
		cmd = string.format("ulimit -v %d; timeout %.3f %s", mem_limit * 1024, time_limit, cmd)

		if M.config.server_debug then
			print("[RUN][" .. i .. "]", cmd)
		end

		local out, err = run_shell(cmd, t.input)

		if err then
			outputs[i] = err
			diffs[i] = false
		else
			outputs[i] = out

			-- 判题
			local ok = normalize(out) == normalize(t.output)
			diffs[i] = ok
		end
	end

	return {
		output = outputs,
		diff = diffs,
	}
end

return M
