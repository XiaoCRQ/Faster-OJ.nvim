---@module "faster-oj.module.submit"
local utils = require("faster-oj.module.utils")
local uv = vim.uv or vim.loop

local M = {}

---@param cfg FOJ.Config 用户传入的配置
function M.setup(cfg)
	M.config = cfg
	utils.setup(cfg)
end

---@param ... any
local function log(...)
	if M.config and M.config.debug then
		print("[FOJ][submit]", ...)
	end
end

---核心提交逻辑：将数据写入 JSON 并发送广播
---@param ws table WebSocket 对象
---@param submit_data table 包含 language, code, url 的表
local function finalize_submission(ws, submit_data)
	local tmp_path = M.config.json_dir .. "/tmp.json"

	-- utils.write_json 内部应使用 vim.json.encode 以确保转义安全
	if not utils.write_json(tmp_path, submit_data) then
		log("Failed to write tmp.json")
		return
	end

	log("Submit JSON generated:", tmp_path)

	ws.wait_for_connection(M.config.max_time_out, function()
		ws.send("broadcast " .. tmp_path)
	end)
end

---@param ws table WebSocket 对象
function M.submit(ws)
	local file_path = utils.get_file_path()
	if file_path == "" then
		log("No active file")
		return
	end

	local ext = vim.fn.fnamemodify(file_path, ":e")
	local language = utils.detect_language(ext)
	local json_path = utils.get_json_path()
	local origin = utils.read_json(json_path)

	if not origin or not origin.url then
		log("Missing url in problem json:", json_path)
		return
	end

	local submit_data = {
		language = language,
		url = origin.url,
		code = "",
	}

	local cmd_cfg = M.config.code_obfuscator
	local vars = utils.get_vars(file_path)

	-- 检查是否需要执行代码混淆
	local should_obscure = cmd_cfg and cmd_cfg.cmd and cmd_cfg.cmd.exec ~= "" and cmd_cfg.result ~= ""

	if should_obscure then
		local exec = utils.expand(cmd_cfg.cmd.exec, vars)
		local result_path = utils.expand(cmd_cfg.result, vars)
		local args = {}
		for _, a in ipairs(cmd_cfg.cmd.args or {}) do
			table.insert(args, utils.expand(a, vars))
		end

		log("Starting obfuscation...")

		local stdout = uv.new_pipe(false)
		local stderr = uv.new_pipe(false)

		uv.spawn(
			exec,
			{ args = args, cwd = vars.DIR, hide = true, stdio = { nil, stdout, stderr } },
			function(code, signal)
				stdout:read_stop()
				stdout:close()
				stderr:read_stop()
				stderr:close()
				if code ~= 0 then
					log(string.format("Obfuscation failed (Exit code: %d, Signal: %d)", code, signal))
					return
				end

				-- 混淆成功，读取生成后的代码
				vim.schedule(function()
					submit_data.code = utils.read_file(result_path)
					if not submit_data.code then
						log("Failed to read obscured file:", result_path)
						return
					end
					finalize_submission(ws, submit_data)
				end)
			end
		)

		stdout:read_start(function(err, data)
			if data then
				log("[Obfuscator stdout]", data:gsub("\n$", ""))
			end
		end)

		stderr:read_start(function(err, data)
			if data then
				log("[Obfuscator stderr] ERROR:", data:gsub("\n$", ""))
			end
		end)
	else
		-- 直接读取当前文件
		submit_data.code = utils.read_file(file_path)
		if not submit_data.code then
			log("Failed to read current file:", file_path)
			return
		end
		finalize_submission(ws, submit_data)
	end
end

return M
