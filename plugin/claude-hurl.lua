local function get_config()
  return require("claude-hurl").config
end

vim.api.nvim_create_user_command("ClaudeHurlOpen", function(cmd_opts)
  local args = cmd_opts.fargs
  if #args < 2 then
    vim.notify("ClaudeHurlOpen requires <file> <signal_path>", vim.log.levels.ERROR)
    return
  end
  local signal_path = args[#args]
  local file_path = table.concat(args, " ", 1, #args - 1)
  require("claude-hurl.signal").open_and_signal(file_path, signal_path, get_config())
end, { nargs = "+", desc = "Open file for Claude Code editing" })

vim.api.nvim_create_user_command("ClaudeHurlSend", function()
  require("claude-hurl.signal").send_current(false)
end, { desc = "Send buffer to Claude Code (keep buffer open)" })

vim.api.nvim_create_user_command("ClaudeHurlSendClose", function()
  require("claude-hurl.signal").send_current(true)
end, { desc = "Send buffer to Claude Code and close buffer" })
