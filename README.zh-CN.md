# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ 在 Neovim 中构建完整的算法竞赛自动化工作流。</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

**Faster-OJ.nvim** 是一款专为**算法竞赛**（Competitive Programming）设计的 Neovim 插件。通过整合题目抓取、本地评测与自动化提交，它旨在为你提供一个**零干扰的沉浸式刷题环境**。

---

## ✨ 核心特性

- **全自动工作流**：配合 [Competitive Companion](https://github.com/jmerle/competitive-companion) 抓题，利用 [Faster-OJ 浏览器插件](https://github.com/XiaoCRQ/Faster-OJ) 一键提交，告别手动复制粘贴。
- **双引擎服务架构**：内置 **HTTP** 服务器接收题目数据，**WebSocket** 服务器与浏览器插件通信完成提交。
- **高性能本地评测**：并发执行测试用例 (`max_workers`)，平台感知的时间/内存测量。支持**词法模糊匹配** (`obscure`) 和系统内存偏移补偿。
- **多面板 UI 系统**：判题结果查看器、实时文件同步的测试用例编辑器、对拍测试 UI。
- **对拍测试 (Stress Test)**：用两份代码对相同输入运行并对比输出，快速定位优化代码的边界情况。
- **智能查找器**：深度集成 `snacks.nvim`、`telescope.nvim`、`fzf-lua`、`mini.pick` 及内置 `vim.ui.select`。

---

## 📦 安装

### 依赖

- **Neovim** >= 0.9（需要 libuv 事件循环）
- **浏览器插件**：
  - [Competitive Companion](https://github.com/jmerle/competitive-companion) — 用于接收题目
  - [Faster-OJ 浏览器插件](https://github.com/XiaoCRQ/Faster-OJ) — 用于提交代码
- **对应语言工具链**（按需安装：gcc/g++、python3、node 等）

### 最小配置 (lazy.nvim)

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

### 推荐配置

仅展示非默认覆盖项，其余字段使用内置默认值。

```lua
local code_path = vim.fn.expand("~/Work/Program/CodeForces")

{
  "xiaocrq/faster-oj.nvim",
  opts = {
    -- 判题时显示编译警告
    warning_msg = true,
    -- 路径配置
    work_dir = code_path,
    temp_dir = code_path .. "/.temp",
    json_dir = code_path .. "/.problem",
    solve_dir = code_path .. "/.solve",
    template_dir = code_path .. "/.template",
    template_default = code_path .. "/.template/template.cpp",
  },
}
```

如需自定义编译/运行命令，覆盖 `compile_command` / `run_command` 即可（参见[配置参数详解](#-配置参数详解)）。

---

## ⌨️ 推荐快捷键

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 服务控制
map("n", "<leader>cda", ":FOJ<CR>",              vim.tbl_extend("force", opts, { desc = "FOJ: Start services" }))
map("n", "<leader>cdq", ":FOJ stop<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Stop services" }))
map("n", "<leader>cdr", ":FOJ submit<CR>",       vim.tbl_extend("force", opts, { desc = "FOJ: Submit solution" }))

-- 评测与 UI
map("n", "<leader>cdt", ":FOJ run<CR>",          vim.tbl_extend("force", opts, { desc = "FOJ: Compile and judge" }))
map("n", "<leader>cdT", ":FOJ test<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Judge only (skip compile)" }))
map("n", "<leader>cdu", ":FOJ show<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Toggle judge UI" }))
map("n", "<leader>cde", ":FOJ edit<CR>",         vim.tbl_extend("force", opts, { desc = "FOJ: Edit test cases" }))

-- 数据管理
map("n", "<leader>cds", ":FOJ solve<CR>",        vim.tbl_extend("force", opts, { desc = "FOJ: Mark as solved" }))
map("n", "<leader>cdS", ":FOJ solve back<CR>",   vim.tbl_extend("force", opts, { desc = "FOJ: Undo solved mark" }))
map("n", "<leader>cdd", ":FOJ erase<CR>",        vim.tbl_extend("force", opts, { desc = "FOJ: Delete problem data" }))

