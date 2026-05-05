---@module "faster-oj.module.solve"

local utils = require("faster-oj.module.utils")
local notify = require("faster-oj.module.notify")

---@class FOJ.SolveModule
---@field config FOJ.Config
local M = {}

local uv = vim.uv or vim.loop

function M.setup(cfg)
	M.config = cfg or {}
end

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][solve][%s] %s: %s", level, func, msg))
	end
end

local function ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

local function read_lines(path)
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	return vim.fn.readfile(path)
end

local function write_lines(path, lines)
	vim.fn.writefile(lines, path)
end

local function trim_history(history_path)
	local max_entries = (M.config and M.config.max_solve_history) or 100
	local lines = read_lines(history_path)
	if #lines <= max_entries then
		return
	end
	local trimmed = {}
	for i = #lines - max_entries + 1, #lines do
		table.insert(trimmed, lines[i])
	end
	write_lines(history_path, trimmed)
	log("INFO", "trim_history", string.format("Trimmed %d -> %d entries", #lines, #trimmed))
end

---归档当前题目到 solve_dir
---
---History 格式: 每行为 \t 分隔的路径对, 每对 (from, to) 表示一次 mv 操作
---  有数据: source_from \t source_to \t data_from \t data_to
---  无数据: source_from \t source_to
function M.solve()
	local file_path = utils.get_file_path()
	if file_path == "" then
		log("WARN", "solve", "No file to solve")
		return
	end
	if not M.config or not M.config.solve_dir then
		log("ERROR", "solve", "solve_dir not configured")
		return
	end

	local solve_dir = M.config.solve_dir
	local data_dir = M.config.data_dir
	ensure_dir(solve_dir)

	local filename = vim.fn.fnamemodify(file_path, ":t")
	local problem_name = vim.fn.fnamemodify(file_path, ":t:r")
	local abs_original = vim.fn.fnamemodify(file_path, ":p")

	vim.cmd("write")

	local problem_dir = utils.get_problem_dir_from(file_path)
	local has_data = (problem_dir ~= "" and utils.dir_exists(problem_dir))

	local history_parts = {}

	if has_data then
		-- Step 1: 源文件 → 数据文件夹内
		local src_in_data = problem_dir .. filename
		local ok, err = uv.fs_rename(abs_original, src_in_data)
		if not ok then
			log("ERROR", "solve", "Move source into data dir failed: " .. (err or ""))
			return
		end
		table.insert(history_parts, abs_original)
		table.insert(history_parts, src_in_data)

		-- Step 2: 数据文件夹 → solve_dir
		local data_target = solve_dir .. "/" .. problem_name
		local pok, perr = uv.fs_rename(problem_dir, data_target)
		if not pok then
			-- 回滚 step 1
			uv.fs_rename(src_in_data, abs_original)
			log("ERROR", "solve", "Move data dir failed: " .. (perr or ""))
			return
		end
		table.insert(history_parts, problem_dir)
		table.insert(history_parts, data_target)

		vim.cmd("bd!")
	else
		-- 单步: 源文件 → solve_dir
		local target_path = solve_dir .. "/" .. filename
		local ok, err = uv.fs_rename(abs_original, target_path)
		if not ok then
			log("ERROR", "solve", "Move source failed: " .. (err or ""))
			return
		end
		table.insert(history_parts, abs_original)
		table.insert(history_parts, target_path)

		vim.cmd("bd!")
	end

	local history_line = table.concat(history_parts, "\t")
	local history_path = solve_dir .. "/.history"
	local lines = read_lines(history_path)
	table.insert(lines, history_line)
	write_lines(history_path, lines)
	trim_history(history_path)

	log("INFO", "solve", "Solved: " .. filename)
	notify.show("Solved: " .. filename, "DONE")
end

---撤销上一次 solve 操作
---
---逐对 (from, to) 反向 mv: to → from
---若中间某对失败则终止, 跳过已损坏的历史条目
function M.solve_back()
	if not M.config or not M.config.solve_dir then
		log("ERROR", "solve_back", "solve_dir not configured")
		return
	end

	local solve_dir = M.config.solve_dir
	local history_path = solve_dir .. "/.history"

	if vim.fn.filereadable(history_path) == 0 then
		log("WARN", "solve_back", "No history file")
		return
	end

	local lines = read_lines(history_path)
	local restored_path = nil -- 用于 auto_open

	while #lines > 0 do
		local last = lines[#lines]
		local parts = vim.split(last, "\t", { plain = true })

		-- 必须为偶数个字段 (from, to 成对)
		if #parts < 2 or #parts % 2 ~= 0 then
			log("WARN", "solve_back", "Corrupted history line, skipped")
			table.remove(lines)
		else
			-- 反向遍历每对 (from, to), 执行 to → from
			local failed = false
			for i = #parts, 1, -2 do
				local from = parts[i - 1] -- 原始位置
				local to = parts[i] -- 当前位置
				-- 确保目标目录存在
				ensure_dir(vim.fn.fnamemodify(from, ":h"))
				-- 检查源是否存在
				if not utils.file_exists(to) and vim.fn.isdirectory(to) == 0 then
					log("WARN", "solve_back", "Path not found: " .. to .. ", skipping entry")
					failed = true
					break
				end
				local ok, err = uv.fs_rename(to, from)
				if not ok then
					log("ERROR", "solve_back", "Restore failed: " .. to .. " → " .. from .. " (" .. (err or "") .. ")")
					failed = true
					break
				end
				-- 记录第一个还原的源文件路径用于 auto_open
				if not restored_path and i == 2 then
					restored_path = from
				end
			end

			if failed then
				-- 终止本次撤销, 保留该行以便重试
				log("WARN", "solve_back", "Undo incomplete, history preserved")
				return
			end

			table.remove(lines)
		end
	end

	-- 写入清理后的 history
	if #lines == 0 then
		uv.fs_unlink(history_path)
	else
		write_lines(history_path, lines)
	end

	if restored_path and M.config.auto_open then
		vim.cmd("edit " .. vim.fn.fnameescape(restored_path))
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		notify.show("Restored: " .. vim.fn.fnamemodify(restored_path, ":t"), "DONE")
		log("INFO", "solve_back", "Restored: " .. restored_path)
	elseif not restored_path then
		log("INFO", "solve_back", "History empty or all entries corrupted")
	end
end

return M
