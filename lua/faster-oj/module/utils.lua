---@module "faster-oj.module.utils"

---@class FOJ.UtilsModule
---@field config FOJ.Config
local M = {}

local uv = vim.uv or vim.loop

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

---@param level string
---@param func string
---@param msg string
local function log(level, func, msg)
	if M.config and M.config.debug then
		print(string.format("[FOJ][utils][%s] %s: %s", level, func, msg))
	end
end

function M.setup(cfg)
	M.config = cfg or {}
end

---根据文件扩展名检测语言类型
---@param ext string
---@return string
function M.detect_language(ext)
	if not ext then
		return ""
	end
	ext = ext:lower()
	return LANGUAGE_MAP[ext] or ext
end

---获取当前缓冲区文件路径
---@return string
function M.get_file_path()
	local path = vim.api.nvim_buf_get_name(0)
	return path ~= "" and path or ""
end

---确保目录存在
---@param path string
function M.ensure_dir(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

---获取题目目录路径 (基于指定文件路径，安全于 fast event context)
---@param file_path string
---@return string
function M.get_problem_dir_from(file_path)
	if not file_path or file_path == "" then
		return ""
	end
	local filename = vim.fn.fnamemodify(file_path, ":t:r")
	local data_dir = M.config.data_dir or vim.fn.stdpath("data") .. "/faster-oj"
	return vim.fn.fnamemodify(data_dir .. "/" .. filename .. "/", ":p")
end

---获取题目目录路径 (从当前缓冲区)
---@return string
function M.get_problem_dir()
	return M.get_problem_dir_from(M.get_file_path())
end

---获取题目 JSON 路径 (problem.json)
---@return string
function M.get_json_path()
	local dir = M.get_problem_dir()
	return dir ~= "" and (dir .. "problem.json") or ""
end

---判断文件是否存在
---@param path string
---@return boolean
function M.file_exists(path)
	if not path or path == "" then
		return false
	end
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "file"
end

---判断目录是否存在
---@param path string
---@return boolean
function M.dir_exists(path)
	if not path or path == "" then
		return false
	end
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "directory"
end

---读取文件内容
---@param path string
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

---写入文件 (纯内容)
---@param path string
---@param content string
---@return boolean
function M.write_file(path, content)
	M.ensure_dir(path)
	local f = io.open(path, "w")
	if not f then
		log("ERROR", "write_file", "Failed to open: " .. path)
		return false
	end
	f:write(content)
	f:close()
	return true
end

---读取 JSON 文件
---@param path string
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
		log("ERROR", "read_json", "Decode error: " .. path)
		return nil
	end
	return data
end

---写入 JSON 文件
---@param path string
---@param data table
---@return boolean
function M.write_json(path, data)
	local ok, encoded = pcall(vim.json.encode, data)
	if not ok then
		log("ERROR", "write_json", "Encode error")
		return false
	end
	M.ensure_dir(path)
	local f = io.open(path, "w")
	if not f then
		log("ERROR", "write_json", "Failed to open: " .. path)
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

---获取测试用例数量
---@param problem_dir string
---@return integer
function M.get_test_count(problem_dir)
	local json = M.read_json(problem_dir .. "problem.json")
	if json and json.testCount then
		return json.testCount
	end
	-- 降级: 扫描 .in 文件数量
	local count = 0
	local handle = uv.fs_scandir(problem_dir)
	if handle then
		while true do
			local name, ftype = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			if ftype == "file" and name:match("%.in$") then
				count = count + 1
			end
		end
	end
	return count
end

---读取单个测试用例文件
---@param problem_dir string
---@param index integer 0-based index
---@return table {input:string, output:string}
function M.read_test_case(problem_dir, index)
	local input = M.read_file(problem_dir .. index .. ".in") or ""
	local output = M.read_file(problem_dir .. index .. ".out") or ""
	return { input = input, output = output }
end

---写入单个测试用例文件
---@param problem_dir string
---@param index integer 0-based index
---@param input string
---@param output string
---@return boolean
function M.write_test_case(problem_dir, index, input, output)
	local ok1 = M.write_file(problem_dir .. index .. ".in", input)
	local ok2 = M.write_file(problem_dir .. index .. ".out", output)
	return ok1 and ok2
end

---删除测试用例，重排后续文件
---@param problem_dir string
---@param index integer 0-based 要删除的索引
---@param count integer 当前测试用例总数
function M.delete_test_case(problem_dir, index, count)
	os.remove(problem_dir .. index .. ".in")
	os.remove(problem_dir .. index .. ".out")
	for i = index + 1, count - 1 do
		os.rename(problem_dir .. i .. ".in", problem_dir .. (i - 1) .. ".in")
		os.rename(problem_dir .. i .. ".out", problem_dir .. (i - 1) .. ".out")
	end
end

---更新 problem.json 中的 testCount
---@param problem_dir string
---@param count integer
function M.update_test_count(problem_dir, count)
	local json = M.read_json(problem_dir .. "problem.json")
	if json then
		json.testCount = count
		M.write_json(problem_dir .. "problem.json", json)
	end
end

---删除整个题目目录
---@param problem_dir string
function M.delete_problem_dir(problem_dir)
	if problem_dir == "" or not M.dir_exists(problem_dir) then
		return
	end
	vim.fn.delete(problem_dir, "rf")
end

---删除文件
---@param path string
---@return boolean
function M.erase(path)
	if not path or path == "" then
		return false
	end
	if not M.file_exists(path) then
		log("INFO", "erase", "File not found, skip: " .. path)
		return true
	end
	local success, err = uv.fs_unlink(path)
	if not success then
		log("ERROR", "erase", "Failed: " .. path .. " - " .. (err or ""))
		return false
	end
	log("INFO", "erase", "Deleted: " .. path)
	return true
end

---获取文件占位符变量
---@param file_path string
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
---支持 $(VAR), @VAR, %VAR% 三种格式
---@param str string
---@param vars table
---@return string
function M.expand(str, vars)
	if not str or str == "" then
		return ""
	end
	local result = str:gsub("[%@%$%%]%(?([%w_]+)%)?", function(k)
		return vars[k] or ""
	end)
	return result
end

return M
