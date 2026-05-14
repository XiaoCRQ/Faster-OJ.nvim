---@module "faster-oj.module.ui.tests"

local ui = require("faster-oj.module.ui")
local M = {}

local GROUP = "TestUI"
local TITLES = { tc = "Testcases", si = "Input", so = "Output", info = "Info", eo = "Expected Output" }
local WIN_OPTS = {
	tc = { number = false, focus = true },
	si = { number = true },
	so = { number = true },
	info = { number = true },
	eo = { number = true },
}

local DETAIL_CYCLE = { "si", "info", "so", "eo" }
local TC_FORMAT = "  %-7s%-9s%-9s%-10s"
local TC_HEADER = string.format(TC_FORMAT, "TESTS", "STATE", "TIME", "MEM")

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
		print(string.format("[FOJ][tests_ui][%s] %s: %s", level, func, msg))
	end
end

function M.setup(cfg)
	M.config = cfg
	M.current_style = cfg.tc_ui and cfg.tc_ui.default_style or "float"
	local hls = cfg.highlights or {}

	local function init_hl_group(prefix, colors)
		colors = colors or {}
		vim.api.nvim_set_hl(0, prefix .. "Header", { fg = colors.Header or "#808080", bold = true })
		vim.api.nvim_set_hl(0, prefix .. "Correct", { fg = colors.Correct or "#00ff00" })
		vim.api.nvim_set_hl(0, prefix .. "Warning", { fg = colors.Warning or "orange" })
		vim.api.nvim_set_hl(0, prefix .. "Wrong", { fg = colors.Wrong or "#ff0000" })
	end

	init_hl_group("TestUIWin", hls.windows)
	init_hl_group("TestUIStd", hls.stdio)
end

---Get current effective style
local function get_style()
	return M.current_style or (M.config.tc_ui and M.config.tc_ui.default_style) or "float"
end

---Get style-specific config table
local function get_style_config()
	local ui_cfg = M.config.tc_ui
	local s = get_style()
	return ui_cfg[s] or ui_cfg.float
end

---Set buffer content with highlights
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
	local tc = M.state.testcases[index]
	if not tc then
		return
	end

	set_buf_content("si", vim.split(tc.input or "", "\n"))
	set_buf_content("eo", vim.split(tc.expected or "", "\n"))
	set_buf_content("info", tc.state and tc.state.msg and vim.split(tc.state.msg, "\n") or {})

	local out_hls = {}
	if tc.diff then
		for _, d in ipairs(tc.diff) do
			table.insert(out_hls, {
				group = "TestUIStdWrong",
				line = d.line,
				col_start = d.start_col,
				col_end = d.end_col,
			})
		end
	end
	set_buf_content("so", vim.split(tc.output or "", "\n"), out_hls)
end

---Update TC list and details
function M.update(size, testcases)
	vim.schedule(function()
		M.state.size, M.state.testcases = size, testcases or {}
		if not M.is_open() then
			return
		end

		local lines, hls = { TC_HEADER }, { { group = "TestUIWinHeader", line = 0, col_start = 0, col_end = -1 } }

		for i = 0, size - 1 do
			local tc = M.state.testcases[i + 1]
			local s_type, time, mem, hl = "Running", "", "", nil
			if tc and tc.state then
				s_type = tc.state.type or "???"
				time = (tc.used_time or 0) .. "MS"
				mem = tc.used_memory < 1024 and (tc.used_memory .. "KB")
					or (string.format("%.2fMB", tc.used_memory / 1024))

				hl = (s_type == "AC") and "TestUIWinCorrect" or "TestUIWinWrong"
			end
			if s_type ~= "Running" then
				s_type = " " .. s_type
			end
			table.insert(lines, string.format(TC_FORMAT, "TC " .. i, s_type, time, mem))
			if hl then
				table.insert(hls, { group = hl, line = i + 1, col_start = 9, col_end = 18 })
			end
		end

		set_buf_content("tc", lines, hls)
		update_details(M.state.current_idx)
	end)
end

