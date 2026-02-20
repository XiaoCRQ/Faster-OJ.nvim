-- ================================================================
-- FOJ Utils Module
-- ================================================================
-- 负责：
--   1. 文件路径管理
--   2. 文件/JSON 读写
--   3. 语言检测
--   4. 占位符变量替换
-- ================================================================

---@module "faster-oj.featrue.utils"

---@class FOJ.UtilsModule
---@field config FOJ.Config 当前生效配置
---@field setup fun(cfg:FOJ.Config) 初始化模块
---@field detect_language fun(ext:string):string 检测文件语言
---@field get_file_path fun():string 获取当前缓冲区文件路径
---@field get_json_path fun():string 获取当前题目 JSON 路径
---@field file_exists fun(path:string):boolean 判断文件是否存在
---@field read_file fun(path:string):string|nil 读取文件内容
---@field read_file_now fun():string|nil 读取当前文件内容
---@field read_json fun(path:string):table|nil 读取 JSON 内容
---@field write_json fun(path:string, data:table):boolean 写入 JSON
---@field get_json_file fun():table|nil 获取当前题目 JSON 内容
---@field get_vars fun(file_path:string):table 获取占位符变量
---@field expand fun(str:string, vars:table):string 字符串占位符替换
local M = {}

-- ----------------------------------------------------------------
-- 📝 Debug Logger
-- ----------------------------------------------------------------

---Debug 日志输出（仅在 config.debug = true 时启用）
---@param ... any
local function log(...)
	if M.config.debug then
		print("[FOJ][utils]", ...)
	end
end

-- ----------------------------------------------------------------
-- ⚙️ Setup
-- ----------------------------------------------------------------

---初始化 Utils 模块
---@param cfg FOJ.Config 用户传入配置
function M.setup(cfg)
	---@type FOJ.Config
	M.config = cfg or {}
end

-- ----------------------------------------------------------------
-- 🌐 Language Detection
-- ----------------------------------------------------------------

---根据文件扩展名检测语言类型
---@param ext string 文件扩展名（例如 "cpp"）
---@return string language
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

-- ----------------------------------------------------------------
-- 📂 File Path Utilities
-- ----------------------------------------------------------------

---获取当前缓冲区文件路径
---@return string file_path
function M.get_file_path()
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		log("No active file")
	end
	return file_path
end

---获取当前题目 JSON 路径
---@return string json_path
function M.get_json_path()
	local file_path = M.get_file_path()
	local filename = vim.fn.fnamemodify(file_path, ":t:r")
	local json_path = M.config.json_dir .. "/" .. filename .. ".json"
	return vim.fn.fnamemodify(json_path, ":p")
end

-- ----------------------------------------------------------------
-- 📄 File Operations
-- ----------------------------------------------------------------

---判断文件是否存在
---@param path string 文件路径
---@return boolean
function M.file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
	end
	return f ~= nil
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
	local file_path = M.get_file_path()
	local content = M.read_file(file_path)
	if not content then
		log("Failed to read current file:", file_path)
		return nil
	end
	return content
end

-- ----------------------------------------------------------------
-- 📦 JSON Operations
-- ----------------------------------------------------------------

---读取 JSON 文件
---@param path string JSON 文件路径
---@return table|nil
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

---写入 JSON 文件
---@param path string JSON 文件路径
---@param data table 待写入数据
---@return boolean success
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

---获取当前题目 JSON 内容
---@return table|nil
function M.get_json_file()
	return M.read_json(M.get_json_path())
end

-- ----------------------------------------------------------------
-- 🔧 Variable Utilities
-- ----------------------------------------------------------------

---获取当前文件占位符变量
---@param file_path string 文件路径
---@return table vars
function M.get_vars(file_path)
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
	if not str then
		return ""
	end
	-- 括号截断多返回值，防止 table.insert 报错
	return (str:gsub("[%@%$%%]%(?([%w_]+)%)?", function(k)
		return vars[k] or ""
	end))
end

return M
