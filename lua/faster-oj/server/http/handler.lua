local M = {}

local function log(...)
	if M.config.server_debug then
		print("[faster-oj][http]", ...)
	end
end

function M.handle(json, cfg)
	M.config = cfg
	local json_dir = M.config.json_dir
	if not json_dir or json_dir == "" then
		log("Error: json_dir not specified in cfg")
		return
	end

	-- 创建目录（如果不存在）
	local code = os.execute('mkdir -p "' .. json_dir .. '"')
	if code ~= 0 then
		log("Failed to create directory:", json_dir)
	end

	-- 确保 json.name 存在
	if not json.name then
		log("Error: json.name is missing")
		return
	end

	local file_path = json_dir .. "/" .. json.name .. ".json"
	local ok, json_str = pcall(vim.fn.json_encode, json)
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
end

return M