-- 快速浏览
map("n", "<leader>cdc", ":FOJ find template<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Find templates" }))
map("n", "<leader>cdp", ":FOJ find problem<CR>",  vim.tbl_extend("force", opts, { desc = "FOJ: Find problem files" }))
map("n", "<leader>cdj", ":FOJ find data<CR>",     vim.tbl_extend("force", opts, { desc = "FOJ: Find problem data" }))

-- 对拍
map("n", "<leader>cdP", ":FOJ stress correct=find: test=find:<CR>",
    vim.tbl_extend("force", opts, { desc = "FOJ: Stress test (对拍)" }))
```

---

## 🛠 命令参考

### 服务控制

| 命令 | 说明 |
| --- | --- |
| `:FOJ` | 启动 HTTP + WebSocket 服务（先切换到 `work_dir`） |
| `:FOJ start [mod]` | 启动指定模式: `all` / `http` / `ws` |
| `:FOJ stop [mod]` | 停止服务 |

### 评测与测试

| 命令 | 说明 |
| --- | --- |
| `:FOJ run` | 保存、编译并运行全部测试用例，展示 UI |
| `:FOJ test` | 运行测试用例（跳过编译） |
| `:FOJ show` | 切换判题结果 UI |
| `:FOJ edit` | 切换测试用例编辑器（支持增删改） |

### 提交

| 命令 | 说明 |
| --- | --- |
| `:FOJ submit` | 通过 WebSocket 将当前代码发送至浏览器插件提交 |

### 题目管理

| 命令 | 说明 |
| --- | --- |
| `:FOJ solve` | 将题目标记为已解决，移动文件至 `solve_dir` |
| `:FOJ solve back` | 撤销上次 solve，还原题目文件 |
| `:FOJ erase` | 删除当前题目源码及题目数据目录 |

### 查找器

| 命令 | 说明 |
| --- | --- |
| `:FOJ find template` | 浏览 `template_dir` 中的模板文件 |
| `:FOJ find problem` | 浏览 `work_dir` 中的题目源码 |
| `:FOJ find data` | 浏览 `json_dir` 中的题目数据目录 |

### 对拍测试 (Stress Test)

| 命令 | 说明 |
| --- | --- |
| `:FOJ stress` | 重新运行上次对拍 |
| `:FOJ stress correct=type:val test=type:val [data=type:val] [time=N] [mem=N]` | 启动对拍 |

**参数说明：**

| 参数 | 格式 | 说明 |
| --- | --- | --- |
| `correct` | `path:FILE` 或 `find:` | 标准程序（正确代码） |
| `test` | `path:FILE` 或 `find:` | 待测程序（被对拍代码） |
| `data` | `path:P1\nP2` / `find:` / `data:RAW` | 数据来源（可省略，默认空输入） |
| `time` | 整数 (ms) | 单次运行时间限制（默认: `default_time_limit`） |
| `mem` | 整数 (MB) | 单次运行内存限制（默认: `default_memory_limit`） |

**使用示例：**
```vim
" 通过选择器选取两个文件
:FOJ stress correct=find: test=find:

" 直接指定路径，支持不同语言
:FOJ stress correct=path:brute.py test=path:solve.cpp

