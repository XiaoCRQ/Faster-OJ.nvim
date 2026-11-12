---@module "faster-oj.module.ui.tests_edit"

local utils = require("faster-oj.module.utils")
local ui = require("faster-oj.module.ui")
local tc_view = require("faster-oj.module.ui.tc_view")
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
---current_index:  1-based index of the open TC.
---pending_new:    the open TC is a new case that has not been written yet.
---raw:            exact on-disk bytes of the open TC (nil when missing/new).
---live:           latest in-memory content (buffer content after capture).
---busy:           a switch/add/delete/close decision is in progress.
local function fresh_state()
	return {
		problem_dir = "",
		problem_name = "",
		disk_count = 0,
		current_index = 1,
		pending_new = false,
		raw = { input = nil, output = nil },
		live = { input = "", output = "" },
		busy = false,
	}
end

M.state = fresh_state()
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
	M.current_style = M.config.tc_edit_ui and M.config.tc_edit_ui.default_style or "float"
end

---Get current effective style
local function get_style()
	return tc_view.get_style(M.current_style, M.config and M.config.tc_edit_ui)
end

---Get style-specific config table
local function get_style_config()
	return tc_view.get_style_config(M.config and M.config.tc_edit_ui, get_style())
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

---Total rows shown in the TC list (disk cases + optional pending case).
local function tc_count()
	return M.state.disk_count + (M.state.pending_new and 1 or 0)
end

---Set buffer lines. `lock` restores nomodifiable (TC list only).
local function set_lines(buf, lines, lock)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.bo[buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines or {})
	if lock then
		vim.bo[buf].modifiable = false
	end
end

---Render the open TC from memory.
local function render_current()
	local inst = get_instance()
	if not inst or not inst.bufs then
		return
	end
	set_lines(inst.bufs.si, vim.split(M.state.live.input or "", "\n"))
	set_lines(inst.bufs.so, vim.split(M.state.live.output or "", "\n"))
end

---Capture the open buffers into `live`.
---@param inst? table  instance to read from (defaults to the current one)
---@return boolean
local function capture_current(inst)
	inst = inst or get_instance()
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

local function has_unsaved_changes()
	if M.state.pending_new then
		return true
	end
	capture_current()
	-- Compare normalized text: one trailing blank line is not a real edit.
	return normalize(M.state.live.input) ~= normalize(M.state.raw.input)
		or normalize(M.state.live.output) ~= normalize(M.state.raw.output)
end

local function focus_tc_row()
	tc_view.focus_row(GROUP, get_style(), M.state.current_index)
end

local function update_tc_list()
	local inst = get_instance()
	if not inst or not inst.bufs or not inst.bufs.tc then
		return
	end
	local lines = {}
	for i = 1, tc_count() do
		lines[i] = "  TC " .. (i - 1)
	end
	set_lines(inst.bufs.tc, lines, true)
end

---Load an existing TC from disk into the open buffers.
local function load_case(index)
	local dir = M.state.problem_dir
	local file_idx = index - 1
	M.state.raw.input = utils.read_file(dir .. file_idx .. ".in")
	M.state.raw.output = utils.read_file(dir .. file_idx .. ".out")
	M.state.live.input = normalize(M.state.raw.input)
	M.state.live.output = normalize(M.state.raw.output)
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

---Discard unsaved edits (and a pending new TC, if any).
local function discard_current_edits()
	if M.state.pending_new then
		M.state.pending_new = false
		M.state.current_index = math.min(M.state.current_index, math.max(tc_count(), 1))
		update_tc_list()
	end
	M.state.live.input = normalize(M.state.raw.input)
	M.state.live.output = normalize(M.state.raw.output)
	render_current()
end

