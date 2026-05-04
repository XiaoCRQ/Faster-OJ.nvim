# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ Build a complete Competitive Programming automation workflow in Neovim.</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

**Faster-OJ.nvim** is a Neovim plugin designed specifically for **Competitive Programming**. By integrating problem fetching, local judging, and automated submission, it aims to provide a **distraction-free and immersive coding environment** for solving problems.

---

## ✨ Core Features

- **Fully Automated Workflow**: Fetch problems via [Competitive Companion](https://github.com/jmerle/competitive-companion) and submit solutions with the [Faster-OJ browser extension](https://github.com/XiaoCRQ/Faster-OJ), eliminating manual copy-paste.
- **Dual Server Architecture**: Built-in **HTTP** server receives problem data; **WebSocket** server communicates with browser extension for submission.
- **High-Performance Local Judge**: Concurrent test execution (`max_workers`) with platform-aware time/memory measurement. Supports **lexical fuzzy matching** (`obscure`) and memory offset compensation.
- **Multi-Panel UI**: Judge results viewer, test case editor with real-time file sync, stress testing UI.
- **Stress Testing (对拍)**: Run two solutions against the same inputs and compare outputs — find edge cases in your optimized solution.
- **Smart Finder**: Deep integration with `snacks.nvim`, `telescope.nvim`, `fzf-lua`, `mini.pick`, or built-in `vim.ui.select`.

---

## 📦 Installation

### Dependencies

- **Neovim** >= 0.9 (libuv event loop)
- **Browser Extensions**:
  - [Competitive Companion](https://github.com/jmerle/competitive-companion) — for receiving problems
  - [Faster-OJ Browser Extension](https://github.com/XiaoCRQ/Faster-OJ) — for submitting solutions
- **Language toolchains** as needed (gcc/g++, python3, node, etc.)

### Minimal Configuration (lazy.nvim)

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

### Recommended Configuration

Only non-default overrides shown. All omitted fields use built-in defaults.

```lua
local code_path = vim.fn.expand("~/Work/Program/CodeForces")

{
  "xiaocrq/faster-oj.nvim",
  opts = {
    -- Show compilation warnings in judge results
    warning_msg = true,
    -- Paths
    work_dir = code_path,
    temp_dir = code_path .. "/.temp",
    json_dir = code_path .. "/.problem",
    solve_dir = code_path .. "/.solve",
    template_dir = code_path .. "/.template",
    template_default = code_path .. "/.template/template.cpp",
  },
}
```

To customize compile/run commands per language, override `compile_command` / `run_command` with your own entries (see [Configuration Reference](#-configuration-reference)).

---

## ⌨️ Recommended Keymaps

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Service control
map("n", "<leader>cda", ":FOJ<CR>",              vim.tbl_extend("force", opts, { desc = "FOJ: Start services" }))
map("n", "<leader>cdq", ":FOJ stop<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Stop services" }))
map("n", "<leader>cdr", ":FOJ submit<CR>",       vim.tbl_extend("force", opts, { desc = "FOJ: Submit solution" }))

-- Judge & UI
map("n", "<leader>cdt", ":FOJ run<CR>",          vim.tbl_extend("force", opts, { desc = "FOJ: Compile and judge" }))
map("n", "<leader>cdT", ":FOJ test<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Judge only (skip compile)" }))
map("n", "<leader>cdu", ":FOJ show<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Toggle judge UI" }))
map("n", "<leader>cde", ":FOJ edit<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Edit test cases" }))

