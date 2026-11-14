---@module "faster-oj.module.archive"

local utils = require("faster-oj.module.utils")
local notify = require("faster-oj.module.notify")
local confirm = require("faster-oj.module.ui.confirm")

---@class FOJ.ArchiveModule
---@field config FOJ.Config
local M = {}

local uv = vim.uv or vim.loop

function M.setup(config)
	M.config = config or {}
end

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][archive][%s] %s: %s", level, func, msg))
	end
end

---确保目录本身存在
---@param dir string
local function ensure_directory(dir)
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
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

---@param history_path string
local function trim_history(history_path)
	local max_entries = (M.config and M.config.max_archive_history) or 100
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

---删除历史记录中所有涉及 target_path 的条目
---@param history_path string
---@param target_path string
---@return integer removed
local function remove_history_entries(history_path, target_path)
	local lines = read_lines(history_path)
	local kept = {}
	local removed = 0
	for _, line in ipairs(lines) do
		local matched = false
		for _, part in ipairs(vim.split(line, "\t", { plain = true })) do
			if part == target_path then
				matched = true
				break
			end
		end
		if matched then
			removed = removed + 1
		else
			table.insert(kept, line)
		end
	end
	write_lines(history_path, kept)
	return removed
end

---归档当前题目到 archive_dir
---
---History 格式: 每行为 \t 分隔的路径对, 每对 (from, to) 表示一次 mv 操作
---  有数据: source_from \t source_to \t data_from \t data_to
---  无数据: source_from \t source_to
function M.archive()
	local file_path = utils.get_file_path()
	if file_path == "" then
		log("WARN", "archive", "No file to archive")
		return
	end
	local source_buf = vim.api.nvim_get_current_buf()
	if not M.config or not M.config.archive_dir then
		log("ERROR", "archive", "archive_dir not configured")
		return
	end

	local archive_dir = M.config.archive_dir
	ensure_directory(archive_dir)

	local filename = vim.fn.fnamemodify(file_path, ":t")
	local problem_name = vim.fn.fnamemodify(file_path, ":t:r")
	local abs_original = vim.fn.fnamemodify(file_path, ":p")

	vim.cmd("write")

	local problem_dir = utils.get_problem_dir(file_path)
	local has_data = (problem_dir ~= "" and utils.dir_exists(problem_dir))

	-- Determine target path for duplicate detection
	local target_path
	if has_data then
		target_path = archive_dir .. "/" .. problem_name
	else
		target_path = archive_dir .. "/" .. filename
	end

	local history_path = archive_dir .. "/.history"

	local function move_and_record()
		local history_parts = {}

		if has_data then
			-- Step 1: source file → data folder
			local src_in_data = problem_dir .. filename
			local ok, err = uv.fs_rename(abs_original, src_in_data)
			if not ok then
				log("ERROR", "archive", "Move source into data dir failed: " .. (err or ""))
				return
			end
			table.insert(history_parts, abs_original)
			table.insert(history_parts, src_in_data)

			-- Step 2: data folder → archive_dir
			local pok, perr = uv.fs_rename(problem_dir, target_path)
			if not pok then
				-- rollback step 1
				uv.fs_rename(src_in_data, abs_original)
				log("ERROR", "archive", "Move data dir failed: " .. (perr or ""))
				return
			end
			table.insert(history_parts, problem_dir)
			table.insert(history_parts, target_path)

			if vim.api.nvim_buf_is_valid(source_buf) then
				vim.api.nvim_buf_delete(source_buf, { force = true })
			end
		else
			-- Single step: source file → archive_dir
			local ok, err = uv.fs_rename(abs_original, target_path)
			if not ok then
				log("ERROR", "archive", "Move source failed: " .. (err or ""))
				return
			end
			table.insert(history_parts, abs_original)
			table.insert(history_parts, target_path)

			if vim.api.nvim_buf_is_valid(source_buf) then
				vim.api.nvim_buf_delete(source_buf, { force = true })
			end
		end

		local lines = read_lines(history_path)
		table.insert(lines, table.concat(history_parts, "\t"))
		write_lines(history_path, lines)
		trim_history(history_path)

		log("INFO", "archive", "Archived: " .. filename)
		notify.show("Archived: " .. filename, "DONE")
	end

	local function remove_old_and_move()
		-- Remove old data from disk
		if vim.fn.isdirectory(target_path) == 1 then
			vim.fn.delete(target_path, "rf")
		else
			os.remove(target_path)
		end

		-- Remove old entry from history
		if remove_history_entries(history_path, target_path) > 0 then
			log("INFO", "archive", "Removed old history entry for: " .. problem_name)
		end

		move_and_record()
	end

	-- Duplicate detection: check if target already exists
	local target_exists = (vim.fn.isdirectory(target_path) == 1)
		or (vim.fn.filereadable(target_path) == 1)

	if target_exists then
		-- Guard: if source file is inside the target archive, do not delete
		if abs_original == target_path
			or vim.startswith(abs_original, target_path .. "/") then
			log("INFO", "archive", "Source file is inside target archive, updating history only")
			-- Remove old history entry and update with new entry at end
			remove_history_entries(history_path, target_path)
			local new_lines = read_lines(history_path)
			local history_parts = {}
			if has_data then
				table.insert(history_parts, abs_original)
				table.insert(history_parts, abs_original)
				table.insert(history_parts, target_path)
			else
				table.insert(history_parts, abs_original)
			end
			table.insert(history_parts, target_path)
			table.insert(new_lines, table.concat(history_parts, "\t"))
			write_lines(history_path, new_lines)
			trim_history(history_path)
			log("INFO", "archive", "History updated: " .. filename)
			notify.show("History updated: " .. filename, "DONE")
			return
		end

		if M.config.confirm_on_duplicate then
			local opened = confirm.open({
				title = "Duplicate Problem",
				message = "Problem '" .. problem_name .. "' already exists in archive directory. Overwrite?",
				choices = {
					{ key = "y", label = "[Y] Yes", value = "yes" },
					{ key = "n", label = "[N] No", value = "no" },
				},
				default = "no",
				on_choice = function(action)
					if action == "yes" then
						remove_old_and_move()
					else
						log("INFO", "archive", "User declined overwrite for: " .. problem_name)
					end
				end,
			})
			if not opened then
				log("WARN", "archive", "Confirmation unavailable; skipping overwrite")
				notify.show("Resolve the pending dialog first", "WARN")
			end
			return
		end

		remove_old_and_move()
		return
	end

	move_and_record()
