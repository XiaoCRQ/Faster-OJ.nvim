# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

默认使用中文回答。

## Project overview

Faster-OJ.nvim is a cross-platform Neovim plugin (Windows/Linux/macOS) for Competitive Programming automation. It receives problem data via a built-in HTTP server from [Competitive Companion](https://github.com/jmerle/competitive-companion), runs async concurrent local judging using libuv, and submits solutions through a WebSocket bridge to the [Faster-OJ browser extension](https://github.com/XiaoCRQ/Faster-OJ).

There is no build step, test suite, or CI. It's a pure Lua plugin distributed via lazy.nvim. Minimum Neovim version: 0.9.

## Architecture

```
lua/faster-oj/
├── init.lua                # Entry: setup(), :FOJ user command, server ops
├── default.lua             # Full default config with emmylua type annotations
├── server/
│   ├── http/
│   │   ├── server.lua      # Raw TCP server (uv.new_tcp), receives JSON from browser
│   │   └── handler.lua     # Writes problem folder: problem.json + N.in/N.out files
│   └── websocket/
│       └── server.lua      # Spawns mini-wsbroad binary, manages WS lifecycle
└── module/
    ├── init.lua            # Orchestrator: run/test/submit/edit/erase/find/stress
    ├── run.lua             # Compile (uv.spawn) + concurrent judging pool + M.run_single()
    ├── stress.lua          # Stress testing: paired execution with picker/file/raw data sources
    ├── submit.lua          # WS submission + optional code obfuscator
    ├── solve.lua           # Problem archiving with pair-based history (.history file)
    ├── notify.lua          # Single-window floating notification + spinner animation
    ├── utils.lua           # File I/O, JSON r/w, variable expansion, test case helpers
    └── ui/
        ├── init.lua        # Layout engine — recursive weight-based rect calculation
        ├── tests.lua       # Judge result viewer (TC list + detail panels)
        ├── tests_edit.lua  # TC editor with file-based real-time sync
        └── stress.lua      # Stress test result viewer
```

## Key patterns & conventions

### Async: all I/O uses libuv
`vim.uv` (or `vim.loop` fallback). No external job libraries. Compile and test execution use `uv.spawn`. UI operations use `vim.schedule()` when called from libuv callbacks.

### Fast event context restriction
Neovim API functions (`vim.fn.mkdir`, `nvim_buf_get_name`, etc.) MUST NOT be called from libuv callbacks. Use `os.execute()` for filesystem ops inside callbacks. Use `vim.schedule()` to defer Neovim API calls. Functions like `utils.get_problem_dir()` that read the current buffer must only be called from main context; use `utils.get_problem_dir_from(file_path)` in async contexts.

### Config: deep merge with defaults
`vim.tbl_deep_extend("force", defaults, user_opts)` — user overrides take priority. `compile_command` / `run_command` keys are **file extensions** (e.g., `py`, `js`, `rs`, `kt`, `pas`), not language names. Config field `data_dir` (was `json_dir`).

### UI: custom layout engine
Config defines a recursive `{weight, content}` tree. `calculate_rects()` computes absolute coords; `ui.open()` creates/moves floating windows with rounded borders. On `VimResized`, windows reposition without teardown. All UI modules use `vim.schedule()` for rendering.

### Logging: unified format
All modules use: `log(level, func, msg)` → `[FOJ][<module>][LEVEL] func: msg`. Levels: INFO, WARN, ERROR. Only outputs when `config.debug == true`. All runtime strings are English.

### Notifications: single-window
`notify.lua` provides `notify.show(msg, level, duration)`, `notify.spinner_start/update/done/fail(msg)`. A single floating window at top-center that replaces previous content. Spinner uses Unicode braille chars `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` at 80ms interval.

### Concurrent judging
`run.lua:fill_queue()` maintains active workers up to `max_workers` (default 5). As each finishes, fill_queue recursively starts the next.

### Output comparison
Two modes controlled by `obscure` config:
- **Token mode** (`obscure=true`): lexical analysis — extract non-whitespace tokens with coords, compare token-by-token
- **Line mode** (`obscure=false`): line-by-line exact match, find first differing char

### Platform execution
- **Linux**: `timeout -s 9 <tl>` (hard wall-clock limit) + `/usr/bin/time -v` (RSS memory). Falls back if `/usr/bin/time` missing.
- **macOS**: `/usr/bin/time -l` (memory) + uv timer (timeout). No native `timeout` command.
- **Windows**: PowerShell `Start-Process` with `WaitForExit(timeout)` + `PeakWorkingSet64`.
- All platforms: uv timer as backup kill at `tl + 500ms`.
- Compile output dir auto-created via `os.execute('mkdir -p')` (safe in fast context).

### Problem data format
```
data_dir/
└── ProblemName/
    ├── problem.json    # { url, name, testCount, memoryLimit, timeLimit }
    ├── 0.in / 0.out
    ├── 1.in / 1.out
    └── ...
```
Read via `utils.read_test_case(dir, index)`, test count from `utils.get_test_count(dir)`.

### Solve history format
`.history` file, one line per solve. Tab-separated path pairs `from\tto` — each pair is a `uv.fs_rename` move. `solve_back()` reverses pairs in order. Max entries controlled by `max_solve_history` (default 100).

### Stress testing
`M.stress(opts)` — `opts` fields:
- `correct` / `test`: `{type="path"|"find", data="..."}`
- `data`: `{type="path"|"find"|"data", data="..."}` — optional. If omitted, auto-loads from `correct`'s problem data dir, then `test`'s problem data dir, then empty input.
- `timeLimit` / `memoryLimit`: optional, fall back to config defaults.

`resolve_code` / `resolve_data` use `vim.ui.select` for "find" type with nested callback chains broken by `vim.schedule()`.

### Variable expansion
`$(VAR)` / `@VAR` / `%VAR%` in compile/run commands:

| Variable | Meaning |
|----------|---------|
| `FNAME` | Full filename (`123A.cpp`) |
| `FNOEXT` | Filename without extension (`123A`) |
| `FABSPATH` | Absolute path to source file |
| `DIR` | Directory of source file |

### Finder integration
`module/init.lua:find()` tries: `snacks.picker` → `telescope.builtin` → `fzf-lua` → `mini.pick` → `vim.ui.select` fallback. Subcommands: `template`, `problem`, `data` (was `json`).

### Key config fields

| Field | Default | Notes |
|-------|---------|-------|
| `data_dir` | `".problem"` | Problem data directory |
| `temp_dir` | `".temp"` | Temp files (stress data, submit) |
| `solve_dir` | `".solve"` | Solved problem archive |
| `default_time_limit` | `2000` | Fallback time limit (ms) |
| `default_memory_limit` | `256` | Fallback memory limit (MB) |
| `max_solve_history` | `100` | Max .history entries |
| `clipboard_submit` | `false` | Copy code to `+` register on submit |
| `compile_command` | table | Keyed by file extension |
| `run_command` | table | Keyed by file extension |

### Code obfuscator
Optional pre-processing before submission. All error paths fall back to original code:
- Not configured → skip
- Binary not executable → skip
- Spawn fails (code≠0) → skip
- Result file missing → skip

### Stress command parser
`:FOJ stress` parses `correct=type:val test=type:val [data=type:val] [time=N] [mem=N]`.
- `data=` extracted greedily first (may contain spaces/`\n`)
- `correct=` / `test=` use `(%S*)` for empty values (e.g., `find:`)
- `\n` in data values decoded to actual newlines

### Compilation output
All compiled languages output binaries to `$(DIR)/.output/`. Directory auto-created before compilation. Script languages (py, js, ts, lua) have no compile step.
