---@module "faster-oj.module.ui.stress"

local ui = require("faster-oj.module.ui")
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
	results = {},
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

function M.setup(cfg)
	M.config = cfg
	local hls = cfg.highlights or {}

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

local function set_buf_content(key, lines, highlights)
	local inst = ui.instances[GROUP]
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

---刷新详情
local function update_details(index)
	local r = M.state.results[index]
	if not r then
		return
	end

	set_buf_content("si", vim.split(r.input or "", "\n"))
	set_buf_content("eo", vim.split(r.correct and r.correct.output or "", "\n"))
	set_buf_content("so", vim.split(r.test and r.test.output or "", "\n"))

	-- info: 合并两份代码的错误信息
	local info_lines = {}
	if r.correct and r.correct.state.type ~= "OK" then
		table.insert(info_lines, "[Correct] " .. r.correct.state.type .. ": " .. (r.correct.state.msg or ""))
		table.insert(info_lines, "  time=" .. (r.correct.used_time or 0) .. "ms mem=" .. (r.correct.used_memory or 0) .. "KB")
	end
	if r.test and r.test.state.type ~= "OK" then
		table.insert(info_lines, "[Test] " .. r.test.state.type .. ": " .. (r.test.state.msg or ""))
		table.insert(info_lines, "  time=" .. (r.test.used_time or 0) .. "ms mem=" .. (r.test.used_memory or 0) .. "KB")
	end
	if r.test and r.test.state.type == "OK" and r.correct and r.correct.state.type == "OK" then
		if r.match then
			table.insert(info_lines, "Outputs match")
		else
			table.insert(info_lines, "Outputs differ")
		end
	end
	set_buf_content("info", info_lines)

	-- so 的高亮 (差异着色)
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
	set_buf_content("so", vim.split(r.test and r.test.output or "", "\n"), out_hls)
end

---更新 TC 列表和详情
function M.update(size, results)
	vim.schedule(function()
		M.state.size, M.state.results = size, results or {}
		if not M.is_open() then
			return
		end

		local lines = { TC_HEADER }
		local hls = { { group = "StressUIWinHeader", line = 0, col_start = 0, col_end = -1 } }

		for i = 0, size - 1 do
			local r = M.state.results[i + 1]
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

function M.bind_keys()
	local inst = ui.instances[GROUP]
	local maps = M.config.stress_ui.mappings

	for key, buf in pairs(inst.bufs) do
		local opts = { buffer = buf, nowait = true, silent = true }

		if key == "tc" then
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, M.close, opts)
			end
			for _, k in ipairs(maps.view) do
				vim.keymap.set("n", k, function()
					local win = ui.get_win_by_key(GROUP, "si")
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
					local win = ui.get_win_by_key(GROUP, "tc")
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
				local win = ui.get_win_by_key(GROUP, next_key)
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

function M.show()
	vim.schedule(function()
		if M.state.size == 0 or M.is_open() then
			return
		end
		ui.open(GROUP, M.config.stress_ui, TITLES, WIN_OPTS, function()
			local inst = ui.instances[GROUP]
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
			M.update(M.state.size, M.state.results)
		end)
	end)
end

function M.close(cb)
	vim.schedule(function()
		ui.close(GROUP)
		if cb then
			cb()
		end
	end)
end

function M.is_open()
	return ui.is_open(GROUP)
end

function M.clear()
	vim.schedule(function()
		ui.clear(GROUP)
		M.state.results, M.state.size = {}, 0
	end)
end

return M
