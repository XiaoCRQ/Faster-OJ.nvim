local M = {}

M.state = {
	wins = {},
	bufs = {},
	augroup = nil,
}

function M.setup(cfg)
	M.config = cfg
end

--------------------------------------------------
-- buffer
--------------------------------------------------
local function ensure_buf(title)
	local buf = M.state.bufs[title]
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end

	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "testui"

	M.state.bufs[title] = buf
	return buf
end

--------------------------------------------------
-- 遍历 layout（仅创建 buffer）
--------------------------------------------------
local function create_bufs(layout)
	for _, node in ipairs(layout) do
		local content = node[2]

		if type(content) == "string" then
			ensure_buf(content)
		else
			for _, c in ipairs(content) do
				ensure_buf(c[2])
			end
		end
	end
end

--------------------------------------------------
-- window
--------------------------------------------------
local function open_win(buf, area, title)
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = area.row + 1,
		col = area.col + 1,
		width = math.max(area.width - 2, 1),
		height = math.max(area.height - 2, 1),
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", M.close, { buffer = buf, nowait = true })
	table.insert(M.state.wins, win)
end

--------------------------------------------------
-- 渲染 layout（打开窗口）
--------------------------------------------------
local function render(layout, area)
	local total_w = 0
	for _, n in ipairs(layout) do
		total_w = total_w + n[1]
	end

	local col = 0

	for i, node in ipairs(layout) do
		local w = math.floor(area.width * node[1] / total_w)
		if i == #layout then
			w = area.width - col
		end

		local sub = {
			row = area.row,
			col = area.col + col,
			width = w,
			height = area.height,
		}

		local content = node[2]

		if type(content) == "string" then
			open_win(ensure_buf(content), sub, content)
		else
			local total_h, row = 0, 0
			for _, c in ipairs(content) do
				total_h = total_h + c[1]
			end

			for j, c in ipairs(content) do
				local h = math.floor(sub.height * c[1] / total_h)
				if j == #content then
					h = sub.height - row
				end

				open_win(ensure_buf(c[2]), {
					row = sub.row + row,
					col = sub.col,
					width = sub.width,
					height = h,
				}, c[2])

				row = row + h
			end
		end

		col = col + w
	end
end

--------------------------------------------------
-- async helper
--------------------------------------------------
local function async(fn)
	vim.schedule(fn)
end

--------------------------------------------------
-- erase（彻底删除）
--------------------------------------------------
function M.erase()
	async(function()
		for _, w in ipairs(M.state.wins) do
			pcall(vim.api.nvim_win_close, w, true)
		end
		M.state.wins = {}

		for k, b in pairs(M.state.bufs) do
			pcall(vim.api.nvim_buf_delete, b, { force = true })
			M.state.bufs[k] = nil
		end

		if M.state.augroup then
			pcall(vim.api.nvim_del_augroup_by_id, M.state.augroup)
			M.state.augroup = nil
		end
	end)
end

--------------------------------------------------
-- close（只关窗口）
--------------------------------------------------
function M.close()
	async(function()
		for _, w in ipairs(M.state.wins) do
			pcall(vim.api.nvim_win_close, w, true)
		end
		M.state.wins = {}
	end)
end

--------------------------------------------------
-- new（创建 buffers）
--------------------------------------------------
function M.new()
	if #M.state.wins > 0 or next(M.state.bufs) then
		M.erase()
	end

	create_bufs(M.config.ui.layout)

	return M.state.bufs
end

--------------------------------------------------
-- show（显示窗口）
--------------------------------------------------
function M.show()
	async(function()
		if #M.state.wins > 0 then
			return
		end

		local ui = M.config.ui
		local ed = vim.api.nvim_list_uis()[1]

		local w = math.floor(ed.width * ui.width)
		local h = math.floor(ed.height * ui.height)

		local area = {
			row = math.floor((ed.height - h) / 2) - 2,
			col = math.floor((ed.width - w) / 2),
			width = w,
			height = h,
		}

		render(ui.layout, area)
		M.setup_resize()
	end)
end

--------------------------------------------------
-- autoresize
--------------------------------------------------
function M.setup_resize()
	if M.state.augroup then
		return
	end

	M.state.augroup = vim.api.nvim_create_augroup("TestUIResize", { clear = true })

	vim.api.nvim_create_autocmd("VimResized", {
		group = M.state.augroup,
		callback = function()
			if #M.state.wins == 0 then
				return
			end
			M.close()
			M.show()
		end,
	})
end

return M
