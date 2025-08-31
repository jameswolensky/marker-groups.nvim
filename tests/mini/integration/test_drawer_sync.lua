local MiniTest = require "mini.test"

local T = MiniTest.new_set()

local function with_child(fn)
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  local ok, err = pcall(fn, child)
  child.stop()
  if not ok then
    error(err)
  end
end

T["drawer sync / deleting from drawer removes buffer marker"] = function()
  with_child(function(child)
    child.lua [[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_drawer', log_level='error' })]]
    child.lua [[require('marker-groups.state').initialize(require('marker-groups.config').get())]]

    local count = child.lua [[
      local drawer = require('marker-groups.ui.drawer')
      local markers = require('marker-groups.markers')
      local state = require('marker-groups.state')
      local groups = require('marker-groups.groups')
      groups.create_group('sync_test_group')
      groups.select_group('sync_test_group')
      local buf = vim.api.nvim_create_buf(false,true)
      vim.api.nvim_buf_set_lines(buf,0,-1,false,{'function test()','  -- marker','  return 1','end'})
      local path = vim.fn.tempname()..'.lua'; vim.api.nvim_buf_set_name(buf,path)
      local res = state.add_marker({ buffer_path = path, start_line=2, end_line=2, annotation='X' }, 'sync_test_group')
      local list = markers.list_markers('sync_test_group', { buffer_path = path })
      local mock_marker_positions = { [5] = list[1] }
      local owiv = vim.api.nvim_win_is_valid; vim.api.nvim_win_is_valid=function() return true end
      local owgc = vim.api.nvim_win_get_cursor; vim.api.nvim_win_get_cursor=function() return {5,0} end
      local oref = drawer.refresh_current_drawer; drawer.refresh_current_drawer=function() end
      drawer.delete_current_marker(1000, mock_marker_positions)
      local updated = markers.list_markers('sync_test_group', { buffer_path = path })
      vim.api.nvim_win_is_valid = owiv; vim.api.nvim_win_get_cursor = owgc; drawer.refresh_current_drawer = oref
      vim.api.nvim_buf_delete(buf,{force=true})
      return #updated
    ]]
    MiniTest.expect.equality(count, 0)
  end)
end

return T
