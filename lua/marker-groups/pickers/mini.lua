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
  for _, gi in ipairs(infos) do
    table.insert(items, { text = groups.format_group_info(gi, "short"), value = gi.name })
  end

  pick.start {
    source = {
      items = vim.tbl_map(function(i)
        return i.text
      end, items),
      name = opts.prompt or "Select Marker Group",
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
