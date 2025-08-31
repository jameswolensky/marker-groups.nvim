local MiniTest = require 'mini.test'

local T = MiniTest.new_set()

local expect_truthy = MiniTest.new_expectation('truthy', function(x) return not not x end, function(x) return 'Object: ' .. vim.inspect(x) end)

local function with_child(fn)
  local child = MiniTest.new_child_neovim()
  child.restart({ '--headless', '-u', 'scripts/minimal_init.lua' })
  local ok, err = pcall(fn, child)
  child.stop()
  if not ok then error(err) end
end

T['json autosave / add, edit, delete reflect in file'] = function()
  with_child(function(child)
    child.lua([[require('marker-groups').setup({ data_dir = vim.fn.stdpath('data') .. '/marker-groups', log_level='error' })]])
    child.lua([[require('marker-groups.state').initialize(require('marker-groups.config').get())]])

    child.lua([[
      local data_file = vim.fn.stdpath('data') .. '/marker-groups/marker-groups.json'
      pcall(os.remove, data_file)
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0,0,-1,false,{'hello','world'})
      local tmp = vim.fn.tempname(); vim.cmd('write '..tmp)
      vim.api.nvim_win_set_cursor(0,{2,0})
      local m = require('marker-groups.markers')
      local a1 = m.add_marker('m1')
    ]])

    child.lua([[vim.wait(150)]])
    local s1 = child.lua([[local f=io.open(vim.fn.stdpath('data')..'/marker-groups/marker-groups.json','r'); if not f then return nil end; local s=f:read('*a'); f:close(); return s]])
    expect_truthy(type(s1)=='string' and s1:find('"annotation":"m1"')~=nil)

    child.lua([[
      local m = require('marker-groups.markers')
      local list = m.get_current_buffer_markers()
      local id = list[#list].id
      m.edit_marker(id, 'm1-edit')
    ]])
    child.lua([[vim.wait(150)]])
    local s2 = child.lua([[local f=io.open(vim.fn.stdpath('data')..'/marker-groups/marker-groups.json','r'); local s=f:read('*a'); f:close(); return s]])
    expect_truthy(type(s2)=='string' and s2:find('"annotation":"m1%-edit"')~=nil)

    child.lua([[
      local m = require('marker-groups.markers')
      local list = m.get_current_buffer_markers()
      local id = list[#list].id
      m.delete_marker(id)
    ]])
    child.lua([[vim.wait(150)]])
    local s3 = child.lua([[local f=io.open(vim.fn.stdpath('data')..'/marker-groups/marker-groups.json','r'); local s=f:read('*a'); f:close(); return s]])
    expect_truthy(type(s3)=='string' and s3:find('"annotation":"m1%-edit"')==nil)
  end)
end

return T


