---@module "faster-oj.module.ui.tests_edit"

local utils = require("faster-oj.module.utils")
local ui = require("faster-oj.module.ui")
local notify = require("faster-oj.module.notify")

local M = {}
local GROUP = "EditUI"

local TITLES = { tc = "Testcases (Edit)", si = "Input", so = "Output" }
local WIN_OPTS = {
	tc = { number = false, focus = true },
	si = { number = true },
	so = { number = true },
}

local EDIT_CYCLE = { "si", "so" }

M.state = {
	problem_dir = "",
	test_count = 0,
	current_index = 1,
	is_updating = false,
}

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][edit_ui][%s] %s: %s", level, func, msg))
	end
end

function M.setup(cfg)
	M.config = cfg or {}
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
	if key == "tc" then
		vim.bo[buf].modifiable = false
	end
	M.state.is_updating = false
end

---刷新 TC 列表
local function update_tc_list()
	local lines = {}
	for i = 1, M.state.test_count do
		table.insert(lines, "  TC " .. i - 1)
	end
	set_buf_content("tc", lines)
end

---保存当前编辑缓冲区到文件
local function flush_current_to_file()
	if M.state.current_index < 1 or M.state.current_index > M.state.test_count then
		return
	end
	local inst = ui.instances[GROUP]
	local file_idx = M.state.current_index - 1

	if inst and inst.bufs["si"] and vim.api.nvim_buf_is_valid(inst.bufs["si"]) then
		local lines = vim.api.nvim_buf_get_lines(inst.bufs["si"], 0, -1, false)
		local content = table.concat(lines, "\n")
		utils.write_file(M.state.problem_dir .. file_idx .. ".in", content)
	end
	if inst and inst.bufs["so"] and vim.api.nvim_buf_is_valid(inst.bufs["so"]) then
		local lines = vim.api.nvim_buf_get_lines(inst.bufs["so"], 0, -1, false)
		local content = table.concat(lines, "\n")
		utils.write_file(M.state.problem_dir .. file_idx .. ".out", content)
	end
end

---加载测试用例到缓冲区
local function update_details(index)
	if index < 1 or index > M.state.test_count then
		return
	end

	-- 保存当前缓冲区
	if index ~= M.state.current_index then
		flush_current_to_file()
	end

	M.state.current_index = index
	local file_idx = index - 1

	local in_content = utils.read_file(M.state.problem_dir .. file_idx .. ".in") or ""
	local out_content = utils.read_file(M.state.problem_dir .. file_idx .. ".out") or ""

	set_buf_content("si", vim.split(in_content:gsub("\n$", ""), "\n"))
	set_buf_content("so", vim.split(out_content:gsub("\n$", ""), "\n"))
end

---实时同步 Buffer 到文件 (TextChanged)
local function setup_sync_logic()
	local inst = ui.instances[GROUP]
	local sync_map = { si = "in", so = "out" }

	for buf_key, ext in pairs(sync_map) do
		local buf = inst.bufs[buf_key]
		if buf then
			vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
				buffer = buf,
				callback = function()
					if M.state.is_updating or M.state.current_index < 1 then
						return
					end
					local file_idx = M.state.current_index - 1
					local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					local content = table.concat(lines, "\n")
					utils.write_file(M.state.problem_dir .. file_idx .. "." .. ext, content)
				end,
			})
		end
	end
end

---保存并更新 testCount
function M.save()
	flush_current_to_file()
	utils.update_test_count(M.state.problem_dir, M.state.test_count)

	local inst = ui.instances[GROUP]
	if inst then
		for _, buf in pairs(inst.bufs) do
			vim.bo[buf].modified = false
		end
	end
	notify.show("Problem data saved", "INFO")
	log("INFO", "save", "Saved to " .. M.state.problem_dir)
end

