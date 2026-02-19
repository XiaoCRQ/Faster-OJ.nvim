local M = {}

M.config = {
	http_host = "127.0.0.1",
	http_port = 10043,
	ws_host = "127.0.0.1",
	ws_port = 10044,

	server_debug = false,
	server_mod = "all", -- only_http | only_ws | all

	json_dir = ".problem/json",
	code_obfuscator = "",
	obscure = true,

	max_workers = 5,
	output_max_chars = 50,
	output_max_lines = 100,

	ui = {
		width = 0.9,
		height = 0.9,
		layout = {
			{ 2, "Testcases" },
			{ 5, { { 1, "Input" }, { 1, "Output" } } },
			{ 5, { { 1, "Info" }, { 1, "Expected Output" } } },
		},
	},

	highlights = {},

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

		-- 本地编译型
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

		-- TypeScript（需 ts-node）
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