end

---撤销上一次归档操作
---
---逐对 (from, to) 反向 mv: to → from
---若中间某对失败则终止, 跳过已损坏的历史条目
function M.restore()
	if not M.config or not M.config.archive_dir then
		log("ERROR", "restore", "archive_dir not configured")
		return
	end

	local archive_dir = M.config.archive_dir
	local history_path = archive_dir .. "/.history"

	if vim.fn.filereadable(history_path) == 0 then
		log("WARN", "restore", "No history file")
		return
	end

	local lines = read_lines(history_path)
	if #lines == 0 then
		log("WARN", "restore", "History file empty")
		return
	end

	local restored_path = nil -- for auto_open

	-- Process only the last entry (stack/LIFO order)
	local last = lines[#lines]
	local parts = vim.split(last, "\t", { plain = true })

	-- Must have even number of fields (from, to pairs)
	if #parts < 2 or #parts % 2 ~= 0 then
		log("WARN", "restore", "Corrupted history line, removing")
		table.remove(lines)
		if #lines == 0 then
			uv.fs_unlink(history_path)
		else
			write_lines(history_path, lines)
		end
		return
	end

	-- Reverse each (from, to) pair: to → from
	local failed = false
	for i = #parts, 1, -2 do
		local from = parts[i - 1] -- original location
		local to = parts[i] -- current location
		ensure_directory(vim.fn.fnamemodify(from, ":h"))
		if not utils.file_exists(to) and vim.fn.isdirectory(to) == 0 then
			log("WARN", "restore", "Path not found: " .. to .. ", removing entry")
			failed = true
			break
		end
		local ok, err = uv.fs_rename(to, from)
		if not ok then
			log("ERROR", "restore", "Restore failed: " .. to .. " → " .. from .. " (" .. (err or "") .. ")")
			failed = true
			break
		end
		-- Record the first restored source path for auto_open
		if not restored_path and i == 2 then
			restored_path = from
		end
	end

	if failed then
		log("WARN", "restore", "Entry removed from history")
	end

	-- Remove the processed entry (success or corrupted)
	table.remove(lines)

	-- Write back history
	if #lines == 0 then
		uv.fs_unlink(history_path)
	else
		write_lines(history_path, lines)
	end

	if failed then
		return
	end

	if restored_path and M.config.auto_open then
		vim.cmd("edit " .. vim.fn.fnameescape(restored_path))
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		notify.show("Restored: " .. vim.fn.fnamemodify(restored_path, ":t"), "DONE")
		log("INFO", "restore", "Restored: " .. restored_path)
	elseif not restored_path then
		log("INFO", "restore", "History empty or all entries corrupted")
	end
end

return M
