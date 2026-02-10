# claude-hurl.nvim

Open Claude Code prompts (Ctrl+G) in an existing NeoVim instance instead of spawning a new one.

## Architecture

- **`bin/claude-hurl`** — Shell script used as `$VISUAL`. Discovers NeoVim socket, creates a FIFO, calls `:ClaudeHurlOpen` via `--remote-send`, blocks on FIFO read.
- **`plugin/claude-hurl.lua`** — Auto-loaded command registration (ClaudeHurlOpen, ClaudeHurlSend, ClaudeHurlSendClose).
- **`lua/claude-hurl/init.lua`** — Plugin entry: `setup()`, config.
- **`lua/claude-hurl/signal.lua`** — Buffer lifecycle management + FIFO signaling.

## Flow

1. Claude Code Ctrl+G calls `$VISUAL <tempfile>`
2. Shell script discovers NeoVim socket, creates FIFO, sends `:ClaudeHurlOpen <file> <signal_path>`
3. Plugin opens file, sets autocmds for buffer close
4. User edits, then `:ClaudeHurlSend` or `:bd`
5. Plugin writes to FIFO → shell unblocks → Claude Code reads edited file

## Key Finding

Claude Code uses `$VISUAL` (not `$EDITOR`) for Ctrl+G prompt editing. The `$EDITOR` env var and `settings.json` `env.EDITOR` do not affect Ctrl+G.

## Conventions

- Commit messages must not include `Co-Authored-By` lines
- Shell script: POSIX-compatible bash, shellcheck clean
- Lua: NeoVim 0.9+ APIs, no external dependencies
- Socket discovery priority: env var → tmux sibling → CWD match → most recent
- All temp files cleaned up via `trap EXIT`
- `CLAUDE_HURL_NVIM` env var controls the fallback nvim command (for NVIM_APPNAME users)

## Commands

| Command | Behavior |
|---------|----------|
| `:ClaudeHurlSend` | Save + signal done, keep buffer open |
| `:ClaudeHurlSendClose` | Save + signal done + close buffer |
| `:ClaudeHurlOpen <file> <signal>` | (Internal) Called by shell script |

## Testing

```bash
./tests/test_blocking.sh
```

## Dev Tips

- Test socket discovery: `bin/claude-hurl status`
- List sockets: `bin/claude-hurl list`
- The shell script must be executable: `chmod +x bin/claude-hurl`
