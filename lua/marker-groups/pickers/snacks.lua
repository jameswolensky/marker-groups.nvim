local M = {}

local groups = require "marker-groups.groups"
local state = require "marker-groups.state"
local utils = require "marker-groups.pickers.utils"

function M.show_groups(opts)
  opts = opts or {}
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks or not snacks.picker then
    vim.notify("Snacks picker not available", vim.log.levels.WARN)
    return
  end

  local info = groups.list_groups()
  local items = {}
  for _, g in ipairs(info) do
    table.insert(items, { text = groups.format_group_info(g, "short"), name = g.name })
  end

  if #items == 0 then
    vim.notify("No marker groups available", vim.log.levels.WARN)
    return
  end

  snacks.picker {
    source = { name = "marker_groups", items = items },
    prompt = "Marker Groups> ",
    format = function(item)
      return item.text
    end,
    preview = function(ctx)
      local name = ctx.item and ctx.item.name
      if not name then
        return true
      end
      local info = nil
      for _, g in ipairs(info or {}) do
        if g.name == name then
          info = g
          break
        end
      end
      -- get fresh info via groups.list_groups
      local list = groups.list_groups()
      for _, gi in ipairs(list) do
        if gi.name == name then
          info = gi
          break
        end
      end
      local lines = utils.generate_group_preview(info or { name = name, marker_count = 0 })
      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
      vim.bo[ctx.buf].filetype = "markdown"
      return true
    end,
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          local name = selected[1].name
          if groups.delete_group_with_confirmation then
            groups.delete_group_with_confirmation(name, { skip_confirmation = true })
          else
            groups.delete_group(name, true)
          end
          require("marker-groups.pickers.utils").show_notification("Deleted group: " .. name, vim.log.levels.INFO, 5000)
        end
      end,
    },
  }
end

function M.show_markers(opts)
  opts = opts or {}
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks or not snacks.picker then
    vim.notify("Snacks picker not available", vim.log.levels.WARN)
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
    table.insert(items, { text = string.format("%-20s %4s: %s", file_name, line_info, m.annotation), marker = m })
  end

  snacks.picker {
    source = { name = "marker_list", items = items },
    prompt = "Markers - " .. active .. "> ",
    format = function(item)
      return item.text
    end,
    preview = function(ctx)
      local m = ctx.item and ctx.item.marker
      if not m then
        return true
      end
      local data = utils.generate_marker_preview(m)
      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data.content)
      vim.bo[ctx.buf].filetype = data.filetype or "text"
      return true
    end,
    actions = {},
  }
end

return M
