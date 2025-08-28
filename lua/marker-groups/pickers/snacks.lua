local S = {}

function S.name()
  return "snacks"
end
S.module_name = "snacks"

function S.is_ready()
  local ok, mod = pcall(require, "snacks")
  if not ok then
    return false
  end
  return type(mod.picker) == "table" and type(mod.picker.open) == "function"
end

function S.show_groups(opts)
  local snacks = require "snacks"
  local groups = require("marker-groups.groups").get_group_names()
  return snacks.picker.open(vim.tbl_deep_extend("force", {
    items = groups,
    format_item = function(g)
      return g
    end,
    on_confirm = function(g)
      if g then
        require("marker-groups.groups").set_active_group(g)
      end
    end,
  }, opts or {}))
end

function S.show_markers(opts)
  local snacks = require "snacks"
  local g = require("marker-groups.state").get_group()
  local items = {}
  for _, m in ipairs(g and g.markers or {}) do
    table.insert(items, m)
  end
  return snacks.picker.open(vim.tbl_deep_extend("force", {
    items = items,
    format_item = function(m)
      local r = (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
      return string.format("%s:%s %s", vim.fn.fnamemodify(m.buffer_path, ":t"), r, m.annotation or "")
    end,
    on_confirm = function(m)
      if m then
        vim.cmd("edit " .. m.buffer_path)
        vim.api.nvim_win_set_cursor(0, { m.start_line, 0 })
      end
    end,
  }, opts or {}))
end

return S
