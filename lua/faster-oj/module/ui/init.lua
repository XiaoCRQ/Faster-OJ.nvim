---@module "faster-oj.module.ui"

local M = {}

M.instances = {}

-- ── Instance management ─────────────────────────────────

---@param group string
---@param style string
---@return string
local function inst_key(group, style)
	return group .. ":" .. (style or "float")
end

---@param group string
---@param style string
---@return table inst
local function get_inst(group, style)
	local key = inst_key(group, style)
	if not M.instances[key] then
		M.instances[key] = {
			wins = {},
			bufs = {},
			augroup = nil,
			last_args = nil,
			style = style or "float",
		}
	end
	return M.instances[key]
end

-- ── Layout normalization ────────────────────────────────

---@param raw_layout table
---@return table[]
local function normalize_layout(raw_layout)
	if type(raw_layout) ~= "table" then
		return {}
	end

	if type(raw_layout[1]) == "number" and (type(raw_layout[2]) == "string" or type(raw_layout[2]) == "table") then
		raw_layout = { raw_layout }
	end

	local normalized = {}
	for _, item in ipairs(raw_layout) do
		if type(item) == "table" then
			local weight = item[1] or 1
			local content = item[2]
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

-- ── Rect calculation (shared by float and split) ────────

---@return table[] rects
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

-- ── Collect leaf keys from layout ───────────────────────

