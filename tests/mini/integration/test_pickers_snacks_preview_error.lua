local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["snacks group preview errors with non-modifiable buffer (repro)"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }

  local has_snacks = child.lua [[return pcall(require, 'snacks')]]
  assert(has_snacks, "snacks not available on runtimepath for repro")

  -- Load our plugin
  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('marker-groups').setup({ picker = 'snacks' })]]

  -- Ensure a group exists and open the picker, then wait for picker readiness
  child.lua [[require('marker-groups.groups').create_group('default')]]
  child.lua [[require('marker-groups.pickers.snacks').show_groups()]]
  child.lua [[
    local Picker = require('snacks.picker.core.picker')
    local deadline = vim.loop.hrtime() + 2e9 -- 2000ms
    while vim.loop.hrtime() < deadline do
      local pickers = Picker.get({ source = 'marker_groups' })
      local p = pickers[#pickers]
      if p and p.preview and p.preview.win and p.preview.buf and p.list and p.list.items and #p.list.items > 0 then
        break
      end
      vim.wait(50, function() return false end)
    end
  ]]

  local ret = child.lua [[
    local Picker = require('snacks.picker.core.picker')
    local pickers = Picker.get({ source = 'marker_groups' })
    local p = pickers[#pickers] or Picker.get()[#Picker.get()]
    if not p then return { ok = false, msg = 'no active picker' } end
    local buf = p.preview and p.preview.buf or (p.preview and p.preview.win and p.preview.win.buf)
    local item = p.list and p.list.items and p.list.items[1]
    if not (buf and item) then
      return { ok = false, msg = 'missing buf or item', has_buf = buf ~= nil, has_item = item ~= nil }
    end
    local ok, err = pcall(function()
      -- Make buffer non-modifiable to simulate observed condition, then call preview
      vim.bo[buf].modifiable = false
      p.opts.preview({ buf = buf, item = item })
    end)
    return { ok = ok, msg = tostring(err), modifiable = vim.bo[buf].modifiable, item = item }
  ]]

  -- Expectation for fix: preview should succeed even if buffer was non-modifiable
  assert(ret and ret.ok == true, "expected preview to succeed, got: " .. tostring(ret and ret.msg))
end

return T
