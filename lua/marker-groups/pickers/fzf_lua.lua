local M = {}

local groups = require "marker-groups.groups"
local state = require "marker-groups.state"
local utils = require "marker-groups.pickers.utils"

function M.show_groups(opts)
  opts = opts or {}
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok or not fzf or type(fzf.fzf_exec) ~= "function" then
    vim.notify("fzf-lua not available", vim.log.levels.WARN)
    return
  end

  local info = groups.list_groups()
  local items, map = {}, {}
  for _, g in ipairs(info) do
    local display = groups.format_group_info(g, "short")
    table.insert(items, display)
    map[display] = g.name
  end

  if #items == 0 then
    vim.notify("No marker groups available", vim.log.levels.WARN)
    return
  end

  fzf.fzf_exec(items, {
    prompt = "Marker Groups> ",
    previewer = "builtin",
    preview = function(selected)
      local display = selected and selected[1]
      local name = display and map[display]
      if not name then
        return ""
      end
      -- regenerate group info via groups.list_groups
      local gi
      for _, info in ipairs(groups.list_groups()) do
        if info.name == name then
          gi = info
          break
        end
      end
      local lines = utils.generate_group_preview(gi or { name = name, marker_count = 0 })
      return table.concat(lines, "\n")
    end,
    actions = {
      ["default"] = function(selected)
        local display = selected and selected[1]
        if display and map[display] then
          local name = map[display]
          if groups.delete_group_with_confirmation then
            groups.delete_group_with_confirmation(name, { skip_confirmation = true })
          else
            groups.delete_group(name, true)
          end
          require("marker-groups.pickers.utils").show_notification("Deleted group: " .. name, vim.log.levels.INFO, 5000)
        end
      end,
    },
  })
end

function M.show_markers(opts)
  opts = opts or {}
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok or not fzf or type(fzf.fzf_exec) ~= "function" then
    vim.notify("fzf-lua not available", vim.log.levels.WARN)
    return
  end

  local active = state.get_active_group()
  if not active then
    vim.notify("No active group selected", vim.log.levels.WARN)
    return
  end
  local grp = state.get_group(active)
  local markers = (grp and grp.markers) or {}

  local items, map = {}, {}
  for _, m in ipairs(markers) do
    local file_name = vim.fn.fnamemodify(m.buffer_path, ":t")
    local line_info = m.start_line ~= m.end_line and (m.start_line .. "-" .. m.end_line) or m.start_line
    local display = string.format("%-20s %4s: %s", file_name, line_info, m.annotation)
    table.insert(items, display)
    map[display] = m
  end

  fzf.fzf_exec(items, {
    prompt = "Markers - " .. active .. "> ",
    previewer = "builtin",
    preview = function(selected)
      local display = selected and selected[1]
      local m = display and map[display]
      if not m then
        return ""
      end
      local data = utils.generate_marker_preview(m)
      return table.concat(data.content, "\n")
    end,
    actions = {},
  })
end

return M
