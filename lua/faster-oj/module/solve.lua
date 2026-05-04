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

---确保目录存在
local function ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

---读取文件行
---@return string[]
local function read_lines(path)
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	return vim.fn.readfile(path)
end

---写入文件行
local function write_lines(path, lines)
	vim.fn.writefile(lines, path)
end

---裁剪历史条目到 max_solve_history
---@param history_path string
local function trim_history(history_path)
	local max_entries = (M.config and M.config.max_solve_history) or 100
	local lines = read_lines(history_path)
	if #lines <= max_entries then
		return
	end
	-- 保留最新的 max_entries 条
	local trimmed = {}
	for i = #lines - max_entries + 1, #lines do
		table.insert(trimmed, lines[i])
	end
	write_lines(history_path, trimmed)
	log("INFO", "trim_history", string.format("Trimmed %d -> %d entries", #lines, #trimmed))
end

---归档当前题目到 solve_dir
function M.solve()
	local file_path = utils.get_file_path()

	if not file_path or file_path == "" then
		log("WARN", "solve", "No file to solve")
		return
	end

	if not M.config or not M.config.solve_dir then
		log("ERROR", "solve", "solve_dir not configured")
		return
	end

	local solve_dir = M.config.solve_dir
	local json_dir = M.config.json_dir
	ensure_dir(solve_dir)

	local filename = vim.fn.fnamemodify(file_path, ":t")
	local problem_name = vim.fn.fnamemodify(file_path, ":t:r")
	local abs_original = vim.fn.fnamemodify(file_path, ":p")

	-- 1. 移动源文件
	vim.cmd("write")
	local target_path = solve_dir .. "/" .. filename

	local ok, err = uv.fs_rename(abs_original, target_path)
	if not ok then
		log("ERROR", "solve", "Move source failed: " .. (err or ""))
		return
	end
	vim.cmd("bd!")

	-- 2. 移动题目文件夹
	local problem_dir = json_dir .. "/" .. problem_name
	local problem_target = solve_dir .. "/" .. problem_name
	local has_problem_dir = vim.fn.isdirectory(problem_dir) == 1

	if has_problem_dir then
		local pok, perr = uv.fs_rename(problem_dir, problem_target)
		if not pok then
			log("WARN", "solve", "Move problem dir failed: " .. (perr or ""))
			has_problem_dir = false
		end
	end

	-- 3. 写入历史
	local history_path = solve_dir .. "/.history"
	-- 格式: file_name \t file_raw_path \t problem_name \t problem_original_dir
	local history_line = string.format(
		"%s\t%s\t%s\t%s",
		filename,
		abs_original,
		problem_name,
		has_problem_dir and problem_dir or ""
	)

	local lines = read_lines(history_path)
	table.insert(lines, history_line)
	write_lines(history_path, lines)

	-- 裁剪超出上限的历史条目
	trim_history(history_path)

	log("INFO", "solve", "Solved: " .. filename)
	notify.show("Solved: " .. filename, "DONE")
end

---撤销上一次 solve 操作，还原文件
function M.solve_back()
	if not M.config or not M.config.solve_dir then
		log("ERROR", "solve_back", "solve_dir not configured")
		return
	end

	local solve_dir = M.config.solve_dir
	local json_dir = M.config.json_dir
	local history_path = solve_dir .. "/.history"

	if vim.fn.filereadable(history_path) == 0 then
		log("WARN", "solve_back", "No history file")
		return
	end

	local lines = read_lines(history_path)

	while #lines > 0 do
		local last = lines[#lines]
		-- 新格式: file_name \t file_raw_path \t problem_name \t problem_original_dir
		local f_name, f_path, p_name, p_original_dir = last:match("^(.-)\t(.-)\t(.-)\t(.-)$")

		if not f_name then
			-- 兼容旧格式: file_name \t file_raw_path [\t json_name \t json_path]
			f_name, f_path = last:match("^(.-)\t(.+)$")
			p_name, p_original_dir = "", ""
		end

		if not f_name or not f_path then
			table.remove(lines)
		else
			local current_f_path = solve_dir .. "/" .. f_name
			local current_p_dir = (p_name ~= "") and (solve_dir .. "/" .. p_name) or nil

			if not utils.file_exists(current_f_path) then
				table.remove(lines)
			else
				-- 1. 还原源文件
				local original_dir = vim.fn.fnamemodify(f_path, ":h")
				ensure_dir(original_dir)
				local ok, err = uv.fs_rename(current_f_path, f_path)
				if not ok then
					log("ERROR", "solve_back", "Restore source failed: " .. (err or ""))
					return
				end

				-- 2. 还原题目文件夹
				if current_p_dir and vim.fn.isdirectory(current_p_dir) == 1 and p_original_dir ~= "" then
					local original_p_dir = p_original_dir
					ensure_dir(vim.fn.fnamemodify(original_p_dir, ":h"))
					uv.fs_rename(current_p_dir, original_p_dir)
				end

				-- 3. 清理历史
				table.remove(lines)
				if #lines == 0 then
					uv.fs_unlink(history_path)
				else
					write_lines(history_path, lines)
				end

				if M.config.auto_open then
					vim.cmd("edit " .. vim.fn.fnameescape(f_path))
					vim.api.nvim_win_set_cursor(0, { 1, 0 })
				end

				log("INFO", "solve_back", "Restored: " .. f_name)
				notify.show("Restored: " .. f_name, "DONE")
				return
			end
		end
	end

	if #lines == 0 and vim.fn.filereadable(history_path) == 1 then
		uv.fs_unlink(history_path)
	end
	log("INFO", "solve_back", "History empty")
end

return M
