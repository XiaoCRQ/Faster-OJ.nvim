# Faster-OJ.nvim

> ⚡ 极速提升 Neovim 中的算法竞赛 (Competitive Programming) 工作流。
> [README.en-US](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.md) | [README.zh-CN](https://github.com/XiaoCRQ/Faster-OJ.nvim/blob/main/README.zh-CN.md)

**Faster-OJ.nvim** 是一款专为算法竞赛选手打造的 Neovim 插件。它将本地代码编写、自动化判题与浏览器自动提交无缝集成，旨在实现“写完即提交”的极致体验。

---

## ✨ 特性

* **🚀 一键提交**：直接从 Neovim 发送代码至浏览器并完成 OJ 提交，彻底告别复制粘贴。
* **🖥 本地判题服务**：内置基于 WebSocket 的本地判题管理系统（配合 [mini-wsbroad](https://github.com/XiaoCRQ/mini-wsbroad)）。
* **🧪 高效本地测试**：一键编译、运行并比对样例输出。
* **🔗 浏览器深度集成**：配合浏览器插件实现题目数据同步与自动提交。
* **🧠 极简高效**：命令直观，不干扰编程思路，专注解题。

---

## 🔄 推荐工作流

```text
Competitive Companion (浏览器)
        ↓ 抓取题目
Neovim + Faster-OJ.nvim (本地)
        ↓ 编写与本地测试
Local Judge Server (WebSocket)
        ↓ 触发提交
Faster-OJ (浏览器插件)
        ↓ 自动执行
Online Judge (在线评测)

```

1. **接收题目**：通过 [Competitive Companion](https://github.com/jmerle/competitive-companion) 自动将题目数据导入 Neovim。
2. **本地开发**：在熟悉的 Neovim 环境中编写代码。
3. **本地测试**：运行 `:FOJ run` 快速验证所有本地样例。
4. **自动提交**：执行 `:FOJ submit`，代码将自动通过 [Faster-OJ](https://github.com/XiaoCRQ/Faster-OJ) 浏览器插件提交。

---

## 📦 安装与配置

### 1. 环境依赖

* **浏览器插件**: [Faster-OJ](https://github.com/XiaoCRQ/Faster-OJ) & [Competitive Companion](https://github.com/jmerle/competitive-companion)。
* **Neovim**: 建议使用最新稳定版。

### 2. 插件安装 (以 lazy.nvim 为例)

#### **最小化安装（默认配置）**

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}

```

#### **标准化配置详解**

你可以根据需求自定义以下选项：

| 选项 | 类型 | 默认值 | 描述 |
| --- | --- | --- | --- |
| `warning_msg` | boolean | `true` | 是否在通知中显示编译器产生的警告信息 |
| `work_dir` | string | `""` | 插件的工作根目录 |
| `json_dir` | string | `".problem"` | 存放从浏览器接收到的题目 JSON 数据的目录 |
| `solve_dir` | string | `".solve"` | 存放已解决（Mark as solved）题目的目录 |
| `template_dir` | string | `""` | 存放代码模板的目录 |
| `template_default` | string | `""` | 默认使用的模板文件名 |
| `template_default_ext` | string | `".cpp"` | 当未指定模板时，新建文件默认使用的后缀名 |
| `compile_command` | table | (见下方) | 不同语言的编译指令配置 |
| `run_command` | table | (见下方) | 不同语言的运行指令配置 |

**编译与运行配置示例：**

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

## 🛠 常用命令

| 命令 | 描述 |
| --- | --- |
| `:FOJ` | 启动完整服务（HTTP + WebSocket） |
| `:FOJ start [all/http/ws]` | 启动指定的本地服务 |
| `:FOJ stop` | 停止所有服务 |
| `:FOJ submit` | 将当前代码提交到判题服务器/浏览器插件 |
| `:FOJ run` | 本地编译并运行当前题目的测试用例 |
| `:FOJ solve [back]` | 将当前题目标记为已解决（移动文件） |
| `:FOJ show / close` | 打开或关闭判题结果窗口 |

---

## 📊 平台支持状态

| 功能 | Windows | Linux | macOS |
| --- | --- | --- | --- |
| 接收题目 | ✅ | ✅ | ✅ |
| 本地测试 | ✅ | ✅ | ✅ |
| 自动提交 | 🚧 | ✅ | 🚧 |

> *注：提交功能深度依赖 WebSocket 服务，非 Linux 平台目前处于测试阶段。*

---

## 📜 许可证

基于 **GNU GPL v3** 开源协议。
