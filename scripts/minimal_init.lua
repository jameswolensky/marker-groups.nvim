-- Minimal initialization for mini.test in headless runs

-- Ensure the current project is on runtimepath
local cwd = vim.fn.getcwd()
if not vim.tbl_contains(vim.opt.runtimepath:get(), cwd) then
  vim.opt.runtimepath:append(cwd)
end

-- Basic vim defaults helpful for tests
vim.cmd 'filetype plugin indent on'
vim.o.hidden = true
vim.o.swapfile = false
vim.o.shada = ''

-- Try to make mini.nvim available if installed
local function maybe_append(path)
  if path and vim.fn.isdirectory(path) == 1 then
    if not vim.tbl_contains(vim.opt.runtimepath:get(), path) then
      vim.opt.runtimepath:append(path)
    end
  end
end

local data = vim.fn.stdpath('data')
-- Common Lazy path
maybe_append(data .. '/lazy/mini.nvim')
-- Common pack/* paths
maybe_append(data .. '/site/pack/packer/start/mini.nvim')
maybe_append(data .. '/site/pack/packer/opt/mini.nvim')
maybe_append(data .. '/site/pack/lazy/start/mini.nvim')
maybe_append(data .. '/site/pack/vendor/start/mini.nvim')
maybe_append(data .. '/site/pack/testing/start/mini.nvim')

pcall(vim.cmd, 'packadd mini.nvim')

-- If needed elsewhere: `require("mini.test")` will be done by the runner
vim.g.__mg_minimal_init = true


