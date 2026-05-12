---@class FOJ.Config
---@field http_host string HTTP 服务器地址
---@field http_port integer HTTP 服务器端口
---@field ws_host string WebSocket 服务器地址
---@field ws_port integer WebSocket 服务器端口
---@field max_time_out integer 浏览器连接最大时间
---@field debug boolean 是否开启调试模式
---@field server_mod '"http"'|'"ws"'|'"all"' 服务器启动模式
---@field temp_dir string 临时文件目录
---@field work_dir string 工作目录
---@field data_dir string 题目数据存储目录
---@field solve_dir string 已解决问题存储目录
---@field template_dir string 模板数据存储目录
---@field template_default string 默认模板
---@field template_default_ext string 无默认模板时使用的默认语言
---@field auto_open boolean 默认打开题目文件
---@field linux_mem_offset integer 系统内存偏移量
---@field macos_mem_offset integer 系统内存偏移量
---@field code_obfuscator table 代码混淆器 —— 仅当混淆器可运行且读取到混淆结果时自动混淆 [慎用 - 不保证oj平台允许该行为]
---@field obscure boolean 是否启用模糊匹配 —— 词法模式 / 逐行模式
---@field warning_msg boolean 判题时是否输出警告信息
---@field clipboard_submit boolean 提交时是否将代码复制到系统剪切板
---@field max_workers integer 最大并发测题数量
---@field max_solve_history integer 最大解题历史条目数
---@field default_time_limit integer 缺省时间限制 (ms)
---@field default_memory_limit integer 缺省内存限制 (MB)
---@field tc_ui FOJ.TCUIConfig UI 布局配置
---@field tc_edit_ui FOJ.TCManageUIConfig UI 布局配置
---@field stress_ui FOJ.TCUIConfig 对拍 UI 布局配置
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

-- Use Neovim standard data directory as the base path
-- Linux: ~/.local/share/nvim/faster-oj
-- macOS: ~/Library/Application Support/nvim/faster-oj
-- Windows: ~/AppData/Local/nvim-data/faster-oj
local cache_base = vim.fn.stdpath("data") .. "/faster-oj"

---@type FOJ.Config
M.config = {

	http_host = "127.0.0.1",
	http_port = 10043,
	ws_host = "127.0.0.1",
	ws_port = 10044,

	max_time_out = 5,

	debug = false, -- Debug mode
	server_mod = "all", -- "http" | "ws" | "all"

	work_dir = cache_base, -- Work directory
	temp_dir = cache_base .. "/.temp", -- Temporary files directory (stress data, submit temp, etc.)
	data_dir = cache_base .. "/.problem", -- Problem data directory
	solve_dir = cache_base .. "/.solve", -- Solve Problem data directory
	template_dir = cache_base .. "/template", -- Template data directory
	template_default = "",
	template_default_ext = ".cpp",
	auto_open = true,

	linux_mem_offset = -2900, -- kb
	macos_mem_offset = -1500, -- kb

	obscure = true, -- Enable fuzzy matching

	warning_msg = false, -- Show warnings while judging
	clipboard_submit = false, -- Copy code to clipboard on submit
	max_workers = 5, -- Max parallel judging workers
	max_solve_history = 100, -- Max solve history entries

	default_time_limit = 2000, -- Default time limit (ms)
	default_memory_limit = 256, -- Default memory limit (MB)

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
			view_focus_next = { "<Tab>" },
			view_focus_prev = { "<S-Tab>" },
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
		},
		-- tc   = Testcases
		-- si   = Standard Input
		-- so   = Standard Output
		-- info = Info Panel
		-- eo   = Expected Output
	},

	tc_edit_ui = {
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
			edit_focus_next = { "<Tab>" },
			edit_focus_prev = { "<S-Tab>" },
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
		},
	},

	stress_ui = {
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
			view_focus_next = { "<Tab>" },
			view_focus_prev = { "<S-Tab>" },
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

	code_obfuscator = {
		result = "",
		cmd = {
			exec = "",
			args = nil,
		},
	},

	compile_command = {

		-- C
		c = {
			exec = "gcc",
			args = {
				"-std=c11",
				"-O2",
				"-Wall",
				"-DONLINE_JUDGE",
				"$(FABSPATH)",
				"-o",
				"$(DIR)/.output/$(FNOEXT)",
			},
		},

		-- C++
		cpp = {
			exec = "g++",
			args = {
				"-std=c++23",
				"-O2",
				"-Wall",
				"-DONLINE_JUDGE",
				"$(FABSPATH)",
				"-o",
				"$(DIR)/.output/$(FNOEXT)",
			},
		},

		-- Rust
		rs = {
			exec = "rustc",
			args = {
				"-C",
				"opt-level=3",
				"$(FABSPATH)",
				"-o",
				"$(DIR)/.output/$(FNOEXT)",
			},
		},

		-- Go
		go = {
			exec = "go",
			args = {
				"build",
				"-ldflags=-s -w",
				"-o",
				"$(DIR)/.output/$(FNOEXT)",
				"$(FABSPATH)",
			},
		},

		-- Java
		java = {
			exec = "javac",
			args = {
				"-encoding",
				"UTF-8",
				"-d",
				"$(DIR)/.output",
				"$(FABSPATH)",
			},
		},

		-- Kotlin
		kt = {
			exec = "kotlinc",
			args = {
				"$(FABSPATH)",
				"-include-runtime",
				"-d",
				"$(DIR)/.output/$(FNOEXT).jar",
			},
		},

		-- C#
		cs = {
			exec = "mcs",
			args = {
				"$(FABSPATH)",
				"-out:$(DIR)/.output/$(FNOEXT).exe",
			},
		},

		-- Pascal
		pas = {
			exec = "fpc",
			args = {
				"$(FABSPATH)",
				"-O3",
				"-o$(DIR)/.output/$(FNOEXT)",
			},
		},

		-- Swift
		swift = {
			exec = "swiftc",
			args = {
				"$(FABSPATH)",
				"-Ounchecked",
				"-o",
				"$(DIR)/.output/$(FNOEXT)",
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
				"-femit-bin=$(DIR)/.output/$(FNOEXT)",
			},
		},
	},

	run_command = {

		-- Native compiled
		c = { exec = "$(DIR)/.output/$(FNOEXT)" },
		cpp = { exec = "$(DIR)/.output/$(FNOEXT)" },
		rs = { exec = "$(DIR)/.output/$(FNOEXT)" },
		go = { exec = "$(DIR)/.output/$(FNOEXT)" },
		swift = { exec = "$(DIR)/.output/$(FNOEXT)" },
		zig = { exec = "$(DIR)/.output/$(FNOEXT)" },
		pas = { exec = "$(DIR)/.output/$(FNOEXT)" },

		-- Java
		java = {
			exec = "java",
			args = { "-cp", "$(DIR)/.output", "$(FNOEXT)" },
		},

		-- Kotlin
		kt = {
			exec = "java",
			args = { "-jar", "$(DIR)/.output/$(FNOEXT).jar" },
		},

		-- Python
		py = {
			exec = "python3",
			args = { "$(FABSPATH)" },
		},

		-- NodeJS
		js = {
			exec = "node",
			args = { "$(FABSPATH)" },
		},

		-- TypeScript (requires ts-node)
		ts = {
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
			args = { "$(DIR)/.output/$(FNOEXT).exe" },
		},
	},
}

return M
