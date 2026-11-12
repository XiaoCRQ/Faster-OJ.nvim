---@module "faster-oj.server.http.handler"

local notify = require("faster-oj.module.notify")
local confirm = require("faster-oj.module.ui.confirm")

local M = {}

local YES_NO_CHOICES = {
	{ key = "y", label = "[Y] Yes", value = "yes" },
	{ key = "n", label = "[N] No", value = "no" },
}

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][http][%s] %s: %s", level, func, msg))
	end
end

---Replace characters that are invalid in cross-platform file paths.
---@param name string
---@return string
local function sanitize_problem_name(name)
	local s = name:gsub('[%c/\\:*?"<>|]', "_")
	s = s:gsub("_+", "_")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	s = s:gsub("[%.%s]+$", "")
	if s == "" then
		s = "problem"
	end
	local upper = (s:match("^([^%.]+)") or s):upper()
	local reserved = upper == "CON" or upper == "PRN" or upper == "AUX" or upper == "NUL"
		or upper:match("^COM[1-9]$") ~= nil
		or upper:match("^LPT[1-9]$") ~= nil
	if reserved then
		s = "_" .. s
	end
	return s
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

---@param path string
---@return table|nil
local function read_json_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.fn.json_decode, content)
	if ok and type(data) == "table" then
		return data
	end
	return nil
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

	if type(json) ~= "table" then
		log("ERROR", "handle", "Invalid problem payload")
		return
	end

	local data_dir = M.config.data_dir

	if not data_dir or data_dir == "" then
		log("ERROR", "handle", "data_dir not configured")
		return
	end

	vim.fn.mkdir(data_dir, "p")

	if type(json.name) ~= "string" or json.name == "" then
		log("ERROR", "handle", "Missing or invalid json.name")
		return
	end

	local original_name = json.name
	local display_name = original_name:gsub("%c", " ")
	local safe_name = sanitize_problem_name(original_name)
	if safe_name ~= original_name then
		log("INFO", "handle", "Sanitized problem name: " .. original_name .. " -> " .. safe_name)
	end

	local tests = type(json.tests) == "table" and json.tests or {}
	local problem_dir = data_dir .. "/" .. safe_name

	local function handle_source()
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
		local target_file = M.config.work_dir .. "/" .. safe_name .. ext

		local function open_target()
			if M.config.auto_open then
				vim.schedule(function()
					vim.cmd("edit " .. vim.fn.fnameescape(target_file))
					vim.api.nvim_win_set_cursor(0, { 1, 0 })
				end)
			end
		end

		local function write_source()
			local tf_out = io.open(target_file, "w")
			if tf_out then
				tf_out:write(content)
				tf_out:close()
				log("INFO", "handle", "File written: " .. target_file)
			else
				log("ERROR", "handle", "Cannot open target file: " .. target_file)
			end
			open_target()
		end

		if vim.fn.filereadable(target_file) == 1 then
			local opened = confirm.open({
				title = "Overwrite File",
				message = '"' .. display_name .. '" already exists. Overwrite?',
				choices = YES_NO_CHOICES,
				default = "no",
				on_choice = function(action)
					if action == "yes" then
						write_source()
					else
						log("INFO", "handle", "Skipped overwriting: " .. target_file)
						open_target()
					end
				end,
			})
			if not opened then
				log("WARN", "handle", "Confirmation unavailable; opening existing file")
				notify.show("Resolve the pending dialog first", "WARN")
				open_target()
			end
			return
		end

		write_source()
	end

	local function write_problem_data()
		vim.fn.mkdir(problem_dir, "p")

		-- 写入 problem.json
		local problem_json = {
			url = type(json.url) == "string" and json.url or "",
			name = original_name,
			testCount = #tests,
			memoryLimit = type(json.memoryLimit) == "number" and json.memoryLimit or 256,
			timeLimit = type(json.timeLimit) == "number" and json.timeLimit or 2000,
		}

		local ok, json_str = pcall(vim.fn.json_encode, problem_json)
		if not ok then
			log("ERROR", "handle", "JSON encode failed: " .. tostring(json_str))
			return
		end

		if not write_text_file(problem_dir .. "/problem.json", json_str) then
			log("ERROR", "handle", "Failed to write " .. problem_dir .. "/problem.json")
			vim.schedule(function()
				notify.show("Failed to save problem data", "ERROR", 3000)
			end)
			return
		end
		log("INFO", "handle", "Saved " .. problem_dir .. "/problem.json")

		-- 写入测试用例文件 (0.in, 0.out, 1.in, 1.out, ...)
		for i, tc in ipairs(tests) do
			local idx = i - 1 -- 0-based file index
			local input = type(tc) == "table" and type(tc.input) == "string" and tc.input or ""
			local output = type(tc) == "table" and type(tc.output) == "string" and tc.output or ""
			local ok_in = write_text_file(problem_dir .. "/" .. idx .. ".in", input)
			local ok_out = write_text_file(problem_dir .. "/" .. idx .. ".out", output)
			if not (ok_in and ok_out) then
				log("ERROR", "handle", string.format("Failed to write test case %d", idx))
				vim.schedule(function()
					notify.show("Failed to save problem data", "ERROR", 3000)
				end)
				return
			end
		end
		log("INFO", "handle", string.format("Wrote %d test case(s)", #tests))

		vim.schedule(function()
			notify.show("Problem received: " .. display_name, "INFO", 3000)
		end)

		handle_source()
	end

	-- Different titles can sanitize to the same folder; do not silently
	-- overwrite another problem's data.
	local existing = read_json_file(problem_dir .. "/problem.json")
	if existing and type(existing.name) == "string" and existing.name ~= original_name then
		local existing_display = existing.name:gsub("%c", " ")
		local opened = confirm.open({
			title = "Overwrite Problem Data",
			message = string.format('Problem "%s" already uses this data folder. Overwrite?', existing_display),
			choices = YES_NO_CHOICES,
			default = "no",
			on_choice = function(action)
				if action == "yes" then
					write_problem_data()
				else
					log("INFO", "handle", "Skipped overwriting data for: " .. safe_name)
				end
			end,
		})
		if not opened then
			log("WARN", "handle", "Confirmation unavailable; skipping data overwrite")
			notify.show("Resolve the pending dialog first", "WARN")
		end
		return
	end

	write_problem_data()
end

return M