-- Data management
map("n", "<leader>cds", ":FOJ solve<CR>",        vim.tbl_extend("force", opts, { desc = "FOJ: Mark as solved" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>",   vim.tbl_extend("force", opts, { desc = "FOJ: Undo solved mark" }))
map("n", "<leader>cdd", ":FOJ erase<CR>",        vim.tbl_extend("force", opts, { desc = "FOJ: Delete problem data" }))

-- Finder
map("n", "<leader>cdc", ":FOJ find template<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Find templates" }))
map("n", "<leader>cdp", ":FOJ find problem<CR>",  vim.tbl_extend("force", opts, { desc = "FOJ: Find problem files" }))
map("n", "<leader>cdj", ":FOJ find data<CR>",     vim.tbl_extend("force", opts, { desc = "FOJ: Find problem data" }))

-- Stress testing
map("n", "<leader>cdP", ":FOJ stress correct=find: test=find:<CR>",
    vim.tbl_extend("force", opts, { desc = "FOJ: Stress test (对拍)" }))
```

---

## 🛠 Commands

### Service Control

| Command | Description |
| --- | --- |
| `:FOJ` | Start HTTP + WebSocket services (switches to `work_dir` first) |
| `:FOJ start [mod]` | Start specific mode: `all` / `http` / `ws` |
| `:FOJ stop [mod]` | Stop services |

### Judge & Test

| Command | Description |
| --- | --- |
| `:FOJ run` | Save, compile, and run all test cases with UI |
| `:FOJ test` | Run test cases without recompiling |
| `:FOJ show` | Toggle judge result UI |
| `:FOJ edit` | Toggle test case editor UI (supports add/delete/modify) |

### Submission

| Command | Description |
| --- | --- |
| `:FOJ submit` | Send current code to browser extension via WebSocket |

### Problem Management

| Command | Description |
| --- | --- |
| `:FOJ solve` | Move problem to `solve_dir` and record in history |
| `:FOJ solve back` | Undo last solve — restore problem files |
| `:FOJ erase` | Delete current problem source + problem data directory |

### Finder

| Command | Description |
| --- | --- |
| `:FOJ find template` | Browse template files in `template_dir` |
| `:FOJ find problem` | Browse problem source files in `work_dir` |
| `:FOJ find data` | Browse problem data directories in `json_dir` |

### Stress Testing (对拍)

| Command | Description |
| --- | --- |
| `:FOJ stress` | Re-run last stress test |
| `:FOJ stress correct=type:val test=type:val [data=type:val] [time=N] [mem=N]` | Run stress test |

**Stress parameters:**

| Parameter | Type | Description |
| --- | --- | --- |
| `correct` | `path:FILE` or `find:` | Reference (correct) solution |
| `test` | `path:FILE` or `find:` | Solution under test |
| `data` | `path:P1\nP2` / `find:` / `data:RAW` | Input data source (optional, defaults to empty input) |
| `time` | integer (ms) | Time limit per case (default: `default_time_limit`) |
| `mem` | integer (MB) | Memory limit per case (default: `default_memory_limit`) |

**Stress examples:**
```vim
" Select both files via picker
:FOJ stress correct=find: test=find:

" Direct paths, different languages
:FOJ stress correct=path:brute.py test=path:solve.cpp

" With raw data and limits
:FOJ stress correct=path:a.cpp test=path:b.cpp data=data:5\n1 2 3\n4 5 6 time=1000 mem=128
```

---

## ⚙️ Configuration Reference

### Path & Basic

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `work_dir` | string | `""` | Base working directory |
| `temp_dir` | string | `".temp"` | Temporary files (stress data, submit temp) |
| `json_dir` | string | `".problem"` | Problem data storage directory |
| `solve_dir` | string | `".solve"` | Archive for solved problems |
| `template_dir` | string | `""` | Template directory |
| `template_default` | string | `""` | Default template file path |
| `template_default_ext` | string | `".cpp"` | Fallback language extension |
| `auto_open` | boolean | `true` | Auto-open source file on problem receipt |

### Server & Judge

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `http_host` | string | `"127.0.0.1"` | HTTP server bind address |
| `http_port` | integer | `10043` | HTTP server port |
| `ws_host` | string | `"127.0.0.1"` | WebSocket server bind address |
| `ws_port` | integer | `10044` | WebSocket server port |
| `server_mod` | string | `"all"` | Startup mode: `http` / `ws` / `all` |
| `max_time_out` | integer | `5` | Browser connection timeout (seconds) |
| `max_workers` | integer | `5` | Max concurrent judge workers |
| `max_solve_history` | integer | `100` | Max entries in solve history |
| `debug` | boolean | `false` | Enable debug logging |

### Judge Behavior

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `obscure` | boolean | `true` | Lexical fuzzy matching (ignore excess whitespace) |
| `warning_msg` | boolean | `false` | Show compilation warnings in judge results |
| `default_time_limit` | integer | `2000` | Fallback time limit (ms) |
| `default_memory_limit` | integer | `256` | Fallback memory limit (MB) |
| `linux_mem_offset` | integer | `-2900` | Memory measurement offset on Linux (KB) |
| `macos_mem_offset` | integer | `-1500` | Memory measurement offset on macOS (KB) |

### Variable Expansion

Compile/run command strings support `$(VAR)` / `@VAR` / `%VAR%` placeholders:

| Variable | Expands to |
| --- | --- |
| `$(FNAME)` | Full filename (e.g., `123A.cpp`) |
| `$(FNOEXT)` | Filename without extension (e.g., `123A`) |
| `$(FABSPATH)` | Absolute path to source file |
| `$(DIR)` | Directory of source file |

### Compile & Run Commands

`compile_command` and `run_command` are tables keyed by file extension. Each entry has `exec` (executable) and optional `args` (argument list).

```lua
-- Example: custom C++ configuration
compile_command = {
  cpp = {
    exec = "g++",
    args = { "-std=c++20", "-O2", "$(FABSPATH)", "-o", "$(DIR)/$(FNOEXT)" },
  },
},
run_command = {
  cpp = { exec = "$(DIR)/$(FNOEXT)" },
},
```

### UI Layouts

Three UI configurations control floating window layouts:

- **`tc_ui`** — Judge results viewer (testcases, input, output, info, expected output)
- **`tc_edit_ui`** — Test case editor (testcase list, input, output)
- **`stress_ui`** — Stress test viewer (same layout as tc_ui)

Each has `width`, `height`, `layout` (recursive `{weight, content}` tree), and `mappings`.

### Highlights

```lua
highlights = {
  windows = {
    Header = "#c0c0c0", Correct = "#00ff00", Warning = "orange", Wrong = "red",
  },
  stdio = {
    Header = "#c0c0c0", Correct = "#00ff00", Warning = "orange", Wrong = "orange",
  },
},
```

### Code Obfuscator

Optional: pre-process code before submission (use with caution).

```lua
code_obfuscator = {
  result = ".obfuscator/$(FNAME)",
  cmd = { exec = "obfuscator_cpp", args = { "$(FABSPATH)", ".obfuscator/$(FNAME)" } },
},
```

---

## 🔄 Recommended Workflow

```
Browser (Competitive Companion)  ➔  Neovim (Faster-OJ.nvim)  ➔  Local Judge
                                                                     ↓
Online Judge  ⬅  Browser Extension (Faster-OJ)  ⬅  Submit Command
```

1. **Fetch**: Click the browser extension — problem data syncs to Neovim automatically.
2. **Code**: Write your solution; a template file is created automatically.
3. **Test**: Run `:FOJ run` to compile and execute all test cases concurrently.
4. **Submit**: After all tests pass, run `:FOJ submit` — the browser extension submits for you.

### Problem Data Format

```
.problem/
└── ProblemName/
    ├── problem.json    # { url, name, testCount, memoryLimit, timeLimit }
    ├── 0.in / 0.out
    ├── 1.in / 1.out
    └── ...
```

---

## 📊 Platform & Language Support

- **Cross-platform**: Windows, Linux, macOS with platform-aware time/memory measurement.
  - Linux: `timeout` + `/usr/bin/time -v` for hard time limits and RSS memory
  - macOS: `/usr/bin/time -l` + uv timer fallback
  - Windows: PowerShell `Start-Process` with `PeakWorkingSet64`
- **Built-in languages**:
  - **Compiled**: C, C++, Rust, Go, Java, Kotlin, C#, Pascal, Swift, Zig
  - **Scripting**: Python, JavaScript (Node), TypeScript (ts-node), Lua

---

If you have questions or suggestions, feel free to open an [Issue](https://github.com/XiaoCRQ/Faster-OJ.nvim/issues) or submit a PR!
