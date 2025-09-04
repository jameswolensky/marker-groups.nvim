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

T["extmark recreation / survives sync, save, reload"] = function()
  with_child(function(child)
    child.lua [[vim.g.__mg_force_persist = true; require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ext', log_level='error' })]]
    child.lua [[require('marker-groups.state').initialize(require('marker-groups.config').get())]]

    child.lua [[
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0,0,-1,false,{'l1','l2','l3','l4','l5','l6','l7'})
      local tmp = vim.fn.tempname(); vim.cmd('write '..tmp); vim.g.__mg_test_path = tmp
      local m = require('marker-groups.markers')
      local s = require('marker-groups.state')
      local add1 = m.add_marker_range(1,6,'multi')
      local add2 = m.add_marker_range(7,7,'single')
      local list = m.list_markers(nil, { buffer_path = tmp })
      local multi
      for _, mm in ipairs(list) do if mm.annotation=='multi' then multi=mm; break end end
      if multi then s.update_marker(multi.id, { extmark_id = 9999999 }) end
      m.sync_extmarks(0)
      require('marker-groups.persistence').save()
    ]]

    child.lua [[
      require('marker-groups').reload()
      vim.wait(200)
      if vim.g.__mg_test_path and vim.fn.filereadable(vim.g.__mg_test_path) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.__mg_test_path))
      end
      local m = require('marker-groups.markers')
      m.refresh_extmarks(0)
      m.sync_extmarks(0)
      vim.wait(50)
    ]]

    local counts = child.lua [=[
      local m = require('marker-groups.markers')
      local buf = vim.api.nvim_get_current_buf()
      m.refresh_extmarks(buf)
      local list = m.get_current_buffer_markers()
      local found_multi, found_single = false, false
      for _, mm in ipairs(list) do
        if mm.start_line==1 and mm.end_line==6 then found_multi=true end
        if mm.start_line==7 and mm.end_line==7 then found_single=true end
      end
      return { #list, found_multi, found_single }
    ]=]
    MiniTest.expect.equality(counts[1] >= 2, true)
    MiniTest.expect.equality(counts[2], true)
    MiniTest.expect.equality(counts[3], true)
  end)
end

return T
