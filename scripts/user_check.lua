-- Ensure local dev plugin path is on runtimepath first
local dev = '/Users/jameswolensky/Development/marker-groups.nvim'
if vim.fn.isdirectory(dev) == 1 then
  if not vim.tbl_contains(vim.opt.runtimepath:get(), dev) then
    vim.opt.runtimepath:prepend(dev)
  end
end

pcall(function()
  -- Touch the plugin to ensure it's loaded and logger is ready
  require('marker-groups')
end)

pcall(function()
  local logger = require('marker-groups.utils.logger')
  logger.write_to_file('/tmp/marker-groups.log')
end)


