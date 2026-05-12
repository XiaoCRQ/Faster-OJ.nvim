---@module "faster-oj.module.notify"

---单窗口通知模块：所有消息显示在同一个浮动窗口中，自动替换旧内容。
---支持旋转加载动画 (spinner)。

local M = {}

local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1

local ns = vim.api.nvim_create_namespace("FOJNotify")

---@type integer|nil win_id
local win_id = nil
---@type integer|nil buf_id
local buf_id = nil
---@type uv_timer|nil hide_timer
local hide_timer = nil
---@type uv_timer|nil spin_timer
local spin_timer = nil

---@type timeout|nil timeout
local timeout = 1000

local SPIN_CHARS = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local ICONS = {
	INFO = "●",
	WARN = "⚠",
	ERROR = "✗",
	DONE = "✓",
}

---@class FOJ.Spinner
---@field spin_idx integer
---@field prefix string 前缀文本
---@field msg string 当前消息
---@field timer uv_timer
local Spinner = {}
Spinner.__index = Spinner

---安全关闭 timer
---@param t uv_timer|nil
local function safe_stop(t)
	if t and not t:is_closing() then
		t:stop()
		t:close()
	end
end

---确保 buffer 存在
local function ensure_buf()
	if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
		return
	end
	buf_id = vim.api.nvim_create_buf(false, true)
	vim.bo[buf_id].bufhidden = "wipe"
	vim.bo[buf_id].filetype = "FOJNotify"
end

---计算浮动窗口位置 (顶部居中)
---@return table win_config
local function get_win_config(width)
	local uis = vim.api.nvim_list_uis()
	if #uis == 0 then
		return {}
	end
	local ed = uis[1]
	local w = math.min(width, ed.width - 4)
	local row = 1
	local col = math.floor((ed.width - w) / 2)
	return {
		relative = "editor",
		row = row,
		col = col,
		width = w,
		height = 1,
		style = "minimal",
		border = "none",
		focusable = false,
		zindex = 100,
	}
end

---关闭浮动窗口
local function close_win()
	safe_stop(hide_timer)
	hide_timer = nil
	if win_id and vim.api.nvim_win_is_valid(win_id) then
		pcall(vim.api.nvim_win_close, win_id, true)
	end
	win_id = nil
end

---刷新窗口内容
---@param text string
---@param hl_group string 高亮组名
---@param width integer 窗口宽度
local function update_win(text, hl_group, width)
	ensure_buf()
	-- Sanitize: nvim_buf_set_lines rejects strings containing newlines
	text = text:gsub("\n", " ")
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { text })
	vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)
	vim.api.nvim_buf_add_highlight(buf_id, ns, hl_group, 0, 0, -1)

	local config = get_win_config(width or #text)
	if config.width then
		if win_id and vim.api.nvim_win_is_valid(win_id) then
			vim.api.nvim_win_set_config(win_id, config)
			vim.api.nvim_win_set_buf(win_id, buf_id)
		else
			win_id = vim.api.nvim_open_win(buf_id, false, config)
			vim.wo[win_id].winhl = "Normal:FOJNotifyNormal,FloatBorder:FOJNotifyBorder"
		end
	end
end

---定义高亮组
local function setup_highlights()
	local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg or "#1e1e2e"
	vim.api.nvim_set_hl(0, "FOJNotifyNormal", { bg = "#2a2a3a", fg = "#cdd6f4" })
	vim.api.nvim_set_hl(0, "FOJNotifyBorder", { bg = "#2a2a3a", fg = "#2a2a3a" })
	vim.api.nvim_set_hl(0, "FOJNotifyInfo", { bg = "#2a2a3a", fg = "#89b4fa", bold = true })
	vim.api.nvim_set_hl(0, "FOJNotifyWarn", { bg = "#2a2a3a", fg = "#f9e2af", bold = true })
	vim.api.nvim_set_hl(0, "FOJNotifyError", { bg = "#2a2a3a", fg = "#f38ba8", bold = true })
	vim.api.nvim_set_hl(0, "FOJNotifyDone", { bg = "#2a2a3a", fg = "#a6e3a1", bold = true })
	vim.api.nvim_set_hl(0, "FOJNotifySpin", { bg = "#2a2a3a", fg = "#89b4fa" })
end

---显示通知 (替换上一次的通知窗口)
---@param msg string 消息内容
---@param level? string "INFO"|"WARN"|"ERROR"|"DONE" (默认 INFO)
---@param duration? integer 自动隐藏毫秒数 (默认 3000)
function M.show(msg, level, duration)
	level = level or "INFO"
	duration = duration or timeout

	vim.schedule(function()
		setup_highlights()

		local icon = ICONS[level] or ICONS.INFO
		local text = string.format(" %s %s", icon, msg)
		local hl_map = {
			INFO = "FOJNotifyInfo",
			WARN = "FOJNotifyWarn",
			ERROR = "FOJNotifyError",
			DONE = "FOJNotifyDone",
		}

		update_win(text, hl_map[level] or "FOJNotifyInfo", #text)

		-- 自动隐藏
		safe_stop(hide_timer)
		hide_timer = uv.new_timer()
		hide_timer:start(duration, 0, function()
			vim.schedule(close_win)
			safe_stop(hide_timer)
			hide_timer = nil
		end)
	end)
end

---启动旋转加载动画 (返回 Spinner 对象)
---@param msg string 初始消息
---@return FOJ.Spinner
function M.spinner_start(msg)
	local s = setmetatable({}, Spinner)
	s.spin_idx = 1
	s.prefix = msg

	s.timer = uv.new_timer()
	s.timer:start(0, 80, function()
		vim.schedule(function()
			if not s.timer then
				return
			end
			s.spin_idx = s.spin_idx % #SPIN_CHARS + 1
			local text = string.format(" %s %s", SPIN_CHARS[s.spin_idx], s.prefix)
			update_win(text, "FOJNotifySpin", #text)
		end)
	end)

	return s
end

---更新旋转动画的消息
---@param spinner FOJ.Spinner
---@param msg string
function M.spinner_update(spinner, msg)
	if spinner then
		spinner.prefix = msg
	end
end

---停止旋转动画，显示完成消息
---@param spinner FOJ.Spinner
---@param msg? string
function M.spinner_done(spinner, msg)
	if not spinner then
		return
	end
	safe_stop(spinner.timer)
	spinner.timer = nil

	local text = string.format(" %s %s", ICONS.DONE, msg or spinner.prefix)
	vim.schedule(function()
		update_win(text, "FOJNotifyDone", #text)
		-- 自动关闭
		safe_stop(hide_timer)
		hide_timer = uv.new_timer()
		hide_timer:start(timeout, 0, function()
			vim.schedule(close_win)
			safe_stop(hide_timer)
			hide_timer = nil
		end)
	end)
end

---停止旋转动画，显示失败消息
---@param spinner FOJ.Spinner
---@param msg? string
function M.spinner_fail(spinner, msg)
	if not spinner then
		return
	end
	safe_stop(spinner.timer)
	spinner.timer = nil

	local text = string.format(" %s %s", ICONS.ERROR, msg or spinner.prefix)
	vim.schedule(function()
		update_win(text, "FOJNotifyError", #text)
		safe_stop(hide_timer)
		hide_timer = uv.new_timer()
		hide_timer:start(5000, 0, function()
			vim.schedule(close_win)
			safe_stop(hide_timer)
			hide_timer = nil
		end)
	end)
end

---立即关闭通知
function M.close()
	safe_stop(hide_timer)
	hide_timer = nil
	vim.schedule(close_win)
end

return M
