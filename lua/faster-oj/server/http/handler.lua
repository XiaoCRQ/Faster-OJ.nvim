---@module "faster-oj.server.http.handler"

local notify = require("faster-oj.module.notify")

local M = {}

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][http][%s] %s: %s", level, func, msg))
	end
end

---写入纯文本文件
---@param path string
---@param content string
local function write_text_file(path, content)
	local f = io.open(path, "w")
	if not f then
		return false
	end
	f:write(content)
	f:close()
	return true
end

---处理来自浏览器插件的题目数据
---存储格式:
---   data_dir/
---   └── ProblemName/
---       ├── problem.json   {url, name, testCount, memoryLimit, timeLimit}
---       ├── 0.in / 0.out
---       ├── 1.in / 1.out
---       └── ...
---@param json table 原始 JSON (含 name, url, tests, memoryLimit, timeLimit)
---@param cfg table 插件配置
function M.handle(json, cfg)
	M.config = cfg
	local data_dir = M.config.data_dir

	if not data_dir or data_dir == "" then
		log("ERROR", "handle", "data_dir not configured")
		return
	end

	vim.fn.mkdir(data_dir, "p")

	if not json.name then
		log("ERROR", "handle", "Missing json.name")
		return
	end

	local tests = json.tests or {}
	local problem_dir = data_dir .. "/" .. json.name
	vim.fn.mkdir(problem_dir, "p")

	-- 写入 problem.json
	local problem_json = {
		url = json.url or "",
		name = json.name,
		testCount = #tests,
		memoryLimit = json.memoryLimit or 256,
		timeLimit = json.timeLimit or 2000,
	}

	local ok, json_str = pcall(vim.fn.json_encode, problem_json)
	if not ok then
		log("ERROR", "handle", "JSON encode failed: " .. tostring(json_str))
		return
	end

	write_text_file(problem_dir .. "/problem.json", json_str)
	log("INFO", "handle", "Saved " .. problem_dir .. "/problem.json")

	-- 写入测试用例文件 (0.in, 0.out, 1.in, 1.out, ...)
	for i, tc in ipairs(tests) do
		local idx = i - 1 -- 0-based file index
		write_text_file(problem_dir .. "/" .. idx .. ".in", tc.input or "")
		write_text_file(problem_dir .. "/" .. idx .. ".out", tc.output or "")
	end
	log("INFO", "handle", string.format("Wrote %d test case(s)", #tests))

	vim.schedule(function()
		notify.show("Problem received: " .. json.name, "INFO", 3000)
	end)

	-- 处理模板文件
	local ext = nil
	local content = ""

	if M.config.template_default and M.config.template_default ~= "" then
		local template_file = M.config.template_default
		local tf = io.open(template_file, "r")
		if tf then
			content = tf:read("*a")
			tf:close()
			ext = template_file:match("^.+(%..+)$") or M.config.template_default_ext
		else
			log("WARN", "handle", "Template file not found: " .. template_file)
		end
	end

	if ext == nil then
		ext = M.config.template_default_ext
	end

	vim.fn.mkdir(M.config.work_dir, "p")
	local target_file = M.config.work_dir .. "/" .. json.name .. ext

	local should_write = true
	if vim.fn.filereadable(target_file) == 1 then
		local choice = vim.fn.confirm('"' .. json.name .. '" already exists. Overwrite?', "&Yes\n&No", 2)
		if choice ~= 1 then
			log("INFO", "handle", "Skipped overwriting: " .. target_file)
			should_write = false
		end
	end

	if should_write then
		local tf_out = io.open(target_file, "w")
		if tf_out then
			tf_out:write(content)
			tf_out:close()
			log("INFO", "handle", "File written: " .. target_file)
		else
			log("ERROR", "handle", "Cannot open target file: " .. target_file)
		end
	end

	if M.config.auto_open then
		vim.schedule(function()
			vim.cmd("edit " .. vim.fn.fnameescape(target_file))
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
		end)
	end
end

return M