---Prepare a new unsaved TC as the open case.
local function begin_pending_case()
	M.state.pending_new = true
	M.state.current_index = tc_count()
	M.state.raw.input, M.state.raw.output = nil, nil
	M.state.live.input, M.state.live.output = "", ""
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
	local was_pending = M.state.pending_new
	local in_content, out_content

	if was_pending then
		in_content, out_content = M.state.live.input, M.state.live.output
	else
		-- Preserve exact bytes for unchanged TCs.
		in_content = (M.state.raw.input ~= nil and M.state.live.input == normalize(M.state.raw.input))
			and M.state.raw.input
			or M.state.live.input
		out_content = (M.state.raw.output ~= nil and M.state.live.output == normalize(M.state.raw.output))
			and M.state.raw.output
			or M.state.live.output
	end

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

	local data = utils.read_json(dir .. "problem.json")
	if type(data) ~= "table" then
		data = {
			url = "",
			name = M.state.problem_name,
			memoryLimit = M.config.default_memory_limit or 256,
			timeLimit = M.config.default_time_limit or 2000,
		}
	end
	data.testCount = M.state.disk_count + (was_pending and 1 or 0)
	if not utils.write_json(dir .. "problem.json", data) then
		cleanup_partial()
		notify.show("Failed to save problem metadata", "ERROR")
		return false
	end

	if was_pending then
		M.state.pending_new = false
		M.state.disk_count = data.testCount
	end

	M.state.raw.input, M.state.raw.output = in_content, out_content
	M.state.live.input, M.state.live.output = normalize(in_content), normalize(out_content)

	notify.show("Problem data saved", "INFO")
	log("INFO", "save", string.format("Saved TC %d to %s", file_idx, dir))
	return true
end

function M.reset_state()
	M.state = fresh_state()
end

---Resolve unsaved edits, then run `action`.
---@param message string
---@param action fun()
---@param on_cancel? fun()
---@return boolean started false when another decision is already pending
local function with_unsaved(message, action, on_cancel)
	if M.state.busy then
		return false
	end
	M.state.busy = true

	local function proceed()
		M.state.busy = false
		action()
	end

	local function cancel()
		M.state.busy = false
		if on_cancel then
			on_cancel()
		else
			focus_tc_row()
		end
	end

	if not has_unsaved_changes() then
		proceed()
		return true
	end

	if not confirm_enabled() then
		log("INFO", "with_unsaved", "Discarding unsaved changes (confirmation disabled)")
		discard_current_edits()
		proceed()
		return true
	end

	local opened = confirm.open({
		title = "Unsaved Changes",
		message = message,
		default = "save",
		on_choice = function(choice)
			if choice == "save" then
				if M.save() then
					proceed()
				else
					cancel()
				end
			elseif choice == "discard" then
				discard_current_edits()
				proceed()
			else
				cancel()
			end
		end,
	})
	if not opened then
		notify.show("Resolve the pending dialog first", "WARN")
		cancel()
	end
	return true
end

---Switch the open TC (TC list cursor moved).
---@param target integer 1-based index
function M.request_switch(target)
	local count = tc_count()
	if target < 1 or target > count or target == M.state.current_index then
		return
	end
	with_unsaved(
		string.format("TC %d has unsaved changes. Save before switching?", M.state.current_index - 1),
		function()
			M.state.current_index = target
			load_case(target)
			tc_view.focus_row(GROUP, get_style(), target)
		end
	)
end

---Create a new pending TC. It always counts as dirty until saved.
function M.add()
	with_unsaved(
		string.format("TC %d has unsaved changes. Save before creating a new TC?", M.state.current_index - 1),
		function()
			begin_pending_case()
			update_tc_list()
			render_current()
			tc_view.focus_row(GROUP, get_style(), M.state.current_index)
		end
	)
end

---Delete the open TC immediately (with confirmation when enabled).
function M.delete_current()
	if M.state.busy or tc_count() <= 1 then
		return
	end

	local idx = M.state.current_index
	local function do_delete()
		if M.state.pending_new then
			M.state.pending_new = false
		else
			utils.delete_test_case(M.state.problem_dir, idx - 1, M.state.disk_count)
			M.state.disk_count = M.state.disk_count - 1
			utils.update_test_count(M.state.problem_dir, M.state.disk_count)
		end
		M.state.current_index = math.min(idx, math.max(tc_count(), 1))
		update_tc_list()
		load_case(M.state.current_index)
		tc_view.focus_row(GROUP, get_style(), M.state.current_index)
		notify.show("Test case deleted", "INFO")
	end

	if not confirm_enabled() then
		do_delete()
		return
	end

	M.state.busy = true
	local opened = confirm.open({
		title = "Delete Test Case",
		message = string.format("Delete TC %d? Unsaved changes will be lost.", idx - 1),
		choices = {
			{ key = "y", label = "[Y] Yes", value = "delete" },
			{ key = "n", label = "[N] No", value = "cancel" },
		},
		default = "cancel",
		on_choice = function(action)
			M.state.busy = false
			if action == "delete" then
				do_delete()
			else
				focus_tc_row()
			end
		end,
	})
	if not opened then
		M.state.busy = false
		notify.show("Resolve the pending dialog first", "WARN")
		focus_tc_row()
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

		local function do_close()
			ui.close_style(GROUP, get_style())
			M.reset_state()
			if cb then
				cb(true)
			end
		end

		local started = with_unsaved(
			string.format("TC %d has unsaved changes. Save before closing?", M.state.current_index - 1),
			do_close,
			function()
				if cb then
					cb(false)
				end
			end
		)
		if not started then
			notify.show("Resolve the pending dialog first", "WARN")
			if cb then
				cb(false)
			end
		end
	end)
