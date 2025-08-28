local N = {}

function N.name()
  return "native"
end
function N.is_ready()
  return true
end

function N.show_groups(opts)
  local state = require "marker-groups.state"
  local names = state.get_group_names() or {}
  return vim.ui.select(names, { prompt = "Marker Groups" }, function(item)
    if item then
      require("marker-groups.groups").select_group(item)
    end
  end)
end

function N.show_markers(opts)
  local g = require("marker-groups.state").get_group()
  local items = {}
  for _, m in ipairs(g and g.markers or {}) do
    local r = (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
    table.insert(
      items,
      { label = string.format("%s:%s %s", vim.fn.fnamemodify(m.buffer_path, ":t"), r, m.annotation or ""), m = m }
    )
  end
  return vim.ui.select(items, {
    prompt = "Markers",
    format_item = function(i)
      return i.label
    end,
  }, function(i)
    if i and i.m then
      vim.cmd("edit " .. i.m.buffer_path)
      vim.api.nvim_win_set_cursor(0, { i.m.start_line, 0 })
    end
  end)
end

return N
