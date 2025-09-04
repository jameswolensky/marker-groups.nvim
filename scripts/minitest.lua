vim.cmd('luafile ' .. vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h') .. '/minimal_init.lua')

local MiniTest = require 'mini.test'

local mode = vim.env.MODE or 'all'
local test_file = vim.env.TEST_FILE
local base = 'tests/mini'

local function find_files_by_mode()
  if test_file and test_file ~= '' then
    return { test_file }
  end
  if mode == 'unit' then
    return vim.fn.globpath(base .. '/unit', '**/test_*.lua', true, true)
  elseif mode == 'integration' then
    return vim.fn.globpath(base .. '/integration', '**/test_*.lua', true, true)
  else
    return vim.fn.globpath(base, '**/test_*.lua', true, true)
  end
end

MiniTest.setup({
  collect = {
    emulate_busted = true,
    find_files = find_files_by_mode,
  },
  execute = { stop_on_error = false },
})

if test_file and test_file ~= '' then
  MiniTest.run_file(test_file)
else
  MiniTest.run()
end


