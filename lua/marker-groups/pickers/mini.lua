local M = {}

local feedback = require "marker-groups.feedback"
local state = require "marker-groups.state"
local groups = require "marker-groups.groups"

local function ensure()
  local ok, pick = pcall(require, "mini.pick")
  if not ok then
    feedback.warning("mini.pick", "mini.pick not available")
    return nil
  end
  return pick
end

function M.show_groups(opts)
  opts = opts or {}
  local pick = ensure()
  if not pick then
    return state.Result.error("mini.pick not available", "NO_MINI_PICK")
  end

  local infos = groups.list_groups()
  if #infos == 0 then
    feedback.warning("Groups", "No groups found")
    return state.Result.error("No groups", "NO_GROUPS")
  end

  local items = {}
  local name_by_text = {}
  for _, gi in ipairs(infos) do
    local text = groups.format_group_info(gi, "short")
    table.insert(items, { text = text, value = gi.name })
    name_by_text[text] = gi.name
  end

  pick.start {
    source = {
      items = vim.tbl_map(function(i)
        return i.text
      end, items),
      name = opts.prompt or "Select Marker Group",
      preview = function(item)
        local group_name = name_by_text[item]
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
      choose = function(item)
        for _, it in ipairs(items) do
          if it.text == item then
            groups.select_group(it.value)
            break
          end
        end
      end,
    },
  }

  return state.Result.ok { message = "mini.pick group picker opened" }
end

function M.show_markers(opts)
  opts = opts or {}
  local pick = ensure()
  if not pick then
    return state.Result.error("mini.pick not available", "NO_MINI_PICK")
  end

  local active = state.get_active_group()
  local group = state.get_group(active)
  if not group or not group.markers or #group.markers == 0 then
    feedback.warning("Markers", "No markers in active group")
    return state.Result.error("No markers", "NO_MARKERS")
  end

  local display = {}
  local map = {}
  for _, m in ipairs(group.markers) do
    local label = string.format("%s:%d %s", vim.fn.fnamemodify(m.buffer_path or "", ":t"), m.start_line, m.annotation)
    table.insert(display, label)
    map[label] = m
  end

  pick.start {
    source = {
      items = display,
      name = "Markers",
      choose = function(item)
        local m = map[item]
        if not m then
          return
        end
        vim.cmd("edit " .. vim.fn.fnameescape(m.buffer_path))
        pcall(vim.api.nvim_win_set_cursor, 0, { m.start_line, 0 })
      end,
    },
  }

  return state.Result.ok { message = "mini.pick marker picker opened" }
end

return M
