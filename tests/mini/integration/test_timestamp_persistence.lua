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

T["timestamps persist and only change on edit"] = function()
  with_child(function(child)
    child.lua [[
      vim.g.__mg_force_persist = true
      local dd = vim.fn.tempname() .. '_mg_time'
      require('marker-groups').setup({ data_dir = dd, log_level='error' })
      require('marker-groups.state').initialize(require('marker-groups.config').get())
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0,0,-1,false,{'a','b','c'})
      local tmp = vim.fn.tempname(); vim.cmd('write '..tmp); vim.g.__mg_test_path = tmp
      local m = require('marker-groups.markers')
      local add = m.add_marker('t1')
    ]]

    local ts1 = child.lua [[
      local m = require('marker-groups.markers')
      local list = m.get_current_buffer_markers()
      return list[#list].timestamp
    ]]

    child.lua [[require('marker-groups.persistence').save()]]

    local ts2 = child.lua [[
      require('marker-groups').reload()
      vim.wait(200)
      if vim.g.__mg_test_path and vim.fn.filereadable(vim.g.__mg_test_path) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.__mg_test_path))
      end
      local m = require('marker-groups.markers')
      local list = m.get_current_buffer_markers()
      return list[#list].timestamp
    ]]

    MiniTest.expect.equality(ts2, ts1)

    local ts3 = child.lua [[
      vim.api.nvim_buf_set_lines(0,0,0,false,{'x'})
      local m = require('marker-groups.markers')
      m.sync_extmarks(0)
      local list = m.get_current_buffer_markers()
      return list[#list].timestamp
    ]]

    MiniTest.expect.equality(ts3, ts2)

    local changed = child.lua [[
      local m = require('marker-groups.markers')
      local list = m.get_current_buffer_markers()
      local id = list[#list].id
      m.edit_marker(id, 't1-edit')
      local list2 = m.get_current_buffer_markers()
      return list2[#list2].timestamp ~= list[#list].timestamp
    ]]

    MiniTest.expect.equality(changed, true)
  end)
end

return T
