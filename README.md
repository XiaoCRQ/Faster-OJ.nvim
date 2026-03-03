# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ Build a complete Competitive Programming automation workflow inside Neovim.</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

---

**Faster-OJ.nvim** is a Neovim plugin designed for Competitive Programming.

It integrates:

* 📥 Problem fetching
* 🧪 Local judging
* 🌐 Browser auto-submission
* 🖥 Local WebSocket service
* 🧩 Multi-language compile & run

Into a complete closed-loop workflow:

> ✨ Write → Test locally → One-click submit → Wait for AC

---

# ✨ Core Features

## 🚀 One-Click Submission

Send code directly from Neovim to the browser extension for automatic OJ submission — no more copy & paste.

Works with browser extensions:

* Faster-OJ
* Competitive Companion

---

## 🖥 Built-in Local Judge Service (HTTP + WebSocket)

The plugin includes:

* HTTP server
* WebSocket server
* Automatic browser connection
* Flexible startup modes (`http` / `ws` / `all`)

Default ports:

```
HTTP: 127.0.0.1:10043
WS:   127.0.0.1:10044
```

Supports browser connection timeout control, debug mode, and concurrency limits.

---

## 🧪 High-Performance Local Testing System

* Multi-language automatic compile & run
* Configurable parallel testing (`max_workers`)
* Line-by-line or lexical fuzzy matching
* Optional compiler warning display
* Real-time UI test status updates
* Cached results with reopen support

---

## 🧩 Multi-Language Support

Built-in compile & run configurations:

### Compiled Languages

* C
* C++
* C#
* Rust
* Go
* Java
* Kotlin
* Pascal
* Swift
* Zig

### Scripting Languages

* Python
* JavaScript (Node)
* TypeScript (ts-node)
* Lua

### Language Configuration Example

```lua
compile_command = { -- Empty for scripting languages
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
}

run_command = {
  cpp = { exec = "$(DIR)/$(FNOEXT)" },
}
```

---

## 🧠 Built-in Code Obfuscation Support (Optional)

Supports custom `code_obfuscator`.

⚠ Notes:

* Code is replaced only if the obfuscator runs successfully and returns valid output
* Not all OJ platforms allow this behavior
* Disabled by default

---

## 🪟 Dual UI System

### Judge UI (`tc_ui`)

Features:

* Multi-window layout
* Visual test result display
* Standard input/output comparison
* Expected output comparison
* Error message display
* Custom key mappings
* Custom highlight colors

---

### Test Case Management UI (`tc_edit_ui`)

Features:

* Add test cases
* Edit test cases
* Delete test cases
* Auto-save
* Multi-window layout

---

# 🔄 Recommended Workflow

```text
Competitive Companion (Browser)
        ↓
Neovim + Faster-OJ.nvim
        ↓
Local Judge (HTTP + WS)
        ↓
Browser Extension (Faster-OJ)
        ↓
Online Judge
```

Workflow explanation:

1. Fetch problem via Competitive Companion
2. Automatically send to Neovim
3. Develop locally + `:FOJ run`
4. One-click `:FOJ submit`
5. Browser completes submission automatically

---

# 📦 Installation

## Requirements

* Neovim (latest stable recommended)
* Browser extensions:

  * Faster-OJ
  * Competitive Companion

---

## Install with lazy.nvim

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

---

# ⚙️ Configuration

Full default configuration is located at:

```
lua/faster-oj/default.lua
```

---

## Server Options

| Option         | Default       | Description                      |
| -------------- | ------------- | -------------------------------- |
| `http_host`    | `"127.0.0.1"` | HTTP server host                 |
| `http_port`    | `10043`       | HTTP server port                 |
| `ws_host`      | `"127.0.0.1"` | WebSocket server host            |
| `ws_port`      | `10044`       | WebSocket server port            |
| `server_mod`   | `"all"`       | Mode: `http` / `ws` / `all`      |
| `max_time_out` | `5`           | Browser connection timeout (sec) |
| `debug`        | `false`       | Enable debug mode                |

---

## Workspace Options

| Option                 | Default    | Description               |
| ---------------------- | ---------- | ------------------------- |
| `work_dir`             | `""`       | Working directory         |
| `json_dir`             | `.problem` | Problem data directory    |
| `solve_dir`            | `.solve`   | Solved problems directory |
| `template_dir`         | `""`       | Template directory        |
| `template_default`     | `""`       | Default template file     |
| `template_default_ext` | `.cpp`     | Default file extension    |
| `open_new`             | `true`     | Auto-open new problems    |

---

## Judge Options

| Option             | Default | Description              |
| ------------------ | ------- | ------------------------ |
| `obscure`          | `true`  | Lexical matching mode    |
| `warning_msg`      | `false` | Show compiler warnings   |
| `max_workers`      | `5`     | Maximum parallel workers |
| `linux_mem_offset` | -2900   | Linux memory offset      |
| `macos_mem_offset` | -1500   | macOS memory offset      |

---

## UI Customization

Supports:

* Custom window ratios
* Custom layout tree
* Custom key mappings
* Custom highlight colors

Highlight example:

```lua
highlights = {
  windows = {
    Header = "#c0c0c0",
    Correct = "#00ff00",
    Warning = "orange",
    Wrong = "red",
  },
}
```

---

# 🛠 Common Commands

| Command                    | Description            |
| -------------------------- | ---------------------- |
| `:FOJ`                     | Start full service     |
| `:FOJ start [all/http/ws]` | Start specific service |
| `:FOJ stop`                | Stop service           |
| `:FOJ run`                 | Compile & run tests    |
| `:FOJ test`                | Run tests only         |
| `:FOJ submit`              | Auto submit            |
| `:FOJ show`                | Open judge UI          |
| `:FOJ close`               | Close UI               |
| `:FOJ edit`                | Edit test cases        |
| `:FOJ erase`               | Delete problem data    |
| `:FOJ solve`               | Mark as solved         |
| `:FOJ solve back`          | Unmark solved          |

---

# ⌨ Recommended Keybindings

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map("n", "<leader>cda", ":FOJ <CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Start" }))
map("n", "<leader>cdq", ":FOJ stop<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Stop" }))
map("n", "<leader>cdr", ":FOJ submit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Submit" }))
map("n", "<leader>cdt", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Judge" }))
map("n", "<leader>cdT", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Judge (no compile)" }))
map("n", "<leader>cdu", ":FOJ show<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Toggle UI" }))
map("n", "<leader>cds", ":FOJ solve<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Mark solved" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Unmark solved" }))
map("n", "<leader>cde", ":FOJ edit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Edit tests" }))
map("n", "<leader>cdd", ":FOJ erase<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Delete problem data" }))
```

---

# 📊 Platform Support

| Feature            | Windows | Linux | macOS |
| ------------------ | ------- | ----- | ----- |
| Receive Problems   | ✅       | ✅     | ✅     |
| Local Testing      | ✅       | ✅     | ✅     |
| Edit Test Cases    | ✅       | ✅     | ✅     |
| Problem Management | ✅       | ✅     | ✅     |
| Auto Submission    | ✅       | ✅     | ✅     |
| Multi-Language     | ✅       | ✅     | ✅     |

---

# 🎯 Design Goals

* Extreme automation
* Zero copy-paste
* Minimal context switching
* Strong extensibility
* High-performance parallel testing
* Optimized for competitive environments

---

If you want:

* 🚀 Maximum problem-solving efficiency
* 🧠 Native Neovim experience
* 🔥 A true one-click AC workflow

Then **Faster-OJ.nvim** will become your ultimate competitive programming tool.
