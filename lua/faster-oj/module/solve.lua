---@module "faster-oj.module.solve"

local utils = require("faster-oj.module.utils")

---@class FOJ.SolveModule
---@field config FOJ.Config
local M = {}

local uv = vim.uv or vim.loop

---@param cfg FOJ.Config 用户传入配置
function M.setup(cfg)
	---@type FOJ.Config
	M.config = cfg or {}
end

---Debug 日志输出
local function log(...)
	if M.config and M.config.debug then
		print("[FOJ][solve]", ...)
	end
end

---确保目录存在
---@param path string
local function ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

---读取文件行
---@param path string
---@return string[]
local function read_lines(path)
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	return vim.fn.readfile(path)
end

---写入文件行
---@param path string
---@param lines string[]
local function write_lines(path, lines)
	vim.fn.writefile(lines, path)
end

function M.solve()
	local file_path = utils.get_file_path()
	local file_json_path = utils.get_json_path()

	if not file_path or file_path == "" then
		log("No file to solve.")
		return
	end

	if not M.config or not M.config.solve_dir then
		log("solve_dir not configured.")
		return
	end

	local solve_dir = M.config.solve_dir
	ensure_dir(solve_dir)

	-- 1. 处理源码文件
	local filename = vim.fn.fnamemodify(file_path, ":t")
	local abs_original = vim.fn.fnamemodify(file_path, ":p")
	local target_path = solve_dir .. "/" .. filename

	vim.cmd("write")

	local ok, err = uv.fs_rename(abs_original, target_path)
	if not ok then
		log("Move failed:", err)
		return
	end
	vim.cmd("bd!")

	-- 2. 处理 JSON 文件 (如果存在)
	local json_filename = ""
	local abs_json_original = ""

	if file_json_path and file_json_path ~= "" and vim.fn.filereadable(file_json_path) == 1 then
		json_filename = vim.fn.fnamemodify(file_json_path, ":t")
		abs_json_original = vim.fn.fnamemodify(file_json_path, ":p")
		local target_json_path = solve_dir .. "/" .. json_filename

		local jok, jerr = uv.fs_rename(abs_json_original, target_json_path)
		if not jok then
			log("JSON move failed:", jerr)
			-- 即使 JSON 失败也继续，或者你可以选择 return
		end
	end

	-- 3. 更新 History (4 列格式)
	local history_path = solve_dir .. "/.history"
	-- 格式: file_name \t file_raw_path \t file_json_name \t file_raw_json_path
	local history_line = string.format("%s\t%s\t%s\t%s", filename, abs_original, json_filename, abs_json_original)

	local lines = read_lines(history_path)
	table.insert(lines, history_line)
	write_lines(history_path, lines)

	log("Solved:", filename, json_filename ~= "" and ("with " .. json_filename) or "")
end

function M.solve_back()
	if not M.config or not M.config.solve_dir then
		log("solve_dir not configured.")
		return
	end

	local solve_dir = M.config.solve_dir
	local history_path = solve_dir .. "/.history"

	if vim.fn.filereadable(history_path) == 0 then
		log("No history file.")
		return
	end

	local lines = read_lines(history_path)

	while #lines > 0 do
		local last = lines[#lines]

		local f_name, f_path, j_name, j_path = last:match("^(.-)\t(.-)\t(.-)\t(.-)$")

		if not f_name then
			f_name, f_path = last:match("^(.-)\t(.+)$")
			j_name, j_path = "", ""
		end

		if not f_name or not f_path then
			table.remove(lines)
		else
			local current_f_path = solve_dir .. "/" .. f_name
			local current_j_path = (j_name ~= "") and (solve_dir .. "/" .. j_name) or nil

			if not utils.file_exists(current_f_path) then
				table.remove(lines)
			else
				-- 1. 还原源码文件
				local original_dir = vim.fn.fnamemodify(f_path, ":h")
				ensure_dir(original_dir)
				local ok, err = uv.fs_rename(current_f_path, f_path)
				if not ok then
					log("Restore source failed:", err)
					return
				end

				-- 2. 还原 JSON 文件 (如果有)
				if current_j_path and utils.file_exists(current_j_path) then
					local original_j_dir = vim.fn.fnamemodify(j_path, ":h")
					ensure_dir(original_j_dir)
					uv.fs_rename(current_j_path, j_path)
				end

				-- 3. 清理历史记录
				table.remove(lines)
				if #lines == 0 then
					uv.fs_unlink(history_path)
				else
					write_lines(history_path, lines)
				end

				-- 4. 打开文件
				if M.config.open_new then
					vim.cmd("edit " .. vim.fn.fnameescape(f_path))
					vim.api.nvim_win_set_cursor(0, { 1, 0 })
				end

				log("Restored:", f_name)
				return
			end
		end
	end

	if #lines == 0 and vim.fn.filereadable(history_path) == 1 then
		uv.fs_unlink(history_path)
	end
	log("History empty.")
end

return M
