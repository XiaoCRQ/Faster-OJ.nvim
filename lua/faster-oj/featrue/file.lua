local utils = require("faster-oj.featrue.utils")
local M = {}

function M.setup(cfg)
	M.config = cfg
	utils.setup(cfg)
end

local function log(...)
	if M.config.debug then
		print("[FOJ][submit]", ...)
	end
end

function M.submit(send)
	local file_path = utils.get_file_path()
	if file_path == "" then
		log("No active file")
		return
	end

	if M.config.code_obfuscator then
		local cmd = M.config.code_obfuscator
		local os_code = cmd.file_path
		local vars = utils.get_vars(file_path)
		local exec = utils.expand(cmd.exec, vars)
		local args = {}
		for _, a in ipairs(cmd.args or {}) do
			table.insert(args, (utils.expand(a, vars)))
		end
		-- TODO: code混淆器
	end

	local code = utils.read_file(file_path)
	if not code then
		log("Failed to read current file:", file_path)
		return
	end

	local ext = vim.fn.fnamemodify(file_path, ":e")
	if ext == "" then
		log("No file extension:", file_path)
		return
	end

	local language = utils.detect_language(ext)

	local json_path = utils.get_json_path()
	local origin = utils.read_json(json_path)
	if not origin or not origin.url then
		log("Missing url in problem json:", json_path)
		return
	end

	local submit_data = {
		language = language,
		code = code,
		url = origin.url,
	}

	local tmp_path = M.config.json_dir .. "/tmp.json"
	if not utils.write_json(tmp_path, submit_data) then
		log("Failed to write tmp.json")
		return
	end

	log("Submit JSON generated:", tmp_path)

	send("broadcast " .. tmp_path)
end

return M
