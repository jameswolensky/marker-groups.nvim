-- Project-specific runner for mini.test

-- Load minimal init
vim.cmd('luafile ' .. vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h') .. '/minimal_init.lua')

local MiniTest = require 'mini.test'

-- Configure collection to discover tests in tests/**/test_*.lua
MiniTest.setup({
  collect = {
    emulate_busted = true,
    find_files = function()
      return vim.fn.globpath('tests', '**/test_*.lua', true, true)
    end,
  },
  execute = {
    stop_on_error = false,
  },
})

MiniTest.run()


