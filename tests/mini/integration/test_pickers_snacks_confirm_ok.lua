local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["confirm action on group list selects group without error"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('marker-groups').setup({ picker = 'snacks' })]]

  local has_snacks = child.lua [[return pcall(require, 'snacks')]]
  if not has_snacks then
    child.stop()
    return
  end

  child.lua [[require('marker-groups.groups').create_group('alpha')]]
  child.lua [[require('marker-groups.pickers.snacks').show_groups()]]

  local ret = child.lua [[
    local Picker = require('snacks.picker.core.picker')
    local Actions = require('snacks.picker.core.actions')
    local deadline = vim.loop.hrtime() + 1e9
    local p
    while vim.loop.hrtime() < deadline do
      p = Picker.get({ source = 'marker_groups' })[#Picker.get({ source = 'marker_groups' })]
      if p and p.list and p.list.items and #p.list.items > 0 then break end
      vim.wait(20, function() return false end)
    end
    if not p then return { ok = false, msg = 'picker not ready (timeout)' } end
    local acts = Actions.get(p)
    local ok, err = pcall(function()
      acts.confirm.action()
    end)
    local state = require('marker-groups.state')
    return { ok = ok, msg = tostring(err), active = state.get_active_group() }
  ]]

  assert(ret and ret.ok == true, "expected confirm to succeed, got: " .. tostring(ret and ret.msg))
  assert(ret.active == "alpha", "expected active group to be alpha, got: " .. tostring(ret.active))
  child.stop()
end

return T
