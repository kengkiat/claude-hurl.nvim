# claude-nvim

Open Claude Code prompts (Ctrl+G) in an existing NeoVim instance instead of spawning a new one.

## Architecture

- **`bin/claude-nvim`** — Shell script used as `$EDITOR`. Discovers NeoVim socket, creates a FIFO, calls `:ClaudeNvimOpen` via `--remote-send`, blocks on FIFO read.
- **`lua/claude-nvim/init.lua`** — Plugin entry: `setup()`, user commands, config.
- **`lua/claude-nvim/signal.lua`** — Buffer lifecycle management + FIFO signaling.

## Flow

1. Claude Code calls `$EDITOR <tempfile>`
2. Shell script discovers NeoVim socket, creates FIFO, sends `:ClaudeNvimOpen <file> <signal_path>`
3. Plugin opens file, sets autocmds for buffer close
4. User edits, then `:ClaudeNvimSend` or `:bd`
5. Plugin writes to FIFO → shell unblocks → Claude Code reads edited file

## Conventions

- Shell script: POSIX-compatible bash, shellcheck clean
- Lua: NeoVim 0.9+ APIs, no external dependencies
- Socket discovery priority: env var → tmux sibling → CWD match → most recent
- All temp files cleaned up via `trap EXIT`

## Commands

| Command | Behavior |
|---------|----------|
| `:ClaudeNvimSend` | Save + signal done, keep buffer open |
| `:ClaudeNvimSendClose` | Save + signal done + close buffer |
| `:ClaudeNvimOpen <file> <signal>` | (Internal) Called by shell script |

## Testing

```bash
./tests/test_blocking.sh
```

## Dev Tips

- Test socket discovery: `bin/claude-nvim status`
- List sockets: `bin/claude-nvim list`
- The shell script must be executable: `chmod +x bin/claude-nvim`
