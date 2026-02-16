local M = {}
M.allowed_keys = {
	"url",
	"tests",
	"memoryLimit",
	"timeLimit",
}

local function log(...)
	if M.config.server_debug then
		print("[FOJ][http]", ...)
	end
end

-- 过滤 JSON，只保留白名单字段
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

function M.handle(json, cfg)
	M.config = cfg
	local json_dir = M.config.json_dir

	if not json_dir or json_dir == "" then
		log("Error: json_dir not specified in cfg")
		return
	end

	-- 创建目录
	local ok_mkdir = os.execute('mkdir -p "' .. json_dir .. '"')
	if ok_mkdir ~= 0 then
		log("Failed to create directory:", json_dir)
	end

	-- 确保 name 存在
	if not json.name then
		log("Error: json.name is missing")
		return
	end

	-- ⭐ 只保留特定字段
	local filtered_json = filter_json(json, M.allowed_keys)

	local file_path = json_dir .. "/" .. json.name .. ".json"

	-- 编码 JSON
	local ok, json_str = pcall(vim.fn.json_encode, filtered_json)
	if not ok then
		log("Error encoding JSON:", json_str)
		return
	end

	-- 写入文件
	local f, err = io.open(file_path, "w")
	if not f then
		log("Error opening file:", file_path, err)
		return
	end

	f:write(json_str)
	f:close()

	log("Saved", file_path)
	print("[FOJ][http] " .. json.name)
end

return M
