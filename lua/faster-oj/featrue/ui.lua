-- ================================================================
-- FOJ UI Module
-- ================================================================
-- 负责：
--   1. 构建测试用例窗口（Testcases / Input / Output / Info / Expected Output）
--   2. 高亮显示 AC / WA / Warning
--   3. 异步更新测试用例状态与输出
--   4. 自动刷新详情窗口
-- ================================================================

---@module "faster-oj.featrue.ui"

---@class FOJUI
---@field config table 用户配置
---@field state table 内部状态
---   state.wins integer[] 窗口句柄列表
---   state.bufs integer[] 缓冲区列表
---   state.augroup integer? 自动命令组
---   state.size integer 测试用例数量
---   state.testcases table 测试用例状态列表，元素结构同 FOJ.RunResult
local M = {}

-- ================================================================
-- 常量与默认配置
-- ================================================================
local TITLES = { tc = "Testcases", si = "Input", so = "Output", info = "Info", eo = "Expected Output" }
local WIN_CONFIGS = {
	tc = { number = false, focus = true },
	si = { number = true, focus = false },
	so = { number = true, focus = false },
	info = { number = true, focus = false },
	eo = { number = true, focus = false },
}

local TC_FORMAT = "  %-7s%-9s%-9s%-10s"
local TC_HEADER = string.format(TC_FORMAT, "TESTS", "STATE", "TIME", "MEM")

local STATE_COL_START = 9
local STATE_COL_END = 18

M.state = {
	wins = {},
	bufs = {},
	augroup = nil,
	size = 0,
	testcases = {},
}

-- ================================================================
-- 📝 Setup 高亮与配置
-- ================================================================
---@param cfg table 用户配置，包含 highlights 字段
function M.setup(cfg)
	M.config = cfg
	local hl = cfg.highlights or { Correct = "#00ff00", Warning = "orange", Wrong = "#ff0000", Header = "#808080" }
	vim.api.nvim_set_hl(0, "TestUICorrect", { fg = hl.Correct })
	vim.api.nvim_set_hl(0, "TestUIWarning", { fg = hl.Warning })
	vim.api.nvim_set_hl(0, "TestUIWrong", { fg = hl.Wrong })
	vim.api.nvim_set_hl(0, "TestUIHeader", { fg = hl.Header, bold = true })
end

-- ================================================================
-- 🔹 窗口状态检查
-- ================================================================
---@return boolean 是否有窗口处于打开状态
function M.is_open()
	if not M.state.wins or #M.state.wins == 0 then
		return false
	end
	-- 检查是否至少有一个有效的窗口
	for _, w in ipairs(M.state.wins) do
		if vim.api.nvim_win_is_valid(w) then
			return true
		end
	end
	return false
end

-- ================================================================
-- 🔹 Buffer 内容更新工具
-- ================================================================
---@private
---@param key string 缓冲区标识 tc/si/so/info/eo
---@param lines string[] 内容
---@param highlights table[] 高亮列表 { group:string, line:integer, col_start:integer, col_end:integer }
local function set_buf_content(key, lines, highlights)
	local buf = M.state.bufs[key]
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	vim.bo[buf].modifiable = false

	local ns = vim.api.nvim_create_namespace("TestUI_" .. key)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	if highlights then
		for _, h in ipairs(highlights) do
			vim.api.nvim_buf_add_highlight(buf, ns, h.group, h.line, h.col_start, h.col_end)
		end
	end
end

-- 更新详细窗口显示
---@private
---@param index integer 当前测试用例序号 (0-based)
local function updata_detail_windows(index)
	if index <= 0 then
		return
	end
	local tc = M.state.testcases[index]

	if not tc or not tc.state then
		set_buf_content("si", { "Waiting for input..." })
		set_buf_content("so", { "Program is running..." })
		set_buf_content("eo", { "Waiting for expected output..." })
		set_buf_content("info", { "Task is in progress..." })
		return
	end

	set_buf_content("si", vim.split(tc.input or "", "\n"))
	set_buf_content("eo", vim.split(tc.expected or "", "\n"))

	local out_lines = vim.split(tc.output or "", "\n")
	local out_hls = {}
	for i = 0, #out_lines - 1 do
		table.insert(out_hls, { group = "TestUICorrect", line = i, col_start = 0, col_end = -1 })
	end
	if tc.diff then
		for _, d in ipairs(tc.diff) do
			table.insert(
				out_hls,
				{ group = "TestUIWrong", line = d.line, col_start = d.start_col, col_end = d.end_col }
			)
		end
	end
	set_buf_content("so", out_lines, out_hls)
	set_buf_content("info", tc.state.msg and vim.split(tc.state.msg, "\n") or {})
end

