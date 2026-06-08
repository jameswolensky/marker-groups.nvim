local data = vim.fn.stdpath('data')
local plugin_root = vim.env.MG_PLUGIN_ROOT or vim.fn.getcwd()

local function append_rtp(path)
  if path and vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:append(path)
  end
end

append_rtp(plugin_root)
append_rtp(data .. '/site/pack/sandbox/start/plenary.nvim')
append_rtp(data .. '/site/pack/sandbox/start/snacks.nvim')

vim.o.swapfile = false
vim.o.shada = ''
vim.o.number = true
vim.o.termguicolors = true
vim.g.__mg_minimal_init = false

require('snacks').setup({ picker = { enabled = true } })

require('marker-groups').setup({
  picker = 'snacks',
  data_dir = vim.env.MG_SANDBOX_DATA or (data .. '/marker-groups-sandbox'),
})
