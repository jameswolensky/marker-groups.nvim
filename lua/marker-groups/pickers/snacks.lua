local M = {}

local feedback = require "marker-groups.feedback"
local state = require "marker-groups.state"
local groups = require "marker-groups.groups"

local function ensure()
  local ok_snacks, snacks = pcall(require, "snacks")
  if not ok_snacks then
    feedback.warning("Snacks Picker", "snacks.nvim not available")
    return nil, nil
  end

  -- Try both field and module forms
  local picker = snacks and snacks.picker or nil
  local ok_mod, picker_mod = pcall(require, "snacks.picker")
  if ok_mod and picker_mod then
    picker = picker or picker_mod
  end

  if not picker then
    feedback.warning("Snacks Picker", "picker API not found (snacks.picker)")
    return snacks, nil
  end

  return snacks, picker
end

function M.show_groups(opts)
  opts = opts or {}
  local snacks, picker = ensure()
  if not snacks or not picker then
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
    preview = function(item, _)
      local group_name = (type(item) == "table" and item.value) or by_text[item]
      local state_data = require("marker-groups.state").get_state()
      local group_data = state_data and state_data.marker_groups and state_data.marker_groups[group_name]
      local lines = {
        "📁 Group: " .. (group_name or ""),
        "═══════════════════════════════════",
        "",
      }
      if group_data and group_data.markers and #group_data.markers > 0 then
        table.insert(lines, "📌 Markers:")
        local max = math.min(5, #group_data.markers)
        for i = 1, max do
          local m = group_data.markers[i]
          local file_name = vim.fn.fnamemodify(m.buffer_path or "", ":t")
          local line_info = (m.start_line == m.end_line) and tostring(m.start_line)
            or (m.start_line .. "-" .. m.end_line)
          table.insert(
            lines,
            string.format("  %d. %s:%s - %s", i, file_name, line_info, string.sub(m.annotation or "", 1, 30))
          )
        end
        if #group_data.markers > 5 then
          table.insert(lines, "  ... and " .. (#group_data.markers - 5) .. " more")
        end
      else
        table.insert(lines, "📝 No markers in this group")
      end
      return table.concat(lines, "\n")
    end,
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

  if type(picker) == "function" then
    picker(picker_opts)
  elseif type(picker) == "table" and type(picker.open) == "function" then
    picker.open(picker_opts)
  elseif type(picker) == "table" and type(picker.pick) == "function" then
    picker.pick(picker_opts)
  elseif type(picker) == "table" and type(picker.start) == "function" then
    picker.start(picker_opts)
  else
    feedback.warning("Snacks Picker", "Unsupported snacks.picker API")
    return state.Result.error("Unsupported snacks.picker API", "SNACKS_API")
  end

  return state.Result.ok { message = "Snacks group picker opened" }
end

function M.show_markers(opts)
  opts = opts or {}
  local snacks, picker = ensure()
  if not snacks or not picker then
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
    table.insert(items, {
      text = text,
      value = m,
      file = m.buffer_path, -- enable Snacks preview
      lnum = m.start_line,
      col = 1,
    })
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

  if type(picker) == "function" then
    picker(picker_opts)
  elseif type(picker) == "table" and type(picker.open) == "function" then
    picker.open(picker_opts)
  elseif type(picker) == "table" and type(picker.pick) == "function" then
    picker.pick(picker_opts)
  elseif type(picker) == "table" and type(picker.start) == "function" then
    picker.start(picker_opts)
  else
    feedback.warning("Snacks Picker", "Unsupported snacks.picker API")
    return state.Result.error("Unsupported snacks.picker API", "SNACKS_API")
  end

  return state.Result.ok { message = "Snacks marker picker opened" }
end

return M
