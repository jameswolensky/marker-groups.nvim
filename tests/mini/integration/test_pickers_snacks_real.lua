local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["Snacks core reproduces line 101 concat error with table opts.source"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }

  local ok = child.lua [[return pcall(require, 'snacks')]]
  assert(ok, "snacks not available on runtimepath")

  local ret = child.lua [[ 
    local PickerCore = require('snacks.picker.core.picker')
    local function run()
      PickerCore.new({ source = { name = 'marker_groups', items = { 'dev' } }, items = { 'dev' } })
    end
    local ok, err = pcall(run)
    return { ok = ok, msg = tostring(err) }
  ]]

  assert(ret and ret.ok == false, "expected PickerCore.new to error")
  assert(type(ret.msg) == "string", "expected error message string")
  assert(ret.msg:match "attempt to concatenate a table value", "expected concat error, got: " .. ret.msg)

  child.stop()
end

return T
