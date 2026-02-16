local M = {}

local function log(...)
	if M.config.server_debug then
		print("[FOJ][submit]", ...)
	end
end

-- 读取文件全部内容
local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

-- 判断文件是否存在
local function file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

-- 根据扩展名判断语言
local function detect_language(ext)
	ext = ext:lower()

	local map = {
		c = "c",
		h = "c",

		cpp = "cpp",
		cc = "cpp",
		cxx = "cpp",
		hpp = "cpp",

		py = "python",
		lua = "lua",

		js = "javascript",
		ts = "typescript",

		java = "java",
		rs = "rust",
		go = "go",
	}

	return map[ext] or ext -- 未匹配就直接返回扩展名
end

function M.submit(cfg, send)
	M.config = cfg

	-- 当前文件绝对路径
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		log("No active file")
		return
	end

	-- 读取当前文件内容
	local code = read_file(file_path)
	if not code then
		log("Failed to read current file:", file_path)
		return
	end

	-- 文件名（无扩展名）
	local filename = vim.fn.fnamemodify(file_path, ":t:r")

	-- 扩展名
	local ext = vim.fn.fnamemodify(file_path, ":e")
	if ext == "" then
		log("No file extension:", file_path)
		return
	end

	local language = detect_language(ext)

	-- JSON 路径
	local json_path = cfg.json_dir .. "/" .. filename .. ".json"
	json_path = vim.fn.fnamemodify(json_path, ":p")

	-- 检查是否存在
	if not file_exists(json_path) then
		log("JSON not found:", json_path)
		return
	end

	-- 读取 JSON
	local json_content = read_file(json_path)
	if not json_content then
		log("Failed to read JSON:", json_path)
		return
	end

	-- 解析 JSON
	local ok, data = pcall(vim.json.decode, json_content)
	if not ok or type(data) ~= "table" then
		log("Invalid JSON:", json_path)
		return
	end

	-- 写入字段
	data.code = code
	data.language = language

	-- 写回 JSON
	local new_json = vim.json.encode(data)
	local f = io.open(json_path, "w")
	if not f then
		log("Failed to write JSON:", json_path)
		return
	end
	f:write(new_json)
	f:close()

	log("Updated JSON:", json_path, "language:", language)

	-- 发送 broadcast
	send("broadcast " .. json_path)
end

return M
