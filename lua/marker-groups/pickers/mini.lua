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

  local function win_config()
    local height = math.floor(0.618 * vim.o.lines)
    local width = math.floor(0.618 * vim.o.columns)
    return {
      anchor = "NW",
      height = height,
      width = width,
      row = math.floor(0.5 * (vim.o.lines - height)),
      col = math.floor(0.5 * (vim.o.columns - width)),
    }
  end

  pick.start {
    source = {
      items = vim.tbl_map(function(i)
        return i.text
      end, items),
      name = opts.prompt or "Select Marker Group",
      -- Use buffer-backed preview per mini.pick API: (buf_id, item, opts)
      preview = function(buf_id, item, _)
        local group_name = name_by_text[item]
        local preview_builder = require "marker-groups.ui.preview"
        local lines = preview_builder.build_group_preview_lines(group_name, { context_lines = 2, max_markers = 5 })
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
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
    window = { config = win_config },
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

  local function win_config_markers()
    local height = math.floor(0.618 * vim.o.lines)
    local width = math.floor(0.618 * vim.o.columns)
    return {
      anchor = "NW",
      height = height,
      width = width,
      row = math.floor(0.5 * (vim.o.lines - height)),
      col = math.floor(0.5 * (vim.o.columns - width)),
    }
  end

  pick.start {
    source = {
      items = display,
      name = "Markers",
      -- Use MiniPick.default_preview for file/pos context
      preview = function(buf_id, item, _)
        local m = map[item]
        if not m or not m.buffer_path or m.buffer_path == "" then
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { "No preview" })
          return
        end
        local ok, MiniPickMod = pcall(require, "mini.pick")
        if ok and MiniPickMod and MiniPickMod.default_preview then
          MiniPickMod.default_preview(buf_id, { file = m.buffer_path, pos = { m.start_line, 0 } }, {
            n_context_lines = 2,
            line_position = "center",
          })
        else
          -- Fallback: simple header if default_preview unavailable
          local header = string.format(
            "📍 %s:%s",
            vim.fn.fnamemodify(m.buffer_path or "", ":t"),
            (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
          )
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { header })
        end
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
    window = { config = win_config_markers },
  }

  return state.Result.ok { message = "mini.pick marker picker opened" }
end

return M
