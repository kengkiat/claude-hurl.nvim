# claude-hurl.nvim

Open Claude Code's editor (Ctrl+G) in an **existing** NeoVim instance instead of spawning a new one.

When you press Ctrl+G in Claude Code, it opens `$VISUAL <tempfile>` for multi-line prompt editing. By default this spawns a brand-new editor. This plugin routes that file to your already-running NeoVim and blocks until you're done editing.

## How It Works

```
Ctrl+G in Claude Code
  → $VISUAL (bin/claude-hurl) discovers your NeoVim socket
  → Opens file in existing NeoVim via :ClaudeHurlOpen
  → Blocks on a FIFO until you signal "done"
  → You edit, then :ClaudeHurlSend or :bd
  → Shell unblocks → Claude Code reads your edited prompt
```

## Requirements

- NeoVim 0.9+
- Claude Code CLI
- bash 4+

## Installation

### lazy.nvim

```lua
{ "kengkiat/claude-hurl.nvim", opts = {} }
```

Commands are registered automatically — no `setup()` call or `cmd` list needed. To customize options:

```lua
{ "kengkiat/claude-hurl.nvim", opts = { open_cmd = "vsplit" } }
```

Then set `$VISUAL` so Claude Code uses the plugin's shell script as its editor.

**Option A** — Shell alias (scoped to Claude Code only):

```bash
# In .zshrc / .bashrc:
alias claude='VISUAL=$(echo ~/.local/share/lazy/claude-hurl.nvim/bin/claude-hurl) claude'
```

**Option B** — Claude Code settings (`~/.claude/settings.json`):

```json
{
  "env": {
    "VISUAL": "~/.local/share/lazy/claude-hurl.nvim/bin/claude-hurl"
  }
}
```

> **Note:** Adjust the path if your lazy.nvim plugin directory is different.
> The default is `~/.local/share/nvim/lazy/claude-hurl.nvim/bin/claude-hurl`.

### Manual

```bash
git clone https://github.com/kengkiat/claude-hurl.nvim \
  ~/.config/nvim/pack/plugins/start/claude-hurl.nvim
```

Add to your NeoVim config (optional, only needed to customize options):

```lua
require("claude-hurl").setup()
```

Then set VISUAL to the script's full path:

```bash
alias claude='VISUAL=~/.config/nvim/pack/plugins/start/claude-hurl.nvim/bin/claude-hurl claude'
```

## Usage

### Commands

| Command | Behavior |
|---------|----------|
| `:ClaudeHurlSend` | Save + signal done to Claude. Buffer stays open. |
| `:ClaudeHurlSendClose` | Save + signal done + close buffer. |
| `:bd` / `:wq` | Also signals done (fallback via autocmd). |

### Keybindings

With lazy.nvim, define keymaps directly in your plugin spec:

```lua
{
  "kengkiat/claude-hurl.nvim",
  opts = {},
  keys = {
    { "<leader>cs", "<cmd>ClaudeHurlSend<cr>", desc = "Send to Claude Code" },
    { "<leader>cS", "<cmd>ClaudeHurlSendClose<cr>", desc = "Send to Claude Code and close" },
  },
}
```

Or set them manually anywhere in your config:

```lua
vim.keymap.set("n", "<leader>cs", "<cmd>ClaudeHurlSend<cr>", { desc = "Send to Claude Code" })
vim.keymap.set("n", "<leader>cS", "<cmd>ClaudeHurlSendClose<cr>", { desc = "Send to Claude Code and close" })
```

### Shell Subcommands

```bash
claude-hurl <file>                  # Open in existing NeoVim, block until done
claude-hurl list                    # List all discoverable NeoVim sockets
claude-hurl status                  # Show which socket would be selected
claude-hurl --fallback-nvim <file>  # Fall back to new NeoVim if none found
```

## Socket Discovery

The shell script finds your NeoVim instance using these strategies (in priority order):

1. **Environment variable** — `$NVIM_CLAUDE_SOCK` or `$NVIM_LISTEN_ADDRESS`
2. **tmux sibling** — NeoVim running in a sibling pane of the same tmux window
3. **CWD match** — NeoVim with the same working directory
4. **Most recent** — Most recently created NeoVim socket

Override with: `CLAUDE_HURL_STRATEGY=env|tmux|cwd|recent|auto`

## Setup Recipes

### tmux (zero config)

If you use tmux with NeoVim in one pane and Claude Code in another, socket discovery finds it automatically:

```bash
alias claude='VISUAL=/path/to/claude-hurl.nvim/bin/claude-hurl claude'
```

### Non-tmux with explicit socket

```lua
-- lazy.nvim:
{ "kengkiat/claude-hurl.nvim", opts = { listen_address = "/tmp/nvim-claude.sock" } }

-- Or manually:
require("claude-hurl").setup({ listen_address = "/tmp/nvim-claude.sock" })
```

```bash
# In .zshrc:
export NVIM_CLAUDE_SOCK="/tmp/nvim-claude.sock"
alias claude='VISUAL=/path/to/claude-hurl.nvim/bin/claude-hurl claude'
```

### Multiple projects

Each project gets its own NeoVim with a unique socket:

```bash
# Project 1
nvim --listen /tmp/nvim-project1.sock
NVIM_CLAUDE_SOCK=/tmp/nvim-project1.sock claude

# Project 2
nvim --listen /tmp/nvim-project2.sock
NVIM_CLAUDE_SOCK=/tmp/nvim-project2.sock claude
```

Or with tmux, just use separate windows — discovery is automatic.

## Configuration

All options have sensible defaults, so `setup()` is optional. Call it only if you need to customize:

```lua
require("claude-hurl").setup({
  listen_address = nil,    -- Start NeoVim server on this path (for non-tmux)
  open_cmd = "drop",       -- How to open: "drop", "edit", "split", "vsplit", "tabedit"
  auto_write = true,       -- Auto-save buffer before signaling
  notify = true,           -- Show "Claude waiting" notification
})
```

With lazy.nvim, pass these as `opts` instead:

```lua
{ "kengkiat/claude-hurl.nvim", opts = { open_cmd = "vsplit", notify = false } }
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NVIM_CLAUDE_SOCK` | Explicit NeoVim socket path |
| `NVIM_LISTEN_ADDRESS` | Fallback socket path (NeoVim legacy) |
| `CLAUDE_HURL_NVIM` | Command to launch NeoVim for fallback (default: `nvim`) |
| `CLAUDE_HURL_STRATEGY` | Discovery strategy: `auto\|env\|tmux\|cwd\|recent` |
| `CLAUDE_HURL_DEBUG` | Set to `1` for debug output |

## Debugging

```bash
claude-hurl status            # Which NeoVim would be selected
claude-hurl list              # All discoverable sockets
CLAUDE_HURL_DEBUG=1 claude-hurl edit /tmp/test.md  # Verbose output
```

## Related

- [neovim-remote (nvr)](https://github.com/mhinz/neovim-remote) — General-purpose remote NeoVim tool. `VISUAL="nvr --remote-wait"` works for the basic case but requires Python and manual socket management. claude-hurl.nvim adds automatic socket discovery and send-without-closing.
- [claudecode.nvim](https://github.com/coder/claudecode.nvim) — IDE integration for Claude Code (selections, diffs, file context). Can be used alongside this plugin.
