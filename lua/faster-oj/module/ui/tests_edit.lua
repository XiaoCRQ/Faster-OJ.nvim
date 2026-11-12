---@module "faster-oj.module.ui.tests_edit"

local utils = require("faster-oj.module.utils")
local ui = require("faster-oj.module.ui")
local notify = require("faster-oj.module.notify")
local confirm = require("faster-oj.module.ui.confirm")

local uv = vim.uv or vim.loop

local M = {}
local GROUP = "EditUI"

local TITLES = { tc = "Testcases (Edit)", si = "Input", so = "Output" }
local WIN_OPTS = {
	tc = { number = false, focus = true },
	si = { number = true },
	so = { number = true },
}

local EDIT_CYCLE = { "si", "so" }

---One TC is open at a time.
---disk_count:     number of .in/.out pairs on disk.
---test_count:     TC-list rows; equals disk_count + (pending_new and 1 or 0).
---current_index:  1-based index of the open TC.
---pending_new:    the open TC is a new case that has not been written yet.
---saved:          normalized disk snapshot of the open TC (one trailing newline stripped).
---live:           latest buffer content of the open TC.
---raw_input/raw_output: exact on-disk bytes of the open TC (nil for a new TC).
---is_updating:    >0 while rendering buffers (suppresses capture callbacks).
---switching:      a TC switch decision is in progress.
---pending_confirm: a confirmation window is open.
---gen:            generation token; stale scheduled callbacks compare it.
M.state = {
	problem_dir = "",
	problem_name = "",
	disk_count = 0,
	test_count = 0,
	current_index = 1,
	pending_new = false,
	saved = { input = "", output = "" },
	live = { input = "", output = "" },
	raw_input = nil,
	raw_output = nil,
	is_updating = 0,
	switching = false,
	pending_confirm = false,
	gen = 0,
}

M.current_style = nil

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
	M.current_style = cfg.tc_edit_ui and cfg.tc_edit_ui.default_style or "float"
end

---Get current effective style
local function get_style()
	return M.current_style or (M.config.tc_edit_ui and M.config.tc_edit_ui.default_style) or "float"
end

---Get style-specific config table
local function get_style_config()
	local ui_cfg = M.config.tc_edit_ui
	local s = get_style()
	return ui_cfg[s] or ui_cfg.float
end

local function confirm_enabled()
	local cfg = M.config.tc_edit_ui or {}
	return cfg.confirm_unsaved ~= false
end

local function normalize(text)
	return ((text or ""):gsub("\n$", ""))
end

local function get_instance()
	return ui.get_instance(GROUP, get_style())
end

---Set buffer lines without triggering capture callbacks.
local function set_buffer_lines(buf, lines)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	M.state.is_updating = M.state.is_updating + 1
	vim.bo[buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines or {})
	M.state.is_updating = M.state.is_updating - 1
end

---Render the current TC from memory.
local function render_current()
	local inst = get_instance()
	if not inst or not inst.bufs then
		return
	end
	set_buffer_lines(inst.bufs.si, vim.split(M.state.live.input or "", "\n"))
	set_buffer_lines(inst.bufs.so, vim.split(M.state.live.output or "", "\n"))
	if inst.bufs.tc and vim.api.nvim_buf_is_valid(inst.bufs.tc) then
		vim.bo[inst.bufs.tc].modifiable = false
	end
end

---Capture the open buffers into `live`.
local function capture_current()
	local inst = get_instance()
	if not inst or not inst.bufs then
		return false
	end
	local si, so = inst.bufs.si, inst.bufs.so
	if not (si and so and vim.api.nvim_buf_is_valid(si) and vim.api.nvim_buf_is_valid(so)) then
		return false
	end
	M.state.live.input = table.concat(vim.api.nvim_buf_get_lines(si, 0, -1, false), "\n")
	M.state.live.output = table.concat(vim.api.nvim_buf_get_lines(so, 0, -1, false), "\n")
	return true
end

local function needs_save_prompt()
	if M.state.pending_new then
		return true
	end
	capture_current()
	-- `saved` is normalized; a trailing blank line in the buffer is not a real edit.
	return normalize(M.state.live.input) ~= M.state.saved.input
		or normalize(M.state.live.output) ~= M.state.saved.output
