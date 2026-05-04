---@module "faster-oj.module.stress"

local utils = require("faster-oj.module.utils")
local runner = require("faster-oj.module.run")
local stress_ui = require("faster-oj.module.ui.stress")
local notify = require("faster-oj.module.notify")

---@class FOJ.StressModule
---@field last_config table|nil
local M = {}
M.last_config = nil

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][stress][%s] %s: %s", level, func, msg))
	end
end

function M.setup(cfg)
	M.config = cfg or {}
	stress_ui.setup(cfg)
end

-- ── Picker ──────────────────────────────────────────────

local function pick_file(dir, title, cb)
	dir = vim.fn.expand(dir)
	local files = vim.fn.globpath(dir, "*", false, true)
	local file_list = {}
	for _, f in ipairs(files) do
		if vim.fn.isdirectory(f) == 0 then
			table.insert(file_list, f)
		end
	end
	if #file_list == 0 then
		notify.show("No files found in: " .. dir, "WARN")
		cb(nil)
		return
	end
	vim.ui.select(file_list, { prompt = title }, function(choice)
		cb(choice)
	end)
end

local function pick_files(dir, cb)
	dir = vim.fn.expand(dir)
	local selected = {}
	local function pick_next()
		local files = vim.fn.globpath(dir, "*", false, true)
		local file_list = { "[Done]" }
		for _, f in ipairs(files) do
			if vim.fn.isdirectory(f) == 0 then
				table.insert(file_list, f)
			end
		end
		vim.ui.select(file_list, {
			prompt = "Select data files (" .. #selected .. " selected) - [Done] to finish",
		}, function(choice)
			if not choice or choice == "[Done]" then
				cb(#selected > 0 and selected or nil)
				return
			end
			table.insert(selected, choice)
			pick_next()
		end)
	end
	pick_next()
end

-- ── Source resolvers ────────────────────────────────────

---@param source {type:string, data:string}
---@param cb fun(path:string|nil)
local function resolve_code(source, title, cb)
	if not source or not source.type then
		cb(nil)
		return
	end
	if source.type == "path" then
		if not utils.file_exists(source.data) then
			notify.show("Code file not found: " .. source.data, "ERROR")
			cb(nil)
			return
		end
		cb(source.data)
	elseif source.type == "find" then
		local dir = (source.data and source.data ~= "") and source.data or vim.fn.getcwd()
		pick_file(dir, title, cb)
	else
		notify.show("Unknown code source type: " .. source.type, "ERROR")
		cb(nil)
	end
end

---@param source {type:string, data:string}
---@param cb fun(inputs:table[]|nil)
local function resolve_data(source, cb)
	if not source or not source.type then
		cb(nil)
		return
	end
	if source.type == "path" then
		local paths = vim.split(source.data, "\n", { trimempty = true })
		local inputs = {}
		for _, p in ipairs(paths) do
			if utils.file_exists(p) then
				local content = utils.read_file(p) or ""
				table.insert(inputs, { input = content, label = vim.fn.fnamemodify(p, ":t") })
			end
		end
		if #inputs == 0 then
			notify.show("No valid data files found", "WARN")
			cb(nil)
			return
		end
		cb(inputs)
	elseif source.type == "find" then
		local dir = (source.data and source.data ~= "") and source.data or vim.fn.getcwd()
		pick_files(dir, function(paths)
			if not paths then
				cb(nil)
				return
			end
			local inputs = {}
			for _, p in ipairs(paths) do
				local content = utils.read_file(p) or ""
				table.insert(inputs, { input = content, label = vim.fn.fnamemodify(p, ":t") })
			end
			cb(inputs)
		end)
	elseif source.type == "data" then
		local temp_dir = M.config.temp_dir or ".temp"
		vim.fn.mkdir(temp_dir, "p")
		local temp_path = temp_dir .. "/stress_data_" .. os.time()
		utils.write_file(temp_path, source.data)
		cb({ { input = source.data, label = "inline", _temp_path = temp_path } })
	else
		notify.show("Unknown data source type: " .. source.type, "ERROR")
		cb(nil)
	end
end

-- ── Compile / Execute ───────────────────────────────────

---@param file_path string
---@param label string
---@param cb fun(success:boolean, msg:string)
local function compile_code(file_path, label, cb)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local has_compile = M.config.compile_command[ext]
		and M.config.compile_command[ext].exec
		and M.config.compile_command[ext].exec ~= ""

	if not has_compile then
		cb(true, "")
		return
	end
	runner.compile(file_path, true, function(success, msg, _)
		if not success then
			log("ERROR", "compile_code", label .. " FAILED: " .. (msg or ""))
		else
			log("INFO", "compile_code", label .. " OK")
		end
		cb(success, msg or "")
	end)
end

---@param file_path string
---@return FOJ.Command|nil
local function get_run_cmd(file_path)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	return M.config.run_command[ext]
end

---@param correct_cmd FOJ.Command
---@param test_cmd FOJ.Command
---@param correct_vars table
---@param test_vars table
---@param input_data {input:string, label:string}
---@param tl_ms integer
---@param ml_mb integer
---@param cb fun(res:table)
local function run_paired(correct_cmd, test_cmd, correct_vars, test_vars, input_data, tl_ms, ml_mb, cb)
	local res = {
		input = input_data.input,
		label = input_data.label,
		correct = nil,
		test = nil,
		match = nil,
	}
	local correct_done, test_done = false, false

	local function try_finish()
		if not correct_done or not test_done then
			return
		end
		if res.correct.state.type == "OK" and res.test.state.type == "OK" then
			res.match = (res.correct.output == res.test.output)
		else
			res.match = false
		end
		cb(res)
	end

	runner.run_single(correct_cmd, correct_vars, input_data.input, tl_ms, ml_mb, nil, function(raw)
		res.correct = raw
		correct_done = true
		try_finish()
	end)
	runner.run_single(test_cmd, test_vars, input_data.input, tl_ms, ml_mb, nil, function(raw)
		res.test = raw
		test_done = true
		try_finish()
	end)
end

-- ── Main ────────────────────────────────────────────────

---@param opts? table
function M.stress(opts)
	if not opts then
		if not M.last_config then
			notify.show("No previous stress config. Provide arguments.", "ERROR")
			return
		end
		opts = M.last_config
		log("INFO", "stress", "Re-running last config")
	end

	M.last_config = opts
	local tl_ms = opts.timeLimit or M.config.default_time_limit or 2000
	local ml_mb = opts.memoryLimit or M.config.default_memory_limit or 256

	if not opts.correct then
		notify.show("Missing 'correct'. Usage: correct=path:FILE or correct=find:", "ERROR")
		return
	end
	if not opts.test then
		notify.show("Missing 'test'. Usage: test=path:FILE or test=find:", "ERROR")
		return
	end

	stress_ui.close()
	local spin = notify.spinner_start("Setting up stress test ...")

	resolve_code(opts.correct, "Select correct code", function(correct_path)
		if not correct_path then
			notify.spinner_fail(spin, "Correct code not resolved")
			return
		end
		log("INFO", "stress", "Correct code: " .. correct_path)

		resolve_code(opts.test, "Select test code", function(test_path)
			if not test_path then
				notify.spinner_fail(spin, "Test code not resolved")
				return
			end
			log("INFO", "stress", "Test code: " .. test_path)

			-- 数据就绪后的后续流程
			local function after_data(inputs)
				if not inputs or #inputs == 0 then
					notify.spinner_fail(spin, "No data sources")
					return
				end

				notify.spinner_update(spin, "Compiling correct code ...")
				compile_code(correct_path, "Correct", function(c_ok)
					if not c_ok then
						notify.spinner_fail(spin, "Correct code compilation FAILED")
						stress_ui.state.size = 0
						stress_ui.state.results = {}
						stress_ui.show()
						stress_ui.update(0, {})
						return
					end

					notify.spinner_update(spin, "Compiling test code ...")
					compile_code(test_path, "Test", function(t_ok)
						if not t_ok then
							notify.spinner_fail(spin, "Test code compilation FAILED")
							stress_ui.state.size = 0
							stress_ui.state.results = {}
							stress_ui.show()
							stress_ui.update(0, {})
							return
						end

						notify.spinner_done(spin, "Compilation OK, running " .. #inputs .. " test(s) ...")

						local correct_cmd = get_run_cmd(correct_path)
						local test_cmd = get_run_cmd(test_path)
						local correct_vars = utils.get_vars(correct_path)
						local test_vars = utils.get_vars(test_path)

						if not correct_cmd then
							notify.show("No run command for correct code", "ERROR")
							return
						end
						if not test_cmd then
							notify.show("No run command for test code", "ERROR")
							return
						end

						stress_ui.state.size = #inputs
						stress_ui.state.results = {}
						stress_ui.show()
						stress_ui.update(#inputs, {})

						local active, idx = 0, 1
						local results = {}
						local max_workers = M.config.max_workers or 4

						local function fill_queue()
							while active < max_workers and idx <= #inputs do
								local i = idx
								idx, active = idx + 1, active + 1
								run_paired(
									correct_cmd,
									test_cmd,
									correct_vars,
									test_vars,
									inputs[i],
									tl_ms,
									ml_mb,
									function(res)
										res.index = i
										results[i] = res
										active = active - 1
										stress_ui.update(#inputs, results)
										fill_queue()

										local finished, matched = 0, 0
										for _, r in pairs(results) do
											finished = finished + 1
											if r.match then
												matched = matched + 1
											end
										end
										if finished == #inputs then
											if matched == #inputs then
												notify.show(
													string.format("Stress done: %d/%d matched", matched, #inputs),
													"DONE"
												)
											else
												notify.show(
													string.format("Stress done: %d/%d matched", matched, #inputs),
													"WARN"
												)
											end
											for _, inp in ipairs(inputs) do
												if inp._temp_path then
													os.remove(inp._temp_path)
												end
											end
										end
									end
								)
							end
						end
						fill_queue()
					end)
				end)
			end

			-- 数据源: 缺失时使用空输入
			if not opts.data then
				after_data({ { input = "", label = "(empty)" } })
			else
				resolve_data(opts.data, after_data)
			end
		end)
	end)
end

return M
