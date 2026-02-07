# claude-nvim

Open Claude Code prompts (Ctrl+G) in an **existing** NeoVim instance instead of spawning a new one.

When you press Ctrl+G in Claude Code, it invokes `$EDITOR <tempfile>`. By default this spawns a new editor. This plugin opens the file in your already-running NeoVim and blocks until you're done editing.

## How It Works

```
Ctrl+G in Claude Code
  → $EDITOR (bin/claude-nvim) discovers your NeoVim socket
  → Opens file in existing NeoVim via :ClaudeNvimOpen
  → Blocks on a FIFO until you signal "done"
  → You edit, then :ClaudeNvimSend or :bd
  → Shell unblocks → Claude Code reads your edited prompt
```

## Installation

### lazy.nvim

```lua
{
  "username/claude-nvim",
  build = "ln -sf $(pwd)/bin/claude-nvim ~/.local/bin/claude-nvim",
  opts = {
    -- listen_address = "/tmp/nvim-claude.sock",  -- optional, for non-tmux setups
  },
}
```

Then add to your shell config (`.zshrc`, `.bashrc`, etc.):

```bash
export EDITOR='claude-nvim'
```

### Manual

```bash
git clone https://github.com/username/claude-nvim ~/.config/nvim/pack/plugins/start/claude-nvim
ln -sf ~/.config/nvim/pack/plugins/start/claude-nvim/bin/claude-nvim ~/.local/bin/claude-nvim
```

Add to your NeoVim config:

```lua
require("claude-nvim").setup()
```

## Usage

### Commands

| Command | Behavior |
|---------|----------|
| `:ClaudeNvimSend` | Save + signal done to Claude. Buffer stays open. |
| `:ClaudeNvimSendClose` | Save + signal done + close buffer. |
| `:bd` / `:wq` | Also signals done (fallback via autocmd). |

### Recommended Keybinding

```lua
vim.keymap.set("n", "<leader>cs", "<cmd>ClaudeNvimSend<cr>", { desc = "Send to Claude Code" })
```

### Shell Subcommands

```bash
claude-nvim <file>           # Open in existing NeoVim, block until done
claude-nvim edit <file>      # Same as above
claude-nvim list             # List all discoverable NeoVim sockets
claude-nvim status           # Show which socket would be selected and why
claude-nvim --fallback-nvim <file>  # Fall back to new NeoVim if none found
```

## Socket Discovery

The shell script finds your NeoVim instance using these strategies (in priority order):

1. **Environment variable**: `$NVIM_CLAUDE_SOCK` or `$NVIM_LISTEN_ADDRESS`
2. **tmux sibling**: Finds NeoVim running in a sibling pane of the same tmux window
3. **CWD match**: Finds NeoVim with the same working directory
4. **Most recent**: Falls back to the most recently created NeoVim socket

Override with: `CLAUDE_NVIM_STRATEGY=tmux|env|cwd|recent|auto`

## Setup Recipes

### tmux (zero config)

If you use tmux with NeoVim in one pane and Claude Code in another, it just works:

```bash
export EDITOR='claude-nvim'
```

### Non-tmux with explicit socket

```lua
-- In NeoVim config:
require("claude-nvim").setup({ listen_address = "/tmp/nvim-claude.sock" })
```

```bash
# In .zshrc:
export NVIM_CLAUDE_SOCK="/tmp/nvim-claude.sock"
export EDITOR='claude-nvim'
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

Or with tmux, just use separate windows — automatic.

## Configuration

```lua
require("claude-nvim").setup({
  listen_address = nil,    -- Start NeoVim server on this path (for non-tmux)
  open_cmd = "drop",       -- How to open: "drop", "edit", "split", "vsplit", "tabedit"
  auto_write = true,       -- Auto-save buffer before signaling
  notify = true,           -- Show "Claude waiting" notification
})
```

## Debugging

```bash
# Check which NeoVim would be selected:
claude-nvim status

# List all sockets:
claude-nvim list

# Enable debug output:
CLAUDE_NVIM_DEBUG=1 claude-nvim edit /tmp/test.md
```

## Relationship with claudecode.nvim

This plugin complements [claudecode.nvim](https://github.com/coder/claudecode.nvim):

- **claude-nvim** (this plugin): Handles Ctrl+G prompt editing in an existing NeoVim
- **claudecode.nvim**: IDE integration (selections, diffs, file context)

They can be used independently or together.
