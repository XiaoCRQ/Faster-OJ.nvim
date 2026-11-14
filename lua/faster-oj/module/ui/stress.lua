---@module "faster-oj.module.ui.stress"

local ui = require("faster-oj.module.ui")
local tc_view = require("faster-oj.module.ui.tc_view")
local M = {}

local GROUP = "StressUI"
local TITLES = {
	tc = "Stress Tests",
	si = "Input",
	so = "Test Output",
	info = "Info / Errors",
	eo = "Correct Output",
}
local WIN_OPTS = {
	tc = { number = false, focus = true },
	si = { number = true },
	so = { number = true },
	info = { number = true },
	eo = { number = true },
}

local DETAIL_CYCLE = { "si", "info", "so", "eo" }
local TC_FORMAT = "  %-7s%-9s%-10s%-10s%-6s"
local TC_HEADER = string.format(TC_FORMAT, "TESTS", "STATE", "TIME(T)", "TIME(C)", "MATCH")

M.state = {
	size = 0,
	testcases = {},
	current_idx = 1,
}

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][stress_ui][%s] %s: %s", level, func, msg))
	end
end

function M.setup(config)
	M.config = config or {}
	M.current_style = M.config.stress_ui and M.config.stress_ui.default_style or "float"
	local hls = M.config.highlights or {}

	local function init_hl_group(prefix, colors)
		colors = colors or {}
		vim.api.nvim_set_hl(0, prefix .. "Header", { fg = colors.Header or "#808080", bold = true })
		vim.api.nvim_set_hl(0, prefix .. "Correct", { fg = colors.Correct or "#00ff00" })
		vim.api.nvim_set_hl(0, prefix .. "Warning", { fg = colors.Warning or "orange" })
		vim.api.nvim_set_hl(0, prefix .. "Wrong", { fg = colors.Wrong or "#ff0000" })
	end

	init_hl_group("StressUIWin", hls.windows)
	init_hl_group("StressUIStd", hls.stdio)
end

---Get current effective style
local function get_style()
	return tc_view.get_style(M.current_style, M.config and M.config.stress_ui)
end

---Get style-specific config table
local function get_style_config()
	return tc_view.get_style_config(M.config and M.config.stress_ui, get_style())
end

local function set_buf_content(key, lines, highlights)
	local inst = ui.get_instance(GROUP, get_style())
	if not inst or not inst.bufs[key] then
		return
	end
	local buf = inst.bufs[key]

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	vim.bo[buf].modifiable = false

	local ns = vim.api.nvim_create_namespace("FOJ_" .. key)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if highlights then
		for _, h in ipairs(highlights) do
			vim.api.nvim_buf_add_highlight(buf, ns, h.group, h.line, h.col_start, h.col_end or -1)
		end
	end
end

---Refresh detail panels
local function update_details(index)
	local r = M.state.testcases[index]
	if not r then
		return
	end

	set_buf_content("si", vim.split(r.input or "", "\n"))
	set_buf_content("eo", vim.split(r.correct and r.correct.actual or "", "\n"))

	local info_lines = {}
	if r.correct and r.correct.state and r.correct.state.type ~= "OK" then
		table.insert(info_lines, "[Correct] " .. r.correct.state.type .. ": " .. (r.correct.state.msg or ""))
		table.insert(info_lines, "  time=" .. (r.correct.used_time or 0) .. "ms mem=" .. (r.correct.used_memory or 0) .. "KB")
	end
	if r.test and r.test.state and r.test.state.type ~= "OK" then
		table.insert(info_lines, "[Test] " .. r.test.state.type .. ": " .. (r.test.state.msg or ""))
		table.insert(info_lines, "  time=" .. (r.test.used_time or 0) .. "ms mem=" .. (r.test.used_memory or 0) .. "KB")
	end
	if r.test and r.test.state and r.test.state.type == "OK" and r.correct and r.correct.state and r.correct.state.type == "OK" then
		if r.match then
			table.insert(info_lines, "Outputs match")
		else
			table.insert(info_lines, "Outputs differ")
		end
	end
	set_buf_content("info", info_lines)

	local out_hls = {}
	if r.diff then
		for _, d in ipairs(r.diff) do
			table.insert(out_hls, {
				group = "StressUIStdWrong",
				line = d.line,
				col_start = d.start_col,
				col_end = d.end_col,
			})
		end
	end
	set_buf_content("so", vim.split(r.test and r.test.actual or "", "\n"), out_hls)
end

---Focus a TC row and refresh the detail panels immediately.
---Keymaps call this directly because nvim_win_set_cursor does not reliably
---fire CursorMoved synchronously.
---@param row integer 1-based row in the TC list (row 1 is the header)
local function select_row(row)
	row = math.max(2, math.min(row, M.state.size + 1))
	tc_view.focus_row(GROUP, get_style(), row)
	M.state.current_idx = row - 1
	update_details(M.state.current_idx)
end

---Update TC list and details
function M.update(size, testcases)
	vim.schedule(function()
		M.state.size, M.state.testcases = size, testcases or {}
		if not M.is_open() then
			return
		end

		local lines = { TC_HEADER }
		local hls = { { group = "StressUIWinHeader", line = 0, col_start = 0, col_end = -1 } }

		for i = 0, size - 1 do
			local r = M.state.testcases[i + 1]
			local state_str, time_t, time_c, match_str, hl = "Running", "", "", "", nil
			if r then
				time_t = r.test and ((r.test.used_time or 0) .. "MS") or ""
				time_c = r.correct and ((r.correct.used_time or 0) .. "MS") or ""
				if r.test and r.test.state.type ~= "OK" then
					state_str = r.test.state.type
					match_str = "-"
					hl = "StressUIWinWrong"
				elseif r.correct and r.correct.state.type ~= "OK" then
					state_str = "CE"
					match_str = "-"
					hl = "StressUIWinWrong"
				elseif r.match then
					state_str = "OK"
					match_str = "YES"
					hl = "StressUIWinCorrect"
				else
					state_str = "WA"
					match_str = "NO"
					hl = "StressUIWinWrong"
				end
			end
			if state_str ~= "Running" then
				state_str = " " .. state_str
			end
			table.insert(lines, string.format(TC_FORMAT, "TC " .. i, state_str, time_t, time_c, match_str))
			if hl then
				table.insert(hls, { group = hl, line = i + 1, col_start = 9, col_end = 18 })
			end
		end

		set_buf_content("tc", lines, hls)
		update_details(M.state.current_idx)
	end)
