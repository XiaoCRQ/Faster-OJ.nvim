# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ Build a complete Competitive Programming automation workflow in Neovim.</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

**Faster-OJ.nvim** is a Neovim plugin designed specifically for **Competitive Programming**. By integrating problem fetching, local judging, and automated submission, it aims to provide a **distraction-free and immersive coding environment** for solving problems.

---

# ✨ Core Features

* **Fully Automated Workflow**: Fetch problems using [Competitive Companion](https://github.com/jmerle/competitive-companion) and submit solutions with the [Faster-OJ browser extension](https://github.com/XiaoCRQ/Faster-OJ), eliminating manual copy-paste completely.
* **Dual Judging Engines**: Built-in **HTTP** and **WebSocket** services support concurrent judging (`max_workers`) and stream real-time test results directly to the UI.
* **High-Performance Local Judge**: Supports **lexical fuzzy matching** (`obscure`) and **memory offset compensation** for Linux/macOS environments.
* **Dual UI Layout System**:
* **Judge UI (`tc_ui`)**: Displays test case results, input/output comparisons, expected output, and error details.
* **Management UI (`tc_edit_ui`)**: Allows adding, deleting, and modifying test cases in real time with instant persistence.

* **Smart Finder**: Deep integration with popular plugins such as `snacks`, `telescope`, and `fzf-lua` for quickly browsing templates and problem data.

---

# 🔄 Recommended Workflow

```text
Browser (Competitive Companion)  ➔  Neovim (Faster-OJ.nvim)  ➔  Local Judge (HTTP + WS)
                                                                       ↓
Online Judge  ⬅  Browser Extension (Faster-OJ)  ⬅  Submit Command

```

1. **Fetch**: Click the browser plugin and the problem data is automatically synchronized to Neovim.
2. **Develop**: Write your solution in Neovim with automatic template filling.
3. **Test**: Run `:FOJ run` to start high-concurrency local judging.
4. **Submit**: After passing locally, run `:FOJ submit` and the browser extension completes the submission automatically.

---

# 📦 Installation

## 1. Minimal Installation Example

Suitable for users who want an **out-of-the-box experience** with default configuration.

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

## 2. Classic Installation Example

Suitable for users who want to customize working directories, templates, and compilation logic.

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {
    work_dir = "",                              -- Base working directory for the plugin
    json_dir = ".problem",                      -- Directory for storing problem metadata
    solve_dir = ".solve",                       -- Directory for archived solved problems
    template_dir = ".template",                 -- Directory for code templates
    template_default = ".template/template.cpp", -- Default template file
    template_default_ext = ".cpp",               -- Default language extension
    compile_command = {
      -- Override or add compilation commands here
    },
    run_command = {
      -- Override or add run commands here
    },
  },
}
```

---

# 🛠 Common Commands

| Command            | Description                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------- |
| `:FOJ`             | Start the full service (HTTP + WebSocket)                                                 |
| `:FOJ start [mod]` | Start a specific mode: `all` / `http` / `ws`                                              |
| `:FOJ stop`        | Stop all judging and communication services                                               |
| `:FOJ run`         | **Core command**: save, compile, and run local test cases                                 |
| `:FOJ test`        | Run local tests only (skip compilation)                                                   |
| `:FOJ submit`      | Automatically send the current code to the browser extension via WebSocket for submission |
| `:FOJ show`        | Open/toggle the local judge result UI                                                     |
| `:FOJ edit`        | Enter test case editing mode (add/delete/modify)                                          |
| `:FOJ solve`       | Mark the problem as solved and move files to `solve_dir`                                  |
| `:FOJ solve back`  | Undo the solved mark and restore the problem                                              |
| `:FOJ erase`       | Physically delete all local cached data of the current problem                            |
| `:FOJ find [type]` | Quick browsing: `template` / `problem` / `json`                                           |

---

# ⚙️ Configuration Details (`opts`)

## 1. Basic and Path Configuration

| Parameter      | Type    | Default      | Description                                                |
| -------------- | ------- | ------------ | ---------------------------------------------------------- |
| `work_dir`     | string  | `""`         | Working directory of the plugin                            |
| `json_dir`     | string  | `".problem"` | Directory storing problem metadata                         |
| `solve_dir`    | string  | `".solve"`   | Directory storing solved problems                          |
| `template_dir` | string  | `""`         | Directory storing template files                           |
| `auto_open`    | boolean | `true`       | Automatically open the code file after receiving a problem |

## 2. Server and Judging

| Parameter      | Type    | Default | Description                                                  |
| -------------- | ------- | ------- | ------------------------------------------------------------ |
| `server_mod`   | string  | `"all"` | Startup mode: `http`, `ws`, or `all`                         |
| `max_workers`  | integer | `5`     | Maximum number of concurrent judging workers                 |
| `obscure`      | boolean | `true`  | Enable lexical fuzzy matching (ignore extra spaces/newlines) |
| `max_time_out` | integer | `5`     | Maximum wait time for browser connection (seconds)           |
| `debug`        | boolean | `false` | Enable debug mode                                            |

## 3. Command Table Configuration (Core Customization)

These two tables determine how the plugin compiles and runs programs in different languages.

* **`compile_command`**: Compilation command table.

* **Description**: Each command includes `exec` (executable) and `args` (argument list) with variable support.

* **`run_command`**: Execution command table.

* **Description**: Defines how compiled binaries or scripts are executed during judging (e.g., `python3`, `node`).

### Minimal Example

```lua
compile_command = {
  c = {
    exec = "gcc",
    args = { "-g", "-Wall", "$(FABSPATH)", "-o", ".output" .. "/$(FNOEXT)" },
  },
  cpp = {
    exec = "g++",
    args = { "-g", "-Wall", "$(FABSPATH)", "-o", ".output" .. "/$(FNOEXT)" },
  },
},
run_command = {
  c = { exec = ".output" .. "/$(FNOEXT)" },
  cpp = { exec = ".output" .. "/$(FNOEXT)" },
},
```

---

# ⌨️ Recommended Keymaps

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Basic control
map("n", "<leader>cda", ":FOJ<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Start coding session" }))
map("n", "<leader>cdq", ":FOJ stop<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Stop services" }))
map("n", "<leader>cdr", ":FOJ submit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Submit solution" }))

-- Judging and UI
map("n", "<leader>cdt", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Compile and judge" }))
map("n", "<leader>cdT", ":FOJ test<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Test only (no compile)" }))
map("n", "<leader>cdu", ":FOJ show<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Toggle judge UI" }))
map("n", "<leader>cde", ":FOJ edit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Edit test cases" }))

-- Data management
map("n", "<leader>cds", ":FOJ solve<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Mark problem as solved" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Undo solved mark" }))
map("n", "<leader>cdd", ":FOJ erase<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Delete problem data" }))

-- Finder
map("n", "<leader>cdc", ":FOJ find template<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Find template files" }))
map("n", "<leader>cdp", ":FOJ find problem<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Find problem history" }))
map("n", "<leader>cdj", ":FOJ find json<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Find problem metadata" }))
```

---

# 📊 Platform and Language Support

* **Cross-platform**: Full support for **Windows, Linux, and macOS**.
* **Built-in language support**:
* **Compiled languages**: C, C++, C#, Rust, Go, Java, Kotlin, Pascal, Swift, Zig.
* **Scripting languages**: Python, JavaScript (Node), TypeScript (ts-node), Lua.

We hope **Faster-OJ.nvim** makes your competitive programming workflow faster and more enjoyable.
If you have questions or suggestions, feel free to open an Issue or submit a PR!
