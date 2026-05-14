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
- **Dual-Style UI**: Float (floating windows) and Split (native Neovim splits) modes. Switch on the fly with `f`.
- **Smart Finder**: Integrates with `snacks.nvim`, `telescope.nvim`, `fzf-lua`, `mini.pick`, or `vim.ui.select`.
- **Robust Quoting**: Stress test arguments support three quoting styles — `"..."`, `'...'`, and C++ raw strings `R"(...)"` — for paths with spaces and special characters.

---

## 🚀 Recommended Workflow

1. **Start services** — `:FOJ` launches HTTP + WebSocket servers
2. **Fetch a problem** — Click a problem link in your browser; the [Competitive Companion](https://github.com/jmerle/competitive-companion) extension sends it to Neovim. A source file and test data are created automatically in `work_dir`
3. **Write your solution** — Edit the generated file
4. **Judge locally** — `<leader>cdt` compiles and runs all test cases. Results open in a multi-panel UI with side-by-side diff
5. **Stress test (optional)** — `<leader>cdP` picks two solutions interactively, or specify paths: `:FOJ stress correct=path:"brute.cpp" test=path:"solve.cpp"`
6. **Submit** — `<leader>cdr` sends the solution via WebSocket through the browser extension

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
map("n", "<leader>cdu", ":FOJ show<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Reopen last session" }))
map("n", "<leader>cdU", ":FOJ show test split<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Show tests (split)" }))
map("n", "<leader>cde", ":FOJ show edit<CR>",    vim.tbl_extend("force", opts, { desc = "FOJ: Toggle test editor" }))
map("n", "<leader>cdC", ":FOJ close<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Close all UI windows" }))

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

### Judge & UI

| Command | Description |
| --- | --- |
| `:FOJ run` | Save, compile, and run all test cases |
| `:FOJ test` | Run test cases without recompiling |
| `:FOJ show [sub1] [sub2]` | Reopen last session or toggle specified UI (see below) |
| `:FOJ close [sub]` | Close UI windows (no arg = close all) |
| `:FOJ edit` | Toggle test case editor (alias for `:FOJ show edit`) |

`show` arguments:

| `sub1` | `sub2` (optional) | Action |
| --- | --- | --- |
| *(none)* | — | Reopen last active session; no-op if no history |
| `test` | — | Toggle test viewer (default style) |
| `test` | `float` / `split` | Test viewer with specific style |
| `edit` | — | Toggle test case editor (default style) |
| `edit` | `float` / `split` | Editor with specific style |
| `stress` | — | Toggle stress viewer (if prior results exist) |
| `stress` | `float` / `split` | Stress viewer with specific style |

`close` arguments: `test` / `edit` / `stress` (no arg = close all).

**Dual-style behavior:** Press `f` inside any UI window to toggle between float and split. Different viewers (test, edit, stress) can coexist as long as they use different styles — e.g., TestUI in float + EditUI in split. Switching a viewer's style automatically closes any other viewer using the target style, ensuring at most one float and one split window globally.

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
| `correct` | `path:FILE` or `find:DIR` | Reference solution |
| `test` | `path:FILE` or `find:DIR` | Solution under test |
| `data` | `path:P1\nP2` / `find:DIR` / `data:RAW` | Input data (optional: auto-loads from correct/test problem dir) |
| `time` | integer (ms) | Time limit per case (default: `default_time_limit`) |
| `mem` | integer (MB) | Memory limit per case (default: `default_memory_limit`) |

Values support three quoting styles for paths containing spaces or special characters:
- Double quotes: `"..."` — single quotes: `'...'` — C++ raw string: `R"(...)"` / `R"delim(...)delim"`

**Examples:**

```vim
" Pick both files interactively (data auto-loaded from problem dirs)
:FOJ stress correct=find: test=find:

" Direct paths
:FOJ stress correct=path:brute.py test=path:solve.cpp

" Paths with spaces (quoted)
:FOJ stress correct=path:"my brute.cpp" test=path:'solve.cpp'

" C++ raw string quoting
:FOJ stress correct=path:R"(brute.cpp)" test=path:R"(solve.cpp)"

" With raw data and time/memory limits
:FOJ stress correct=path:a.cpp test=path:b.cpp data=data:5\n1 2 3 time=1000 mem=512
```

---

## ⚙️ Configuration Reference

### Paths

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `work_dir` | string | `vim.fn.stdpath("data") .. "/faster-oj"` | Base working directory |
| `data_dir` | string | `".problem"` | Problem data directory (relative to `work_dir`) |
| `solve_dir` | string | `".solve"` | Solved problems archive (relative to `work_dir`) |
| `temp_dir` | string | `".temp"` | Temporary files (relative to `work_dir`) |
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

Each UI (`tc_ui`, `tc_edit_ui`, `stress_ui`) supports two styles: **float** (floating windows) and **split** (native Neovim splits). Press `f` inside any UI window to toggle between them.

```lua
tc_ui = {
  default_style = "float",            -- "float" | "split"
  mappings = {                        -- shared across styles
    close = { "<esc>", "<C-c>", "q", "Q" },
    toggle_style = { "f" },           -- NEW: switch float/split
    -- ... view, focus_next, etc.
  },
  float = {
    width = 0.9, height = 0.9,
    layout = {                        -- recursive {weight, content} tree
      { 4, "tc" },                    -- test case list, weight 4
      { 5, { { 1, "si" }, { 1, "so" } } },  -- input/output, vertical split
      { 5, { { 1, "info" }, { 1, "eo" } } }, -- info/expected, vertical split
    },
  },
  split = {
    width = 0.3,                      -- ratio of editor width/height
    direction = "right",              -- "right"|"left"|"above"|"below"
    layout = { ... },                 -- same recursive syntax
  },
}
```

| Style | Parameters |
| --- | --- |
| `float` | `width` (ratio), `height` (ratio), `layout` |
| `split` | `width` (ratio), `direction` (`"right"` default), `layout` |

- **`tc_ui`** — Judge results (panels: `tc`, `si`, `so`, `info`, `eo`)
- **`tc_edit_ui`** — Test case editor (panels: `tc`, `si`, `so`)
- **`stress_ui`** — Stress test viewer (panels: `tc`, `si`, `so`, `info`, `eo`)

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
