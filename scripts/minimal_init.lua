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

-- Try to make mini.test available if installed
pcall(vim.cmd, 'packadd mini.test')

-- If needed elsewhere: `require("mini.test")` will be done by the runner
vim.g.__mg_minimal_init = true


