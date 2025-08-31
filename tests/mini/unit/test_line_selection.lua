local MiniTest = require 'mini.test'

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      package.loaded['marker-groups'] = nil
      package.loaded['marker-groups.line_selection'] = nil
      require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ls', keymaps = { enabled = false }, log_level = 'error' })
    end,
  },
})

T['returns cursor line for normal mode'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c' })
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  local ls = require('marker-groups.line_selection')
  local r = ls.make_range()
  MiniTest.expect.equality({ lstart = 2, lend = 2 }, { lstart = r.lstart, lend = r.lend })
end

T['returns visual range for visual mode'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c', 'd' })
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd('normal! vjj')
  local ls = require('marker-groups.line_selection')
  local r = ls.make_range()
  MiniTest.expect.equality(true, (r.lstart >= 2 and r.lend >= r.lstart))
end

return T


