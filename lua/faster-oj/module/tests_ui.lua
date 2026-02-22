---@module "faster-oj.module.tests_ui"
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

---初始化高亮组
function M.setup(cfg)
	M.config = cfg
	local hls = cfg.highlights or {}

	-- 定义初始化辅助函数
	local function init_hl_group(prefix, colors)
		colors = colors or {}
		vim.api.nvim_set_hl(0, prefix .. "Header", { fg = colors.Header or "#808080", bold = true })
		vim.api.nvim_set_hl(0, prefix .. "Correct", { fg = colors.Correct or "#00ff00" })
		vim.api.nvim_set_hl(0, prefix .. "Warning", { fg = colors.Warning or "orange" })
		vim.api.nvim_set_hl(0, prefix .. "Wrong", { fg = colors.Wrong or "#ff0000" })
	end

	-- 初始化两套独立的高亮：Win(窗口列表) 和 Std(标准读写详情)
	init_hl_group("TestUIWin", hls.windows)
	init_hl_group("TestUIStd", hls.stdio)
end

---获取特定 key 的窗口 ID
local function get_win_by_key(key)
	local inst = ui.instances[GROUP]
	if not inst then
		return nil
	end
	local buf = inst.bufs[key]
	for _, win in ipairs(inst.wins) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
			return win
		end
	end
	return nil
end

---设置缓冲区内容和高亮
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

---刷新详情窗口（使用 Std 高亮）
local function update_details(index)
	local tc = M.state.testcases[index]
	if not tc then
		return
	end

	set_buf_content("si", vim.split(tc.input or "", "\n"))
	set_buf_content("eo", vim.split(tc.expected or "", "\n"))
	set_buf_content("info", tc.state and tc.state.msg and vim.split(tc.state.msg, "\n") or {})

	-- 只有 Standard Output (so) 需要根据对比结果着色，使用 TestUIStd 系列
	local out_hls = {}
	if tc.diff then
		for _, d in ipairs(tc.diff) do
			table.insert(out_hls, {
				group = "TestUIStdWrong", -- 使用 stdio 配置中的 Wrong 颜色
				line = d.line,
				col_start = d.start_col,
				col_end = d.end_col,
			})
		end
	end
	set_buf_content("so", vim.split(tc.output or "", "\n"), out_hls)
end

---更新主 UI 及 TC 列表（使用 Windows 高亮）
function M.update(size, testcases)
	vim.schedule(function()
		M.state.size, M.state.testcases = size, testcases or {}
		if not M.is_open() then
			return
		end

		-- TC 列表头部使用 TestUIWinHeader
		local lines, hls = { TC_HEADER }, { { group = "TestUIWinHeader", line = 0, col_start = 0, col_end = -1 } }

		for i = 0, size - 1 do
			local tc = M.state.testcases[i + 1]
			local s_type, time, mem, hl = "Running", "", "", nil
			if tc and tc.state then
				s_type = tc.state.type or "???"
				time = (tc.used_time or 0) .. "MS"
				mem = tc.used_memory < 1024 and (tc.used_memory .. "KB")
					or (string.format("%.2fMB", tc.used_memory / 1024))

				-- 根据状态选择 TestUIWinCorrect 或 TestUIWinWrong
				hl = (s_type == "AC") and "TestUIWinCorrect" or "TestUIWinWrong"
			end
			if s_type ~= "Running" then
				s_type = " " .. s_type
			end
			table.insert(lines, string.format(TC_FORMAT, "TC " .. i, s_type, time, mem))
			if hl then
				-- 状态列着色
				table.insert(hls, { group = hl, line = i + 1, col_start = 9, col_end = 18 })
			end
		end

		set_buf_content("tc", lines, hls)
		update_details(M.state.current_idx)
	end)
end

--- ... 其余函数 (bind_keys, show, close, clear) 保持之前逻辑不变 ...

function M.bind_keys()
	local inst = ui.instances[GROUP]
	local maps = M.config.tc_ui.mappings

	for key, buf in pairs(inst.bufs) do
		local opts = { buffer = buf, nowait = true, silent = true }

		if key == "tc" then
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, M.close, opts)
			end
			for _, k in ipairs(maps.view) do
				vim.keymap.set("n", k, function()
					local win = get_win_by_key("si")
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
					local win = get_win_by_key("tc")
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
				local win = get_win_by_key(next_key)
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
		if M.state.size == 0 then
			return
		end
		ui.open(GROUP, M.config.tc_ui, TITLES, WIN_OPTS, function()
			local tc_buf = ui.instances[GROUP].bufs.tc
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
			M.update(M.state.size, M.state.testcases)
		end)
	end)
end

function M.close()
	vim.schedule(function()
		ui.close(GROUP)
	end)
end

function M.is_open()
	return ui.is_open(GROUP)
end

function M.clear()
	vim.schedule(function()
		ui.clear(GROUP)
		M.state.testcases, M.state.size = {}, 0
	end)
end

return M
