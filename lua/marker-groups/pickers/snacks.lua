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
  local name_to_info = {}
  for _, g in ipairs(info) do
    local name = tostring(g.name or "")
    name_to_info[name] = g
    table.insert(items, {
      text = groups.format_group_info(g, "short"),
      value = name,
      name = name,
    })
  end

  if #items == 0 then
    vim.notify("No marker groups available", vim.log.levels.WARN)
    return
  end

  local function coerce_name(val)
    if type(val) == "string" then
      return val
    end
    if type(val) == "table" then
      if type(val.name) == "string" then
        return val.name
      end
      if type(val.text) == "string" then
        return val.text
      end
      if type(val.value) == "string" then
        return val.value
      end
    end
    return nil
  end

  local function with_modifiable(buf, fn)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      return false
    end
    local prev = vim.bo[buf].modifiable
    if not prev then
      vim.bo[buf].modifiable = true
    end
    local ok, err = pcall(fn)
    if not prev then
      vim.bo[buf].modifiable = false
    end
    return ok, err
  end

  local function generate_group_markers_lines(group_name)
    local grp = state.get_group(group_name)
    local markers = (grp and grp.markers) or {}
    if #markers == 0 then
      return { "No markers in group" }
    end
    local lines = {}
    for _, m in ipairs(markers) do
      local file_name = vim.fn.fnamemodify(m.buffer_path, ":t")
      local line_info = m.start_line ~= m.end_line and (m.start_line .. "-" .. m.end_line) or m.start_line
      table.insert(lines, string.format("%s:%s - %s", file_name, line_info, m.annotation or ""))
    end
    return lines
  end

  snacks.picker {
    source = "marker_groups",
    items = items,
    prompt = "Marker Groups> ",
    -- Explicitly format list entries as highlight chunks so names render in the list
    format = function(item)
      local txt
      if type(item) == "table" then
        txt = item.text or item.name or item.value
      else
        txt = tostring(item)
      end
      return { { tostring(txt or "") } }
    end,
    -- Use Snacks default formatter to avoid shape mismatches
    preview = function(ctx)
      local name
      if ctx and ctx.item then
        if type(ctx.item) == "table" then
          name = coerce_name(ctx.item.value) or coerce_name(ctx.item) or ctx.item.text
        elseif type(ctx.item) == "string" then
          name = ctx.item
        end
      end
      if not name then
        return true
      end
      -- Show only markers for the selected group
      local lines = generate_group_markers_lines(name)
      with_modifiable(ctx.buf, function()
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        vim.bo[ctx.buf].filetype = "text"
      end)
      return true
    end,
    -- Use Snacks default actions (confirm => jump)
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
    -- Use default formatter
    preview = function(ctx)
      local m = ctx.item and ctx.item.marker
      if not m then
        return true
      end
      local data = utils.generate_marker_preview(m)
      with_modifiable(ctx.buf, function()
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data.content)
        vim.bo[ctx.buf].filetype = data.filetype or "text"
      end)
      return true
    end,
    actions = {},
  }
end

return M
