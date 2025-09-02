local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["left list shows plain group names only"] = function()
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
    groups.create_group('beta')
  ]]

  child.lua [[require('marker-groups.pickers.snacks').show_groups()]]

  local ret = child.lua [[
    local Picker = require('snacks.picker.core.picker')
    local deadline = vim.loop.hrtime() + 2e9
    local p
    while vim.loop.hrtime() < deadline do
      p = Picker.get({ source = 'marker_groups' })[#Picker.get({ source = 'marker_groups' })]
      if p and p.list and p.list.items and #p.list.items >= 2 then break end
      vim.wait(50, function() return false end)
    end
    if not p then return { ok = false, msg = 'picker not ready' } end
    local names = {}
    for _, it in ipairs(p.list.items) do
      local name = (it.name or it.value or it.text)
      table.insert(names, tostring(name))
    end
    return { ok = true, items = names }
  ]]

  assert(ret and ret.ok, "picker not ready: " .. tostring(ret and ret.msg))
  local joined = table.concat(ret.items, ",")
  -- Expect plain names, not formatted counts or decorations
  assert(joined:find "alpha", "missing alpha in items: " .. joined)
  assert(joined:find "beta", "missing beta in items: " .. joined)
  assert(not joined:find "%(", "items should not include counts/parentheses: " .. joined)

  child.stop()
end

return T
