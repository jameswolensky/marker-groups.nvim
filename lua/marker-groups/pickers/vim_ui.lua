local M = {}

local state = require "marker-groups.state"
local groups = require "marker-groups.groups"
local utils = require "marker-groups.pickers.utils"

function M.show_groups(opts)
  opts = opts or {}
  local group_data = groups.list_groups()
  local items, map = {}, {}

  for _, info in ipairs(group_data) do
    local display = groups.format_group_info(info, "short")
    table.insert(items, display)
    map[display] = info.name
  end

  if #items == 0 then
    vim.notify("No marker groups available", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Select marker group:",
    format_item = function(item)
      return item
    end,
    kind = "marker_group",
  }, function(choice)
    if not choice then
      return
    end
    local name = map[choice]
    if name then
      if (opts and opts.action) == "delete" then
        if groups.delete_group_with_confirmation then
          groups.delete_group_with_confirmation(name, { skip_confirmation = true })
        else
          groups.delete_group(name, true)
        end
        require("marker-groups.pickers.utils").show_notification("Deleted group: " .. name, vim.log.levels.INFO, 5000)
      else
        groups.select_group(name)
        require("marker-groups.pickers.utils").show_notification("Selected group: " .. name, vim.log.levels.INFO, 3000)
      end
    end
  end)
end

function M.show_markers(opts)
  opts = opts or {}
  local active = state.get_active_group()
  if not active then
    vim.notify("No active group selected", vim.log.levels.WARN)
    return
  end

  local group = state.get_group(active)
  local markers = (group and group.markers) or {}
  if #markers == 0 then
    vim.notify("No markers in active group: " .. active, vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, marker in ipairs(markers) do
    local file_name = vim.fn.fnamemodify(marker.buffer_path, ":t")
    local line_info = marker.start_line
    if marker.start_line ~= marker.end_line then
      line_info = marker.start_line .. "-" .. marker.end_line
    end
    table.insert(items, string.format("%-20s %4s: %s", file_name, line_info, marker.annotation))
  end

  vim.ui.select(items, {
    prompt = "Navigate to marker:",
    format_item = function(item)
      return item
    end,
    kind = "marker_navigation",
  }, function(choice)
    return
  end)
end

return M
