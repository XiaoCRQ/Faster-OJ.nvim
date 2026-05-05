# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ Build a complete Competitive Programming automation workflow in Neovim.</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

**Faster-OJ.nvim** is a Neovim plugin designed for **Competitive Programming**. It integrates problem fetching, local judging, stress testing, and automated submission into a distraction-free workflow.

---

## ✨ Core Features

- **Fully Automated Workflow**: Fetch problems via [Competitive Companion](https://github.com/jmerle/competitive-companion) and submit with the [Faster-OJ browser extension](https://github.com/XiaoCRQ/Faster-OJ).
- **Local Judge**: Concurrent test execution with time/memory measurement. Lexical fuzzy matching (`obscure`) and memory offset compensation.
- **Stress Testing (对拍)**: Run two solutions against the same inputs — catch edge cases fast.
- **Multi-Panel UI**: Judge results, test case editor with real-time sync, stress test viewer.
- **Smart Finder**: Integrates with `snacks.nvim`, `telescope.nvim`, `fzf-lua`, `mini.pick`, or `vim.ui.select`.

---

## 📦 Installation

### Dependencies

- **Neovim** >= 0.9
- **Browser Extensions**:
  - [Competitive Companion](https://github.com/jmerle/competitive-companion) — receives problems
  - [Faster-OJ Browser Extension](https://github.com/XiaoCRQ/Faster-OJ) — submits solutions
- **Language toolchains** as needed (gcc/g++, python3, node, etc.)

### Minimal Configuration (lazy.nvim)

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

### Recommended Configuration

Only non-default overrides shown.

```lua
local code_path = vim.fn.expand("~/Work/Program/CodeForces")

{
  "xiaocrq/faster-oj.nvim",
  opts = {
    warning_msg = true,
    work_dir = code_path,
    temp_dir = code_path .. "/.temp",
    data_dir = code_path .. "/.problem",
    solve_dir = code_path .. "/.solve",
    template_dir = code_path .. "/.template",
    template_default = code_path .. "/.template/template.cpp",
  },
}
```

To customize compile/run commands, override `compile_command` / `run_command` .

---

## ⌨️ Recommended Keymaps

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Service
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
    vim.tbl_extend("force", opts, { desc = "FOJ: Stress test" }))
```

---

## 🛠 Commands

### Service

| Command | Description |
| --- | --- |
| `:FOJ` | Start HTTP + WebSocket services (switches to `work_dir` first) |
| `:FOJ start [mod]` | Start mode: `all` / `http` / `ws` |
| `:FOJ stop [mod]` | Stop services |

### Judge

| Command | Description |
| --- | --- |
| `:FOJ run` | Save, compile, and run all test cases |
| `:FOJ test` | Run test cases without recompiling |
| `:FOJ show` | Toggle judge result UI |
| `:FOJ edit` | Toggle test case editor (add/delete/modify) |

### Submit

| Command | Description |
| --- | --- |
| `:FOJ submit` | Send code to browser extension via WebSocket |

### Problem Management

| Command | Description |
| --- | --- |
| `:FOJ solve` | Move problem to `solve_dir`, record history |
| `:FOJ solve back` | Undo last solve, restore files |
| `:FOJ erase` | Delete problem source + data directory |

### Finder

| Command | Description |
| --- | --- |
| `:FOJ find template` | Browse templates in `template_dir` |
| `:FOJ find problem` | Browse source files in `work_dir` |
| `:FOJ find data` | Browse problem data in `data_dir` |

### Stress Testing

| Command | Description |
| --- | --- |
| `:FOJ stress` | Re-run last stress test |
| `:FOJ stress correct=type:val test=type:val [data=type:val] [time=N] [mem=N]` | Run stress test |

**Parameters:**

| Parameter | Type | Description |
| --- | --- | --- |
| `correct` | `path:FILE` or `find:` | Reference solution |
| `test` | `path:FILE` or `find:` | Solution under test |
| `data` | `path:P1\nP2` / `find:` / `data:RAW` | Input data (optional: auto-loads from correct/test problem dir) |
| `time` | integer (ms) | Time limit per case (default: `default_time_limit`) |
| `mem` | integer (MB) | Memory limit per case (default: `default_memory_limit`) |

**Examples:**

```vim
" Pick both files interactively (data auto-loaded from problem dirs)
:FOJ stress correct=find: test=find:

" Direct paths, different languages
:FOJ stress correct=path:brute.py test=path:solve.cpp

" With raw data
:FOJ stress correct=path:a.cpp test=path:b.cpp data=data:5\n1 2 3 time=1000
```

---

## ⚙️ Configuration Reference

### Paths

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `work_dir` | string | `""` | Base working directory |
| `data_dir` | string | `".problem"` | Problem data directory |
| `solve_dir` | string | `".solve"` | Solved problems archive |
| `temp_dir` | string | `".temp"` | Temporary files |
| `template_dir` | string | `""` | Template directory |
| `template_default` | string | `""` | Default template file |
| `template_default_ext` | string | `".cpp"` | Fallback language extension |
| `auto_open` | boolean | `true` | Auto-open file on problem receipt |

### Server

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `http_host` | string | `"127.0.0.1"` | HTTP bind address |
| `http_port` | integer | `10043` | HTTP port |
| `ws_host` | string | `"127.0.0.1"` | WebSocket bind address |
| `ws_port` | integer | `10044` | WebSocket port |
| `server_mod` | string | `"all"` | Startup mode: `http` / `ws` / `all` |
| `max_time_out` | integer | `5` | Browser connection timeout (s) |

### Judge

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `max_workers` | integer | `5` | Max concurrent workers |
| `obscure` | boolean | `true` | Lexical fuzzy matching |
| `warning_msg` | boolean | `false` | Show compile warnings in results |
| `clipboard_submit` | boolean | `false` | Copy code to clipboard on submit |
| `default_time_limit` | integer | `2000` | Fallback time limit (ms) |
| `default_memory_limit` | integer | `256` | Fallback memory limit (MB) |
| `linux_mem_offset` | integer | `-2900` | Linux memory offset (KB) |
| `macos_mem_offset` | integer | `-1500` | macOS memory offset (KB) |
| `max_solve_history` | integer | `100` | Max solve history entries |
| `debug` | boolean | `false` | Debug logging |

### Variable Expansion

Commands support `$(VAR)` / `@VAR` / `%VAR%`:

| Variable | Expands to |
| --- | --- |
| `$(FNAME)` | Full filename (`123A.cpp`) |
| `$(FNOEXT)` | Filename without extension (`123A`) |
| `$(FABSPATH)` | Absolute path to source file |
| `$(DIR)` | Directory of source file |

### Compile & Run Commands

Tables keyed by file extension. Each entry: `exec` + optional `args`.

```lua
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

- **`tc_ui`** — Judge results (testcases, input, output, info, expected output)
- **`tc_edit_ui`** — Test case editor (testcase list, input, output)
- **`stress_ui`** — Stress test viewer

Each has `width`, `height`, `layout` (recursive tree), and `mappings`.

### Highlights

```lua
highlights = {
  windows = { Header = "#c0c0c0", Correct = "#00ff00", Warning = "orange", Wrong = "red" },
  stdio   = { Header = "#c0c0c0", Correct = "#00ff00", Warning = "orange", Wrong = "orange" },
},
```

### Code Obfuscator

Optional pre-processing before submission (use with caution).

```lua
code_obfuscator = {
  result = ".obfuscator/$(FNAME)",
  cmd = { exec = "obfuscator_cpp", args = { "$(FABSPATH)", ".obfuscator/$(FNAME)" } },
},
```

---

## 📊 Platform & Language Support

- **Cross-platform**: Windows, Linux, macOS.
- **Compiled languages**: C, C++, Rust, Go, Java, Kotlin, C#, Pascal, Swift, Zig.
- **Scripting languages**: Python, JavaScript (Node), TypeScript (ts-node), Lua.

---

If you have questions or suggestions, open an [Issue](https://github.com/XiaoCRQ/Faster-OJ.nvim/issues) or submit a PR!