---@param layout table
---@return string[]
local function collect_leaf_keys(layout)
	local keys = {}
	local nodes = normalize_layout(layout)
	for _, node in ipairs(nodes) do
		local content = node[2]
		if type(content) == "string" then
			keys[#keys + 1] = content
		elseif type(content) == "table" then
			local sub = collect_leaf_keys(content)
			for _, k in ipairs(sub) do
				keys[#keys + 1] = k
			end
		end
	end
	return keys
end

-- ── Split layout: recursive window creation ─────────────
-- Uses :N vsplit / :N split commands for reliable sized splits.
-- Non-anchor windows get their target size at creation time;
-- anchors reuse the parent window and inherit remaining space.
-- This avoids nvim_win_set_width/height which behaves unreliably
-- in deeply nested split hierarchies.

---@param parent_win integer    window to split from
---@param nodes table[]         normalized [{weight, content}]
---@param depth integer          recursion depth (0 = root)
---@param root_dir string       "right"|"left"|"above"|"below"
---@param avail_w number         available width (columns) at this level
---@param avail_h number         available height (lines) at this level
---@param bufs table            { key = buf_id }
---@param titles table<string,string>
---@param wins table            output: { key = win_id }
local function create_split_layout(parent_win, nodes, depth, root_dir, avail_w, avail_h, bufs, titles, wins)
	if #nodes == 0 then
		return
	end

	local is_horiz = depth % 2 == 0

	-- Determine split direction for this level
	local split_dir
	if root_dir == "right" or root_dir == "left" then
		split_dir = is_horiz and root_dir or "below"
	else -- "below" or "above"
		split_dir = is_horiz and root_dir or "right"
	end

	-- Processing order: rightmost/bottommost first
	local reverse = (split_dir == "right" or split_dir == "below")
	local avail = is_horiz and avail_w or avail_h

	-- Sum weights for proportional allocation
	local total_weight = 0
	for _, node in ipairs(nodes) do
		total_weight = total_weight + node[1]
	end

	for iter = 1, #nodes do
		local idx = reverse and (#nodes - iter + 1) or iter
		local node = nodes[idx]
		local weight, content = node[1], node[2]
		local is_anchor = (iter == #nodes)

		if is_anchor then
			-- Anchor reuses parent_win — gets remaining space.
			if type(content) == "string" then
				local key = content
				vim.api.nvim_win_set_buf(parent_win, bufs[key])
				if titles[key] and #titles[key] > 0 then
					vim.wo[parent_win].winbar = " " .. titles[key] .. " "
				end
				wins[key] = parent_win
			else
				local children = normalize_layout(content)
				local cw = vim.api.nvim_win_get_width(parent_win)
				local ch = vim.api.nvim_win_get_height(parent_win)
				create_split_layout(parent_win, children, depth + 1, root_dir, cw, ch, bufs, titles, wins)
			end
		else
			-- Non-anchor: create sized split via :N vsplit / :N split
			local size = math.floor(avail * weight / total_weight)
			size = math.max(size, 1)

			vim.api.nvim_set_current_win(parent_win)
			local prefix = (split_dir == "right" or split_dir == "below") and "rightbelow " or "leftabove "
			local split_cmd = is_horiz and "vsplit" or "split"
			vim.cmd(prefix .. size .. split_cmd)
			local new_win = vim.api.nvim_get_current_win()

			if type(content) == "string" then
				local key = content
				-- Mark auto-created buffer for cleanup, then swap to real buf
				pcall(function()
					local tmp = vim.api.nvim_win_get_buf(new_win)
					vim.bo[tmp].bufhidden = "wipe"
				end)
				vim.api.nvim_win_set_buf(new_win, bufs[key])
				if titles[key] and #titles[key] > 0 then
					vim.wo[new_win].winbar = " " .. titles[key] .. " "
				end
				wins[key] = new_win
			else
				local children = normalize_layout(content)
				local cw = vim.api.nvim_win_get_width(new_win)
				local ch = vim.api.nvim_win_get_height(new_win)
				create_split_layout(new_win, children, depth + 1, root_dir, cw, ch, bufs, titles, wins)
			end
		end
	end
end

-- ── Public API ───────────────────────────────────────────

--- Open or reposition a UI window group
---@param group string
---@param style string    "float" | "split"
---@param config table    style-specific {width, height?, layout, direction?}
---@param titles table<string,string>
---@param win_opts table<string,table>
---@param on_win_created fun()?
function M.open(group, style, config, titles, win_opts, on_win_created)
	style = style or "float"

	-- Interlock: close all windows of the same style across all groups
	M.close_style_global(style)

	local inst = get_inst(group, style)
	inst.last_args = { config = config, titles = titles, win_opts = win_opts, on_created = on_win_created }

	vim.schedule(function()
		local uis = vim.api.nvim_list_uis()
		if #uis == 0 then
			return
		end
		local ed = uis[1]

		if style == "float" then
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

				if not inst.bufs[key] or not vim.api.nvim_buf_is_valid(inst.bufs[key]) then
					inst.bufs[key] = vim.api.nvim_create_buf(false, true)
				end
				local buf = inst.bufs[key]
				local opt = opts_map[key] or {}

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
					vim.api.nvim_win_set_config(inst.wins[key], win_config)
				else
					local win = vim.api.nvim_open_win(buf, opt.focus or false, win_config)
					vim.wo[win].number = opt.number or false
					inst.wins[key] = win
				end
			end

			for key, win in pairs(inst.wins) do
				if not active_keys[key] then
					if vim.api.nvim_win_is_valid(win) then
						pcall(vim.api.nvim_win_close, win, true)
					end
					inst.wins[key] = nil
				end
			end
		else
			-- Split style
			local direction = config.direction or "right"
			local layout = config.layout
			if not layout then
				return
			end

			-- Create or reuse buffers for all leaf panels
			local flat_keys = collect_leaf_keys(layout)
			for _, key in ipairs(flat_keys) do
				if not inst.bufs[key] or not vim.api.nvim_buf_is_valid(inst.bufs[key]) then
					inst.bufs[key] = vim.api.nvim_create_buf(false, true)
				end
			end

			-- Create root container by splitting the current editor window
			local editor_win = vim.api.nvim_get_current_win()
			local container_size
			if direction == "right" or direction == "left" then
				container_size = math.floor(ed.width * (config.width or 0.3))
			else
				container_size = math.floor(ed.height * (config.width or 0.3))
			end
			container_size = math.max(container_size, 1)

			vim.api.nvim_set_current_win(editor_win)
			local prefix = (direction == "right" or direction == "below") and "rightbelow " or "leftabove "
			local split_type = (direction == "right" or direction == "left") and "vsplit" or "split"
			vim.cmd(prefix .. container_size .. split_type)
			local container_win = vim.api.nvim_get_current_win()

			-- Save container dimensions for the recursive layout
			local root_w = vim.api.nvim_win_get_width(container_win)
			local root_h = vim.api.nvim_win_get_height(container_win)

			-- Recursively build split layout (sizes set inline)
			local wins = {}
			local nodes = normalize_layout(layout)
			local titles_map = titles or {}
			create_split_layout(container_win, nodes, 0, direction, root_w, root_h, inst.bufs, titles_map, wins)

			-- Apply window options
			local opts_map = win_opts or {}
			for key, win in pairs(wins) do
				if vim.api.nvim_win_is_valid(win) then
					local opt = opts_map[key] or {}
					vim.wo[win].number = opt.number or false
					if opt.focus and vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_set_current_win(win)
					end
				end
			end

			inst.wins = wins

			-- Kill all windows when container closes
			if flat_keys[1] and inst.bufs[flat_keys[1]] then
				vim.api.nvim_create_autocmd("BufWinLeave", {
					buffer = inst.bufs[flat_keys[1]],
					once = true,
					callback = function()
						M.close_style(group, style)
					end,
				})
			end
		end

		if on_win_created then
			on_win_created()
		end
		M.setup_resize(group, style)
	end)
end

--- Close ALL windows of a given style across all groups
---@param style string
function M.close_style_global(style)
	local to_close = {}
	for k, inst in pairs(M.instances) do
		if inst.style == style then
			to_close[#to_close + 1] = k
		end
	end
	for _, k in ipairs(to_close) do
		local inst = M.instances[k]
		if inst then
			for _, w in pairs(inst.wins) do
				if vim.api.nvim_win_is_valid(w) then
					pcall(vim.api.nvim_win_close, w, true)
				end
			end
			if inst.augroup then
				vim.api.nvim_del_augroup_by_id(inst.augroup)
			end
			M.instances[k] = nil
		end
	end
end

--- Close windows for a specific group:style
---@param group string
---@param style string
function M.close_style(group, style)
	local inst = M.instances[inst_key(group, style)]
	if not inst then
		return
	end

	for key, w in pairs(inst.wins) do
		if vim.api.nvim_win_is_valid(w) then
			pcall(vim.api.nvim_win_close, w, true)
		end
		inst.wins[key] = nil
	end

	if inst.augroup then
		vim.api.nvim_del_augroup_by_id(inst.augroup)
		inst.augroup = nil
	end

	M.instances[inst_key(group, style)] = nil
end

--- Close ALL styles for a group
---@param group string
function M.close(group)
	local keys = {}
	for k, _ in pairs(M.instances) do
		if k:match("^" .. group .. ":") then
			keys[#keys + 1] = k
		end
	end

	for _, k in ipairs(keys) do
		local inst = M.instances[k]
		if inst then
			for _, w in pairs(inst.wins) do
				if vim.api.nvim_win_is_valid(w) then
					pcall(vim.api.nvim_win_close, w, true)
				end
			end
			if inst.augroup then
				vim.api.nvim_del_augroup_by_id(inst.augroup)
			end
			M.instances[k] = nil
		end
	end
end

--- Clear all styles for a group: close wins + delete bufs + remove augroups
---@param group string
function M.clear(group)
	local keys = {}
	for k, _ in pairs(M.instances) do
		if k:match("^" .. group .. ":") then
			keys[#keys + 1] = k
		end
	end

	for _, k in ipairs(keys) do
		local inst = M.instances[k]
		if inst then
			for _, w in pairs(inst.wins) do
				if vim.api.nvim_win_is_valid(w) then
					pcall(vim.api.nvim_win_close, w, true)
				end
			end
			for _, buf in pairs(inst.bufs) do
				if vim.api.nvim_buf_is_valid(buf) then
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end
			end
			if inst.augroup then
				vim.api.nvim_del_augroup_by_id(inst.augroup)
			end
			M.instances[k] = nil
		end
	end
end

--- Check if a specific style is open for a group
---@param group string
---@param style string
---@return boolean
function M.is_open(group, style)
	local inst = M.instances[inst_key(group, style)]
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

--- Register VimResized handler
---@param group string
---@param style string
function M.setup_resize(group, style)
	local inst = get_inst(group, style)
	if inst.augroup then
		return
	end

	inst.augroup = vim.api.nvim_create_augroup("FOJUIResize_" .. inst_key(group, style), { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = inst.augroup,
		callback = function()
			if M.is_open(group, style) and inst.last_args then
				local a = inst.last_args
				M.open(group, style, a.config, a.titles, a.win_opts, a.on_created)
			end
		end,
	})
end

--- Get window by key for a group:style
---@param group string
---@param key string
---@param style string  default "float"
---@return integer|nil win_id
function M.get_win_by_key(group, key, style)
	style = style or "float"
	local inst = M.instances[inst_key(group, style)]
	if not inst or not inst.wins then
		return nil
	end
	local win = inst.wins[key]
	if win and vim.api.nvim_win_is_valid(win) then
		return win
	end
	return nil
end

--- Get the instance table for a group:style
---@param group string
---@param style string
---@return table|nil
function M.get_instance(group, style)
	return M.instances[inst_key(group, style)]
end

return M
