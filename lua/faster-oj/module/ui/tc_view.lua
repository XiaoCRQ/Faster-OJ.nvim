---@module "faster-oj.module.ui.tc_view"

---Shared helpers for the TC-list viewers (`tests` and `tests_edit`).
---Owns the cursor policy: row changes are driven by the modules themselves,
---the buffer-local CursorMoved autocmd only normalizes native/mouse movement.

local ui = require("faster-oj.module.ui")

local M = {}

---0-based column pinned on the TC list (last character of the "TC <n>" label).
M.CURSOR_COL = 5

---Resolve the active style for a viewer.
---@param style string|nil
---@param section table|nil
---@return string
function M.get_style(style, section)
	return style or (section and section.default_style) or "float"
end

---Get the style-specific config table.
---@param section table|nil
---@param style string|nil
---@return table
function M.get_style_config(section, style)
	section = section or {}
	style = style or "float"
	return section[style] or section.float or {}
end

---Bind a list of normal-mode keys on one buffer.
---@param buf integer
---@param keys string[]|nil
---@param fn fun()
function M.bind(buf, keys, fn)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	for _, key in ipairs(keys or {}) do
		vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
	end
end

---Move the TC-list cursor to `row`, pinned to CURSOR_COL.
---@param group string
---@param style string
---@param row integer|nil
function M.focus_row(group, style, row)
	local win = ui.get_win_by_key(group, "tc", style)
	if not win then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
	row = math.max(1, math.min(row or 1, line_count))
	pcall(vim.api.nvim_win_set_cursor, win, { row, M.CURSOR_COL })
end

---@class FOJ.TCViewSpec
---@field group string
---@field style string
---@field inst table
---@field row_range fun(): integer, integer  inclusive min/max row
---@field on_row fun(row: integer)
---@field on_before_leave? fun()             runs synchronously on BufWinLeave
---@field on_leave? fun()                    runs after the instance is torn down

---Attach the shared TC-list lifecycle hooks to an open instance.
---The instance identity check replaces per-module generation counters: the
---engine rebuilds windows/buffers on toggle and resize, so callbacks that
---survive into a new instance must be ignored.
---@param spec FOJ.TCViewSpec
function M.attach(spec)
	local inst = spec.inst
	if not inst or not inst.bufs then
		return
	end

	for _, buf in pairs(inst.bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_create_autocmd("BufWinLeave", {
				buffer = buf,
				callback = function()
					if spec.on_before_leave then
						spec.on_before_leave()
					end
					vim.schedule(function()
						if ui.get_instance(spec.group, spec.style) ~= inst then
							return
						end
						if spec.on_leave then
							spec.on_leave()
						end
					end)
				end,
			})
		end
	end

	local tc_buf = inst.bufs.tc
	if not tc_buf or not vim.api.nvim_buf_is_valid(tc_buf) then
		return
	end
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = tc_buf,
		callback = function()
			local win = ui.get_win_by_key(spec.group, "tc", spec.style)
			if not win or vim.api.nvim_get_current_win() ~= win then
				return
			end
			local min_row, max_row = spec.row_range()
			if max_row < min_row then
				return
			end
			local cursor = vim.api.nvim_win_get_cursor(win)
			local row = math.max(min_row, math.min(cursor[1], max_row))
			if row ~= cursor[1] or cursor[2] ~= M.CURSOR_COL then
				pcall(vim.api.nvim_win_set_cursor, win, { row, M.CURSOR_COL })
			end
			spec.on_row(row)
		end,
	})
end

return M
