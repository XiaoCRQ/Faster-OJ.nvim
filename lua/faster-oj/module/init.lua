---@module "faster-oj.module.init"

local ui = require("faster-oj.module.ui.tests")
local edit = require("faster-oj.module.ui.tests_edit")
local ui_engine = require("faster-oj.module.ui")
local utils = require("faster-oj.module.utils")
local runner = require("faster-oj.module.run")
local submit = require("faster-oj.module.submit")
local stress_mod = require("faster-oj.module.stress")
local stress_ui = require("faster-oj.module.ui.stress")
local notify = require("faster-oj.module.notify")

---@class FOJ.moduleModule
---@field config FOJ.Config
---@field setup fun(cfg:FOJ.Config)
---@field submit fun(send:any)
---@field run fun(need_compile:boolean)
---@field show fun(ctrl:string?)
---@field close fun(ctrl:string?)
---@field last_session string|nil
local M = {}

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config.debug then
		print(string.format("[FOJ][module][%s] %s: %s", level, func, msg))
	end
end

function M.setup(cfg)
	M.config = cfg or {}
	ui.setup(cfg)
	utils.setup(cfg)
	runner.setup(cfg)
	submit.setup(cfg)
	edit.setup(cfg)
	stress_mod.setup(cfg)
end

function M.submit(send)
	submit.submit(send)
end

function M.run(need_compile)
	-- Close all edit styles
	ui_engine.close("EditUI")

	local file_path = utils.get_file_path()
	local json = utils.get_json_file()
	local tests = {}

	vim.cmd("write")

	if json == nil then
		log("WARN", "run", "No problem data found")
		notify.show("No problem data found", "WARN")
		return
	end

	local test_count = json.testCount or 0
	local problem_dir = utils.get_problem_dir_from(file_path)
	for i = 0, test_count - 1 do
		local tc = utils.read_test_case(problem_dir, i)
		tests[i + 1] = { input = tc.input, expected = tc.output }
	end

	ui.update(test_count, tests)

	local ext = vim.fn.fnamemodify(file_path, ":e")
	local has_compile = M.config.compile_command[ext]
		and M.config.compile_command[ext].exec
		and M.config.compile_command[ext].exec ~= ""

	local compile_spin = nil
	if has_compile and need_compile ~= false then
		compile_spin = notify.spinner_start("Compiling " .. vim.fn.fnamemodify(file_path, ":t"))
	end

	log("INFO", "run", "Starting test execution")

	runner.compile(file_path, need_compile, function(success, msg, did_compile)
		if not success then
			if compile_spin then
				notify.spinner_fail(compile_spin, "Compilation FAILED")
			end
			notify.show("Compilation FAILED", "ERROR")
			vim.notify(msg or "", vim.log.levels.ERROR, { title = "Compilation Error" })
			return
		end

		if did_compile then
			notify.spinner_done(compile_spin, "Compilation OK")
		end

		if not ui.is_open() then
			ui.show()
		end

		log("INFO", "run", "Running " .. test_count .. " test(s)")
		notify.show("Running " .. test_count .. " test(s) ...", "INFO", 2000)

		runner.run(file_path, json, function(res)
			log("INFO", "run", "Test " .. res.test_index .. " completed")
			tests[res.test_index] = res
			ui.update(test_count, tests)

			local finished = 0
			local ac_count = 0
			for _, t in pairs(tests) do
				finished = finished + 1
				if t.state and t.state.type == "AC" then
					ac_count = ac_count + 1
				end
			end
			if finished == test_count then
				M.last_session = "tests"
				log("INFO", "run", string.format("All done: %d/%d AC", ac_count, finished))
				local total = test_count
				if ac_count == total then
					notify.show(string.format("Done: %d/%d AC", ac_count, total), "DONE")
				else
					notify.show(string.format("Done: %d/%d AC", ac_count, total), "WARN")
				end
			end
		end)
	end)
end

-- ── Unified show ─────────────────────────────────────────

---Returns true if any UI window is currently open (any viewer, any style).
local function any_open()
	return ui.is_open() or edit.is_open() or stress_ui.is_open()
end

