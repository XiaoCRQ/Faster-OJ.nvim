# Faster-OJ.nvim

加快你算法竞赛的速度。

## 介绍

`Faster-OJ.nvim` 是一个为算法竞赛选手设计的 Neovim 插件，提供本地判题服务器启动、代码提交等功能，帮助你在本地快速测试与调试题目。

## 安装

使用你喜欢的插件管理器安装，例如 `lazy.nvim`：

```lua
{
  "xiaocrq/faster-oj.nvim",
  opts = {
  },
  config = function(_, opts)
    local oj = require("faster-oj")
    oj.setup(opts)
  end,
},
```

## 配置

默认配置如下：

```lua
require("faster-oj").setup({
  http_host = "127.0.0.1",
  http_port = 10043,
  ws_host = "127.0.0.1",
  ws_port = 10044,
  server_debug = false,
  server_mod = "all",        -- 可选: "only_http" | "only_ws" | "all"
  json_dir = ".problem/json",
  code_obfuscator = "",      -- 提交前混淆代码的命令（可选）
})
```

## 命令

在 Neovim 中使用以下命令：

- `:FOJ server [start|stop]` 或 `:FOJ sv [start|stop]`  
  启动或停止本地判题服务。不带参数默认启动。

- `:FOJ submit` 或 `:FOJ sb`  
  提交当前文件到判题服务器。

## 注意事项

- 本插件依赖外部判题服务（需自行部署）。
- `json_dir` 应包含符合格式的题目元信息（如 `.problem/json/xxx.json`）。
- `code_obfuscator` 示例：`"bash obfuscate.sh"`，用于在提交前处理代码。
