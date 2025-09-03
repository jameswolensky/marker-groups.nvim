local M = {}

local groups = require "marker-groups.groups"
local state = require "marker-groups.state"
local utils = require "marker-groups.pickers.utils"

local function coerce_name(item)
  if type(item) == "string" then
    return item
  end
  if type(item) == "table" then
    if type(item.value) == "string" then
      return item.value
    end
    if type(item.name) == "string" then
      return item.name
    end
    if type(item.text) == "string" then
      return item.text
    end
  end
  return nil
end

function M.show_groups(opts)
  opts = opts or {}
  local ok, pick = pcall(require, "mini.pick")
  if not ok or not pick or type(pick.start) ~= "function" then
    vim.notify("mini.pick not available", vim.log.levels.WARN)
    return
  end

  local info = groups.list_groups()
  info = utils.filter_groups_for_action(info, opts)
  local items = {}
  local by_name = {}
  for _, g in ipairs(info) do
    local name = tostring(g.name or "")
    local text = groups.format_group_info(g, "short")
    table.insert(items, { text = text, value = name, name = name })
    by_name[name] = g
  end

  if #items == 0 then
    vim.notify(utils.empty_groups_message(opts), vim.log.levels.WARN)
    return
  end

  local preview = function(buf_id, item)
    local name = coerce_name(item)
    if not name then
      return
    end
    local data = utils.generate_group_markers_code_preview(name, { max_width = 70 })
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, data.content)
    vim.bo[buf_id].filetype = data.filetype or "text"
  end

  local choose = function(item)
    local name = coerce_name(item)
    if not name or name == "" then
      return
    end
    if opts.action == "delete" then
      if groups.delete_group_with_confirmation then
        groups.delete_group_with_confirmation(name, { skip_confirmation = true })
      else
        groups.delete_group(name, true)
      end
      utils.show_notification("Deleted group: " .. tostring(name), vim.log.levels.INFO, 5000)
    else
      groups.select_group(name)
      utils.show_notification("Selected group: " .. tostring(name), vim.log.levels.INFO, 3000)
    end
    pick.stop()
    return true
  end

  pick.start { source = { name = "Marker Groups mini.pick", items = items, preview = preview, choose = choose } }
end

function M.show_markers(opts)
  opts = opts or {}
  local ok, pick = pcall(require, "mini.pick")
  if not ok or not pick or type(pick.start) ~= "function" then
    vim.notify("mini.pick not available", vim.log.levels.WARN)
    return
  end

  local active = state.get_active_group()
  if not active then
    vim.notify("No active group selected", vim.log.levels.WARN)
    return
  end

  local grp = state.get_group(active)
  local markers = (grp and grp.markers) or {}
  local items = {}
  for _, m in ipairs(markers) do
    local file_name = vim.fn.fnamemodify(m.buffer_path, ":t")
    local line_info = m.start_line ~= m.end_line and (m.start_line .. "-" .. m.end_line) or m.start_line
    local text = string.format("%-20s %4s: %s", file_name, line_info, m.annotation)
    table.insert(items, { text = text, marker = m })
  end

  local preview = function(buf_id, item)
    local m = type(item) == "table" and item.marker or nil
    if not m then
      return
    end
    local data = utils.generate_marker_preview(m)
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, data.content)
    vim.bo[buf_id].filetype = data.filetype or "text"
  end

  local choose = function(item)
    return true
  end

  pick.start { source = { name = "Markers - " .. active, items = items, preview = preview, choose = choose } }
end

return M
