local M = {}

function M.init(cfg)
	M.config = cfg
end

local function log(...)
	if M.config.server_debug then
		print("[FOJ][submit]", ...)
	end
end

local function detect_language(ext)
	ext = ext:lower()
	local map = {
		c = "c",
		h = "c",
		cpp = "cpp",
		cc = "cpp",
		cxx = "cpp",
		hpp = "cpp",
		hh = "cpp",
		py = "python",
		lua = "lua",
		js = "javascript",
		ts = "typescript",
		java = "java",
		rs = "rust",
		go = "go",
		pas = "pascal",
		kt = "kotlin",
		cs = "csharp",
	}
	return map[ext] or ext
end

-- ---------------- 文件路径 ----------------
local function get_file_path()
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		log("No active file")
	end
	return file_path
end

local function get_json_path()
	local file_path = get_file_path()
	local filename = vim.fn.fnamemodify(file_path, ":t:r")
	local json_path = M.config.json_dir .. "/" .. filename .. ".json"
	return vim.fn.fnamemodify(json_path, ":p")
end

function M.get_file_path()
	return get_file_path()
end

-- ---------------- 文件工具 ----------------
function M.file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function M.read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

function M.read_file_now()
	local file_path = get_file_path()
	local content = M.read_file(file_path)
	if not content then
		log("Failed to read current file:", file_path)
		return
	end
	return content
end

-- ---------------- JSON 工具 ----------------
local function read_json(path)
	if not M.file_exists(path) then
		log("JSON not found:", path)
		return nil
	end

	local content = M.read_file(path)
	if not content then
		log("Failed to read JSON:", path)
		return nil
	end

	local ok, data = pcall(vim.json.decode, content)
	if not ok or type(data) ~= "table" then
		log("Invalid JSON:", path)
		return nil
	end

	return data
end

local function write_json(path, data)
	local encoded = vim.json.encode(data)

	local f = io.open(path, "w")
	if not f then
		log("Failed to write JSON:", path)
		return false
	end

	f:write(encoded)
	f:close()
	return true
end

function M.get_json_file()
	return read_json(get_json_path())
end

-- ---------------- Submit 主流程 ----------------
function M.submit(send)
	local file_path = get_file_path()
	if file_path == "" then
		return
	end

	local code = M.read_file(file_path)
	if not code then
		log("Failed to read current file:", file_path)
		return
	end

	local ext = vim.fn.fnamemodify(file_path, ":e")
	if ext == "" then
		log("No file extension:", file_path)
		return
	end

	local language = detect_language(ext)

	local json_path = get_json_path()
	local data = read_json(json_path)
	if not data then
		return
	end

	data.code = code
	data.language = language

	if not write_json(json_path, data) then
		return
	end

	log("Updated JSON:", json_path, "language:", language)

	send("broadcast " .. json_path)
end

return M
