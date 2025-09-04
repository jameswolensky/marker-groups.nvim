vim.cmd('luafile ' .. vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h') .. '/minimal_init.lua')

vim.g.__mg_force_persist = true
local dd = vim.fn.tempname() .. '_mg_time'
require('marker-groups').setup({ data_dir = dd, log_level='error' })
require('marker-groups.state').initialize(require('marker-groups.config').get())
vim.cmd('enew')
vim.api.nvim_buf_set_lines(0,0,-1,false,{'a','b','c'})
local tmp = vim.fn.tempname(); vim.cmd('write '..tmp); vim.g.__mg_test_path = tmp
local m = require('marker-groups.markers')
local add = m.add_marker('t1')
local list = m.get_current_buffer_markers()
local ts1 = list[#list].timestamp
require('marker-groups.persistence').save()
require('marker-groups').reload()
vim.wait(200)
if vim.g.__mg_test_path and vim.fn.filereadable(vim.g.__mg_test_path) == 1 then
  vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.__mg_test_path))
end
local list2 = require('marker-groups.markers').get_current_buffer_markers()
local ts2 = list2[#list2].timestamp
print('ts1='..tostring(ts1)..' ts2='..tostring(ts2)..' eq='..tostring(ts1==ts2))

