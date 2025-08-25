local M = {}

local feedback = require "marker-groups.feedback"
local state = require "marker-groups.state"
local groups = require "marker-groups.groups"

local function ensure()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks then
    feedback.warning("Snacks Picker", "snacks.nvim not available")
    return nil
  end
  if not snacks.picker then
    feedback.warning("Snacks Picker", "snacks.picker not available")
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
  local by_text = {}
  for _, gi in ipairs(infos) do
    local text = groups.format_group_info(gi, "short")
    table.insert(items, { text = text, value = gi.name })
    by_text[text] = gi.name
  end

  local picker_opts = {
    title = opts.prompt or "Select Marker Group",
    items = items,
    action = function(item)
      if not item then
        return
      end
      if type(item) == "table" and item.value then
        groups.select_group(item.value)
        return
      end
      if type(item) == "string" then
        local name = by_text[item]
        if name then
          groups.select_group(name)
        end
      end
    end,
  }

  if type(snacks.picker) == "function" then
    snacks.picker(picker_opts)
  elseif snacks.picker.open then
    snacks.picker.open(picker_opts)
  else
    feedback.warning("Snacks Picker", "Unsupported snacks.picker API")
    return state.Result.error("Unsupported snacks.picker API", "SNACKS_API")
  end

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
  local by_text = {}
  for _, m in ipairs(group.markers) do
    local text = string.format("%s:%d %s", vim.fn.fnamemodify(m.buffer_path or "", ":t"), m.start_line, m.annotation)
    table.insert(items, { text = text, value = m })
    by_text[text] = m
  end

  local picker_opts = {
    title = "Markers",
    items = items,
    action = function(item)
      local m = nil
      if type(item) == "table" and item.value then
        m = item.value
      elseif type(item) == "string" then
        m = by_text[item]
      end
      if not m then
        return
      end
      vim.cmd("edit " .. vim.fn.fnameescape(m.buffer_path))
      pcall(vim.api.nvim_win_set_cursor, 0, { m.start_line, 0 })
    end,
  }

  if type(snacks.picker) == "function" then
    snacks.picker(picker_opts)
  elseif snacks.picker.open then
    snacks.picker.open(picker_opts)
  else
    feedback.warning("Snacks Picker", "Unsupported snacks.picker API")
    return state.Result.error("Unsupported snacks.picker API", "SNACKS_API")
  end

  return state.Result.ok { message = "Snacks marker picker opened" }
end

return M
