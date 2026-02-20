# Faster-OJ.nvim

> ⚡ Accelerate your Competitive Programming workflow inside Neovim.

**Faster-OJ.nvim** 是一款专为算法竞赛选手打造的 Neovim 插件。
它负责本地判题、代码运行、以及与浏览器自动提交插件协作，构建完整的 **本地开发 → 自动提交 → 在线评测** 工作流。

配合浏览器插件 **Faster-OJ** 使用，可实现真正的“写完即提交”。

---

## ✨ 核心特性

* 🚀 **一键提交**
  本地写代码 → 直接提交到 OJ

* 🖥️ **本地判题服务器**
  内置本地服务启动与管理功能

* 🧪 **快速测试**
  编译、运行、查看输出一体化操作

* 🔗 **无缝联动**
  与浏览器插件协作完成自动提交

* 🧠 **极简设计**
  命令清晰，行为直观，专注竞赛效率

---

## 🔄 推荐工作流

```text
Competitive Companion
        ↓
Neovim (Faster-OJ.nvim)
        ↓
Local Judge Server
        ↓
Faster-OJ (Browser)
        ↓
Online Judge
```

### 1️⃣ 接收题目

通过浏览器插件 **competitive-companion** 接收题目数据。

### 2️⃣ 本地开发

在 Neovim 中编写代码。

### 3️⃣ 本地测试

运行本地判题机快速验证。

### 4️⃣ 一键提交

调用提交命令，自动发送至浏览器插件完成在线提交。

---

## 📦 前置插件

* 🌐 浏览器自动提交插件
  **Faster-OJ**

* 📥 浏览器题目接收插件
  **competitive-companion**

---

## 📦 安装

使用你喜欢的插件管理器，例如 `lazy.nvim`：

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {},
}
```

---

## ⚙️ 配置

默认配置文件：

👉 [https://github.com/XiaoCRQ/Faster-OJ.nvim/lua/faster-oj/default.lua](https://github.com/XiaoCRQ/Faster-OJ.nvim/lua/faster-oj/default.lua)

如无特殊需求，开箱即用。

---

## 🛠️ 可用命令

### 🔌 服务控制

```vim
:FOJ server
:FOJ sv
```

* 启动/停止本地服务
* 不带参数时作为开关循环（默认参数启动 / 关闭）

---

### 🚀 提交代码

```vim
:FOJ submit
:FOJ sb
```

将当前文件提交到判题服务器。

---

### ▶️ 本地运行

```vim
:FOJ run
```

编译并运行当前题目。

---

### 🪟 控制运行窗口

```vim
:FOJ show
:FOJ close
```

显示 / 关闭判题机运行窗口。

---

## 📊 平台支持情况

| 操作   | Windows | Linux | macOS |
| ---- | ------- | ----- | ----- |
| 接收题目 | ✅       | ✅     | ✅     |
| 本地测试 | ✅       | ✅     | ✅     |
| 提交题目 | 🚧      | ✅     | 🚧    |

> 提交功能依赖浏览器插件运行环境。

---

## 🎯 适用人群

* 使用 Neovim 进行算法竞赛开发的选手
* 追求极致效率的 Competitive Programmer
* 想打造完整自动化 OJ 工作流的用户

---

## 📜 开源协议

本项目采用 [GNU GPL v3](https://www.google.com/search?q=https://www.gnu.org/licenses/gpl-3.0) 协议。
