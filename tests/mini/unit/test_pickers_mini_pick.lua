local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["mini.pick backend detection honors picker = 'mini_pick'"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }

  local has_pick = child.lua [[return pcall(require, 'mini.pick')]]
  if not has_pick then
    child.stop()
    return
  end

  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('mini.pick').setup()]]
  child.lua [[require('marker-groups').setup({ picker = 'mini_pick' })]]
  child.lua [[require('marker-groups.pickers').setup({ picker = 'mini_pick' })]]

  local current = child.lua [[ local s=require('marker-groups.pickers').get_status(); return s.current_backend ]]
  assert(current == "mini_pick", "expected current_backend mini_pick, got " .. tostring(current))
  child.stop()
end

return T
