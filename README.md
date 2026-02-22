# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)
<p>⚡ Accelerate your Competitive Programming workflow inside Neovim.</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)
</div>

**Faster-OJ.nvim** is a powerful Neovim plugin designed for Competitive Programmers. It bridges the gap between local coding, testing, and online submission, providing a seamless "Code and Submit" experience.

---

## ✨ Features

* **🚀 One-Key Submit**: Submit code directly to Online Judges from Neovim without manual copy-pasting.
* **🖥 Local Judge Server**: Built-in WebSocket management for handling judge tasks (powered by [mini-wsbroad](https://github.com/XiaoCRQ/mini-wsbroad)).
* **🧪 Fast Local Testing**: Compile, execute, and verify your logic against sample cases with one command.
* **🔗 Seamless Browser Integration**: Works hand-in-hand with browser extensions for data synchronization.
* **🧠 Minimal & Efficient**: Simple commands and intuitive UI to keep you focused on the problem.

---

## 🔄 Recommended Workflow

```text
Competitive Companion (Browser)
        ↓ Fetch Problem
Neovim + Faster-OJ.nvim (Local)
        ↓ Code & Test
Local Judge Server (WebSocket)
        ↓ Trigger Submit
Faster-OJ (Browser Extension)
        ↓ Execute
Online Judge (Web)

```

1. **Receive Problem**: Use [Competitive Companion](https://github.com/jmerle/competitive-companion) to parse problem data into Neovim.
2. **Develop Locally**: Write your solution in your customized Neovim environment.
3. **Test Locally**: Run `:FOJ run` to verify against local samples.
4. **Submit**: Call `:FOJ submit` to send your code to the [Faster-OJ](https://github.com/XiaoCRQ/Faster-OJ) browser extension for final submission.

---

## 📦 Installation & Configuration

### 1. Requirements

* **Browser Extensions**: [Faster-OJ](https://github.com/XiaoCRQ/Faster-OJ) & [Competitive Companion](https://github.com/jmerle/competitive-companion).
* **Neovim**: Latest stable version recommended.

### 2. Plugin Installation (using lazy.nvim)

#### **Minimal Installation (Default Settings)**

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}

```

#### **Standard Configuration Options**

You can customize the behavior via the `opts` table: [more default opts](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/lua/faster-oj/default.lua)

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `obscure` | boolean | `true` | Enable token-based judging ( `false` for line-by-line mode) |
| `warning_msg` | boolean | `true` | Whether to show compiler warnings in notifications |
| `work_dir` | string | `""` | Root directory for the plugin workspace |
| `json_dir` | string | `".problem"` | Directory to store problem data JSON files |
| `solve_dir` | string | `".solve"` | Directory to move files when marked as solved |
| `template_dir` | string | `""` | Directory where your code templates are located |
| `template_default` | string | `""` | Filename of the default template to use |
| `template_default_ext` | string | `".cpp"` | Default extension for new files if no template is set |
| `tc_ui` | table | (See below) | Judging UI Settings |
| `tc_edit_ui` | table | (See below) | Test Case Edit UI Settings |
| `compile_command` | table | (see below) | Compilation settings for different languages |
| `run_command` | table | (see below) | Execution settings for different languages |

**Example Command Config:**

```lua
opts = {
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
   edit = { "e", "i" ,"o", "O"},
   edit_focus_next = { "<down>", "<Tab>" },
   edit_focus_prev = { "<up>", "<S-Tab>" },
   focus_next = { "j", "<down>", "<Tab>" },
   focus_prev = { "k", "<up>", "<S-Tab>" },
  },
 },

 compile_command = {
   cpp = {
     exec = "g++",
     args = { "-O2", "-Wall", "$(FABSPATH)", "-o", "Output" .. "/$(FNOEXT)" },
   },
 },
 run_command = {
   cpp = { exec = "Output" .. "/$(FNOEXT)" },
 },
```

---

## 🛠 Commands

| Command | Description |
| --- | --- |
| `:FOJ` | Full startup (starts both HTTP and WS services) |
| `:FOJ start [all/http/ws]` | Start specific background services |
| `:FOJ stop` | Stop all services |
| `:FOJ submit` | Submit the current buffer to the Judge/Browser |
| `:FOJ run` | Compile and run tests for the current problem |
| `:FOJ solve [back]` | Mark problem as solved (moves the file) |
| `:FOJ show / close` | Toggle the Judge result window |
| `:FOJ edit` | Edit test cases |

* Keymap settings

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map("n", "<leader>cda", ":FOJ <CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Start Practicing" }))
map("n", "<leader>cdq", ":FOJ stop<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Stop Practicing" }))
map("n", "<leader>cdr", ":FOJ submit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Submit" }))
map("n", "<leader>cdt", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Judge" }))
map("n", "<leader>cdu", ":FOJ show<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Toggle UI" }))
map("n", "<leader>cds", ":FOJ solve<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Mark as Solved" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Unmark as Solved" }))
map("n", "<leader>cde", ":FOJ edit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Edit Test Cases" }))
```

---

## 📊 Platform Support

| Feature | Windows | Linux | macOS |
| :--- | :---: | :---: | :---: |
| Receive Problems | ✅ | ✅ | ✅ |
| Local Testing | ✅ | ✅ | ✅ |
| Code Obfuscation | ✅ | ✅ | ✅ |
| Case edit | ✅ | ✅ | ✅ |
| Issue Management | ✅ | ✅ | ✅ |
| Auto Submission | 🚧 | ✅ | 🚧 |

> *Note: Auto Submission features rely on WebSocket services. Support for non-Linux platforms is currently experimental.*

---

## 📜 License

Distributed under the **GNU GPL v3** License.
