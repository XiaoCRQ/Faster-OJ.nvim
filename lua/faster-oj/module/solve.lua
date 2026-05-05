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
---有题目数据时: 源文件放入数据文件夹后一并转移
---无题目数据时: 源文件单独转移
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
	local data_dir = M.config.data_dir
	ensure_dir(solve_dir)

	local filename = vim.fn.fnamemodify(file_path, ":t")
	local problem_name = vim.fn.fnamemodify(file_path, ":t:r")
	local abs_original = vim.fn.fnamemodify(file_path, ":p")

	vim.cmd("write")

	local problem_dir = utils.get_problem_dir_from(file_path)
	local has_data = (problem_dir ~= "" and utils.dir_exists(problem_dir))

	if has_data then
		-- 有题目数据: 源文件移入数据文件夹, 再整体转移
		local src_in_data = problem_dir .. filename
		local ok, err = uv.fs_rename(abs_original, src_in_data)
		if not ok then
			log("ERROR", "solve", "Move source into data dir failed: " .. (err or ""))
			return
		end

		local data_target = solve_dir .. "/" .. problem_name
		local pok, perr = uv.fs_rename(problem_dir, data_target)
		if not pok then
			-- 回滚源文件
			uv.fs_rename(src_in_data, abs_original)
			log("ERROR", "solve", "Move data dir failed: " .. (perr or ""))
			return
		end

		vim.cmd("bd!")
	else
		-- 无题目数据: 仅转移源文件
		local target_path = solve_dir .. "/" .. filename
		local ok, err = uv.fs_rename(abs_original, target_path)
		if not ok then
			log("ERROR", "solve", "Move source failed: " .. (err or ""))
			return
		end
		vim.cmd("bd!")
	end

	-- 写入历史: file_name \t original_path \t problem_name
	local history_path = solve_dir .. "/.history"
	local history_line = string.format("%s\t%s\t%s", filename, abs_original, has_data and problem_name or "")

	local lines = read_lines(history_path)
	table.insert(lines, history_line)
	write_lines(history_path, lines)
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
	local data_dir = M.config.data_dir
	local history_path = solve_dir .. "/.history"

	if vim.fn.filereadable(history_path) == 0 then
		log("WARN", "solve_back", "No history file")
		return
	end

	local lines = read_lines(history_path)

	while #lines > 0 do
		local last = lines[#lines]
		-- 新格式: file_name \t original_path \t problem_name
		-- 旧格式兼容: file_name \t original_path \t problem_name \t problem_original_dir
		local f_name, f_path, p_name = last:match("^(.-)\t(.-)\t(.-)\t.-$")
			or last:match("^(.-)\t(.-)\t(.-)$")
		if not f_name then
			-- 更旧的格式: file_name \t original_path
			f_name, f_path = last:match("^(.-)\t(.+)$")
			p_name = ""
		end

		if not f_name or not f_path then
			table.remove(lines)
		else
			local current_f_path = solve_dir .. "/" .. f_name

			if p_name and p_name ~= "" then
				-- 有题目数据: 源文件在 solve_dir/name/filename
				current_f_path = solve_dir .. "/" .. p_name .. "/" .. f_name
			end

			if not utils.file_exists(current_f_path) then
				table.remove(lines)
			else
				-- 1. 还原
				local original_dir = vim.fn.fnamemodify(f_path, ":h")
				ensure_dir(original_dir)

				if p_name and p_name ~= "" then
					-- 有数据: 先还原整个数据文件夹, 再抽出源文件
					local current_p_dir = solve_dir .. "/" .. p_name
					local target_p_dir = data_dir .. "/" .. p_name
					ensure_dir(vim.fn.fnamemodify(target_p_dir, ":h"))

					-- 先移出源文件到原始位置
					local ok, err = uv.fs_rename(current_f_path, f_path)
					if not ok then
						log("ERROR", "solve_back", "Restore source failed: " .. (err or ""))
						return
					end

					-- 再还原数据文件夹(无源文件的数据文件夹)
					if vim.fn.isdirectory(current_p_dir) == 1 then
						ensure_dir(vim.fn.fnamemodify(target_p_dir, ":h"))
						uv.fs_rename(current_p_dir, target_p_dir)
					end
				else
					-- 无数据: 直接还原源文件
					local ok, err = uv.fs_rename(current_f_path, f_path)
					if not ok then
						log("ERROR", "solve_back", "Restore source failed: " .. (err or ""))
						return
					end
				end

				-- 2. 清理历史
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