end

---Shared on_created callback for open / toggle / resize.
local function setup_ui()
	local style = get_style()
	local inst = ui.get_instance(GROUP, style)
	if not inst or not inst.bufs then
		return
	end

	tc_view.attach({
		group = GROUP,
		style = style,
		inst = inst,
		row_range = function()
			return 1, tc_count()
		end,
		on_before_leave = function()
			capture_current(inst)
		end,
		on_row = function(row)
			if M.state.busy then
				return
			end
			if row ~= M.state.current_index then
				M.request_switch(row)
			end
		end,
		on_leave = function()
			if M.is_open() then
				M.close()
			end
		end,
	})

	update_tc_list()
	render_current()
	M.bind_keys()
	tc_view.focus_row(GROUP, style, M.state.current_index)
end

---Bind keymaps.
function M.bind_keys()
	local inst = get_instance()
	if not inst then
		return
	end
	local style = get_style()
	local maps = M.config.tc_edit_ui.mappings

	local function focus_tc()
		local win = ui.get_win_by_key(GROUP, "tc", style)
		if win then
			vim.api.nvim_set_current_win(win)
			tc_view.focus_row(GROUP, style, M.state.current_index)
		end
	end

	local function focus_detail(key)
		local win = ui.get_win_by_key(GROUP, key, style)
		if win then
			vim.api.nvim_set_current_win(win)
		end
	end

	local function move(step)
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local target = row + step
		if target < 1 or target > tc_count() then
			return
		end
		tc_view.focus_row(GROUP, style, target)
		-- Drive the switch now: API cursor moves do not reliably fire CursorMoved.
		M.request_switch(target)
	end

	local function jump(key, step)
		local curr_idx = 1
		for i, v in ipairs(EDIT_CYCLE) do
			if v == key then
				curr_idx = i
				break
			end
		end
		focus_detail(EDIT_CYCLE[(curr_idx + step - 1) % #EDIT_CYCLE + 1])
	end

	for key, buf in pairs(inst.bufs) do
		tc_view.bind(buf, maps.toggle_style, M.toggle_style)
		tc_view.bind(buf, maps.write, M.save)
		if key == "tc" then
			tc_view.bind(buf, maps.close, M.close)
			tc_view.bind(buf, maps.edit, function()
				focus_detail("si")
			end)
			tc_view.bind(buf, maps.focus_next, function()
				move(1)
			end)
			tc_view.bind(buf, maps.focus_prev, function()
				move(-1)
			end)
			tc_view.bind(buf, maps.add, M.add)
			tc_view.bind(buf, maps.erase, M.delete_current)
		else
			tc_view.bind(buf, maps.close, focus_tc)
			tc_view.bind(buf, maps.edit_focus_next, function()
				jump(key, 1)
			end)
			tc_view.bind(buf, maps.edit_focus_prev, function()
				jump(key, -1)
			end)
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
	if M.state.busy then
		return
	end

	capture_current()
	ui.close_style(GROUP, old_style)
	M.current_style = new_style
	ui.open(GROUP, new_style, get_style_config(), TITLES, WIN_OPTS, setup_ui)
end

---@param style? '"float"'|'"split"'
function M.edit(style)
	vim.schedule(function()
		if M.state.busy then
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

		M.reset_state()
		M.state.problem_dir = problem_dir
		M.state.problem_name = vim.fn.fnamemodify(file_path, ":t:r")

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
					begin_pending_case()
					log("INFO", "edit", "New problem data will be created on save")
					open_editor()
				end,
			})
			if not opened then
				log("WARN", "edit", "Confirmation unavailable")
				notify.show("Resolve the pending dialog first", "WARN")
				M.reset_state()
			end
			return
		end

		M.state.disk_count = scan_disk_count(problem_dir)
		if M.state.disk_count == 0 then
			begin_pending_case()
		else
			load_case(1)
		end
		open_editor()
	end)
end

function M.is_open()
	return ui.is_open(GROUP, get_style())
end

return M
