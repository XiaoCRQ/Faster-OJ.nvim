# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ 在 Neovim 中构建完整的算法竞赛自动化工作流。</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

**Faster-OJ.nvim** 是一款专为算法竞赛（Competitive Programming）设计的 Neovim 插件。通过整合题目抓取、本地评测与自动化提交，它旨在为你提供一个“零干扰”的沉浸式刷题环境。

---

# ✨ 核心特性

* **全自动工作流**：配合 [Competitive Companion](https://github.com/jmerle/competitive-companion) 抓题，利用 [Faster-OJ 浏览器插件](https://github.com/XiaoCRQ/Faster-OJ) 实现一键提交，彻底告别手动复制粘贴。
* **双引擎评测服务**：内置 HTTP 与 WebSocket 服务，支持并发评测 (`max_workers`)，实时将测试状态反馈至 UI。
* **高性能本地评测**：支持**词法模糊匹配** (`obscure`) 与针对 Linux/macOS 的**内存偏移补偿**。
* **双布局 UI 系统**：
* **判题 UI (`tc_ui`)**：展示测试点状态、标准输入输出对比、预期输出及错误详情。
* **管理 UI (`tc_edit_ui`)**：实时添加、删除或修改测试用例，即时保存。

* **智能查找器**：深度集成 `snacks`、`telescope`、`fzf-lua` 等主流插件，快速浏览模板与题目数据。

---

# 🔄 推荐工作流

```text
Browser (Competitive Companion)  ➔  Neovim (Faster-OJ.nvim)  ➔  Local Judge (HTTP + WS)
                                                                       ↓
Online Judge  ⬅  Browser Extension (Faster-OJ)  ⬅  Submit Command

```

1. **抓取**：浏览器点击插件，题目数据自动同步至 Neovim。
2. **开发**：在 Neovim 内编写代码，支持模板自动填充。
3. **测试**：执行 `:FOJ run` 开启本地高并发评测。
4. **提交**：本地 AC 后执行 `:FOJ submit`，浏览器自动完成提交。

---

# 📦 安装

## 1. 最小化安装示例

适合追求开箱即用，仅使用默认配置的用户。

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}

```

## 2. 经典安装示例

适合需要自定义工作目录、模板以及编译逻辑的用户。

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {
    work_dir = "",                              -- 插件运行的基础工作目录
    json_dir = ".problem",                      -- 题目元数据存储子目录
    solve_dir = ".solve",                       -- 归档已解决题目的目录
    template_dir = ".template",                 -- 存放代码模板的目录
    template_default = ".template/template.cpp", -- 指定默认填充的模板文件
    template_default_ext = ".cpp",               -- 缺省时的默认语言扩展名
    compile_command = {
      -- 此处可重写或新增编译命令
    },
    run_command = {
      -- 此处可重写或新增运行命令
    },
  },
}
```

---

# 🛠 常用命令

| 命令 | 描述 |
| --- | --- |
| `:FOJ` | 启动完整服务（HTTP + WebSocket） |
| `:FOJ start [mod]` | 启动指定模式服务：`all` / `http` / `ws` |
| `:FOJ stop` | 停止所有评测与通信服务 |
| `:FOJ run` | **核心**：执行保存、编译并运行本地测试用例 |
| `:FOJ test` | 仅运行本地测试（跳过编译步骤） |
| `:FOJ submit` | 自动将当前代码通过 WebSocket 发送至浏览器插件提交 |
| `:FOJ show` | 打开/切换本地判题结果 UI |
| `:FOJ edit` | 进入测试用例编辑模式，支持增删改 |
| `:FOJ solve` | 将题目标记为已解决，自动移动文件至 `solve_dir` |
| `:FOJ solve back` | 撤销已解决标记，回退题目数据 |
| `:FOJ erase` | 物理删除当前题目的所有本地缓存数据 |
| `:FOJ find [type]` | 快速浏览：`template`(模板) / `problem`(题目) / `json`(数据) |

---

# ⚙️ 配置参数详解 (`opts`)

## 1. 基础与路径配置

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `work_dir` | string | `""` | 插件的工作目录 |
| `json_dir` | string | `".problem"` | 题目元数据存储目录 |
| `solve_dir` | string | `".solve"` | 已解决题目存储目录 |
| `template_dir` | string | `""` | 模板文件存储目录 |
| `auto_open` | boolean | `true` | 接收题目后是否自动打开代码文件 |

## 2. 服务器与评测

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `server_mod` | string | `"all"` | 启动模式：`http`, `ws`, 或 `all` |
| `max_workers` | integer | `5` | 最大并发评测线程数 |
| `obscure` | boolean | `true` | 是否启用词法模糊匹配（忽略多余空格/空行） |
| `max_time_out` | integer | `5` | 浏览器连接的最大等待时间 (s) |
| `debug` | boolean | `false` | 是否开启调试模式 |

## 3. 命令表配置 (核心自定义)

这两项决定了插件如何处理不同语言的评测。

* **`compile_command`**：编译命令配置表。
* **说明**：每个命令包含 `exec` (执行程序) 和 `args` (参数列表)，支持变量。

* **`run_command`**：运行命令配置表。
* **说明**：定义评测时如何执行编译后的二进制文件或脚本（如 `python3`, `node` 等）。

### 最小化示例

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

# ⌨️ 推荐快捷键

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 基础控制
map("n", "<leader>cda", ":FOJ<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 开始刷题" }))
map("n", "<leader>cdq", ":FOJ stop<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 停止刷题" }))
map("n", "<leader>cdr", ":FOJ submit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 提交代码" }))

-- 评测与 UI
map("n", "<leader>cdt", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 编译并评测" }))
map("n", "<leader>cdT", ":FOJ test<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 仅评测 (不编译)" }))
map("n", "<leader>cdu", ":FOJ show<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 判题 UI 开关" }))
map("n", "<leader>cde", ":FOJ edit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 编辑测试案例" }))

-- 数据管理
map("n", "<leader>cds", ":FOJ solve<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 标记题目已解决" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 撤销解决标记" }))
map("n", "<leader>cdd", ":FOJ erase<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 删除题目数据" }))

-- 快速浏览 (查找器)
map("n", "<leader>cdc", ":FOJ find template<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 查找模板文件" }))
map("n", "<leader>cdp", ":FOJ find problem<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 查找历史题目" }))
map("n", "<leader>cdj", ":FOJ find json<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: 查找题目数据" }))

```

---

# 📊 平台与语言支持

* **全平台适配**：Windows, Linux, macOS 均提供完整功能支持。
* **多语言内置**：
* **编译型**：C, C++, C#, Rust, Go, Java, Kotlin, Pascal, Swift, Zig.
* **脚本型**：Python, JavaScript (Node), TypeScript (ts-node), Lua.

希望 **Faster-OJ.nvim** 能让你的算法竞赛之旅更加高效。如有问题或建议，欢迎提交 Issue 或 PR！
