local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["snacks picker works with real plugin (no stubs)"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }

  local has_snacks = child.lua [[return pcall(require, 'snacks')]]
  if not has_snacks then
    child.stop()
    return
  end

  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('marker-groups').setup({ picker = 'snacks' })]]

  local ret = child.lua [[ 
    local ok, err = pcall(function()
      require('marker-groups.groups').create_group('dev')
      require('marker-groups.pickers.snacks').show_groups()
    end)
    return { ok = ok, msg = tostring(err) }
  ]]

  assert(ret and ret.ok == true, "snacks show_groups errored: " .. tostring(ret and ret.msg))
  child.stop()
end

return T