--- Show/toggle/switch windows.
--- ctrl: "test"|"edit"|"stress" [float|split]
---   nil / ""         -> close all if any open, else reopen last session
---   "test"           -> toggle test viewer (default_style)
---   "test float"     -> show test viewer in float style
---   "test split"     -> show test viewer in split style
---   "edit"           -> toggle edit viewer
---   "edit float" / "edit split"
---   "stress"         -> show last stress results (if any)
---   "stress float" / "stress split"
---@param ctrl string|nil
function M.show(ctrl)
	-- Parse "sub1 [sub2]" -> viewer + optional style
	local viewer, style
	if ctrl and ctrl ~= "" then
		local parts = vim.split(ctrl, "%s+", { trimempty = true })
		local sub1 = parts[1]:lower()

		-- Map user-facing names to internal viewer keys
		if sub1 == "test" then
			viewer = "tests"
		elseif sub1 == "edit" then
			viewer = "edit"
		elseif sub1 == "stress" then
			viewer = "stress"
		else
			return -- invalid, no-op
		end

		style = (parts[2] or ""):lower()
		if style ~= "float" and style ~= "split" then
			style = nil
		end
	end

	if viewer == "edit" then
		if style then
			edit.current_style = style
		end
		if edit.is_open() then
			edit.close()
		else
			edit.edit()
			M.last_session = "edit"
		end
	elseif viewer == "stress" then
		if style then
			stress_ui.current_style = style
		end
		if stress_ui.is_open() then
			stress_ui.close()
		else
			if stress_ui.state and stress_ui.state.size and stress_ui.state.size > 0 then
				stress_ui.show()
				M.last_session = "stress"
			end
		end
	elseif viewer == "tests" then
		if style then
			ui.current_style = style
		end
		if ui.is_open() then
			ui.close()
		else
			ui.show()
			if ui.is_open() then
				M.last_session = "tests"
			end
		end
	else
		-- nil / "" : close all if any open, else reopen last session
		if any_open() then
			M.close()
			return
		end
		if not M.last_session then
			return
		end
		if M.last_session == "tests" then
			ui.show()
		elseif M.last_session == "edit" then
			edit.edit()
		elseif M.last_session == "stress" then
			stress_ui.show()
		end
	end
end

-- ── Unified close ────────────────────────────────────────

--- Close windows.
--- ctrl:
---   nil / ""      -> close all UI windows (all groups, both styles)
---   "test"        -> close test viewer (both styles)
---   "edit"        -> close edit viewer (both styles)
---   "stress"      -> close stress viewer (both styles)
---   invalid       -> no-op
---@param ctrl string|nil
function M.close(ctrl)
	if not ctrl or ctrl == "" then
		ui_engine.close("TestUI")
		ui_engine.close("EditUI")
		ui_engine.close("StressUI")
	else
		local sub = ctrl:lower()
		if sub == "test" then
			ui_engine.close("TestUI")
		elseif sub == "edit" then
			ui_engine.close("EditUI")
		elseif sub == "stress" then
			ui_engine.close("StressUI")
		end
	end
end

---@param opts? table
function M.stress(opts)
	stress_mod.stress(opts)
	M.last_session = "stress"
end

function M.erase()
	local file_path = utils.get_file_path()
	local file_name = vim.fn.fnamemodify(file_path, ":t:r")
	local problem_dir = utils.get_problem_dir()
	if file_path == "" or file_name == "" then
		return
	end
	if vim.fn.confirm("Delete " .. file_name .. "?", "&Yes\n&No", 2) == 1 then
		vim.cmd("bd!")
		utils.erase(file_path)
		utils.delete_problem_dir(problem_dir)
		notify.show("Deleted: " .. file_name, "INFO")
	end
end

function M.find(sub)
	local picker_title
	local path

	if sub == "template" then
		path = M.config.template_dir
		picker_title = "Template Files"
	elseif sub == "problem" then
		path = M.config.work_dir
		picker_title = "Problem Files"
	elseif sub == "data" then
		path = M.config.data_dir
		picker_title = "Problem Data"
	else
		return
	end

	path = vim.fn.expand(path)

	local ok, snacks = pcall(require, "snacks")
	if ok and snacks.picker then
		snacks.picker.files({ cwd = path, title = picker_title })
		return
	end

	local ok_telescope, telescope = pcall(require, "telescope.builtin")
	if ok_telescope then
		telescope.find_files({ cwd = path, prompt_title = picker_title })
		return
	end

	local ok_fzf, fzf = pcall(require, "fzf-lua")
	if ok_fzf then
		fzf.files({ cwd = path, prompt = picker_title .. "> " })
		return
	end

	local ok_mini, mini_pick = pcall(require, "mini.pick")
	if ok_mini then
		mini_pick.builtin.files(nil, { source = { cwd = path } })
		return
	end

	if vim.ui and vim.ui.select then
		local files = vim.fn.globpath(path, "*", false, true)
		if #files == 0 then
			return
		end
		vim.ui.select(files, { prompt = picker_title }, function(choice)
			if choice then
				vim.cmd("edit " .. choice)
			end
		end)
		return
	end
end

return M