end

local function update_tc_list()
	local inst = get_instance()
	if not inst or not inst.bufs or not inst.bufs.tc then
		return
	end
	local buf = inst.bufs.tc
	local lines = {}
	for i = 1, M.state.test_count do
		lines[#lines + 1] = "  TC " .. (i - 1)
	end
	M.state.is_updating = M.state.is_updating + 1
	vim.bo[buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	M.state.is_updating = M.state.is_updating - 1
end

local function set_tc_cursor(row)
	local win = ui.get_win_by_key(GROUP, "tc", get_style())
	if win then
		pcall(vim.api.nvim_win_set_cursor, win, { row, 2 })
	end
end

---Load an existing TC from disk into the open buffers.
local function load_case(index)
	local dir = M.state.problem_dir
	local file_idx = index - 1
	local raw_in = utils.read_file(dir .. file_idx .. ".in")
	local raw_out = utils.read_file(dir .. file_idx .. ".out")
	M.state.raw_input = raw_in
	M.state.raw_output = raw_out
	M.state.saved = { input = normalize(raw_in), output = normalize(raw_out) }
	M.state.live = { input = M.state.saved.input, output = M.state.saved.output }
	M.state.current_index = index
	render_current()
end

local function scan_disk_count(dir)
	local max_idx = -1
	local handle = uv.fs_scandir(dir)
	if handle then
		while true do
			local name = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local idx = name:match("^(%d+)%.in$") or name:match("^(%d+)%.out$")
			if idx then
				idx = tonumber(idx)
				if idx and idx > max_idx then
					max_idx = idx
				end
			end
		end
	end
	return max_idx + 1
end

---Drop the pending new TC (memory only).
local function discard_current_pending()
	if not M.state.pending_new then
		return
	end
	M.state.pending_new = false
	M.state.test_count = M.state.disk_count
	if M.state.current_index > M.state.test_count then
		M.state.current_index = math.max(M.state.test_count, 1)
	end
	update_tc_list()
end

---Discard unsaved edits (and a pending new TC, if any).
local function discard_current_edits()
	discard_current_pending()
	M.state.live = { input = M.state.saved.input, output = M.state.saved.output }
	render_current()
end

---Prepare a new unsaved TC as the open case.
local function begin_pending_case()
	M.state.pending_new = true
	M.state.test_count = M.state.disk_count + 1
	M.state.current_index = M.state.test_count
	M.state.raw_input, M.state.raw_output = nil, nil
	M.state.saved = { input = "", output = "" }
	M.state.live = { input = "", output = "" }
end

---Save the open TC to disk and refresh problem.json.
---@return boolean
function M.save()
	if M.state.problem_dir == "" then
		notify.show("No problem data directory", "WARN")
		return false
	end

	capture_current()
	local dir = M.state.problem_dir
	local file_idx = M.state.current_index - 1
	local in_content, out_content

	if M.state.pending_new then
		in_content, out_content = M.state.live.input, M.state.live.output
	else
		-- Preserve exact bytes for unchanged TCs.
		local same_in = M.state.raw_input ~= nil and M.state.live.input == normalize(M.state.raw_input)
		local same_out = M.state.raw_output ~= nil and M.state.live.output == normalize(M.state.raw_output)
		in_content = same_in and M.state.raw_input or M.state.live.input
		out_content = same_out and M.state.raw_output or M.state.live.output
	end

	local was_pending = M.state.pending_new
	local function cleanup_partial()
		-- A failed first save must not leave orphan TC files behind.
		if was_pending then
			os.remove(dir .. file_idx .. ".in")
			os.remove(dir .. file_idx .. ".out")
		end
	end

	vim.fn.mkdir(dir, "p")
	if not utils.write_file(dir .. file_idx .. ".in", in_content) then
		cleanup_partial()
		notify.show("Failed to save test data", "ERROR")
		return false
	end
	if not utils.write_file(dir .. file_idx .. ".out", out_content) then
		cleanup_partial()
		notify.show("Failed to save test data", "ERROR")
		return false
	end

	local new_disk_count = M.state.disk_count + (was_pending and 1 or 0)

	local json_path = dir .. "problem.json"
	local data = utils.read_json(json_path)
	if type(data) ~= "table" then
		data = {
			url = "",
			name = M.state.problem_name,
			memoryLimit = M.config.default_memory_limit or 256,
			timeLimit = M.config.default_time_limit or 2000,
		}
	end
	data.testCount = new_disk_count
	if not utils.write_json(json_path, data) then
		cleanup_partial()
		notify.show("Failed to save problem metadata", "ERROR")
		return false
	end

	if was_pending then
		M.state.pending_new = false
		M.state.disk_count = new_disk_count
		M.state.test_count = M.state.disk_count
		update_tc_list()
	end

	M.state.raw_input, M.state.raw_output = in_content, out_content
	M.state.saved = { input = normalize(in_content), output = normalize(out_content) }
	M.state.live = { input = M.state.saved.input, output = M.state.saved.output }

	notify.show("Problem data saved", "INFO")
	log("INFO", "save", string.format("Saved TC %d to %s", file_idx, dir))
	return true
end

function M.reset_state()
	M.state.problem_dir = ""
	M.state.problem_name = ""
	M.state.disk_count = 0
	M.state.test_count = 0
	M.state.current_index = 1
	M.state.pending_new = false
	M.state.saved = { input = "", output = "" }
	M.state.live = { input = "", output = "" }
	M.state.raw_input, M.state.raw_output = nil, nil
	M.state.is_updating = 0
	M.state.switching = false
	M.state.pending_confirm = false
end

---Resolve unsaved changes before closing/switching the open TC.
---@param message string
---@param on_proceed fun()
---@param on_cancel fun()
local function resolve_unsaved(message, on_proceed, on_cancel)
	if not needs_save_prompt() then
		on_proceed()
		return
	end

	if not confirm_enabled() then
		log("INFO", "resolve_unsaved", "Discarding unsaved changes (confirmation disabled)")
		discard_current_edits()
		on_proceed()
		return
	end

	M.state.pending_confirm = true
	local opened = confirm.open({
		title = "Unsaved Changes",
		message = message,
		default = "save",
		on_choice = function(action)
			M.state.pending_confirm = false
			if action == "save" then
				if M.save() then
					on_proceed()
				else
					on_cancel()
				end
			elseif action == "discard" then
				discard_current_edits()
				on_proceed()
			else
				on_cancel()
			end
		end,
	})
	if not opened then
		M.state.pending_confirm = false
		on_cancel()
	end
end

---Switch the open TC (TC list cursor moved).
---@param target integer 1-based index
function M.request_switch(target)
	if target < 1 or target > M.state.test_count then
		return
	end
	if target == M.state.current_index then
		return
	end
	if M.state.switching or M.state.pending_confirm then
		return
	end

	M.state.switching = true
	local saved_index = M.state.current_index

	local function do_switch()
		M.state.switching = false
		local idx = math.min(target, math.max(M.state.test_count, 1))
		M.state.current_index = idx
		update_tc_list()
		load_case(idx)
		set_tc_cursor(idx)
	end

	local function cancel_switch()
		M.state.switching = false
		set_tc_cursor(saved_index)
	end

	resolve_unsaved(string.format("TC %d has unsaved changes. Save before switching?", saved_index - 1), do_switch, cancel_switch)
end

---Create a new pending TC. It always counts as dirty until saved.
function M.add()
	if M.state.switching or M.state.pending_confirm then
		return
	end

	M.state.switching = true
	local saved_index = M.state.current_index

	local function create_new()
		M.state.switching = false
		begin_pending_case()
		update_tc_list()
		render_current()
		set_tc_cursor(M.state.current_index)
	end

	resolve_unsaved(
		string.format("TC %d has unsaved changes. Save before creating a new TC?", saved_index - 1),
		create_new,
		function()
			M.state.switching = false
			set_tc_cursor(saved_index)
		end
	)
end

---Delete the open TC immediately (with confirmation when enabled).
function M.delete_current()
	if M.state.switching or M.state.pending_confirm then
		return
	end
	if M.state.test_count <= 1 then
		return
	end

	local idx = M.state.current_index

	local function do_delete()
		if M.state.pending_new then
			M.state.pending_new = false
			M.state.test_count = M.state.disk_count
		else
			local count_before = M.state.disk_count
			utils.delete_test_case(M.state.problem_dir, idx - 1, count_before)
			M.state.disk_count = count_before - 1
			M.state.test_count = M.state.disk_count
			utils.update_test_count(M.state.problem_dir, M.state.disk_count)
		end

		local new_idx = math.min(idx, math.max(M.state.test_count, 1))
		M.state.current_index = new_idx
		update_tc_list()
		load_case(new_idx)
		set_tc_cursor(new_idx)
		notify.show("Test case deleted", "INFO")
	end

	if not confirm_enabled() then
		do_delete()
		return
	end

	M.state.pending_confirm = true
	local opened = confirm.open({
		title = "Delete Test Case",
		message = string.format("Delete TC %d? Unsaved changes will be lost.", idx - 1),
		choices = {
			{ key = "y", label = "[Y] Yes", value = "delete" },
			{ key = "n", label = "[N] No", value = "cancel" },
		},
		default = "cancel",
		on_choice = function(action)
			M.state.pending_confirm = false
			if action == "delete" then
				do_delete()
			else
				set_tc_cursor(M.state.current_index)
			end
		end,
	})
	if not opened then
		M.state.pending_confirm = false
	end
end

---Close the editor after resolving unsaved changes.
---@param cb? fun(ok:boolean)
function M.close(cb)
	vim.schedule(function()
		if not M.is_open() then
			if cb then
				cb(true)
			end
			return
		end
		if M.state.pending_confirm then
			notify.show("Resolve the pending dialog first", "WARN")
			if cb then
				cb(false)
			end
			return
		end

		local function do_close()
			M.state.gen = M.state.gen + 1
			ui.close_style(GROUP, get_style())
			M.reset_state()
			if cb then
				cb(true)
			end
		end

		resolve_unsaved(
			string.format("TC %d has unsaved changes. Save before closing?", M.state.current_index - 1),
			do_close,
			function()
				if cb then
					cb(false)
				end
			end
		)
	end)
end

local function on_cursor_moved()
	local win = ui.get_win_by_key(GROUP, "tc", get_style())
	if not win or vim.api.nvim_get_current_win() ~= win then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	local row = cursor[1]
	if cursor[2] ~= 5 then
		pcall(vim.api.nvim_win_set_cursor, win, { row, 5 })
	end
	if M.state.switching or M.state.pending_confirm then
		return
	end
	if row ~= M.state.current_index then
		M.request_switch(row)
	end
end

---Shared on_created callback for open / toggle / resize.
local function setup_ui()
	local style = get_style()
	local inst = ui.get_instance(GROUP, style)
	if not inst or not inst.bufs then
		return
	end
	local gen = M.state.gen
	local tc_buf = inst.bufs.tc

	for _, key in ipairs({ "si", "so" }) do
		local buf = inst.bufs[key]
		if buf and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
				buffer = buf,
				callback = function()
					if M.state.is_updating > 0 then
						return
					end
					capture_current()
				end,
			})

			-- Capture before the engine rebuilds buffers (resize/toggle).
			vim.api.nvim_create_autocmd("BufWinLeave", {
				buffer = buf,
				callback = function()
					capture_current()
					vim.schedule(function()
						if M.state.gen ~= gen then
							return
						end
						if ui.get_instance(GROUP, style) ~= inst then
							return
						end
						if M.is_open() then
							M.close()
						end
					end)
				end,
			})
		end
	end

	update_tc_list()
	render_current()
	M.bind_keys()

	if tc_buf and vim.api.nvim_buf_is_valid(tc_buf) then
		vim.bo[tc_buf].modifiable = false
		-- Manual close of the TC list window (float style).
		vim.api.nvim_create_autocmd("BufWinLeave", {
			buffer = tc_buf,
			callback = function()
				vim.schedule(function()
					if M.state.gen ~= gen then
						return
					end
					if ui.get_instance(GROUP, style) ~= inst then
						return
					end
					if M.is_open() then
						M.close()
					end
				end)
			end,
		})
		vim.api.nvim_clear_autocmds({ buffer = tc_buf, event = "CursorMoved" })
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = tc_buf,
			callback = on_cursor_moved,
		})
	end
	set_tc_cursor(M.state.current_index)
