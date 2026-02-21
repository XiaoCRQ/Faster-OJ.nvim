---@module "faster-oj.module.tests_manage_ui"
local utils = require("faster-oj.module.utils")
local ui = require("faster-oj.module.ui")

local M = {}
local GROUP = "ManageUI"

local TITLES = { tc = "Testcases (Manage)", si = "Input", so = "Output" }
local WIN_OPTS = {
	tc = { number = false, focus = true },
	si = { number = true },
	so = { number = true },
}

-- 编辑窗口循环顺序
local EDIT_CYCLE = { "si", "so" }

M.state = {
	json = nil,
	json_file_path = "",
	current_index = 1,
	is_updating = false, -- 锁：防止程序写入Buffer时触发内容同步回调
}

---初始化配置
function M.setup(cfg)
	M.config = cfg or {}
end

---获取特定 Key 的窗口
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

---设置 Buffer 内容
local function set_buf_content(key, lines)
	local inst = ui.instances[GROUP]
	if not inst or not inst.bufs[key] then
		return
	end
	local buf = inst.bufs[key]

	M.state.is_updating = true
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	-- 列表窗口设为不可编辑
	if key == "tc" then
		vim.bo[buf].modifiable = false
	end
	M.state.is_updating = false
end

---刷新左侧 TC 列表
local function update_tc_list()
	if not M.state.json or not M.state.json.tests then
		return
	end
	local lines = {}
	for i = 1, #M.state.json.tests do
		table.insert(lines, "  TC " .. i)
	end
	set_buf_content("tc", lines)
end

---刷新右侧编辑详情
local function update_details(index)
	if not M.state.json or not M.state.json.tests[index] then
		return
	end
	M.state.current_index = index
	local tc = M.state.json.tests[index]

	-- 移除结尾多余换行防止 Buffer 多出一行，同步时会补齐
	local in_lines = vim.split(string.gsub(tc.input or "", "\n$", ""), "\n")
	local out_lines = vim.split(string.gsub(tc.output or "", "\n$", ""), "\n")

	set_buf_content("si", in_lines)
	set_buf_content("so", out_lines)
end

---实时同步 Buffer 内容到内存 JSON 对象
local function setup_sync_logic()
	local inst = ui.instances[GROUP]
	local sync_map = { si = "input", so = "output" }

	for buf_key, json_key in pairs(sync_map) do
		local buf = inst.bufs[buf_key]
		if buf then
			vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
				buffer = buf,
				callback = function()
					if M.state.is_updating or not M.state.json then
						return
					end
					local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					local content = table.concat(lines, "\n")
					if content ~= "" then
						content = content .. "\n"
					end
					M.state.json.tests[M.state.current_index][json_key] = content
				end,
			})
		end
	end
end

