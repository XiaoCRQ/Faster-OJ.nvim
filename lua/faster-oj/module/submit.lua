---@module "faster-oj.module.submit"

local utils = require("faster-oj.module.utils")
local notify = require("faster-oj.module.notify")
local uv = vim.uv or vim.loop

local M = {}

function M.setup(cfg)
	M.config = cfg
	utils.setup(cfg)
end

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][submit][%s] %s: %s", level, func, msg))
	end
end

---写入提交 JSON 并发送广播
---@param ws table
---@param submit_data table
local function finalize_submission(ws, submit_data)
	local temp_path = M.config.data_dir .. "/temp.json"

	if M.config.clipboard_submit and submit_data.code ~= "" then
		vim.fn.setreg("+", submit_data.code)
		log("INFO", "finalize_submission", "Code copied to clipboard")
	end

	if not utils.write_json(temp_path, submit_data) then
		log("ERROR", "finalize_submission", "Failed to write temp.json")
		notify.show("Failed to create submission file", "ERROR")
		return
	end

	log("INFO", "finalize_submission", "Submit JSON written: " .. temp_path)

	ws.wait_for_connection(M.config.max_time_out, function()
		ws.send("broadcast " .. temp_path)
		notify.show("Submitted OK", "DONE")
	end, function()
		notify.show("No connection", "ERROR")
	end)
end

---读取代码并提交 (原代码)
local function submit_code(submit_data, file_path, ws)
	submit_data.code = utils.read_file(file_path)
	if not submit_data.code then
		log("ERROR", "submit_code", "Failed to read file: " .. file_path)
		notify.show("Failed to read file", "ERROR")
		return
	end
	finalize_submission(ws, submit_data)
end

---提交当前代码到 OJ 平台
function M.submit(ws)
	local file_path = utils.get_file_path()
	if file_path == "" then
		log("WARN", "submit", "No active file")
		notify.show("No active file", "WARN")
		return
	end

	if not ws or not ws.send then
		log("ERROR", "submit", "WebSocket not available")
		notify.show("WebSocket server not running. Start with :FOJ start", "ERROR")
		return
	end

	local ext = vim.fn.fnamemodify(file_path, ":e")
	local language = utils.detect_language(ext)
	local json_path = utils.get_json_path()
	local origin = utils.read_json(json_path)

	if not origin or not origin.url then
		log("ERROR", "submit", "Missing url in problem json: " .. json_path)
		notify.show("No problem URL found", "WARN")
		return
	end

	local submit_data = {
		language = language,
		url = origin.url,
		code = "",
	}

	local cmd_cfg = M.config.code_obfuscator
	local vars = utils.get_vars(file_path)

	local should_obscure = cmd_cfg and cmd_cfg.cmd and cmd_cfg.cmd.exec ~= "" and cmd_cfg.result ~= ""

	if should_obscure then
		local exec = utils.expand(cmd_cfg.cmd.exec, vars)

		if vim.fn.executable(exec) ~= 1 then
			log("WARN", "submit", "Obfuscator not found: " .. exec .. " - falling back")
			submit_code(submit_data, file_path, ws)
			return
		end

		local result_path = utils.expand(cmd_cfg.result, vars)
		local args = {}
		for _, a in ipairs(cmd_cfg.cmd.args or {}) do
			table.insert(args, utils.expand(a, vars))
		end

		log("INFO", "submit", "Starting obfuscation via " .. exec)
		local spin = notify.spinner_start("Obfuscating ...")

		local stdout = uv.new_pipe(false)
		local stderr = uv.new_pipe(false)

		uv.spawn(exec, { args = args, cwd = vars.DIR, hide = true, stdio = { nil, stdout, stderr } }, function(code)
			stdout:read_stop()
			stdout:close()
			stderr:read_stop()
			stderr:close()

			if code ~= 0 then
				log("ERROR", "submit", string.format("Obfuscation failed (code=%d)", code))
				notify.spinner_fail(spin, "Obfuscation failed, submitting original")
				submit_code(submit_data, file_path, ws)
				return
			end

			vim.schedule(function()
				submit_data.code = utils.read_file(result_path)
				if not submit_data.code then
					log("ERROR", "submit", "Failed to read obfuscated file: " .. result_path)
					notify.spinner_fail(spin, "Obfuscation failed")
					submit_code(submit_data, file_path, ws)
					return
				end
				notify.spinner_done(spin, "Obfuscated OK, submitting ...")
				finalize_submission(ws, submit_data)
			end)
		end)

		stdout:read_start(function(_, data)
			if data then
				log("INFO", "obfuscator:stdout", data:gsub("\n$", ""))
			end
		end)

		stderr:read_start(function(_, data)
			if data then
				log("WARN", "obfuscator:stderr", data:gsub("\n$", ""))
			end
		end)
	else
		submit_code(submit_data, file_path, ws)
	end
end

return M