end

---Bind keymaps.
function M.bind_keys()
	local inst = get_instance()
	if not inst then
		return
	end
	local maps = M.config.tc_edit_ui.mappings

	for key, buf in pairs(inst.bufs) do
		local opts = { buffer = buf, nowait = true, silent = true }

		-- Toggle style key on all buffers
		if maps.toggle_style then
			for _, k in ipairs(maps.toggle_style) do
				vim.keymap.set("n", k, M.toggle_style, opts)
			end
		end

		for _, k in ipairs(maps.write) do
			vim.keymap.set("n", k, M.save, opts)
		end

		if key == "tc" then
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, M.close, opts)
			end
			for _, k in ipairs(maps.edit) do
				vim.keymap.set("n", k, function()
					local win = ui.get_win_by_key(GROUP, "si", get_style())
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
			for _, k in ipairs(maps.add) do
				vim.keymap.set("n", k, M.add, opts)
			end
			for _, k in ipairs(maps.erase) do
				vim.keymap.set("n", k, M.delete_current, opts)
			end
		else
			for _, k in ipairs(maps.close) do
				vim.keymap.set("n", k, function()
					local win = ui.get_win_by_key(GROUP, "tc", get_style())
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
				local win = ui.get_win_by_key(GROUP, target, get_style())
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

---Switch style. Display-only: no prompt, no disk write.
---@param target? '"float"'|'"split"'
function M.toggle_style(target)
	local old_style = get_style()
	local new_style = target or ((old_style == "float") and "split" or "float")
	if new_style == old_style then
		return
	end
	if not M.is_open() then
		M.current_style = new_style
		return
	end
	if M.state.switching or M.state.pending_confirm then
		return
	end

	capture_current()
	M.state.gen = M.state.gen + 1
	ui.close_style(GROUP, old_style)
	M.current_style = new_style
	ui.open(GROUP, new_style, get_style_config(), TITLES, WIN_OPTS, setup_ui)
end

---@param style? '"float"'|'"split"'
function M.edit(style)
	vim.schedule(function()
		if M.state.pending_confirm then
			notify.show("Resolve the pending dialog first", "WARN")
			return
		end
		if style then
			M.current_style = style
		end
		local s = get_style()
		if ui.is_open(GROUP, s) then
			return
		end

		local other = (s == "float") and "split" or "float"
		ui.close_style(GROUP, other)

		local file_path = utils.get_file_path()
		if file_path == "" then
			notify.show("Save the source file first (unnamed buffer)", "WARN")
			return
		end

		local problem_dir = utils.get_problem_dir_from(file_path)
		if problem_dir == "" then
			notify.show("No problem data directory", "WARN")
			return
		end

		M.state.gen = M.state.gen + 1
		M.state.problem_dir = problem_dir
		M.state.problem_name = vim.fn.fnamemodify(file_path, ":t:r")
		M.state.current_index = 1
		M.state.switching = false
		M.state.pending_confirm = false

		local function open_editor()
			ui.open(GROUP, s, get_style_config(), TITLES, WIN_OPTS, setup_ui)
		end

		if not utils.dir_exists(problem_dir) then
			local opened = confirm.open({
				title = "Create Problem Data",
				message = "Problem data not found. Create on save?",
				choices = {
					{ key = "y", label = "[Y] Yes", value = "yes" },
					{ key = "n", label = "[N] No", value = "no" },
				},
				default = "no",
				on_choice = function(action)
					if action ~= "yes" then
						M.reset_state()
						return
					end
					M.state.disk_count = 0
					begin_pending_case()
					log("INFO", "edit", "New problem data will be created on save")
					open_editor()
				end,
			})
			if not opened then
				log("WARN", "edit", "Confirmation unavailable")
				M.reset_state()
			end
			return
		end

		local count = scan_disk_count(problem_dir)
		M.state.disk_count = count
		if count == 0 then
			M.state.disk_count = 0
			begin_pending_case()
		else
			M.state.test_count = count
			M.state.pending_new = false
			load_case(1)
		end

		open_editor()
	end)
end

function M.is_open()
	return ui.is_open(GROUP, get_style())
end

return M
