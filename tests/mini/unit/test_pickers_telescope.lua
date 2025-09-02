local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["telescope picker works with real plugin if available (no stubs)"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  local has_telescope = child.lua [[return pcall(require, 'telescope')]]
  if not has_telescope then
    child.stop()
    return
  end
  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('marker-groups').setup({ picker = 'telescope' })]]
  local ret = child.lua [[ 
    local ok, err = pcall(function()
      require('marker-groups.groups').create_group('dev')
      require('marker-groups.pickers').show_groups()
    end)
    return { ok = ok, msg = tostring(err) }
  ]]
  assert(ret and ret.ok == true, "telescope picker errored: " .. tostring(ret and ret.msg))
  child.stop()
end

return T