-- ================================================================
-- 🔹 异步更新测试用例状态
-- ================================================================
---@param size integer 测试用例数量
---@param testcases FOJ.RunResult[] 测试用例结果列表
function M.updata(size, testcases)
	vim.schedule(function()
		M.state.size = size
		M.state.testcases = testcases or {}

		for key, _ in pairs(TITLES) do
			M.state.bufs[key] = M.state.bufs[key] or vim.api.nvim_create_buf(false, true)
		end

		local tc_lines = { TC_HEADER }
		local tc_hls = { { group = "TestUIHeader", line = 0, col_start = 0, col_end = -1 } }

		for i = 0, size - 1 do
			local tc = testcases[i + 1]
			local s_type, time, mem, hl_group = "Running", "", "", nil

			if tc and tc.state then
				s_type = tc.state.type or "???"
				time = (tc.used_time or 0) .. "MS"
				if tc.used_memory < 1024 then
					mem = (tc.used_memory or 0) .. "KB"
				else
					mem = string.format("%.2f", (tc.used_memory or 0) / 1024) .. "MB"
				end
				hl_group = (s_type == "AC") and "TestUICorrect" or "TestUIWrong"
			end

			table.insert(tc_lines, string.format(TC_FORMAT, "TC " .. i, s_type, time, mem))

			if hl_group then
				table.insert(tc_hls, {
					group = hl_group,
					line = i + 1,
					col_start = STATE_COL_START,
					col_end = STATE_COL_END,
				})
			end
		end

		set_buf_content("tc", tc_lines, tc_hls)

		-- 核心修改：如果窗口打开，获取当前光标位置并自动刷新详情窗口
		if M.is_open() then
			local tc_buf = M.state.bufs.tc
			local win = nil
			for _, w in ipairs(M.state.wins) do
				if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == tc_buf then
					win = w
					break
				end
			end
			if win then
				local row = vim.api.nvim_win_get_cursor(win)[1]
				updata_detail_windows(row - 1)
			else
				updata_detail_windows(1)
			end
		else
			-- 窗口未打开也预先填充第一个项的数据
			updata_detail_windows(1)
		end
	end)
end

-- ================================================================
-- 🔹 窗口构建与渲染
-- ================================================================
---@private
local function open_win(key, area)
	local buf = M.state.bufs[key]
	local conf = WIN_CONFIGS[key]
	local win = vim.api.nvim_open_win(buf, conf.focus, {
		relative = "editor",
		row = area.row + 1,
		col = area.col + 1,
		width = math.max(area.width - 2, 1),
		height = math.max(area.height - 2, 1),
		style = "minimal",
		border = "rounded",
		title = " " .. TITLES[key] .. " ",
		title_pos = "center",
	})

	vim.wo[win].number = conf.number

	if key == "tc" then
		pcall(vim.api.nvim_win_set_cursor, win, { 2, 2 })
		local group = vim.api.nvim_create_augroup("TestUIInternal", { clear = true })
		vim.api.nvim_create_autocmd("CursorMoved", {
			group = group,
			buffer = buf,
			callback = function()
				local cursor = vim.api.nvim_win_get_cursor(0)
				local r, c = cursor[1], cursor[2]
				local changed = false

				if r < 2 then
					r = 2
					changed = true
				end
				if c ~= 2 then
					c = 2
					changed = true
				end

				if changed then
					pcall(vim.api.nvim_win_set_cursor, 0, { r, c })
				end
				updata_detail_windows(r - 1)
			end,
		})
	end

	vim.keymap.set("n", "q", M.close, { buffer = buf, nowait = true })
	table.insert(M.state.wins, win)
end

-- 渲染多窗口布局
---@param layout table 窗口布局配置
---@param area table 可用区域 { row, col, width, height }
function M.render_layout(layout, area)
	local total_w = 0
	for _, n in ipairs(layout) do
		total_w = total_w + n[1]
	end
	local current_col = 0
	for i, node in ipairs(layout) do
		local weight, content = node[1], node[2]
		local width = (i == #layout) and (area.width - current_col) or math.floor(area.width * weight / total_w)
		local sub = { row = area.row, col = area.col + current_col, width = width, height = area.height }
		if type(content) == "string" then
			open_win(content, sub)
		else
			local total_h, current_row = 0, 0
			for _, c in ipairs(content) do
				total_h = total_h + c[1]
			end
			for j, c in ipairs(content) do
				local h = (j == #content) and (sub.height - current_row) or math.floor(sub.height * c[1] / total_h)
				open_win(c[2], { row = sub.row + current_row, col = sub.col, width = sub.width, height = h })
				current_row = current_row + h
			end
		end
		current_col = current_col + width
	end
end

-- ================================================================
-- 🔹 窗口显示 / 关闭 / 清空
-- ================================================================
function M.show()
	vim.schedule(function()
		-- 清理旧窗口，防止重复打开
		if M.state.wins then
			for _, w in ipairs(M.state.wins) do
				if vim.api.nvim_win_is_valid(w) then
					pcall(vim.api.nvim_win_close, w, true)
				end
			end
		end
		M.state.wins = {}

		if not M.config or not M.config.ui then
			return
		end
		local ui = M.config.ui
		local ed = vim.api.nvim_list_uis()[1]
		if not ed then
			return
		end

		local w = math.floor(ed.width * ui.width)
		local h = math.floor(ed.height * ui.height)
		local area = {
			row = math.floor((ed.height - h) / 2) - 2,
			col = math.floor((ed.width - w) / 2),
			width = w,
			height = h,
		}

		M.render_layout(ui.layout, area)
		M.setup_resize()
	end)
end

function M.close()
	vim.schedule(function()
		for _, w in ipairs(M.state.wins) do
			if vim.api.nvim_win_is_valid(w) then
				pcall(vim.api.nvim_win_close, w, true)
			end
		end
		M.state.wins = {}
	end)
end

function M.clear()
	vim.schedule(function()
		for key, _ in pairs(TITLES) do
			set_buf_content(key, {})
		end
		M.state.testcases, M.state.size = {}, 0
	end)
end

-- ================================================================
-- 🔹 窗口 Resize 监听
-- ================================================================
function M.setup_resize()
	if M.state.augroup then
		return
	end
	M.state.augroup = vim.api.nvim_create_augroup("TestUIResize", { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = M.state.augroup,
		callback = function()
			-- 检查由于是异步调用，需要确认打开状态
			if M.is_open() then
				M.show()
			end
		end,
	})
end

return M
