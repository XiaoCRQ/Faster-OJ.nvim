---@module "faster-oj.module.ui"
local M = {}

-- 存储所有组的状态
M.instances = {}

---获取或初始化组状态
local function get_inst(group)
	if not M.instances[group] then
		M.instances[group] = {
			wins = {}, -- key -> win_id
			bufs = {}, -- key -> buf_id
			augroup = nil,
			last_args = nil,
		}
	end
	return M.instances[group]
end

---格式化布局配置
local function normalize_layout(raw_layout)
	if type(raw_layout) ~= "table" then
		return {}
	end

	-- 情况 A: 兼容单节点写法 {weight, content}
	if type(raw_layout[1]) == "number" and (type(raw_layout[2]) == "string" or type(raw_layout[2]) == "table") then
		raw_layout = { raw_layout }
	end

	local normalized = {}
	for _, item in ipairs(raw_layout) do
		if type(item) == "table" then
			local weight = item[1] or 1
			local content = item[2]
			-- 情况 B: 兼容平铺式嵌套 {weight, {w1, c1}, {w2, c2}}
			if type(content) == "table" and type(content[1]) == "number" then
				content = {}
				for i = 2, #item do
					table.insert(content, item[i])
				end
			end
			table.insert(normalized, { weight, content })
		end
	end
	return normalized
end

---递归计算布局坐标 (不执行 UI 操作)
---@return table[] 包含所有待渲染窗口的 rect 列表
local function calculate_rects(layout, area, rects)
	rects = rects or {}
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

		local sub_area = {
			row = area.is_horizontal and area.row or (area.row + current_pos),
			col = area.is_horizontal and (area.col + current_pos) or area.col,
			width = area.is_horizontal and size or area.width,
			height = area.is_horizontal and area.height or size,
		}

		if type(content) == "string" then
			table.insert(rects, { key = content, area = sub_area })
		elseif type(content) == "table" then
			sub_area.is_horizontal = not area.is_horizontal
			sub_area.total_size = sub_area.is_horizontal and sub_area.width or sub_area.height
			calculate_rects(content, sub_area, rects)
		end
		current_pos = current_pos + size
	end
	return rects
end

---显示 UI
function M.open(group, config, titles, win_opts, on_win_created)
	local inst = get_inst(group)
	inst.last_args = { config = config, titles = titles, win_opts = win_opts, on_created = on_win_created }

	vim.schedule(function()
		local uis = vim.api.nvim_list_uis()
		if #uis == 0 then
			return
		end
		local ed = uis[1]

		local w = math.floor(ed.width * (config.width or 0.8))
		local h = math.floor(ed.height * (config.height or 0.8))
		local root_area = {
			row = math.floor((ed.height - h) / 2),
			col = math.floor((ed.width - w) / 2),
			width = w,
			height = h,
			total_size = w,
			is_horizontal = true,
		}

		local rects = calculate_rects(config.layout, root_area)
		local titles_map = titles or {}
		local opts_map = win_opts or {}
		local active_keys = {}

		for _, item in ipairs(rects) do
			local key, area = item.key, item.area
			active_keys[key] = true

			-- 初始化或获取 Buffer
			if not inst.bufs[key] or not vim.api.nvim_buf_is_valid(inst.bufs[key]) then
				inst.bufs[key] = vim.api.nvim_create_buf(false, true)
			end
			local buf = inst.bufs[key]
			local opt = opts_map[key] or {}

			-- 考虑 border 占用的空间 (rounded 为上下左右各占1)
			local win_w = math.max(area.width - 2, 1)
			local win_h = math.max(area.height - 2, 1)

			local win_config = {
				relative = "editor",
				row = area.row,
				col = area.col,
				width = win_w,
				height = win_h,
				style = "minimal",
				border = "rounded",
				title = titles_map[key] and (" " .. titles_map[key] .. " ") or nil,
				title_pos = "center",
				focusable = opt.focus ~= false,
			}

			if inst.wins[key] and vim.api.nvim_win_is_valid(inst.wins[key]) then
				-- 核心优化：如果窗口已存在，仅更新位置和尺寸，避免闪烁
				vim.api.nvim_win_set_config(inst.wins[key], win_config)
			else
				-- 创建新窗口
				local win = vim.api.nvim_open_win(buf, opt.focus or false, win_config)
				vim.wo[win].number = opt.number or false
				inst.wins[key] = win
			end
		end

		-- 清理本次布局中不再需要的窗口
		for key, win in pairs(inst.wins) do
			if not active_keys[key] then
				if vim.api.nvim_win_is_valid(win) then
					pcall(vim.api.nvim_win_close, win, true)
				end
				inst.wins[key] = nil
			end
		end

		if on_win_created then
			on_win_created()
		end
		M.setup_resize(group)
	end)
end

---关闭特定组的窗口
function M.close(group)
	local inst = M.instances[group]
	if not inst then
		return
	end
	for key, w in pairs(inst.wins) do
		if vim.api.nvim_win_is_valid(w) then
			pcall(vim.api.nvim_win_close, w, true)
		end
		inst.wins[key] = nil
	end
end

---清理所有资源
function M.clear(group)
	M.close(group)
	local inst = M.instances[group]
	if not inst then
		return
	end

	for _, buf in pairs(inst.bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	if inst.augroup then
		vim.api.nvim_del_augroup_by_id(inst.augroup)
	end
	M.instances[group] = nil
end

---检查组是否处于打开状态
function M.is_open(group)
	local inst = M.instances[group]
	if not inst then
		return false
	end
	for _, w in pairs(inst.wins) do
		if vim.api.nvim_win_is_valid(w) then
			return true
		end
	end
	return false
end

---重绘监听：使用逻辑优化的 open 函数实现平滑重绘
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
				local a = inst.last_args
				-- 注意：直接调用 open，内部的 nvim_win_set_config 会处理平滑移动
				M.open(group, a.config, a.titles, a.win_opts, a.on_created)
			end
		end,
	})
end

function M.get_win_by_key(group, key)
	local inst = M.instances[group]
	if not inst or not inst.wins then
		return nil
	end
	local win = inst.wins[key]
	if win and vim.api.nvim_win_is_valid(win) then
		return win
	end
	return nil
end

return M
