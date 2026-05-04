# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

默认使用中文回答。

## Project overview

Faster-OJ.nvim 是一个跨平台 Neovim 插件（支持 Windows/Linux/macOS），用于构建完整的算法竞赛/刷题自动化工作流。通过本地 HTTP 服务器接收 [Competitive Companion](https://github.com/jmerle/competitive-companion) 浏览器插件推送的题目数据，使用 libuv 异步并发进行本地判题，并通过 WebSocket 连接浏览器插件完成自动提交。

There is no build step, test suite, or CI. It's a pure Lua plugin distributed via lazy.nvim.

## Architecture

```
lua/faster-oj/
├── init.lua              # Plugin entry: setup(), :FOJ user command, server start/stop
├── default.lua           # Full default config (commands, UI layout, highlights, etc.)
├── server/
│   ├── http/
│   │   ├── server.lua    # Raw TCP server using uv.new_tcp — receives JSON from browser
│   │   └── handler.lua   # Whitelist-filters JSON fields, writes problem .json + template file
│   └── websocket/
│       └── server.lua    # Spawns platform-specific mini-wsbroad binary, manages WS lifecycle
└── module/
    ├── init.lua          # Module orchestrator — wires run/test/submit/edit/erase/find commands
    ├── run.lua           # Compilation (uv.spawn) + concurrent test execution with worker pool
    ├── submit.lua        # Sends code via WS; optional code obfuscator pre-processing
    ├── solve.lua         # Moves problem to solve_dir, writes .history; undo with solve_back()
    ├── utils.lua         # File I/O, JSON r/w, path variable expansion ($(FNAME) etc.), language detection
    ├── ui.lua            # Generic weight-based recursive layout engine with resize handling
    ├── tests_ui.lua      # Judge result viewer: TC list + input/output/expected/info panels
    ├── tests_edit_ui.lua # TC editor with real-time buffer→JSON sync, add/delete/modify
    └── stress.lua        # Stress testing (WIP, mostly empty)
```

**Key architectural decisions:**

- **All async I/O uses libuv** (`vim.uv` / `vim.loop`) — no external job libraries. Compilation and each test case run as `uv.spawn` children.
- **UI is a custom layout engine** (`ui.lua`). The config defines a recursive `{weight, content}` tree. `calculate_rects` computes absolute coordinates; `ui.open` creates/moves floating windows with rounded borders. On `VimResized`, windows are repositioned without teardown to avoid flicker.
- **Concurrent judging**: `run.lua:fill_queue()` maintains an active worker count up to `max_workers`. As each worker finishes, `fill_queue()` is called recursively to start the next pending test case.
- **Output comparison**: Two modes controlled by `obscure` config — token-based fuzzy matching (lexical analysis ignoring whitespace) or line-by-line exact matching. Computed in `compute_diff_ranges()`.
- **Platform support**: Memory measurement differs per OS (Linux `/usr/bin/time`, macOS `/usr/bin/time -l`, Windows PowerShell `PeakWorkingSet64`). Process spawning uses `/usr/bin/time` wrappers on Unix, PowerShell on Windows. Platform-specific `mini-wsbroad` binaries in `server/websocket/`.
- **Finder integration** (`module/init.lua:find()`): tries `snacks.picker` → `telescope.builtin` → `fzf-lua` → `mini.pick` → `vim.ui.select` fallback.

## Variable expansion in commands

Compile/run command strings support `$(VARNAME)` / `@VARNAME` / `%VARNAME%` expansion. Available vars from `utils.get_vars()`:

| Variable | Meaning |
|----------|---------|
| `FNAME` | Full filename with extension |
| `FNOEXT` | Filename without extension |
| `FABSPATH` | Absolute path to the source file |
| `DIR` | Directory of the source file |
