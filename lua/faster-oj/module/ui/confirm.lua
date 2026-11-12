---@module "faster-oj.module.ui.confirm"

---Single floating confirmation window.
---Choices are selected with single keys; Esc/Ctrl-C/q cancel.

local M = {}

local ns = vim.api.nvim_create_namespace("FOJConfirm")

---Keys disabled in the dialog: cursor movement, modes, and command-line entry.
local LOCKED_KEYS = {
	"h", "j", "k", "l",
	"<Left>", "<Right>", "<Up>", "<Down>",
	"<Home>", "<End>", "0", "^", "$",
	"w", "W", "b", "B", "e", "E",
	"gg", "G", "ge", "gE",
	"<PageUp>", "<PageDown>", "<C-b>", "<C-f>", "<C-u>", "<C-d>",
	"|", "%", "{", "}", "(", ")",
	"H", "M", "L", "+", "-", "_",
	"<Space>", "<BS>", "<Del>", "<C-o>", "<C-i>",
	":", "<C-w>",
	"i", "I", "a", "A", "o", "O", "R",
	"v", "V", "<C-v>",
}

local state = {
	win = nil,
	buf = nil,
	prev_win = nil,
	augroup = nil,
	on_choice = nil,
	finished = true,
	gen = 0,
}

---@class FOJ.ConfirmChoice
---@field key string
---@field label string
---@field value string

---@class FOJ.ConfirmOpts
---@field title? string
---@field message string
---@field choices? FOJ.ConfirmChoice[]
---@field default? string
---@field on_choice fun(action:string|nil)

local function setup_highlights()
	vim.api.nvim_set_hl(0, "FOJConfirmNormal", { link = "NormalFloat" })
	vim.api.nvim_set_hl(0, "FOJConfirmBorder", { link = "FloatBorder" })
	vim.api.nvim_set_hl(0, "FOJConfirmChoice", { link = "Function", bold = true })
end

local function restore_focus()
	local prev = state.prev_win
	state.prev_win = nil
	if prev and vim.api.nvim_win_is_valid(prev) and vim.api.nvim_get_current_win() ~= prev then
		pcall(vim.api.nvim_set_current_win, prev)
	end
end

local function close_window()
	local win = state.win
	local buf = state.buf
	state.win, state.buf = nil, nil
	if state.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
		state.augroup = nil
	end
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
	if buf and vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
end

---@param action string|nil
local function finish(action)
	if state.finished then
		return
	end
	state.finished = true
	local cb = state.on_choice
	state.on_choice = nil
	close_window()
	restore_focus()
	if cb then
		vim.schedule(function()
			cb(action)
		end)
	end
end

---@return boolean
function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

---@param opts FOJ.ConfirmOpts
---@return boolean opened
function M.open(opts)
	if M.is_open() then
		return false
	end
	if #vim.api.nvim_list_uis() == 0 then
		return false
	end

	setup_highlights()

	local choices = opts.choices or {
		{ key = "y", label = "[Y] Yes", value = "save" },
		{ key = "n", label = "[N] No", value = "discard" },
		{ key = "c", label = "[C] Cancel", value = "cancel" },
	}
	local title = opts.title or "Confirm"

	local lines = {}
	for _, line in ipairs(vim.split(opts.message or "", "\n", { plain = true })) do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = ""

	local labels = {}
	for _, choice in ipairs(choices) do
		labels[#labels + 1] = choice.label
	end
	lines[#lines + 1] = "  " .. table.concat(labels, "   ")

	-- Place the locked cursor on the key letter inside the first option's brackets.
	local cursor_col = 2
	if choices[1] then
		local first_label = labels[1] or ""
		local key = choices[1].key
		local key_pos = first_label:find("[" .. key:upper() .. "]", 1, true)
			or first_label:find("[" .. key .. "]", 1, true)
		if key_pos then
			cursor_col = 2 + key_pos
		end
	end

	local ed = vim.api.nvim_list_uis()[1]
	local width = 20
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
	end
	width = math.min(width, math.max(ed.width - 8, 20))
	local height = #lines

	local function win_config()
		local ui_list = vim.api.nvim_list_uis()
		local u = ui_list[1]
		local w = math.min(width, math.max(u.width - 8, 20))
		return {
			relative = "editor",
			row = math.max(math.floor((u.height - height) / 2) - 1, 0),
			col = math.max(math.floor((u.width - w) / 2), 0),
			width = w,
			height = height,
			style = "minimal",
			border = "rounded",
			title = " " .. title .. " ",
			title_pos = "center",
			focusable = true,
			zindex = 200,
		}
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "FOJConfirm"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local prev_win = vim.api.nvim_get_current_win()
	local win = vim.api.nvim_open_win(buf, true, win_config())
	vim.wo[win].winhl = "Normal:FOJConfirmNormal,FloatBorder:FOJConfirmBorder"
	local fixed_cursor = { #lines, cursor_col }
	pcall(vim.api.nvim_win_set_cursor, win, fixed_cursor)

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	vim.api.nvim_buf_add_highlight(buf, ns, "FOJConfirmChoice", #lines - 1, 0, -1)

	state.win = win
	state.buf = buf
	state.prev_win = prev_win
	state.on_choice = opts.on_choice
	state.finished = false
	state.gen = state.gen + 1
	local gen = state.gen

	local augroup = vim.api.nvim_create_augroup("FOJConfirm_" .. buf, { clear = true })
	state.augroup = augroup

	-- Lock the cursor on the first option's key letter.
	local resetting_cursor = false
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = augroup,
		buffer = buf,
		callback = function()
			if resetting_cursor then
				return
			end
			local c = vim.api.nvim_win_get_cursor(win)
			if c[1] ~= fixed_cursor[1] or c[2] ~= fixed_cursor[2] then
				resetting_cursor = true
				pcall(vim.api.nvim_win_set_cursor, win, fixed_cursor)
				resetting_cursor = false
			end
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(win),
		callback = function()
			vim.schedule(function()
				if state.gen == gen and not state.finished then
					finish(nil)
				end
			end)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = augroup,
		callback = function()
			if state.gen ~= gen or not M.is_open() then
				return
			end
			pcall(vim.api.nvim_win_set_config, state.win, win_config())
			-- The UI engine may reopen and focus its windows after this autocmd.
			vim.defer_fn(function()
				if state.gen == gen and M.is_open() then
					pcall(vim.api.nvim_set_current_win, state.win)
				end
			end, 30)
		end,
	})

	local function map(keys, action)
		for _, key in ipairs(keys) do
			vim.keymap.set("n", key, function()
				finish(action)
			end, { buffer = buf, nowait = true, silent = true })
		end
	end

	for _, choice in ipairs(choices) do
		map({ choice.key, choice.key:upper() }, choice.value)
	end
	map({ "<CR>" }, opts.default or choices[1].value)
	map({ "<Esc>", "<C-c>", "q", "Q" }, "cancel")

	local choice_keys = {}
	for _, choice in ipairs(choices) do
		choice_keys[choice.key] = true
		choice_keys[choice.key:upper()] = true
	end
	for _, key in ipairs(LOCKED_KEYS) do
		if not choice_keys[key] then
			vim.keymap.set("n", key, "<Nop>", { buffer = buf, nowait = true, silent = true })
		end
	end

	return true
end

---Programmatically cancel the open confirmation.
function M.close()
	finish("cancel")
end

return M