" 含原始数据和限制
:FOJ stress correct=path:a.cpp test=path:b.cpp data=data:5\n1 2 3\n4 5 6 time=1000 mem=128
```

---

## ⚙️ 配置参数详解

### 路径与基础

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `work_dir` | string | `""` | 工作目录 |
| `temp_dir` | string | `".temp"` | 临时文件目录（对拍数据、提交临时文件等） |
| `json_dir` | string | `".problem"` | 题目数据存储目录 |
| `solve_dir` | string | `".solve"` | 已解决题目归档目录 |
| `template_dir` | string | `""` | 模板文件目录 |
| `template_default` | string | `""` | 默认模板文件路径 |
| `template_default_ext` | string | `".cpp"` | 默认语言扩展名 |
| `auto_open` | boolean | `true` | 接收题目后自动打开代码文件 |

### 服务器与评测

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `http_host` | string | `"127.0.0.1"` | HTTP 服务器绑定地址 |
| `http_port` | integer | `10043` | HTTP 服务器端口 |
| `ws_host` | string | `"127.0.0.1"` | WebSocket 服务器绑定地址 |
| `ws_port` | integer | `10044` | WebSocket 服务器端口 |
| `server_mod` | string | `"all"` | 启动模式: `http` / `ws` / `all` |
| `max_time_out` | integer | `5` | 浏览器连接超时（秒） |
| `max_workers` | integer | `5` | 最大并发评测数 |
| `max_solve_history` | integer | `100` | solve 历史最大条目数 |
| `debug` | boolean | `false` | 是否开启调试日志 |

### 评测行为

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `obscure` | boolean | `true` | 词法模糊匹配（忽略多余空白字符） |
| `warning_msg` | boolean | `false` | 判题时显示编译警告 |
| `default_time_limit` | integer | `2000` | 默认时间限制 (ms) |
| `default_memory_limit` | integer | `256` | 默认内存限制 (MB) |
| `linux_mem_offset` | integer | `-2900` | Linux 内存测量偏移 (KB) |
| `macos_mem_offset` | integer | `-1500` | macOS 内存测量偏移 (KB) |

### 变量占位符

编译/运行命令中支持 `$(VAR)` / `@VAR` / `%VAR%` 占位符：

| 变量 | 展开为 |
| --- | --- |
| `$(FNAME)` | 完整文件名（如 `123A.cpp`） |
| `$(FNOEXT)` | 无扩展名文件名（如 `123A`） |
| `$(FABSPATH)` | 源文件绝对路径 |
| `$(DIR)` | 源文件所在目录 |

### 编译与运行命令

`compile_command` 和 `run_command` 是按扩展名索引的命令表。每项包含 `exec`（可执行程序）和可选的 `args`（参数列表）。

```lua
-- 示例: 自定义 C++ 配置
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

### UI 布局

三套 UI 配置控制浮动窗口布局：

- **`tc_ui`** — 判题结果查看器（用例列表、输入、输出、信息、预期输出）
- **`tc_edit_ui`** — 测试用例编辑器（用例列表、输入、输出）
- **`stress_ui`** — 对拍结果查看器（布局同 tc_ui）

每项含 `width`、`height`、`layout`（递归 `{权重, 内容}` 树结构）和 `mappings`。

### 高亮

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

### 代码混淆器

可选功能：提交前对代码进行预处理（请慎用，不保证 OJ 平台允许此行为）。

```lua
code_obfuscator = {
  result = ".obfuscator/$(FNAME)",
  cmd = { exec = "obfuscator_cpp", args = { "$(FABSPATH)", ".obfuscator/$(FNAME)" } },
},
```

---

## 🔄 推荐工作流

```
浏览器 (Competitive Companion)  ➔  Neovim (Faster-OJ.nvim)  ➔  本地评测
                                                                     ↓
在线判题平台  ⬅  浏览器插件 (Faster-OJ)  ⬅  提交命令
```

1. **抓取**：浏览器点击插件，题目数据自动同步至 Neovim。
2. **编码**：编写代码，模板文件自动创建。
3. **测试**：执行 `:FOJ run` 编译并并发运行全部测试用例。
4. **提交**：本地全部通过后执行 `:FOJ submit`，浏览器插件自动完成提交。

### 题目数据存储格式

```
.problem/
└── ProblemName/
    ├── problem.json    # { url, name, testCount, memoryLimit, timeLimit }
    ├── 0.in / 0.out
    ├── 1.in / 1.out
    └── ...
```

---

## 📊 平台与语言支持

- **全平台适配**：Windows、Linux、macOS 均提供平台感知的时间/内存测量。
  - Linux: `timeout` + `/usr/bin/time -v` 硬墙钟限制 + RSS 内存测量
  - macOS: `/usr/bin/time -l` + uv timer 后备超时
  - Windows: PowerShell `Start-Process` + `PeakWorkingSet64`
- **内置语言支持**：
  - **编译型**：C, C++, Rust, Go, Java, Kotlin, C#, Pascal, Swift, Zig
  - **脚本型**：Python, JavaScript (Node), TypeScript (ts-node), Lua

---

如有问题或建议，欢迎提交 [Issue](https://github.com/XiaoCRQ/Faster-OJ.nvim/issues) 或 PR！
