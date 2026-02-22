---@module "faster-oj.module.ui"
local M = {}

-- 存储所有组的状态
M.instances = {}

---获取或初始化组状态
local function get_inst(group)
	if not M.instances[group] then
		M.instances[group] = {
			wins = {},
			bufs = {},
			augroup = nil,
			last_args = nil, -- 用于 resize 时重新渲染
		}
	end
	return M.instances[group]
end

local function normalize_layout(raw_layout)
	if type(raw_layout) ~= "table" then
		return {}
	end

	-- 情况 A: 传入的是单节点 {weight, content} 而不是节点列表
	-- 判断标准：第一个元素是数字，且第二个元素是字符串或表
	if type(raw_layout[1]) == "number" and (type(raw_layout[2]) == "string" or type(raw_layout[2]) == "table") then
		raw_layout = { raw_layout }
	end

	local normalized = {}
	for _, item in ipairs(raw_layout) do
		if type(item) == "table" then
			local weight = item[1] or 1
			local content

			-- 情况 B: 平铺式嵌套 {weight, {w1, c1}, {w2, c2}, ...}
			-- 如果第二个元素是表，且该表的第一项是数字，说明它是子节点而非节点列表
			if type(item[2]) == "table" and type(item[2][1]) == "number" then
				content = {}
				for i = 2, #item do
					table.insert(content, item[i])
				end
			else
				-- 标准式嵌套 {weight, "key"} 或 {weight, {{w,c}, {w,c}}}
				content = item[2]
			end
			table.insert(normalized, { weight, content })
		end
	end
	return normalized
end

---递归渲染布局
---@param group_name string 组名
---@param layout table 布局配置
---@param area table 区域参数
---@param titles table 标题
---@param win_opts table 窗口配置
local function render_recursive(group_name, layout, area, titles, win_opts)
	local inst = get_inst(group_name)
	local nodes = normalize_layout(layout)
	local total_weight = 0
	for _, node in ipairs(nodes) do
		total_weight = total_weight + node[1]
	end

	local current_pos = 0
	for i, node in ipairs(nodes) do
		local weight, content = node[1], node[2]
		local is_last = (i == #nodes)
		local size = is_last and (area.total_size - current_pos) or math.floor(area.total_size * weight / total_weight)
		size = math.max(size, 1)

		if type(content) == "string" then
			local key = content
			if not inst.bufs[key] or not vim.api.nvim_buf_is_valid(inst.bufs[key]) then
				inst.bufs[key] = vim.api.nvim_create_buf(false, true)
			end
			local buf = inst.bufs[key]
			local opt = win_opts[key] or {}

			local win_w = math.max((area.is_horizontal and size or area.width) - 2, 1)
			local win_h = math.max((area.is_horizontal and area.height or size) - 2, 1)

			local win = vim.api.nvim_open_win(buf, opt.focus or false, {
				relative = "editor",
				row = area.is_horizontal and area.row or (area.row + current_pos),
				col = area.is_horizontal and (area.col + current_pos) or area.col,
				width = win_w,
				height = win_h,
				style = "minimal",
				border = "rounded",
				title = titles[key] and (" " .. titles[key] .. " ") or nil,
				title_pos = "center",
			})

			vim.wo[win].number = opt.number or false
			table.insert(inst.wins, win)
		elseif type(content) == "table" then
			local sub_area = {
				row = area.is_horizontal and area.row or (area.row + current_pos),
				col = area.is_horizontal and (area.col + current_pos) or area.col,
				width = area.is_horizontal and size or area.width,
				height = area.is_horizontal and area.height or size,
				is_horizontal = not area.is_horizontal,
			}
			sub_area.total_size = sub_area.is_horizontal and sub_area.width or sub_area.height
			render_recursive(group_name, content, sub_area, titles, win_opts)
		end
		current_pos = current_pos + size
	end
end

---显示 UI
---@param group string 组名，用于隔离不同功能的 UI
---@param config table UI布局配置 {width, height, layout}
---@param titles table 标题映射 {buf_key = "Title"}
---@param win_opts table 窗口额外配置 {buf_key = {focus=bool, number=bool}}
---@param on_win_created function 回调
function M.open(group, config, titles, win_opts, on_win_created)
	local inst = get_inst(group)
	inst.last_args = { config, titles, win_opts, on_win_created }

	vim.schedule(function()
		M.close(group)

		local uis = vim.api.nvim_list_uis()
		if #uis == 0 then
			return
		end
		local ed = uis[1]

		local w = math.floor(ed.width * (config.width or 0.8))
		local h = math.floor(ed.height * (config.height or 0.8))

		local area = {
			row = math.floor((ed.height - h) / 2),
			col = math.floor((ed.width - w) / 2),
			width = w,
			height = h,
			total_size = w,
			is_horizontal = true,
		}

		render_recursive(group, config.layout, area, titles or {}, win_opts or {})

		if on_win_created then
			on_win_created()
		end

		M.setup_resize(group)
	end)
end

---关闭特定组的窗口
---@param group string
function M.close(group)
	local inst = M.instances[group]
	if not inst then
		return
	end

	for _, w in ipairs(inst.wins) do
		if vim.api.nvim_win_is_valid(w) then
			pcall(vim.api.nvim_win_close, w, true)
		end
	end
	inst.wins = {}
end

---清理特定组的所有数据（包括 buffer 和 autocmd）
---@param group string
function M.clear(group)
	M.close(group)
	local inst = M.instances[group]
	if not inst then
		return
	end

	-- 清理 buffer
	for _, buf in pairs(inst.bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end

	-- 清理 autocmd
	if inst.augroup then
		vim.api.nvim_del_augroup_by_id(inst.augroup)
	end

	M.instances[group] = nil
end

---检查特定组是否处于打开状态
function M.is_open(group)
	local inst = M.instances[group]
	if not inst then
		return false
	end
	for _, w in ipairs(inst.wins) do
		if vim.api.nvim_win_is_valid(w) then
			return true
		end
	end
	return false
end

---设置重绘监听
function M.setup_resize(group)
	local inst = get_inst(group)
	if inst.augroup then
		return
	end

	inst.augroup = vim.api.nvim_create_augroup("FOJUIResize_" .. group, { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = inst.augroup,
		callback = function()
			if M.is_open(group) and inst.last_args then
				-- 重新调用 open 实现重绘
				M.open(group, unpack(inst.last_args))
			end
		end,
	})
end

return M
