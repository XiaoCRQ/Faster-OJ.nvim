# AGENTS.md

本文件为在本仓库中工作的 AI 编码代理（pi）提供指导。

**本文件（AGENTS.md）使用中文编写。** 与用户对话时使用中文；代码、命令、路径、日志、变量名等技术标识一律保持原样，不做翻译。英文版本见 `CLAUDE.md`（供 Claude Code 使用，内容强制为英文）。

## 项目概览

Faster-OJ.nvim 是一个跨平台（Windows/Linux/macOS）的 Neovim 插件，用于竞赛编程（Competitive Programming）自动化。它通过内置 HTTP 服务器接收来自 [Competitive Companion](https://github.com/jmerle/competitive-companion) 的题目数据，使用 libuv 异步并发地在本地评测，并通过 WebSocket 桥接把代码提交到 [Faster-OJ 浏览器扩展](https://github.com/XiaoCRQ/Faster-OJ)。

没有构建步骤、没有测试套件、没有 CI。这是一个纯 Lua 插件，通过 lazy.nvim 分发。最低支持的 Neovim 版本：0.9。

## 目录结构

```
lua/faster-oj/
├── init.lua                # 入口：setup()、:FOJ 用户命令、服务器操作
├── default.lua             # 完整默认配置，带 emmylua 类型注解
├── server/
│   ├── http/
│   │   ├── server.lua      # 原生 TCP 服务器（uv.new_tcp），接收浏览器发来的 JSON
│   │   └── handler.lua     # 写题目目录：problem.json + N.in/N.out 文件
│   └── websocket/
│       └── server.lua      # 启动 mini-wsbroad 二进制，管理 WS 生命周期
└── module/
    ├── init.lua            # 编排层：run/test/submit/edit/delete/find/stress
    ├── run.lua             # 编译（uv.spawn）+ 并发评测池 + M.run_single()
    ├── stress.lua          # 对拍：成对执行，数据源支持 picker/文件/裸数据
    ├── submit.lua          # WS 提交 + 可选代码混淆器
    ├── archive.lua         # 题目归档，基于路径对的历史记录（.history 文件）
    ├── notify.lua          # 单窗口浮层通知 + spinner 动画
    ├── utils.lua           # 文件 I/O、JSON 读写、变量展开、测试点辅助函数
    └── ui/
        ├── init.lua        # 布局引擎 —— 基于权重的递归矩形计算
        ├── tc_view.lua     # 测试点列表共用的光标/键位/生命周期辅助
        ├── tests.lua       # 评测结果查看器（测试点列表 + 详情面板）
        ├── tests_edit.lua  # 测试点编辑器：同一时间只打开一个，内存内编辑，显式保存
        ├── confirm.lua     # 浮层选择对话框（是/否/取消；删除场景为是/否）
        └── stress.lua      # 对拍结果查看器
```

## 关键模式与约定

### 异步：所有 I/O 使用 libuv
使用 `vim.uv`（或回退到 `vim.loop`）。不引入外部 job 库。编译与测试执行使用 `uv.spawn`。在 libuv 回调中被调用的 UI 操作需用 `vim.schedule()` 延迟。

### Fast event 上下文限制
Neovim API 函数（`vim.fn.mkdir`、`nvim_buf_get_name` 等）**禁止**在 libuv 回调中调用。回调内的文件系统操作请使用 `os.execute()`。Neovim API 调用请用 `vim.schedule()` 延迟。像 `utils.get_current_problem_dir()` 这类会读取当前缓冲区的函数只能从主上下文调用；异步上下文中请显式传入路径（如 `utils.get_problem_dir(file_path)`）。

### 配置：与默认值深度合并
`vim.tbl_deep_extend("force", defaults, user_opts)` —— 用户配置优先。`compile_command` / `run_command` 的键是**文件扩展名**（如 `py`、`js`、`rs`、`kt`、`pas`），不是语言名。配置字段为 `data_dir`（旧名 `json_dir`）。

### UI：自定义布局引擎
配置中定义递归的 `{weight, content}` 树。`calculate_rects()` 计算绝对坐标；`ui.open()` 创建/移动带圆角边框的浮窗。在 `VimResized` 时，引擎会关闭并重开实例；查看器在 on-created 回调中恢复自身状态。所有 UI 模块渲染都使用 `vim.schedule()`。

测试点列表光标策略（`ui/tc_view.lua`）：测试点列表类查看器（`tests.lua`、`tests_edit.lua`、`stress.lua`）把列表光标固定在列 5，并由各自的键位映射同步驱动行切换（`focus_row()` + 直接回调）。缓冲区局部的 `CursorMoved` 自动命令仅作为原生/鼠标移动的兜底 —— `nvim_win_set_cursor` 不保证会同步触发 `CursorMoved`，因此刷新逻辑绝不能依赖它。`tc_view.attach()` 同时负责 `BufWinLeave` 的拆解钩子，并通过比较引擎实例身份来忽略过期的回调。

### 日志：统一格式
所有模块使用：`log(level, func, msg)` → `[FOJ][<module>][LEVEL] func: msg`。级别：INFO、WARN、ERROR。仅当 `config.debug == true` 时输出。所有运行期字符串使用英文。

### 通知：单窗口
`notify.lua` 提供 `notify.show(msg, level, duration)`、`notify.spinner_start/update/done/fail(msg)`。顶部居中的单个浮窗，新内容会替换旧内容。spinner 使用 Unicode 盲文字符 `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`，间隔 80ms。

### 确认：浮层选择对话框
所有确认提示都使用 `module/ui/confirm.lua`（`confirm.open`），而不是 `vim.fn.confirm`。对话框是异步的（基于回调）、单实例，并把光标锁定在第一个选项的按键字母上。默认选项为 是/否/取消；破坏性操作使用 是/否，且默认选中「否」。当无法打开对话框（无 UI）时，调用方必须选择安全默认值（中止破坏性操作）。

### 并发评测
`run.lua:fill_queue()` 维持活跃 worker 数不超过 `max_workers`（默认 5）。每完成一个，fill_queue 递归启动下一个。

### 输出比对
由配置项 `obscure` 控制两种模式：
- **Token 模式**（`obscure=true`）：词法分析 —— 提取非空白 token 及其坐标，逐 token 比对
- **行模式**（`obscure=false`）：逐行精确匹配，定位第一个不同字符

### 平台执行
- **Linux**：`timeout -s 9 <tl>`（硬性挂钟上限）+ `/usr/bin/time -v`（RSS 内存）。若 `/usr/bin/time` 缺失则回退。
- **macOS**：`/usr/bin/time -l`（内存）+ uv 定时器（超时）。系统无原生 `timeout` 命令。
- **Windows**：PowerShell `Start-Process` 配合 `WaitForExit(timeout)` + `PeakWorkingSet64`。
- 所有平台：uv 定时器在 `tl + 500ms` 作为兜底 kill。
- 编译输出目录通过 `os.execute('mkdir -p')` 自动创建（在 fast context 中安全）。

### 题目数据格式
```
data_dir/
└── ProblemName/
    ├── problem.json    # { url, name, testCount, memoryLimit, timeLimit }
    ├── 0.in / 0.out
    ├── 1.in / 1.out
    └── ...
```
读取使用 `utils.read_test_case(dir, index)`，测试点数量来自 `utils.get_test_count(dir)`。

浏览器发来的题目名会被净化处理：在 Linux/macOS/Windows 上非法的字符（`/ \ : * ? " < > |` 以及控制字符）替换为 `_`；连续的 `_` 折叠为一个；去除首尾空白以及结尾的点和空格；结果为空时回退为 `problem`；Windows 保留设备名（`CON`、`PRN`、`AUX`、`NUL`、`COM1`-`COM9`、`LPT1`-`LPT9`）前缀加 `_`。数据目录与源文件名使用同一个净化后的名称，而 `problem.json.name` 保留原始标题。若另一个原始标题净化后与已有目录重名，handler 会在覆盖该题数据前询问用户。

### 解题历史格式
`.history` 文件，每次归档一行。制表符分隔的路径对 `from\tto` —— 每一对对应一次 `uv.fs_rename` 移动。`M.restore()` 按顺序反向执行这些路径对。最大条目数由 `max_archive_history` 控制（默认 100）。

### 对拍（压力测试）
`M.stress(opts)` —— `opts` 字段：
- `correct` / `test`：`{type="path"|"find", data="..."}`
- `data`：`{type="path"|"find"|"data", data="..."}` —— 可选。省略时依次从 `correct` 的题目数据目录、`test` 的题目数据目录自动加载，最后回退为空输入。
- `timeLimit` / `memoryLimit`：可选，回退到配置默认值。

`resolve_code` / `resolve_data` 对 "find" 类型使用 `vim.ui.select`，嵌套回调链通过 `vim.schedule()` 打断。

### 变量展开
编译/运行命令支持 `$(VAR)` / `@VAR` / `%VAR%`：

| 变量 | 含义 |
|------|------|
| `FNAME` | 完整文件名（`123A.cpp`） |
| `FNOEXT` | 不含扩展名的文件名（`123A`） |
| `FABSPATH` | 源文件的绝对路径 |
| `DIR` | 源文件所在目录 |

### 选择器集成
`module/init.lua:find()` 依次尝试：`snacks.picker` → `telescope.builtin` → `fzf-lua` → `mini.pick` → 回退到 `vim.ui.select`。子命令：`template`、`problem`、`data`（旧名 `json`）。

### 关键配置字段

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `data_dir` | `stdpath("data").."/faster-oj/.problem"` | 题目数据目录 |
| `temp_dir` | `stdpath("data").."/faster-oj/.temp"` | 临时文件（对拍数据、提交代码） |
| `archive_dir` | `stdpath("data").."/faster-oj/.archive"` | 已归档题目目录 |
| `default_time_limit` | `2000` | 兜底时间限制（毫秒） |
| `default_memory_limit` | `256` | 兜底内存限制（MB） |
| `max_archive_history` | `100` | `.history` 最大条目数 |
| `clipboard_submit` | `false` | 提交时把代码复制到 `+` 寄存器 |
| `tc_edit_ui.confirm_unsaved` | `true` | 切换/关闭/新建测试点及删除测试点前确认未保存修改 |
| `compile_command` | table | 以文件扩展名为键 |
| `run_command` | table | 以文件扩展名为键 |

### 代码混淆器
提交前的可选预处理。所有异常路径都回退到原始代码：
- 未配置 → 跳过
- 二进制不可执行 → 跳过
- spawn 失败（退出码≠0）→ 跳过
- 结果文件缺失 → 跳过

### stress 命令解析
`:FOJ stress` 解析形如 `correct=type:val test=type:val [data=type:val] [time=N] [mem=N]`。
- 使用 `parse_quoted_value()`，单次从左到右扫描，支持三种引号风格：
  - 双引号 `"..."`
  - 单引号 `'...'`
  - C++ 原始字符串 `R"delim(...)delim"`（含自定义分隔符）
- `data=` 值中的 `\n` / `\t` 转义序列会被解码为真实换行/制表符
- 未加引号的 `correct=` / `test=` 值在空白处结束；未加引号的 `data=` 会一直取到行尾（保持向后兼容）

### 编译输出
所有编译型语言都把二进制输出到 `$(DIR)/.output/`。编译前自动创建该目录。脚本型语言（py、js、ts、lua）没有编译步骤。

## 开发流程

任何改动或新功能都必须从描述性的 git 分支开始（`fix/<描述>` 或 `feature/<描述>`），然后在计划模式下规划实现。

### 计划模式（Plannotator 扩展）

实现规划一律通过 `@plannotator/pi-extension` 提供的计划模式完成，不再使用旧的 `feature-dev` 技能：

- 开启/关闭：`/plannotator-plan-mode` 或 `Ctrl+Alt+P`；也可用 `pi --plan` 直接以计划模式启动会话。
- 计划模式下代理受限制：破坏性命令被禁止，写操作仅限计划文件。此时应只探索代码库，不修改代码。
- 计划以 markdown 清单（checklist）形式写入工作目录下的计划文件，然后提交计划文件路径。
- 提交计划不会阻塞等待：评审在浏览器中打开，代理结束本轮对话，用户的批准/批注稍后作为新消息返回。
- 评审期间可继续对话；计划被修改时已打开的评审页会自动同步并保留批注。
- 退出计划模式才会关闭未完成的评审（Esc 不会取消评审）。

### 工作循环

```
┌── 循环开始 ─────────────────────────────────────────────┐
│                                                         │
│  1. 计划模式：探索代码库，产出实现计划                   │
│                                                         │
│  2. 提交计划 → 浏览器打开计划评审                        │
│     ├── 批准 → 退出计划模式，修改代码，等待用户测试      │
│     └── 批注/驳回 → 按反馈修订计划，再次提交评审         │
│                       或与用户讨论后取消本次流程         │
│                                                         │
│  3. 用户反馈缺陷 / 代码错误                              │
│     └── 重新进入计划模式，做针对性修复计划并实施         │
│                                                         │
│  4. 用户确认测试通过                                     │
│     └── 询问用户是否合并分支                             │
│        （代码审查由用户自行完成，代理不主动审查）        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Git 提交规范

使用 GitHub 标准 conventional commit 格式，并附上详细的变更描述：

```
<type>(<scope>): <简要描述>

<变更详情、原因及影响范围>

Co-Authored-By: pi
```

（若提交由具体模型生成，可在 trailer 中注明模型名，例如 `Co-Authored-By: pi <model-name>`。）

- **type**：feat / fix / refactor / docs / chore
- **scope**：受影响的模块名（如 stress、run、submit、ui）
- **简要描述**：一行概述本次变更
- **详细描述**：列出具体改动、影响范围、向后兼容性说明

### 提交后同步 AGENTS.md（强制）

**每次完成一次提交，都必须检查并更新本文件中对应的架构说明。** 只要改动涉及以下任一项，就在同一次提交（或紧随其后的文档提交）中同步修改本文件：

- 目录结构或文件名变化（新增/删除/重命名模块）
- 模块职责、公开函数名、异步/回调约定变化
- 配置字段、默认值、命令、keymap 变化
- 数据格式（题目数据、`.history`、`problem.json` 等）变化
- 工作流程、分支规范、提交规范变化

英文版 `CLAUDE.md` 需保持同步，内容强制为英文。文档与代码不一致时，以代码为准并立即修正文档。