---绑定按键映射
local function bind_keys()
	local inst = ui.instances[GROUP]
	local maps = M.config.tc_manage_ui.mappings

	for key, buf in pairs(inst.bufs) do
		local opts = { buffer = buf, nowait = true, silent = true }

		-- 全局写入映射 (w)
		for _, k in ipairs(maps.write) do
			vim.keymap.set("n", k, function()
				if M.state.json then
					utils.write_json(M.state.json_file_path, M.state.json)
					vim.notify(
						"[FOJ] Saved to " .. vim.fn.fnamemodify(M.state.json_file_path, ":t"),
						vim.log.levels.INFO
					)
				end
			end, opts)
		end

		if key == "tc" then
			-- TC 列表窗口映射
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, M.close, opts)
			end

			-- 进入编辑 (e/i)
			for _, k in ipairs(maps.edit) do
				vim.keymap.set("n", k, function()
					local win = get_win_by_key("si")
					if win then
						vim.api.nvim_set_current_win(win)
					end
				end, opts)
			end

			-- 列表导航 (j/k)
			for _, k in ipairs(maps.focus_next) do
				vim.keymap.set("n", k, function()
					local r = vim.api.nvim_win_get_cursor(0)[1]
					if r < #M.state.json.tests then
						vim.api.nvim_win_set_cursor(0, { r + 1, 2 })
					end
				end, opts)
			end
			for _, k in ipairs(maps.focus_prev) do
				vim.keymap.set("n", k, function()
					local r = vim.api.nvim_win_get_cursor(0)[1]
					if r > 1 then
						vim.api.nvim_win_set_cursor(0, { r - 1, 2 })
					end
				end, opts)
			end

			-- 增加 (a)
			for _, k in ipairs(maps.add) do
				vim.keymap.set("n", k, function()
					table.insert(M.state.json.tests, { input = "", output = "" })
					update_tc_list()
					vim.api.nvim_win_set_cursor(0, { #M.state.json.tests, 2 })
				end, opts)
			end

			-- 删除 (d)
			for _, k in ipairs(maps.erase) do
				vim.keymap.set("n", k, function()
					local idx = vim.api.nvim_win_get_cursor(0)[1]
					if vim.fn.confirm("Delete TC " .. idx .. "?", "&Yes\n&No", 2) == 1 then
						table.remove(M.state.json.tests, idx)
						if #M.state.json.tests == 0 then
							table.insert(M.state.json.tests, { input = "", output = "" })
						end
						update_tc_list()
						local new_r = math.min(idx, #M.state.json.tests)
						vim.api.nvim_win_set_cursor(0, { new_r, 2 })
						update_details(new_r)
					end
				end, opts)
			end
		else
			-- 编辑区 (si/so) 窗口映射
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, function()
					local win = get_win_by_key("tc")
					if win then
						vim.api.nvim_set_current_win(win)
						vim.api.nvim_win_set_cursor(win, { M.state.current_index, 2 })
					end
				end, opts)
			end

			-- 编辑窗切换 (Tab)
			local function jump(step)
				local curr_idx = 1
				for i, v in ipairs(EDIT_CYCLE) do
					if v == key then
						curr_idx = i
						break
					end
				end
				local target = EDIT_CYCLE[(curr_idx + step - 1) % #EDIT_CYCLE + 1]
				local win = get_win_by_key(target)
				if win then
					vim.api.nvim_set_current_win(win)
				end
			end
			for _, k in ipairs(maps.edit_focus_next) do
				vim.keymap.set("n", k, function()
					jump(1)
				end, opts)
			end
			for _, k in ipairs(maps.edit_focus_prev) do
				vim.keymap.set("n", k, function()
					jump(-1)
				end, opts)
			end
		end
	end
end

---异步打开管理界面
function M.manage()
	vim.schedule(function()
		if ui.is_open(GROUP) then
			return
		end

		local json = utils.get_json_file()
		if not json then
			-- 如果不存在，询问创建 (此处简化处理，假设 utils 处理了创建逻辑或调用 creat)
			if vim.fn.confirm("Data not found. Create new?", "&Yes\n&No", 2) == 1 then
				json = { tests = { { input = "", output = "" } } }
				-- utils.write_json(utils.get_json_path(), json)
			else
				return
			end
		end

		M.state.json = json
		M.state.json_file_path = utils.get_json_path()
		M.state.current_index = 1

		ui.open(GROUP, M.config.tc_manage_ui, TITLES, WIN_OPTS, function()
			local tc_buf = ui.instances[GROUP].bufs.tc

			update_tc_list()
			update_details(1)
			bind_keys()
			setup_sync_logic()

			-- 列表光标移动监听
			vim.api.nvim_create_autocmd("CursorMoved", {
				buffer = tc_buf,
				callback = function()
					local cursor = vim.api.nvim_win_get_cursor(0)
					local r = cursor[1] -- 管理界面无 Headline，从 1 开始
					if cursor[2] ~= 2 then
						vim.api.nvim_win_set_cursor(0, { r, 2 })
					end
					if r ~= M.state.current_index then
						update_details(r)
					end
				end,
			})
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

return M
