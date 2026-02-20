local M = {}

local function log(...)
	if M.config.debug then
		print("[FOJ][utils]", ...)
	end
end

function M.setup(cfg)
	M.config = cfg or {}
end

function M.detect_language(ext)
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

function M.get_file_path()
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		log("No active file")
	end
	return file_path
end

function M.get_json_path()
	local file_path = M.get_file_path()
	local filename = vim.fn.fnamemodify(file_path, ":t:r")
	local json_path = M.config.json_dir .. "/" .. filename .. ".json"
	return vim.fn.fnamemodify(json_path, ":p")
end

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
	local file_path = M.get_file_path()
	local content = M.read_file(file_path)
	if not content then
		log("Failed to read current file:", file_path)
		return
	end
	return content
end

function M.read_json(path)
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

function M.write_json(path, data)
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
	return M.read_json(M.get_json_path())
end

function M.get_vars(file_path)
	return {
		FNAME = vim.fn.fnamemodify(file_path, ":t"),
		FNOEXT = vim.fn.fnamemodify(file_path, ":t:r"),
		FABSPATH = vim.fn.fnamemodify(file_path, ":p"),
		DIR = vim.fn.fnamemodify(file_path, ":h"),
	}
end

function M.expand(str, vars)
	if not str then
		return ""
	end
	-- 括号截断多返回值，防止 table.insert 报错
	return (str:gsub("[%@%$%%]%(?([%w_]+)%)?", function(k)
		return vars[k] or ""
	end))
end

return M
