local MiniTest = require "mini.test"

local T = MiniTest.new_set()

local function setup_child()
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua [[require('marker-groups').setup({ picker = 'snacks' })]]
  return child
end

T["groups preview shows only markers or 'No markers in group'"] = function()
  local child = setup_child()
  local has_snacks = child.lua [[return pcall(require, 'snacks')]]
  if not has_snacks then
    child.stop()
    return
  end

  -- Prepare two groups: g_empty (no markers), g_pop (with 2 markers)
  local tmp = child.lua [[return vim.fn.tempname()]]
  child.lua(([=[
    local groups = require('marker-groups.groups')
    local state = require('marker-groups.state')
    groups.create_group('g_empty')
    groups.create_group('g_pop')
    state.set_active_group('g_pop')
    -- create a temp file with content for markers
    local path = %q
    vim.fn.writefile({ 'line one', 'line two', 'line three' }, path)
    -- add two markers to g_pop
    state.add_marker({ buffer_path = path, start_line = 1, end_line = 1, annotation = 'A1' }, 'g_pop')
    state.add_marker({ buffer_path = path, start_line = 3, end_line = 3, annotation = 'A3' }, 'g_pop')
  ]=]):format(tmp))

  -- Open groups picker
  child.lua [[require('marker-groups.pickers.snacks').show_groups()]]

  -- Wait for picker
  child.lua [[
    local Picker = require('snacks.picker.core.picker')
    local deadline = vim.loop.hrtime() + 2e9
    while vim.loop.hrtime() < deadline do
      local p = Picker.get({ source = 'marker_groups' })[#Picker.get({ source = 'marker_groups' })]
      if p and p.preview and p.preview.buf and p.list and p.list.items and #p.list.items > 0 then break end
      vim.wait(50, function() return false end)
    end
  ]]

  -- Helper to run preview for a given group name and collect preview lines
  local function preview_for(group)
    return child.lua(([=[
      local Picker = require('snacks.picker.core.picker')
      local p = Picker.get({ source = 'marker_groups' })[#Picker.get({ source = 'marker_groups' })]
      local buf = p.preview and (p.preview.buf or (p.preview.win and p.preview.win.buf))
      local item
      for _, it in ipairs(p.list.items or {}) do
        if (it.name or it.value or it.text) == %q then item = it; break end
      end
      if not (buf and item) then return { ok = false, msg = 'picker not ready' } end
      local ok, err = pcall(function()
        p.opts.preview({ buf = buf, item = item })
      end)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      return { ok = ok, msg = tostring(err), lines = lines }
    ]=]):format(group))
  end

  -- g_empty should show "No markers in group" and not contain Statistics/Actions
  local empty_res = preview_for "g_empty"
  assert(empty_res and empty_res.ok, "preview failed for g_empty: " .. tostring(empty_res and empty_res.msg))
  local joined_empty = table.concat(empty_res.lines, "\n")
  assert(joined_empty:find "No markers in group", "expected empty message, got:\n" .. joined_empty)
  assert(not joined_empty:find "📊 Statistics", "should not show Statistics")
  assert(not joined_empty:find "🎯 Actions", "should not show Actions")

  -- g_pop should list markers, not Statistics/Actions
  local pop_res = preview_for "g_pop"
  assert(pop_res and pop_res.ok, "preview failed for g_pop: " .. tostring(pop_res and pop_res.msg))
  local joined_pop = table.concat(pop_res.lines, "\n")
  assert(joined_pop:find "A1" and joined_pop:find "A3", "expected markers listed, got:\n" .. joined_pop)
  assert(not joined_pop:find "📊 Statistics", "should not show Statistics in populated group")
  assert(not joined_pop:find "🎯 Actions", "should not show Actions in populated group")

  child.stop()
end

return T