end

---Set up the current instance (open / style toggle / resize).
---@param style string
local function setup_viewer(style)
	local inst = ui.get_instance(GROUP, style)
	if not inst or not inst.bufs then
		return
	end

	tc_view.attach({
		group = GROUP,
		style = style,
		inst = inst,
		row_range = function()
			return 2, M.state.size + 1
		end,
		on_row = function(row)
			M.state.current_idx = row - 1
			update_details(M.state.current_idx)
		end,
		on_leave = function()
			if M.is_open() then
				M.close()
			end
		end,
	})

	M.bind_keys()
	M.update(M.state.size, M.state.testcases)
	-- M.update renders on the next tick; focus after its buffer rewrite.
	vim.schedule(function()
		if ui.get_instance(GROUP, style) ~= inst then
			return
		end
		tc_view.focus_row(GROUP, style, M.state.current_idx + 1)
	end)
end

---Toggle between float and split styles
local function do_toggle_style(old_style, new_style)
	local saved = {
		size = M.state.size,
		testcases = M.state.testcases,
		idx = M.state.current_idx,
	}

	ui.close_style(GROUP, old_style)
	M.current_style = new_style
	ui.open(GROUP, new_style, get_style_config(), TITLES, WIN_OPTS, function()
		M.state.size = saved.size
		M.state.testcases = saved.testcases
		M.state.current_idx = math.min(math.max(saved.idx, 1), math.max(saved.size, 1))
		setup_viewer(new_style)
	end)
end

function M.toggle_style()
	local old_style = get_style()
	local new_style = (old_style == "float") and "split" or "float"
	local edit = require("faster-oj.module.ui.tests_edit")
	if edit.is_open() and edit.current_style == new_style then
		edit.close(function(ok)
			if ok then
				do_toggle_style(old_style, new_style)
			end
		end)
		return
	end
	do_toggle_style(old_style, new_style)
end

function M.bind_keys()
	local inst = ui.get_instance(GROUP, get_style())
	if not inst then
		return
	end
	local style = get_style()
	local maps = M.config.stress_ui.mappings

	local function focus_tc()
		local win = ui.get_win_by_key(GROUP, "tc", style)
		if win then
			vim.api.nvim_set_current_win(win)
			tc_view.focus_row(GROUP, style, M.state.current_idx + 1)
		end
	end

	local function move(step)
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local target = row + step
		if target >= 2 and target <= M.state.size + 1 then
			select_row(target)
		end
	end

	local function focus_details()
		local win = ui.get_win_by_key(GROUP, "si", style)
		if win then
			vim.api.nvim_set_current_win(win)
		end
	end

	local function jump(key, step)
		local curr_idx = 1
		for i, v in ipairs(DETAIL_CYCLE) do
			if v == key then
				curr_idx = i
				break
			end
		end
		local next_key = DETAIL_CYCLE[(curr_idx + step - 1) % #DETAIL_CYCLE + 1]
		local win = ui.get_win_by_key(GROUP, next_key, style)
		if win then
			vim.api.nvim_set_current_win(win)
		end
	end

	for key, buf in pairs(inst.bufs) do
		tc_view.bind(buf, maps.toggle_style, M.toggle_style)
		if key == "tc" then
			tc_view.bind(buf, maps.close, M.close)
			tc_view.bind(buf, maps.view, focus_details)
			tc_view.bind(buf, maps.focus_next, function()
				move(1)
			end)
			tc_view.bind(buf, maps.focus_prev, function()
				move(-1)
			end)
		else
			tc_view.bind(buf, maps.close, focus_tc)
			tc_view.bind(buf, maps.view_focus_next, function()
				jump(key, 1)
			end)
			tc_view.bind(buf, maps.view_focus_prev, function()
				jump(key, -1)
			end)
		end
	end
end

function M.show(style)
	vim.schedule(function()
		if style then
			M.current_style = style
		end
		if M.state.size == 0 then
			return
		end

		local s = get_style()
		if ui.is_open(GROUP, s) then
			return
		end

		local function open()
			-- Close other style of same viewer, engine handles cross-viewer same-style interlock
			local other = (s == "float") and "split" or "float"
			ui.close_style(GROUP, other)

			ui.open(GROUP, s, get_style_config(), TITLES, WIN_OPTS, function()
				setup_viewer(s)
			end)
		end

		local edit = require("faster-oj.module.ui.tests_edit")
		if edit.is_open() and edit.current_style == s then
			edit.close(function(ok)
				if ok then
					open()
				end
			end)
		else
			open()
		end
	end)
end

function M.close(cb)
	vim.schedule(function()
		ui.close_style(GROUP, get_style())
		if cb then
			cb()
		end
	end)
end

function M.is_open()
	return ui.is_open(GROUP, get_style())
end

function M.clear()
	vim.schedule(function()
		ui.clear(GROUP)
		M.state.testcases, M.state.size = {}, 0
	end)
end

return M
