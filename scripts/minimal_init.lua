local cwd = vim.fn.getcwd()
if not vim.tbl_contains(vim.opt.runtimepath:get(), cwd) then
  vim.opt.runtimepath:append(cwd)
end

vim.cmd 'filetype plugin indent on'
vim.o.hidden = true
vim.o.swapfile = false
vim.o.shada = ''


local function maybe_append(path)
  if path and vim.fn.isdirectory(path) == 1 then
    if not vim.tbl_contains(vim.opt.runtimepath:get(), path) then
      vim.opt.runtimepath:append(path)
    end
  end
end

local data = vim.fn.stdpath('data')
maybe_append(data .. '/lazy/mini.nvim')
maybe_append(data .. '/lazy/snacks.nvim')
maybe_append(data .. '/site/pack/packer/start/mini.nvim')
maybe_append(data .. '/site/pack/testing/opt/mini.nvim')
maybe_append(data .. '/site/pack/packer/opt/mini.nvim')
maybe_append(data .. '/site/pack/lazy/start/mini.nvim')
maybe_append(data .. '/site/pack/vendor/start/mini.nvim')
maybe_append(data .. '/site/pack/testing/start/mini.nvim')

if not pcall(require, 'mini.test') then
  local target = data .. '/site/pack/testing/start/mini.nvim'
  if vim.fn.isdirectory(target) == 0 then
    vim.fn.mkdir(target, 'p')
    vim.fn.system({ 'git', 'clone', '--depth=1', 'https://github.com/echasnovski/mini.nvim', target })
  end
  maybe_append(target)
end

vim.g.__mg_minimal_init = true


