# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ 在 Neovim 中构建完整的算法竞赛自动化工作流。</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

---

**Faster-OJ.nvim** 是一款面向算法竞赛（Competitive Programming）的 Neovim 插件。

它将：

* 📥 题目抓取
* 🧪 本地判题
* 🌐 浏览器自动提交
* 🖥 WebSocket 本地服务
* 🧩 多语言编译运行

整合为一个完整闭环，实现真正的：

> ✨ 写完 → 本地验证 → 一键提交 → 等待 AC

---

# ✨ 核心特性

## 🚀 一键接收 + 提交

1. 由 Neovim 接受从浏览发送的题目数据
2. 由 Neovim 将代码发送至浏览器插件完成 OJ 提交

配合浏览器插件：

* [Competitive Companion](https://github.com/jmerle/competitive-companion) —— 题目接收
* [Faster-OJ](https://github.com/XiaoCRQ/Faster-OJ) —— 自动提交

---

## 🖥 内置本地判题服务（HTTP + WebSocket）

插件自带：

* HTTP 服务
* WebSocket 服务
* 浏览器自动连接
* 可单独启动或组合启动（`http` / `ws` / `all`）

默认端口：

```
HTTP: 127.0.0.1:10043
WS:   127.0.0.1:10044
```

支持浏览器连接超时控制、调试模式、并发控制。

---

## 🧪 高性能本地测试系统

* 支持多语言自动编译运行
* 支持最大并发测题 (`max_workers`)
* 支持逐行匹配 / 词法模糊匹配
* 可选显示编译 warning
* UI 实时更新测试状态
* 支持重新打开历史结果（带缓存）

---

## 🧩 多语言支持

内置编译与运行配置：

### 编译型语言

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

### 脚本语言

* Python
* JavaScript (Node)
* TypeScript (ts-node)
* Lua

### 语言配置

示例配置

```lua
compile_command = { -- 脚本语言默认为空
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

## 🧠 内置代码混淆支持（可选）

支持自定义 `code_obfuscator`。

⚠ 注意：

* 仅当混淆器可运行且成功读取结果时自动替换代码
* 不保证所有 OJ 平台允许该行为
* 默认关闭

---

## 🪟 双 UI 系统

### 判题 UI (`tc_ui`)

支持：

* 多窗口布局
* 可视化测试结果
* 标准输入输出对比
* 预期输出对比
* 错误信息展示
* 自定义快捷键
* 自定义高亮颜色

### 测试用例管理 UI (`tc_edit_ui`)

支持：

* 添加测试
* 编辑测试
* 删除测试
* 实时保存
* 多窗口布局

---

# 🔄 推荐工作流

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

流程说明：

1. 浏览器通过 Competitive Companion 抓题
2. 自动传入 Neovim
3. 本地开发 + `:FOJ run`
4. 一键 `:FOJ submit`
5. 浏览器自动完成提交

---

# 📦 安装

## 环境依赖

* Neovim (推荐最新稳定版)
* 浏览器插件：

  * [Competitive Companion](https://github.com/jmerle/competitive-companion) —— 题目接收
  * [Faster-OJ](https://github.com/XiaoCRQ/Faster-OJ) —— 自动提交

---

## 使用 lazy.nvim 安装

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

---

# ⚙️ 配置说明

完整默认配置位于：

```
lua/faster-oj/default.lua
```

---

## 服务器相关

| 选项             | 默认值           | 说明                         |
| -------------- | ------------- | -------------------------- |
| `http_host`    | `"127.0.0.1"` | HTTP 服务地址                  |
| `http_port`    | `10043`       | HTTP 端口                    |
| `ws_host`      | `"127.0.0.1"` | WebSocket 地址               |
| `ws_port`      | `10044`       | WebSocket 端口               |
| `server_mod`   | `"all"`       | 启动模式：`http` / `ws` / `all` |
| `max_time_out` | `5`           | 浏览器连接超时时间                  |
| `debug`        | `false`       | Debug 模式                   |

---

## 工作目录相关

| 选项                     | 默认值        | 说明       |
| ---------------------- | ---------- | -------- |
| `work_dir`             | `""`       | 工作目录     |
| `json_dir`             | `.problem` | 题目数据目录   |
| `solve_dir`            | `.solve`   | 已解决目录    |
| `template_dir`         | `""`       | 模板目录     |
| `template_default`     | `""`       | 默认模板     |
| `template_default_ext` | `.cpp`     | 默认扩展名    |
| `open_new`             | `true`     | 是否自动打开新题 |

---

## 判题相关

| 选项                 | 默认值     | 说明         |
| ------------------ | ------- | ---------- |
| `obscure`          | `true`  | 词法模式判题     |
| `warning_msg`      | `false` | 显示 warning |
| `max_workers`      | `5`     | 最大并发数      |
| `linux_mem_offset` | -2900   | Linux 内存偏移 |
| `macos_mem_offset` | -1500   | macOS 内存偏移 |

---

## UI 自定义

支持：

* 自定义窗口比例
* 自定义布局树结构
* 自定义快捷键
* 自定义高亮颜色

高亮示例：

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

# 🛠 常用命令

| 命令                         | 说明      |
| -------------------------- | ------- |
| `:FOJ`                     | 启动完整服务  |
| `:FOJ start [all/http/ws]` | 启动指定服务  |
| `:FOJ stop`                | 停止服务    |
| `:FOJ run`                 | 编译并运行测试 |
| `:FOJ test`                | 仅测试     |
| `:FOJ submit`              | 自动提交    |
| `:FOJ show`                | 打开判题 UI |
| `:FOJ close`               | 关闭 UI   |
| `:FOJ edit`                | 编辑测试    |
| `:FOJ erase`               | 删除问题数据  |
| `:FOJ solve`               | 标记已解决   |
| `:FOJ solve back`          | 撤销已解决   |

---

# ⌨ 推荐快捷键

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map("n", "<leader>cda", ":FOJ <CR>", vim.tbl_extend("force", opts, { desc = "FOJ：开始刷题" }))
map("n", "<leader>cdq", ":FOJ stop<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：停止刷题" }))
map("n", "<leader>cdr", ":FOJ submit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：提交" }))
map("n", "<leader>cdt", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：判题" }))
map("n", "<leader>cdT", ":FOJ run<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：判题(不编译)" }))
map("n", "<leader>cdu", ":FOJ show<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：UI开关" }))
map("n", "<leader>cds", ":FOJ solve<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：问题已解决" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：撤销解决问题" }))
map("n", "<leader>cde", ":FOJ edit<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：编辑案例" }))
map("n", "<leader>cdd", ":FOJ erase<CR>", vim.tbl_extend("force", opts, { desc = "FOJ：删除问题数据" }))
```

---

# 📊 平台支持

| 功能    | Windows | Linux | macOS |
| ----- | ------- | ----- | ----- |
| 题目接收  | ✅       | ✅     | ✅     |
| 本地测试  | ✅       | ✅     | ✅     |
| 编辑案例  | ✅       | ✅     | ✅     |
| 问题管理  | ✅       | ✅     | ✅     |
| 自动提交  | ✅       | ✅     | ✅     |
| 多语言支持 | ✅       | ✅     | ✅     |

---

# 🎯 设计目标

* 极致自动化
* 零复制粘贴
* 最小思维打断
* 强扩展性
* 高并发本地测试
* 面向竞赛环境优化

---

如果你追求：

* 🚀 极限刷题效率
* 🧠 Neovim 原生体验
* 🔥 真正的一键 AC 工作流

那么 **Faster-OJ.nvim** 将成为你的主力竞赛工具。
