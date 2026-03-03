---@module "faster-oj.module.utils"

---@class FOJ.UtilsModule
---@field config FOJ.Config 当前生效配置
local M = {}

local uv = vim.uv or vim.loop

-- 静态语言映射表，避免在函数内重复初始化
local LANGUAGE_MAP = {
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

---内部日志函数
---@param ... any
local function log(...)
	if M.config and M.config.debug then
		print(string.format("[FOJ][utils] %s", table.concat({ ... }, " ")))
	end
end

---初始化模块
---@param cfg FOJ.Config 用户传入配置
function M.setup(cfg)
	M.config = cfg or {}
end

---根据文件扩展名检测语言类型
---@param ext string 文件扩展名
---@return string language
function M.detect_language(ext)
	if not ext then
		return ""
	end
	ext = ext:lower()
	return LANGUAGE_MAP[ext] or ext
end

---获取当前缓冲区文件路径
---@return string file_path
function M.get_file_path()
	local path = vim.api.nvim_buf_get_name(0)
	return path ~= "" and path or ""
end

---获取当前题目 JSON 路径
---@return string json_path
function M.get_json_path()
	local file_path = M.get_file_path()
	if file_path == "" then
		return ""
	end

	local filename = vim.fn.fnamemodify(file_path, ":t:r")
	local json_dir = M.config.json_dir or vim.fn.stdpath("data") .. "/faster-oj"
	local json_path = json_dir .. "/" .. filename .. ".json"

	return vim.fn.fnamemodify(json_path, ":p")
end

---判断文件是否存在
---@param path string 文件路径
---@return boolean
function M.file_exists(path)
	if not path or path == "" then
		return false
	end
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "file"
end

---读取文件内容
---@param path string 文件路径
---@return string|nil
function M.read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

---读取当前缓冲区文件内容
---@return string|nil
function M.read_file_now()
	local path = M.get_file_path()
	return path ~= "" and M.read_file(path) or nil
end

---读取 JSON 文件
---@param path string JSON 文件路径
---@return table|nil
function M.read_json(path)
	if not M.file_exists(path) then
		return nil
	end
	local content = M.read_file(path)
	if not content then
		return nil
	end

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		log("JSON Decode Error:", path)
		return nil
	end
	return data
end

---写入 JSON 文件
---@param path string JSON 文件路径
---@param data table 待写入数据
---@return boolean success
function M.write_json(path, data)
	local ok, encoded = pcall(vim.json.encode, data)
	if not ok then
		log("JSON Encode Error")
		return false
	end

	local f = io.open(path, "w")
	if not f then
		log("Failed to open for writing:", path)
		return false
	end
	f:write(encoded)
	f:close()
	return true
end

---获取当前题目 JSON 内容
---@return table|nil
function M.get_json_file()
	return M.read_json(M.get_json_path())
end

---删除指定路径的文件
---@param path string 文件路径
---@return boolean success 是否成功删除
function M.erase(path)
	if not path or path == "" then
		return false
	end
	if not M.file_exists(path) then
		log("File not found, skip erase:", path)
		return true
	end

	local success, err = uv.fs_unlink(path)
	if not success then
		log("Failed to delete file:", path, err)
		return false
	end
	log("File deleted:", path)
	return true
end

---获取当前文件占位符变量
---@param file_path string 文件路径
---@return table vars
function M.get_vars(file_path)
	if not file_path or file_path == "" then
		return {}
	end
	return {
		FNAME = vim.fn.fnamemodify(file_path, ":t"),
		FNOEXT = vim.fn.fnamemodify(file_path, ":t:r"),
		FABSPATH = vim.fn.fnamemodify(file_path, ":p"),
		DIR = vim.fn.fnamemodify(file_path, ":h"),
	}
end

---字符串占位符替换
---@param str string 待替换字符串
---@param vars table 占位符变量表
---@return string
function M.expand(str, vars)
	if not str or str == "" then
		return ""
	end
	-- 支持 @VAR, $VAR, %VAR 以及 @(VAR) 等格式
	local result = str:gsub("[%@%$%%]%(?([%w_]+)%)?", function(k)
		return vars[k] or ""
	end)
	return result
end

return M
