---@class FOJ.Config
---@field http_host string HTTP 服务器地址
---@field http_port integer HTTP 服务器端口
---@field ws_host string WebSocket 服务器地址
---@field ws_port integer WebSocket 服务器端口
---@field max_time_out integer 浏览器连接最大时间
---@field debug boolean 是否开启调试模式
---@field server_mod '"http"'|'"ws"'|'"all"' 服务器启动模式
---@field work_dir string 工作目录
---@field json_dir string 题目数据存储目录
---@field solve_dir string 已解决问题存储目录
---@field template_dir string 模板数据存储目录
---@field template_default string 默认模板
---@field template_default_ext string 默认模板无扩展名时使用的默认扩展名
---@field open_new boolean 默认打开题目文件
---@field linux_mem_offset integer 系统内存偏移量
---@field macos_mem_offset integer 系统内存偏移量
---@field code_obfuscator table 代码混淆器 —— 默认不启用
---@field obscure boolean 是否启用模糊匹配 —— 词法模式 / 逐行模式
---@field warning_msg boolean 判题时是否输出警告信息
---@field max_workers integer 最大并发测题数量
---@field tc_ui FOJ.TCUIConfig UI 布局配置
---@field tc_manage_ui FOJ.TCManageUIConfig UI 布局配置
---@field highlights FOJ.HighlightConfig 高亮颜色配置
---@field compile_command table<string, FOJ.Command> 编译命令表
---@field run_command table<string, FOJ.Command> 运行命令表

---@class FOJ.TCUIConfig
---@field width number UI 宽度比例 (0~1)
---@field height number UI 高度比例 (0~1)
---@field layout table UI 布局结构
---@field mappings table UI 快捷键

---@class FOJ.TCManageUIConfig
---@field width number UI 宽度比例 (0~1)
---@field height number UI 高度比例 (0~1)
---@field layout table UI 布局结构
---@field mappings table UI 快捷键

---@class FOJ.HighlightConfig
---@class FOJ.HighlightConfig.windows
---@field Header string 标题颜色
---@field Correct string 正确颜色
---@field Warning string 警告颜色
---@field Wrong string 错误颜色
---@class FOJ.HighlightConfig.stdio
---@field Header string 标题颜色
---@field Correct string 正确颜色
---@field Warning string 警告颜色
---@field Wrong string 错误颜色

---@class FOJ.Command
---@field exec string 可执行程序
---@field args? string[] 参数列表

local M = {}

