local M = {}

-- Track active signal paths per buffer: { [bufnr] = signal_path }
M.active = {}

function M.open_and_signal(file_path, signal_path, config)
  -- Open the file
  vim.cmd(config.open_cmd .. " " .. vim.fn.fnameescape(file_path))

  local bufnr = vim.fn.bufnr(file_path)
  if bufnr == -1 then
    M.write_signal(signal_path, "error")
    return
  end

  -- Track this buffer's signal path (for :ClaudeHurlSend)
  M.active[bufnr] = signal_path

  -- Notification
  if config.notify then
    vim.notify("Claude Code waiting — :ClaudeHurlSend when done", vim.log.levels.INFO)
  end

  -- Autocmd group (unique per buffer)
  local group = vim.api.nvim_create_augroup("ClaudeHurl_" .. bufnr, { clear = true })

  local function signal_done(reason)
    if M.active[bufnr] then
      pcall(M.write_signal, M.active[bufnr], reason)
      M.active[bufnr] = nil
    end
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end

  -- Fallback: also signal on buffer close (user does :bd directly)
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      -- Save before closing if modified
      if config.auto_write and vim.bo[bufnr] and vim.bo[bufnr].modified then
        pcall(vim.api.nvim_buf_call, bufnr, function()
          vim.cmd("silent! write")
        end)
      end
      vim.defer_fn(function()
        signal_done("closed")
      end, 50)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      signal_done("exit")
    end,
  })
end

--- Called by :ClaudeHurlSend and :ClaudeHurlSendClose
function M.send_current(close_buffer)
  local bufnr = vim.api.nvim_get_current_buf()
  local signal_path = M.active[bufnr]

  if not signal_path then
    vim.notify("No active Claude Code session for this buffer", vim.log.levels.WARN)
    return
  end

  -- Save the buffer
  if vim.bo[bufnr].modified then
    vim.cmd("silent write")
  end

  -- Signal done
  M.write_signal(signal_path, "sent")
  M.active[bufnr] = nil

  -- Clean up autocmds for this buffer
  pcall(vim.api.nvim_del_augroup_by_name, "ClaudeHurl_" .. bufnr)

  if close_buffer then
    vim.cmd("bdelete")
  else
    vim.notify("Sent to Claude Code", vim.log.levels.INFO)
  end
end

function M.write_signal(signal_path, reason)
  local f = io.open(signal_path, "w")
  if f then
    f:write(reason .. "\n")
    f:close()
  end
end

return M
