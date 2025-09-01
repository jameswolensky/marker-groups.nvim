local M = {}

local groups = require "marker-groups.groups"
local state = require "marker-groups.state"
local utils = require "marker-groups.pickers.utils"

local function safe_require()
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  if not ok_pickers then
    return nil
  end
  local ok_finders, finders = pcall(require, "telescope.finders")
  if not ok_finders then
    return nil
  end
  local ok_conf, conf_mod = pcall(require, "telescope.config")
  if not ok_conf then
    return nil
  end
  local ok_actions, actions = pcall(require, "telescope.actions")
  if not ok_actions then
    return nil
  end
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  if not ok_state then
    return nil
  end
  local ok_prev, previewers = pcall(require, "telescope.previewers")
  if not ok_prev then
    return nil
  end
  return {
    pickers = pickers,
    finders = finders,
    conf = conf_mod.values,
    actions = actions,
    action_state = action_state,
    previewers = previewers,
  }
end

function M.show_groups(opts)
  opts = opts or {}
  local t = safe_require()
  if not t then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end

  local group_info = groups.list_groups()
  local entries = {}
  for _, info in ipairs(group_info) do
    local display = groups.format_group_info(info, "short")
    table.insert(entries, {
      value = info.name,
      display = display,
      ordinal = info.name,
      group_info = info,
    })
  end

  if #entries == 0 then
    vim.notify("No marker groups available", vim.log.levels.WARN)
    return
  end

  t.pickers
    .new(opts, {
      prompt_title = "Marker Groups",
      finder = t.finders.new_table {
        results = entries,
        entry_maker = function(e)
          return {
            value = e.value,
            display = e.display,
            ordinal = e.ordinal,
            group_info = e.group_info,
          }
        end,
      },
      sorter = t.conf.generic_sorter(opts),
      previewer = t.previewers.new_buffer_previewer {
        title = "Group Info",
        define_preview = function(self, entry, status)
          local info = entry.group_info or {}
          local lines = utils.generate_group_preview(info)
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "markdown"
        end,
      },
      attach_mappings = function(bufnr, map)
        t.actions.select_default:replace(function()
          local selection = t.action_state.get_selected_entry()
          t.actions.close(bufnr)
          if selection and selection.value then
            if groups.delete_group_with_confirmation then
              groups.delete_group_with_confirmation(selection.value, { skip_confirmation = true })
              require("marker-groups.pickers.utils").show_notification(
                "Deleted group: " .. selection.value,
                vim.log.levels.INFO,
                5000
              )
            else
              groups.delete_group(selection.value, true)
              require("marker-groups.pickers.utils").show_notification(
                "Deleted group: " .. selection.value,
                vim.log.levels.INFO,
                5000
              )
            end
          end
        end)
        if map then
          map("n", "<Esc>", t.actions.close)
        end
        return true
      end,
    })
    :find()
end

function M.show_markers(opts)
  opts = opts or {}
  local t = safe_require()
  if not t then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end

  local active = state.get_active_group()
  if not active then
    vim.notify("No active group selected", vim.log.levels.WARN)
    return
  end
  local g = state.get_group(active)
  local markers = (g and g.markers) or {}

  if #markers == 0 then
    vim.notify("No markers in active group: " .. active, vim.log.levels.INFO)
    return
  end

  t.pickers
    .new(opts, {
      prompt_title = "Markers - " .. active,
      finder = t.finders.new_table {
        results = markers,
        entry_maker = function(m)
          local file_name = vim.fn.fnamemodify(m.buffer_path, ":t")
          local line_info = m.start_line ~= m.end_line and (m.start_line .. "-" .. m.end_line) or m.start_line
          return {
            value = m,
            display = string.format("%-20s %4s: %s", file_name, line_info, m.annotation),
            ordinal = file_name .. " " .. m.annotation,
          }
        end,
      },
      sorter = t.conf.generic_sorter(opts),
      previewer = t.previewers.new_buffer_previewer {
        title = "Code Context",
        define_preview = function(self, entry, status)
          local marker = entry.value
          local preview_data = utils.generate_marker_preview(marker)
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_data.content)
          vim.bo[self.state.bufnr].filetype = preview_data.filetype or "text"
        end,
      },
      attach_mappings = function(bufnr, map)
        t.actions.select_default:replace(function()
          -- No jump; preview-only per desired behavior
        end)
        if map then
          map("n", "<Esc>", t.actions.close)
        end
        return true
      end,
    })
    :find()
end

return M
