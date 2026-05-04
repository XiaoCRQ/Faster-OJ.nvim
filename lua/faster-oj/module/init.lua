---@module "faster-oj.module.init"

local ui = require("faster-oj.module.ui.tests")
local utils = require("faster-oj.module.utils")
local runner = require("faster-oj.module.run")
local submit = require("faster-oj.module.submit")
local edit = require("faster-oj.module.ui.tests_edit")
local stress_mod = require("faster-oj.module.stress")
local notify = require("faster-oj.module.notify")

---@class FOJ.moduleModule
---@field config FOJ.Config
---@field setup fun(cfg:FOJ.Config)
---@field submit fun(send:any)
---@field run fun(need_compile:boolean)
---@field show fun()
---@field close fun()
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
	edit.close(function()
		local file_path = utils.get_file_path()
		local json = utils.get_json_file()
		local tests = {}
		local test_count = 0

		vim.cmd("write")

		if json == nil then
			log("WARN", "run", "No problem data found")
			notify.show("No problem data found", "WARN")
			return
		end

		ui.update(json.testCount or 0, tests)

		local ext = vim.fn.fnamemodify(file_path, ":e")
		local has_compile = M.config.compile_command[ext]
			and M.config.compile_command[ext].exec
			and M.config.compile_command[ext].exec ~= ""

		local compile_spin = nil
		if has_compile and need_compile ~= false then
			compile_spin = notify.spinner_start("Compiling " .. vim.fn.fnamemodify(file_path, ":t") .. " ...")
		end

		log("INFO", "run", "Starting test execution")

		runner.compile(file_path, need_compile, function(success, msg, did_compile)
			if not success then
				if compile_spin then
					notify.spinner_fail(compile_spin, "Compilation FAILED")
				end
				vim.notify("[FOJ] Compilation FAILED:\n" .. msg, vim.log.levels.ERROR)
				return
			end

			if did_compile then
				notify.spinner_done(compile_spin, "Compilation OK")
			end

			if not ui.is_open() then
				ui.show()
			end

			log("INFO", "run", "Running " .. (json.testCount or 0) .. " test(s)")
			notify.show("Running " .. (json.testCount or 0) .. " test(s) ...", "INFO", 2000)

			runner.run(file_path, json, function(res)
				log("INFO", "run", "Test " .. res.test_index .. " completed")
				tests[res.test_index] = res
				ui.update(json.testCount or 0, tests)

				local finished = 0
				local ac_count = 0
				for _, t in pairs(tests) do
					finished = finished + 1
					if t.state and t.state.type == "AC" then
						ac_count = ac_count + 1
					end
				end
				if finished == (json.testCount or 0) then
					log("INFO", "run", string.format("All done: %d/%d AC", ac_count, finished))
					local total = json.testCount or 0
					if ac_count == total then
						notify.show(string.format("Done: %d/%d AC", ac_count, total), "DONE")
					else
						notify.show(string.format("Done: %d/%d AC", ac_count, total), "WARN")
					end
				end
			end)
		end)
	end)
end

function M.show()
	edit.close()
	if ui.is_open() then
		ui.close()
		return
	end
	ui.show()
end

function M.close()
	ui.close()
end

---启动对拍测试
---@param opts? table
function M.stress(opts)
	stress_mod.stress(opts)
end

function M.edit()
	ui.close()
	if edit.is_open() then
		edit.close()
		return
	end
	edit.edit()
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
		path = M.config.json_dir
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
