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
  local name_by_text = {}
  for _, gi in ipairs(infos) do
    local text = groups.format_group_info(gi, "short")
    table.insert(items, { text = text, value = gi.name })
    name_by_text[text] = gi.name
  end

  pick.start {
    source = {
      items = vim.tbl_map(function(i)
        return i.text
      end, items),
      name = opts.prompt or "Select Marker Group",
      preview = function(item)
        local group_name = name_by_text[item]
        local preview_builder = require "marker-groups.ui.preview"
        local lines = preview_builder.build_group_preview_lines(group_name, { context_lines = 2, max_markers = 5 })
        return table.concat(lines, "\n")
      end,
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
      preview = function(item)
        local m = map[item]
        if not m or not m.buffer_path or m.buffer_path == "" then
          return "No preview"
        end
        -- Read lines from loaded buffer if available, else from file
        local function get_lines(path)
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
              if vim.api.nvim_buf_get_name(buf) == path then
                return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
              end
            end
          end
          local lines = {}
          local f = io.open(path, "r")
          if f then
            for l in f:lines() do
              table.insert(lines, l)
            end
            f:close()
          end
          return lines
        end

        local context_lines = 2
        local file_lines = get_lines(m.buffer_path)
        local start_line = math.max(m.start_line - context_lines, 1)
        local end_line = math.min(m.end_line + context_lines, #file_lines)

        local out = {}
        table.insert(
          out,
          string.format(
            "📍 %s:%s",
            vim.fn.fnamemodify(m.buffer_path or "", ":t"),
            (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
          )
        )
        table.insert(out, "   " .. (m.buffer_path or ""))
        table.insert(out, string.rep("─", 40))
        for i = start_line, end_line do
          local prefix = (i >= m.start_line and i <= m.end_line) and "► " or "  "
          local content = file_lines[i] or ""
          table.insert(out, string.format("%s%-4d: %s", prefix, i, content))
        end
        table.insert(out, string.rep("─", 40))
        if m.annotation and m.annotation ~= "" then
          table.insert(out, "💬 " .. m.annotation)
        end
        return table.concat(out, "\n")
      end,
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
