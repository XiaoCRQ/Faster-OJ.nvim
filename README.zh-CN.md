# Faster-OJ.nvim

<div align="center">

![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/test.png)
![image](https://raw.githubusercontent.com/XiaoCRQ/faster-oj.nvim/main/img/edit.png)

<p>⚡ 在 Neovim 中构建完整的算法竞赛自动化工作流。</p>

[README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

</div>

**Faster-OJ.nvim** 是一款专为**算法竞赛**设计的 Neovim 插件，整合题目抓取、本地评测、对拍测试与自动化提交。

---

## ✨ 核心特性

- **全自动工作流**：配合 [Competitive Companion](https://github.com/jmerle/competitive-companion) 抓题，利用 [Faster-OJ 浏览器插件](https://github.com/XiaoCRQ/Faster-OJ) 一键提交。
- **本地评测**：并发执行测试用例，时间/内存测量。词法模糊匹配 (`obscure`) 与内存偏移补偿。
- **对拍测试**：两份代码同输入对比输出，快速定位边界情况。
- **多面板 UI**：判题结果查看、测试用例实时编辑、对拍结果展示。
- **智能查找器**：集成 `snacks.nvim`、`telescope.nvim`、`fzf-lua`、`mini.pick` 及 `vim.ui.select`。
- **健壮引号支持**：对拍参数支持三种引用风格 — `"..."`、`'...'` 及 C++ 原始字符串 `R"(...)"` — 处理含空格和特殊字符的路径。

---

## 🚀 推荐工作流

1. **启动服务** — `:FOJ` 启动 HTTP + WebSocket 服务器
2. **抓取题目** — 在浏览器中点击题目链接，[Competitive Companion](https://github.com/jmerle/competitive-companion) 插件会将题目发送至 Neovim，自动在 `work_dir` 下创建源文件和测试数据
3. **编写解答** — 编辑生成的源文件
4. **本地评测** — `<leader>cdt` 编译并运行所有测试用例，结果展示在多面板 UI 中，支持逐行/逐 token 对比
5. **对拍测试（可选）** — `<leader>cdP` 交互选取两份代码，或直接指定路径：`:FOJ stress correct=path:"brute.cpp" test=path:"solve.cpp"`
6. **提交** — `<leader>cdr` 通过 WebSocket 经浏览器插件提交代码

---

## 📦 安装

### 依赖

- **Neovim** >= 0.9
- **浏览器插件**：
  - [Competitive Companion](https://github.com/jmerle/competitive-companion) — 接收题目
  - [Faster-OJ 浏览器插件](https://github.com/XiaoCRQ/Faster-OJ) — 提交代码
- **语言工具链**（按需：gcc/g++、python3、node 等）

### 最小配置 (lazy.nvim)

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

### 推荐配置

仅展示非默认覆盖项。

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

如需自定义编译/运行命令，覆盖 `compile_command` / `run_command` 即可。

---

## ⌨️ 推荐快捷键

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 服务
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

-- 查找器
map("n", "<leader>cdc", ":FOJ find template<CR>", vim.tbl_extend("force", opts, { desc = "FOJ: Find templates" }))
map("n", "<leader>cdp", ":FOJ find problem<CR>",  vim.tbl_extend("force", opts, { desc = "FOJ: Find problem files" }))
map("n", "<leader>cdj", ":FOJ find data<CR>",     vim.tbl_extend("force", opts, { desc = "FOJ: Find problem data" }))

-- 对拍
map("n", "<leader>cdP", ":FOJ stress correct=find: test=find:<CR>",
    vim.tbl_extend("force", opts, { desc = "FOJ: Stress test (对拍)" }))
```

---

## 🛠 命令参考

### 服务

| 命令 | 说明 |
| --- | --- |
| `:FOJ` | 启动 HTTP + WebSocket 服务（先切换到 `work_dir`） |
| `:FOJ start [mod]` | 启动指定模式: `all` / `http` / `ws` |
| `:FOJ stop [mod]` | 停止服务 |

### 评测

| 命令 | 说明 |
| --- | --- |
| `:FOJ run` | 保存、编译并运行全部测试用例 |
| `:FOJ test` | 运行测试用例（跳过编译） |
| `:FOJ show` | 切换判题结果 UI |
| `:FOJ edit` | 切换测试用例编辑器（增删改） |

### 提交

| 命令 | 说明 |
| --- | --- |
| `:FOJ submit` | 通过 WebSocket 将代码发送至浏览器插件提交 |

### 题目管理

| 命令 | 说明 |
| --- | --- |
| `:FOJ solve` | 标记已解决，移动至 `solve_dir` |
| `:FOJ solve back` | 撤销上次 solve，还原文件 |
| `:FOJ erase` | 删除题目源码及数据目录 |

### 查找器

| 命令 | 说明 |
| --- | --- |
| `:FOJ find template` | 浏览 `template_dir` 中的模板 |
| `:FOJ find problem` | 浏览 `work_dir` 中的题目源码 |
| `:FOJ find data` | 浏览 `data_dir` 中的题目数据 |

### 对拍测试

| 命令 | 说明 |
| --- | --- |
| `:FOJ stress` | 重跑上次对拍 |
| `:FOJ stress correct=type:val test=type:val [data=type:val] [time=N] [mem=N]` | 启动对拍 |

**参数：**

| 参数 | 格式 | 说明 |
| --- | --- | --- |
| `correct` | `path:FILE` 或 `find:DIR` | 标准程序 |
| `test` | `path:FILE` 或 `find:DIR` | 待测程序 |
| `data` | `path:P1\nP2` / `find:DIR` / `data:RAW` | 数据来源（可选：自动从 correct/test 题目目录加载） |
| `time` | 整数 (ms) | 时间限制（默认: `default_time_limit`） |
| `mem` | 整数 (MB) | 内存限制（默认: `default_memory_limit`） |

参数值支持三种引用风格，用于包含空格或特殊字符的路径：
- 双引号 `"..."` — 单引号 `'...'` — C++ 原始字符串 `R"(...)"` / `R"delim(...)delim"`

**示例：**

```vim
" 交互选取两个文件（数据自动从题目目录加载）
:FOJ stress correct=find: test=find:

" 直接指定路径
:FOJ stress correct=path:brute.py test=path:solve.cpp

" 路径含空格（使用引号）
:FOJ stress correct=path:"my brute.cpp" test=path:'solve.cpp'

" C++ 原始字符串引用
:FOJ stress correct=path:R"(brute.cpp)" test=path:R"(solve.cpp)"

" 含原始数据和时限/内存限制
:FOJ stress correct=path:a.cpp test=path:b.cpp data=data:5\n1 2 3 time=1000 mem=512
```

---

## ⚙️ 配置参数详解

### 路径

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `work_dir` | string | `vim.fn.stdpath("data") .. "/faster-oj"` | 工作目录 |
| `data_dir` | string | `".problem"` | 题目数据目录（相对 `work_dir`） |
| `solve_dir` | string | `".solve"` | 已解决题目归档（相对 `work_dir`） |
| `temp_dir` | string | `".temp"` | 临时文件目录（相对 `work_dir`） |
| `template_dir` | string | `""` | 模板目录 |
| `template_default` | string | `""` | 默认模板文件 |
| `template_default_ext` | string | `".cpp"` | 默认语言扩展名 |
| `auto_open` | boolean | `true` | 接收题目后自动打开文件 |

### 服务器

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `http_host` | string | `"127.0.0.1"` | HTTP 绑定地址 |
| `http_port` | integer | `10043` | HTTP 端口 |
| `ws_host` | string | `"127.0.0.1"` | WebSocket 绑定地址 |
| `ws_port` | integer | `10044` | WebSocket 端口 |
| `server_mod` | string | `"all"` | 启动模式: `http` / `ws` / `all` |
| `max_time_out` | integer | `5` | 浏览器连接超时 (s) |

### 评测

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `max_workers` | integer | `5` | 最大并发数 |
| `obscure` | boolean | `true` | 词法模糊匹配 |
| `warning_msg` | boolean | `false` | 结果显示编译警告 |
| `clipboard_submit` | boolean | `false` | 提交时复制代码到剪切板 |
| `default_time_limit` | integer | `2000` | 默认时间限制 (ms) |
| `default_memory_limit` | integer | `256` | 默认内存限制 (MB) |
| `linux_mem_offset` | integer | `-2900` | Linux 内存偏移 (KB) |
| `macos_mem_offset` | integer | `-1500` | macOS 内存偏移 (KB) |
| `max_solve_history` | integer | `100` | solve 历史上限 |
| `debug` | boolean | `false` | 调试日志 |

### 变量占位符

命令支持 `$(VAR)` / `@VAR` / `%VAR%`：

| 变量 | 展开为 |
| --- | --- |
| `$(FNAME)` | 完整文件名 (`123A.cpp`) |
| `$(FNOEXT)` | 无扩展名 (`123A`) |
| `$(FABSPATH)` | 源文件绝对路径 |
| `$(DIR)` | 源文件所在目录 |

### 编译与运行命令

按扩展名索引的命令表，每项含 `exec` + 可选 `args`。

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

### UI 布局

- **`tc_ui`** — 判题结果（用例列表、输入、输出、信息、预期输出）
- **`tc_edit_ui`** — 测试用例编辑器（用例列表、输入、输出）
- **`stress_ui`** — 对拍结果查看器

每项含 `width`、`height`、`layout`（递归树结构）和 `mappings`。

### 高亮

```lua
highlights = {
  windows = { Header = "#c0c0c0", Correct = "#00ff00", Warning = "orange", Wrong = "red" },
  stdio   = { Header = "#c0c0c0", Correct = "#00ff00", Warning = "orange", Wrong = "orange" },
},
```

### 代码混淆器

可选：提交前预处理代码（请慎用）。

```lua
code_obfuscator = {
  result = ".obfuscator/$(FNAME)",
  cmd = { exec = "obfuscator_cpp", args = { "$(FABSPATH)", ".obfuscator/$(FNAME)" } },
},
```

---

## 📊 平台与语言支持

- **全平台**：Windows, Linux, macOS。
- **编译型**：C, C++, Rust, Go, Java, Kotlin, C#, Pascal, Swift, Zig。
- **脚本型**：Python, JavaScript (Node), TypeScript (ts-node), Lua。

---

如有问题或建议，欢迎提交 [Issue](https://github.com/XiaoCRQ/Faster-OJ.nvim/issues) 或 PR！
