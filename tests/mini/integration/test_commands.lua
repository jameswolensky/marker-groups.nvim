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

T['group management / MarkerGroupsCreate adds group'] = function()
  with_child(function(child)
    child.lua([[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_it_cmd', log_level = 'error' })]])
    child.lua([[require('marker-groups.state').initialize(require('marker-groups.config').get())]])
    child.lua([[require('marker-groups.commands').setup()]])

    child.cmd('MarkerGroupsCreate test-group-cmd')

    local ok, exists = child.lua([[local s=require('marker-groups.state'); return s.get_group('test-group-cmd')~=nil]])
    expect_truthy(ok)
    expect_truthy(exists)
  end)
end

T['marker commands / MarkerAdd adds marker to current buffer'] = function()
  with_child(function(child)
    child.lua([[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_it_cmd2', log_level = 'error' })]])
    child.lua([[require('marker-groups.state').initialize(require('marker-groups.config').get())]])
    child.lua([[require('marker-groups.commands').setup()]])

    child.lua([[vim.cmd('enew')]])
    child.lua([[vim.api.nvim_buf_set_lines(0,0,-1,false,{'one','two','three'})]])
    child.lua([[local tmp=vim.fn.tempname(); vim.cmd('write '..tmp)]])
    child.lua([[vim.api.nvim_win_set_cursor(0,{2,0})]])

    child.cmd('MarkerAdd added-via-command')

    local ok, count = child.lua([[local m=require('marker-groups.markers'); return #m.get_current_buffer_markers()]])
    expect_truthy(ok)
    MiniTest.expect.equality(count, 1)

    local ok2, ann = child.lua([[local m=require('marker-groups.markers'); local list=m.get_current_buffer_markers(); return list[1].annotation]])
    expect_truthy(ok2)
    MiniTest.expect.equality(ann, 'added-via-command')
  end)
end

return T


