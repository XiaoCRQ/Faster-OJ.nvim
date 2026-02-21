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

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config and M.config.debug then
		print("[FOJ][solve]", ...)
	end
end

---@param path string
---@return boolean
local function file_exists(path)
	return uv.fs_stat(path) ~= nil
end

---@param path string
local function ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

---@param path string
---@return string[]
local function read_lines(path)
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	return vim.fn.readfile(path)
end

---@param path string
---@param lines string[]
local function write_lines(path, lines)
	vim.fn.writefile(lines, path)
end

function M.solve()
	local file_path = utils.get_file_path()

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

	local filename = vim.fn.fnamemodify(file_path, ":t")
	local abs_original = vim.fn.fnamemodify(file_path, ":p")
	local target_path = solve_dir .. "/" .. filename

	-- 保存当前文件
	vim.cmd("write")

	-- 移动文件
	local ok, err = uv.fs_rename(abs_original, target_path)
	if not ok then
		log("Move failed:", err)
		return
	end

	-- 关闭 buffer
	vim.cmd("bd!")

	-- 处理 history
	local history_path = solve_dir .. "/.history"
	local line = filename .. "\t" .. abs_original

	local lines = read_lines(history_path)
	table.insert(lines, line)
	write_lines(history_path, lines)

	log("Solved:", filename)
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

		-- 解析 TAB 分隔
		local filename, original_path = last:match("^(.-)\t(.+)$")

		if not filename or not original_path then
			-- 格式错误，删除该行
			table.remove(lines)
		else
			local current_path = solve_dir .. "/" .. filename

			if not file_exists(current_path) then
				-- 文件不存在，删除该记录
				table.remove(lines)
			else
				-- 创建原目录
				local original_dir = vim.fn.fnamemodify(original_path, ":h")
				ensure_dir(original_dir)

				local ok, err = uv.fs_rename(current_path, original_path)

				if not ok then
					log("Restore failed:", err)
					return
				end

				-- 删除该行
				table.remove(lines)
				write_lines(history_path, lines)

				-- 若为空，删除 history
				if #lines == 0 then
					uv.fs_unlink(history_path)
				end

				if M.config.open_new then
					vim.cmd("edit " .. vim.fn.fnameescape(original_path))
					vim.api.nvim_win_set_cursor(0, { 1, 0 })
				end

				log("Restored:", filename)
				return
			end
		end
	end

	-- 清空后删除 history
	if #lines == 0 then
		uv.fs_unlink(history_path)
	end

	log("History empty.")
end

return M
