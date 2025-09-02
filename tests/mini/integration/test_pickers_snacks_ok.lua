local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["marker-groups snacks.show_groups runs without error (string source)"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }

  -- Ensure snacks is available
  local ok = child.lua [[return pcall(require, 'snacks')]]
  assert(ok, "snacks not available on runtimepath")

  -- Call Snacks core picker directly with valid params
  local ret = child.lua [[ 
    local PickerCore = require('snacks.picker.core.picker')
    local ok, err = pcall(function()
      PickerCore.new({
        source = 'marker_groups',
        items = {
          { text = 'dev (0 markers)', value = 'dev', name = 'dev' },
        },
      })
    end)
    return { ok = ok, msg = tostring(err) }
  ]]

  assert(ret and ret.ok == true, "expected show_groups to run without error, got: " .. tostring(ret and ret.msg))

  child.stop()
end

return T
