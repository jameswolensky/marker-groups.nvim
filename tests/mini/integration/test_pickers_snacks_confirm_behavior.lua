local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["confirm selects group without Snacks jump error (bounded)"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('marker-groups').setup({ picker = 'snacks' })]]

  local has_snacks = child.lua [[return pcall(require, 'snacks')]]
  if not has_snacks then
    child.stop()
    return
  end

  child.lua [[
    local groups = require('marker-groups.groups')
    groups.create_group('alpha')
  ]]

  child.lua [[require('marker-groups.pickers.snacks').show_groups()]]

  local ret = child.lua [[
    local Picker = require('snacks.picker.core.picker')
    local Actions = require('snacks.picker.core.actions')
    local snacks = require('snacks')
    local captured = {}
    local old_err = snacks.notify.error
    snacks.notify.error = function(msg, opts)
      table.insert(captured, tostring(msg))
      return old_err(msg, opts)
    end

    local start = vim.loop.hrtime()
    local p
    while (vim.loop.hrtime() - start) < 8e8 do -- 800ms budget
      local arr = Picker.get({ source = 'marker_groups' })
      p = arr[#arr]
      if p and p.list and p.list.items and #p.list.items > 0 then break end
      vim.wait(10, function() return false end)
    end
    if not p then return { ok = false, msg = 'picker not ready (timeout)' } end

    local acts = Actions.get(p)
    local ok, err = pcall(function()
      acts.confirm.action()
    end)
    vim.wait(50, function() return false end)
    local state = require('marker-groups.state')
    return { ok = ok, msg = tostring(err), active = state.get_active_group(), errors = captured }
  ]]

  MiniTest.expect.equality(true, ret and ret.ok)
  MiniTest.expect.equality("alpha", ret.active)
  MiniTest.expect.equality(0, #(ret.errors or {}))

  child.stop()
end

return T