---@type FOJ.Config
M.config = {

	http_host = "127.0.0.1",
	http_port = 10043,
	ws_host = "127.0.0.1",
	ws_port = 10044,

	max_time_out = 5,

	debug = false, -- Debug mode
	server_mod = "all", -- "http" | "ws" | "all"

	work_dir = "", -- Work directory
	json_dir = ".problem", -- Problem data directory
	solve_dir = ".solve", -- Solve Problem data directory
	template_dir = "", -- Template data directory
	template_default = "",
	template_default_ext = ".cpp",
	open_new = true,

	linux_mem_offset = -2900, -- kb
	macos_mem_offset = -1500, -- kb

	code_obfuscator = {
		result = "",
		cmd = {
			exec = "",
			args = nil,
		},
	},
	obscure = true, -- Enable fuzzy matching

	warning_msg = false, -- Show warnings while judging
	max_workers = 5, -- Max parallel judging workers

	tc_ui = {
		width = 0.9,
		height = 0.9,
		layout = {
			{ 4, "tc" },
			{ 5, { { 1, "si" }, { 1, "so" } } },
			{ 5, { { 1, "info" }, { 1, "eo" } } },
		},
		mappings = {
			close = { "<esc>", "<C-c>", "q", "Q" },
			view = { "a", "i", "o", "O" },
			view_focus_next = { "<down>", "<Tab>" },
			view_focus_prev = { "<up>", "<S-Tab>" },
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
		},
		-- tc   = Testcases
		-- si   = Standard Input
		-- so   = Standard Output
		-- info = Info Panel
		-- eo   = Expected Output
	},

	tc_manage_ui = {
		width = 0.9,
		height = 0.9,
		layout = {
			{ 3, "tc" },
			{ 5, "si" },
			{ 5, "so" },
		},
		mappings = {
			close = { "<esc>", "<C-c>", "q", "Q" },
			erase = { "d" },
			write = { "w" },
			add = { "a" },
			edit = { "e", "i", "o", "O" },
			edit_focus_next = { "<down>", "<Tab>" },
			edit_focus_prev = { "<up>", "<S-Tab>" },
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
		},
	},

	highlights = {
		windows = {
			Header = "#c0c0c0",
			Correct = "#00ff00",
			Warning = "orange",
			Wrong = "red",
		},
		stdio = {
			Header = "#c0c0c0",
			Correct = "#00ff00",
			Warning = "orange",
			Wrong = "orange",
		},
	},

	compile_command = {

		-- C
		c = {
			exec = "gcc",
			args = {
				"-O2",
				"-Wall",
				"$(FABSPATH)",
				"-o",
				"$(DIR)/$(FNOEXT)",
			},
		},

		-- C++
		cpp = {
			exec = "g++",
			args = {
				"-O2",
				"-Wall",
				"$(FABSPATH)",
				"-o",
				"$(DIR)/$(FNOEXT)",
			},
		},

		-- Rust
		rust = {
			exec = "rustc",
			args = {
				"-O",
				"$(FABSPATH)",
				"-o",
				"$(DIR)/$(FNOEXT)",
			},
		},

		-- Go
		go = {
			exec = "go",
			args = {
				"build",
				"-o",
				"$(DIR)/$(FNOEXT)",
				"$(FABSPATH)",
			},
		},

		-- Java
		java = {
			exec = "javac",
			args = {
				"-encoding",
				"UTF-8",
				"$(FABSPATH)",
			},
		},

		-- Kotlin
		kotlin = {
			exec = "kotlinc",
			args = {
				"$(FABSPATH)",
				"-include-runtime",
				"-d",
				"$(DIR)/$(FNOEXT).jar",
			},
		},

		-- C#
		cs = {
			exec = "mcs",
			args = {
				"$(FABSPATH)",
				"-out:$(DIR)/$(FNOEXT).exe",
			},
		},

		-- Pascal
		pascal = {
			exec = "fpc",
			args = {
				"$(FABSPATH)",
				"-O2",
				"-o$(DIR)/$(FNOEXT)",
			},
		},

		-- Swift
		swift = {
			exec = "swiftc",
			args = {
				"$(FABSPATH)",
				"-O",
				"-o",
				"$(DIR)/$(FNOEXT)",
			},
		},

		-- Zig
		zig = {
			exec = "zig",
			args = {
				"build-exe",
				"$(FABSPATH)",
				"-O",
				"ReleaseFast",
				"-femit-bin=$(DIR)/$(FNOEXT)",
			},
		},
	},

	run_command = {

		-- Native compiled
		c = { exec = "$(DIR)/$(FNOEXT)" },
		cpp = { exec = "$(DIR)/$(FNOEXT)" },
		rust = { exec = "$(DIR)/$(FNOEXT)" },
		go = { exec = "$(DIR)/$(FNOEXT)" },
		swift = { exec = "$(DIR)/$(FNOEXT)" },
		zig = { exec = "$(DIR)/$(FNOEXT)" },
		pascal = { exec = "$(DIR)/$(FNOEXT)" },

		-- Java
		java = {
			exec = "java",
			args = { "-cp", "$(DIR)", "$(FNOEXT)" },
		},

		-- Kotlin
		kotlin = {
			exec = "java",
			args = { "-jar", "$(DIR)/$(FNOEXT).jar" },
		},

		-- Python
		python = {
			exec = "python3",
			args = { "$(FABSPATH)" },
		},

		-- NodeJS
		javascript = {
			exec = "node",
			args = { "$(FABSPATH)" },
		},

		-- TypeScript (requires ts-node)
		typescript = {
			exec = "ts-node",
			args = { "$(FABSPATH)" },
		},

		-- Lua
		lua = {
			exec = "lua",
			args = { "$(FABSPATH)" },
		},

		-- C#
		cs = {
			exec = "mono",
			args = { "$(DIR)/$(FNOEXT).exe" },
		},
	},
}

return M