---Toggle between float and split styles
function M.toggle_style()
	local old_style = get_style()
	local new_style = (old_style == "float") and "split" or "float"

	-- Save state
	local saved_size = M.state.size
	local saved_cases = {}
	for i, tc in ipairs(M.state.testcases) do
		saved_cases[i] = {
			input = tc.input,
			expected = tc.expected,
			output = tc.output,
			diff = tc.diff,
			state = tc.state,
			used_time = tc.used_time,
			used_memory = tc.used_memory,
		}
	end

	-- Close old style
	ui.close_style(GROUP, old_style)

	-- Open new style
	M.current_style = new_style
	local cfg = get_style_config()
	ui.open(GROUP, new_style, cfg, TITLES, WIN_OPTS, function()
		local inst = ui.get_instance(GROUP, new_style)
		local tc_buf = inst.bufs.tc

		-- BufWinLeave cleanup
		for _, buf in pairs(inst.bufs) do
			vim.api.nvim_create_autocmd("BufWinLeave", {
				buffer = buf,
				once = true,
				callback = function()
					vim.schedule(function()
						if M.is_open() then
							M.close()
						end
					end)
				end,
			})
		end

		M.bind_keys()

		vim.api.nvim_clear_autocmds({ buffer = tc_buf, event = "CursorMoved" })
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = tc_buf,
			callback = function()
				local cursor = vim.api.nvim_win_get_cursor(0)
				local r = math.max(2, cursor[1])
				if r ~= cursor[1] or cursor[2] ~= 5 then
					vim.api.nvim_win_set_cursor(0, { r, 5 })
				end
				M.state.current_idx = r - 1
				update_details(M.state.current_idx)
			end,
		})

		-- Restore state
		M.state.size = saved_size
		M.state.testcases = saved_cases
		M.state.current_idx = 1
		M.update(saved_size, saved_cases)
	end)
end

function M.bind_keys()
	local inst = ui.get_instance(GROUP, get_style())
	if not inst then
		return
	end
	local maps = M.config.tc_ui.mappings

	for key, buf in pairs(inst.bufs) do
		local opts = { buffer = buf, nowait = true, silent = true }

		-- Toggle style key on all buffers
		if maps.toggle_style then
			for _, k in ipairs(maps.toggle_style) do
				vim.keymap.set("n", k, M.toggle_style, opts)
			end
		end

		if key == "tc" then
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, M.close, opts)
			end
			for _, k in ipairs(maps.view) do
				vim.keymap.set("n", k, function()
					local win = ui.get_win_by_key(GROUP, "si", get_style())
					if win then
						vim.api.nvim_set_current_win(win)
					end
				end, opts)
			end
			for _, k in ipairs(maps.focus_next) do
				vim.keymap.set("n", k, function()
					local r = vim.api.nvim_win_get_cursor(0)[1]
					if r < M.state.size + 1 then
						vim.api.nvim_win_set_cursor(0, { r + 1, 2 })
					end
				end, opts)
			end
			for _, k in ipairs(maps.focus_prev) do
				vim.keymap.set("n", k, function()
					local r = vim.api.nvim_win_get_cursor(0)[1]
					if r > 2 then
						vim.api.nvim_win_set_cursor(0, { r - 1, 2 })
					end
				end, opts)
			end
		else
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, function()
					local win = ui.get_win_by_key(GROUP, "tc", get_style())
					if win then
						vim.api.nvim_set_current_win(win)
						vim.api.nvim_win_set_cursor(win, { M.state.current_idx + 1, 2 })
					end
				end, opts)
			end
			local function jump(step)
				local curr_idx = 1
				for i, v in ipairs(DETAIL_CYCLE) do
					if v == key then
						curr_idx = i
						break
					end
				end
				local next_key = DETAIL_CYCLE[(curr_idx + step - 1) % #DETAIL_CYCLE + 1]
				local win = ui.get_win_by_key(GROUP, next_key, get_style())
				if win then
					vim.api.nvim_set_current_win(win)
				end
			end
			for _, k in ipairs(maps.view_focus_next) do
				vim.keymap.set("n", k, function()
					jump(1)
				end, opts)
			end
			for _, k in ipairs(maps.view_focus_prev) do
				vim.keymap.set("n", k, function()
					jump(-1)
				end, opts)
			end
		end
	end
end

---@param style? string  style override; nil uses M.current_style or default
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

		-- Close other style of same viewer, engine handles cross-viewer same-style interlock
		local other = (s == "float") and "split" or "float"
		ui.close_style(GROUP, other)

		local cfg = get_style_config()
		ui.open(GROUP, s, cfg, TITLES, WIN_OPTS, function()
			local inst = ui.get_instance(GROUP, s)
			local tc_buf = inst.bufs.tc

			for _, buf in pairs(inst.bufs) do
				vim.api.nvim_create_autocmd("BufWinLeave", {
					buffer = buf,
					callback = function()
						vim.schedule(function()
							if M.is_open() then
								M.close()
							end
						end)
					end,
				})
			end

			M.bind_keys()

			vim.api.nvim_clear_autocmds({ buffer = tc_buf, event = "CursorMoved" })
			vim.api.nvim_create_autocmd("CursorMoved", {
				buffer = tc_buf,
				callback = function()
					local cursor = vim.api.nvim_win_get_cursor(0)
					local r = math.max(2, cursor[1])
					if r ~= cursor[1] or cursor[2] ~= 5 then
						vim.api.nvim_win_set_cursor(0, { r, 5 })
					end
					M.state.current_idx = r - 1
					update_details(M.state.current_idx)
				end,
			})
			M.update(M.state.size, M.state.testcases)
		end)
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
