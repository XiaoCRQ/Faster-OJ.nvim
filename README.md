# Faster-OJ.nvim

> ⚡ Accelerate your Competitive Programming workflow inside Neovim.
> [README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

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

You can customize the behavior via the `opts` table:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `warning_msg` | boolean | `true` | Whether to show compiler warnings in notifications |
| `work_dir` | string | `""` | Root directory for the plugin workspace |
| `json_dir` | string | `".problem"` | Directory to store problem data JSON files |
| `solve_dir` | string | `".solve"` | Directory to move files when marked as solved |
| `template_dir` | string | `""` | Directory where your code templates are located |
| `template_default` | string | `""` | Filename of the default template to use |
| `template_default_ext` | string | `".cpp"` | Default extension for new files if no template is set |
| `compile_command` | table | (see below) | Compilation settings for different languages |
| `run_command` | table | (see below) | Execution settings for different languages |

**Example Command Config:**

```lua
opts = {
  compile_command = {
    cpp = {
      exec = "g++",
      args = { "-O2", "-Wall", "$(FABSPATH)", "-o", "Output" .. "/$(FNOEXT)" },
    },
  },
  run_command = {
    cpp = { exec = "Output" .. "/$(FNOEXT)" },
  },
}

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

---

## 📊 Platform Support

| Feature | Windows | Linux | macOS |
| --- | --- | --- | --- |
| Receive Problem | ✅ | ✅ | ✅ |
| Local Testing | ✅ | ✅ | ✅ |
| Submit | 🚧 | ✅ | 🚧 |

> *Note: Submission features rely on WebSocket services. Support for non-Linux platforms is currently experimental.*

---

## 📜 License

Distributed under the **GNU GPL v3** License.
