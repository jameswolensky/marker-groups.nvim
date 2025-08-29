local S = {}

function S.name()
  return "snacks"
end
S.module_name = "snacks"

function S.is_ready()
  -- Non-loading readiness: consider Snacks ready if the module is loaded
  -- or a global `Snacks` is present. Avoid requiring or checking subfields
  -- that may be initialized only after user setup.
  return package.loaded["snacks"] ~= nil or rawget(_G, "Snacks") ~= nil
end

function S.show_groups(opts)
  local snacks = require "snacks"
  local names = require("marker-groups.state").get_group_names() or {}
  local items = {}
  for _, g in ipairs(names) do
    items[#items + 1] = { text = g, value = g }
  end
  return snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Marker Groups",
    items = items,
    -- Robust preview for both ctx-based (new) and item-based (legacy) signatures
    preview = function(arg1)
      local function build_lines(group_name)
        local st = require "marker-groups.state"
        local g = st.get_group(group_name)
        local lines = { "Group: " .. (group_name or ""), "Markers: " .. tostring(g and #g.markers or 0) }
        if g and g.markers then
          local max = math.min(#g.markers, 5)
          for i = 1, max do
            local m = g.markers[i]
            local r = (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
            lines[#lines + 1] =
              string.format("%d. %s:%s %s", i, vim.fn.fnamemodify(m.buffer_path or "", ":t"), r, m.annotation or "")
          end
        end
        return lines
      end

      if type(arg1) == "table" and arg1.preview and arg1.item then
        -- New API: preview(ctx)
        local ctx = arg1
        local it = ctx.item
        local name = it and (it.value or it.text) or ""
        ctx.preview:reset()
        ctx.preview:set_title("Group: " .. name)
        ctx.preview:set_lines(build_lines(name))
        return
      end
      -- Legacy API: preview(item)
      local it = arg1
      local name = type(it) == "table" and (it.value or it.text) or (type(it) == "string" and it or "")
      return table.concat(build_lines(name), "\n")
    end,
    confirm = function(_, item)
      local g = item and (item.value or item.text)
      if g then
        require("marker-groups.groups").select_group(g)
      end
    end,
  }, opts or {}))
end

function S.show_markers(opts)
  local snacks = require "snacks"
  local g = require("marker-groups.state").get_group()
  local items = {}
  for _, m in ipairs(g and g.markers or {}) do
    local r = (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
    items[#items + 1] = {
      text = string.format("%s:%s %s", vim.fn.fnamemodify(m.buffer_path, ":t"), r, m.annotation or ""),
      file = m.buffer_path,
      lnum = m.start_line,
      col = 1,
      buffer_path = m.buffer_path,
      start_line = m.start_line,
      end_line = m.end_line,
      marker = m,
    }
  end
  return snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Markers",
    items = items,
    confirm = function(_, item)
      if item and item.buffer_path and item.start_line then
        vim.cmd("edit " .. item.buffer_path)
        vim.api.nvim_win_set_cursor(0, { item.start_line, 0 })
      end
    end,
  }, opts or {}))
end

return S
