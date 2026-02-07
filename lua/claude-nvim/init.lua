local M = {}

M.config = {
  listen_address = nil,    -- Optional: start server on known path for easy discovery
  open_cmd = "drop",       -- How to open: "drop", "edit", "split", "vsplit", "tabedit"
  auto_write = true,       -- Auto-save buffer before signaling
  notify = true,           -- Show "Claude waiting" notification
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.listen_address then
    pcall(vim.fn.serverstart, M.config.listen_address)
  end

  -- :ClaudeNvimOpen <file> <signal_path>  (called by shell script via --remote-send)
  -- Signal path (last arg) is always a mktemp path with no spaces.
  -- File path (everything else) may contain spaces, so we join all args except the last.
  vim.api.nvim_create_user_command("ClaudeNvimOpen", function(cmd_opts)
    local args = cmd_opts.fargs
    if #args < 2 then
      vim.notify("ClaudeNvimOpen requires <file> <signal_path>", vim.log.levels.ERROR)
      return
    end
    local signal_path = args[#args]
    local file_path = table.concat(args, " ", 1, #args - 1)
    require("claude-nvim.signal").open_and_signal(file_path, signal_path, M.config)
  end, { nargs = "+", desc = "Open file for Claude Code editing" })

  -- :ClaudeNvimSend — save + signal done, keep buffer open
  vim.api.nvim_create_user_command("ClaudeNvimSend", function()
    require("claude-nvim.signal").send_current(false)
  end, { desc = "Send buffer to Claude Code (keep buffer open)" })

  -- :ClaudeNvimSendClose — save + signal done + close buffer
  vim.api.nvim_create_user_command("ClaudeNvimSendClose", function()
    require("claude-nvim.signal").send_current(true)
  end, { desc = "Send buffer to Claude Code and close buffer" })
end

return M
