local M = {}

local feedback = require "marker-groups.feedback"
local state = require "marker-groups.state"
local groups = require "marker-groups.groups"

local function ensure()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks or not snacks.picker then
    feedback.warning("Snacks Picker", "snacks.nvim picker not available")
    return nil
  end
  return snacks
end

function M.show_groups(opts)
  opts = opts or {}
  local snacks = ensure()
  if not snacks then
    return state.Result.error("snacks.nvim not available", "NO_SNACKS")
  end

  local infos = groups.list_groups()
  if #infos == 0 then
    feedback.warning("Groups", "No groups found")
    return state.Result.error("No groups", "NO_GROUPS")
  end

  local items = {}
  for _, gi in ipairs(infos) do
    table.insert(items, {
      text = groups.format_group_info(gi, "short"),
      value = gi.name,
    })
  end

  snacks.picker.open {
    title = opts.prompt or "Select Marker Group",
    items = items,
    action = function(item)
      if item and item.value then
        groups.select_group(item.value)
      end
    end,
  }

  return state.Result.ok { message = "Snacks group picker opened" }
end

function M.show_markers(opts)
  opts = opts or {}
  local snacks = ensure()
  if not snacks then
    return state.Result.error("snacks.nvim not available", "NO_SNACKS")
  end

  local active = state.get_active_group()
  local group = state.get_group(active)
  if not group or not group.markers or #group.markers == 0 then
    feedback.warning("Markers", "No markers in active group")
    return state.Result.error("No markers", "NO_MARKERS")
  end

  local items = {}
  for _, m in ipairs(group.markers) do
    table.insert(items, {
      text = string.format("%s:%d %s", vim.fn.fnamemodify(m.buffer_path or "", ":t"), m.start_line, m.annotation),
      value = m,
    })
  end

  snacks.picker.open {
    title = "Markers",
    items = items,
    action = function(item)
      local m = item and item.value
      if not m then
        return
      end
      vim.cmd("edit " .. vim.fn.fnameescape(m.buffer_path))
      pcall(vim.api.nvim_win_set_cursor, 0, { m.start_line, 0 })
    end,
  }

  return state.Result.ok { message = "Snacks marker picker opened" }
end

return M
