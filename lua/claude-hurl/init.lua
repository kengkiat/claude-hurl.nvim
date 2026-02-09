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

end

return M
