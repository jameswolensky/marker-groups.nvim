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
    local text = groups.format_group_info(g, "short")
    -- Provide both `value` and `name` to be compatible with Snacks picker expectations
    table.insert(items, {
      text = tostring(text or g.name or ""),
      value = tostring(g.name or ""),
      name = tostring(g.name or ""),
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

  snacks.picker {
    source = { name = "marker_groups", items = items },
    prompt = "Marker Groups> ",
    format = function(item)
      if type(item) == "table" then
        if type(item.text) == "string" then
          return item.text
        end
        if type(item.value) == "string" then
          return item.value
        end
        if type(item.name) == "string" then
          return item.name
        end
      end
      return tostring(item or "")
    end,
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
      -- get fresh info via groups.list_groups
      local info
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
        local function extract_name(sel)
          if type(sel) == "table" then
            -- Multiple selections case
            if #sel > 0 then
              local first = sel[1]
              if type(first) == "table" then
                return coerce_name(first.value) or coerce_name(first) or first.text
              elseif type(first) == "string" then
                return first
              end
            end
            -- Single selection as table
            return coerce_name(sel.value) or coerce_name(sel) or sel.text
          elseif type(sel) == "string" then
            return sel
          end
          return nil
        end
        local name = extract_name(selected)
        if not name or name == "" then
          return
        end
        if opts.action == "delete" then
          if groups.delete_group_with_confirmation then
            groups.delete_group_with_confirmation(name, { skip_confirmation = true })
          else
            groups.delete_group(name, true)
          end
          require("marker-groups.pickers.utils").show_notification(
            "Deleted group: " .. tostring(name),
            vim.log.levels.INFO,
            5000
          )
        else
          groups.select_group(name)
          require("marker-groups.pickers.utils").show_notification(
            "Selected group: " .. tostring(name),
            vim.log.levels.INFO,
            3000
          )
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