---绑定按键映射
local function bind_keys()
	local inst = ui.instances[GROUP]
	local maps = M.config.tc_edit_ui.mappings

	for key, buf in pairs(inst.bufs) do
		local opts = { buffer = buf, nowait = true, silent = true }

		for _, k in ipairs(maps.write) do
			vim.keymap.set("n", k, M.save, opts)
		end

		if key == "tc" then
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, M.close, opts)
			end
			for _, k in ipairs(maps.edit) do
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
					if r < M.state.test_count then
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
			-- 新增测试用例
			for _, k in ipairs(maps.add) do
				vim.keymap.set("n", k, function()
					local new_idx = M.state.test_count
					utils.write_file(M.state.problem_dir .. new_idx .. ".in", "")
					utils.write_file(M.state.problem_dir .. new_idx .. ".out", "")
					M.state.test_count = M.state.test_count + 1
					update_tc_list()
					vim.api.nvim_win_set_cursor(0, { M.state.test_count, 2 })
				end, opts)
			end
			-- 删除测试用例
			for _, k in ipairs(maps.erase) do
				vim.keymap.set("n", k, function()
					local idx = vim.api.nvim_win_get_cursor(0)[1]
					if M.state.test_count <= 1 then
						return -- 至少保留一个
					end
					if vim.fn.confirm("Delete TC " .. idx - 1 .. "?", "&Yes\n&No", 2) == 1 then
						flush_current_to_file()
						utils.delete_test_case(M.state.problem_dir, idx - 1, M.state.test_count)
						M.state.test_count = M.state.test_count - 1
						update_tc_list()
						local new_r = math.min(idx, M.state.test_count)
						vim.api.nvim_win_set_cursor(0, { new_r, 2 })
						update_details(new_r)
					end
				end, opts)
			end
		else
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, function()
					local win = ui.get_win_by_key(GROUP, "tc")
					if win then
						vim.api.nvim_set_current_win(win)
						vim.api.nvim_win_set_cursor(win, { M.state.current_index, 2 })
					end
				end, opts)
			end
			local function jump(step)
				local curr_idx = 1
				for i, v in ipairs(EDIT_CYCLE) do
					if v == key then
						curr_idx = i
						break
					end
				end
				local target = EDIT_CYCLE[(curr_idx + step - 1) % #EDIT_CYCLE + 1]
				local win = ui.get_win_by_key(GROUP, target)
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

function M.edit()
	vim.schedule(function()
		if ui.is_open(GROUP) then
			return
		end

		local problem_dir = utils.get_problem_dir()
		if problem_dir == "" or not utils.dir_exists(problem_dir) then
			if vim.fn.confirm("Problem data not found. Create new?", "&Yes\n&No", 2) == 1 then
				utils.ensure_dir(problem_dir)
				-- 创建最小 problem.json
				utils.write_json(problem_dir .. "problem.json", {
					url = "",
					name = vim.fn.fnamemodify(utils.get_file_path(), ":t:r"),
					testCount = 1,
					memoryLimit = 256,
					timeLimit = 2000,
				})
				utils.write_file(problem_dir .. "0.in", "")
				utils.write_file(problem_dir .. "0.out", "")
			else
				return
			end
		end

		local test_count = utils.get_test_count(problem_dir)

		M.state.problem_dir = problem_dir
		M.state.test_count = math.max(test_count, 1)
		M.state.current_index = 1

		ui.open(GROUP, M.config.tc_edit_ui, TITLES, WIN_OPTS, function()
			local inst = ui.instances[GROUP]
			local tc_buf = inst.bufs.tc

			-- :q 关闭处理
			for _, buf in pairs(inst.bufs) do
				vim.api.nvim_create_autocmd("BufWinLeave", {
					buffer = buf,
					callback = function()
						vim.schedule(function()
							if M.is_open() then
								-- 关闭前保存
								flush_current_to_file()
								utils.update_test_count(M.state.problem_dir, M.state.test_count)
								M.close()
							end
						end)
					end,
				})
			end

			update_tc_list()
			update_details(1)
			bind_keys()
			setup_sync_logic()

			vim.api.nvim_create_autocmd("CursorMoved", {
				buffer = tc_buf,
				callback = function()
					local cursor = vim.api.nvim_win_get_cursor(0)
					local r = cursor[1]
					if cursor[2] ~= 5 then
						vim.api.nvim_win_set_cursor(0, { r, 5 })
					end
					if r ~= M.state.current_index then
						update_details(r)
					end
				end,
			})
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

return M
