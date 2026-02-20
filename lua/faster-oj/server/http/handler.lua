-- ================================================================
-- FOJ HTTP Handler
-- ================================================================
-- 功能：
--   1. 处理 HTTP Server 接收的 JSON 请求
--   2. 过滤 JSON 只保留允许字段
--   3. 写入题目 JSON 文件
--   4. 可选地根据 template_default 生成初始代码文件
-- ================================================================

---@module "faster-oj.server.http.handler"

local M = {}

--- 白名单 JSON 字段
M.allowed_keys = {
	"url",
	"tests",
	"memoryLimit",
	"timeLimit",
}

-- ================================================================
-- 🔹 内部日志工具
-- ================================================================
---@private
local function log(...)
	if M.config.debug then
		print("[FOJ][http]", ...)
	end
end

-- ================================================================
-- 🔹 内部工具：过滤 JSON，只保留 allowed_keys
-- ================================================================
---@private
---@param json table 原始 JSON 数据
---@param allowed_keys string[] 白名单字段
---@return table 过滤后的 JSON
local function filter_json(json, allowed_keys)
	local filtered = {}

	local key_set = {}
	for _, k in ipairs(allowed_keys) do
		key_set[k] = true
	end

	for k, v in pairs(json) do
		if key_set[k] then
			filtered[k] = v
		end
	end

	return filtered
end

-- ================================================================
-- 🔹 处理 HTTP 接收到的题目 JSON
-- ================================================================
---@param json table 原始 JSON 请求数据
---   json.name string 题目名称（必填，用作文件名）
---   json.url string 题目 URL
---   json.tests table 测试用例列表
---   json.memoryLimit integer 内存限制
---   json.timeLimit integer 时间限制
---@param cfg table 配置
---   cfg.json_dir string 存放题目 JSON 的目录
---   cfg.work_dir string 存放代码文件的工作目录
---   cfg.template_default string 默认模板路径（可选）
---   cfg.template_default_ext string 默认模板扩展名（可选）
---   cfg.debug boolean 是否打印调试信息
function M.handle(json, cfg)
	M.config = cfg
	local json_dir = M.config.json_dir

	if not json_dir or json_dir == "" then
		log("Error: json_dir not specified in cfg")
		return
	end

	local ok_mkdir = os.execute('mkdir -p "' .. json_dir .. '"')
	if ok_mkdir ~= 0 then
		log("Failed to create directory:", json_dir)
	end

	if not json.name then
		log("Error: json.name is missing")
		return
	end

	local filtered_json = filter_json(json, M.allowed_keys)
	local file_path = json_dir .. "/" .. json.name .. ".json"

	local ok, json_str = pcall(vim.fn.json_encode, filtered_json)
	if not ok then
		log("Error encoding JSON:", json_str)
		return
	end

	local f, err = io.open(file_path, "w")
	if not f then
		log("Error opening file:", file_path, err)
		return
	end
	f:write(json_str)
	f:close()
	log("Saved", file_path)
	-- print("[FOJ] " .. json.name)

	if M.config.template_default and M.config.template_default ~= "" then
		local template_content = ""
		local template_file = M.config.template_default
		local tf = io.open(template_file, "r")
		if tf then
			template_content = tf:read("*a")
			tf:close()
		else
			log("Warning: template_default file not found:", template_file)
			return
		end

		local ext = template_file:match("^.+(%..+)$") or M.config.template_default_ext
		local target_file = M.config.work_dir .. "/" .. json.name .. ext

		os.execute('mkdir -p "' .. M.config.work_dir .. '"')

		local should_write = true
		if vim.fn.filereadable(target_file) == 1 then
			-- 弹出确认窗口，按钮顺序：Yes, No
			local choice = vim.fn.confirm('"' .. json.name .. '" already exists. Overwrite?', "&Yes\n&No", 2)
			if choice ~= 1 then
				log("Skipped writing template for", target_file)
				should_write = false
			end
		end

		if should_write then
			local tf_out, err_out = io.open(target_file, "w")
			if not tf_out then
				log("Error opening target file:", target_file, err_out)
				return
			end
			tf_out:write(template_content)
			tf_out:close()
			log("Template written to", target_file)
			vim.cmd("edit " .. vim.fn.fnameescape(target_file))
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
		end
	end
end

return M
