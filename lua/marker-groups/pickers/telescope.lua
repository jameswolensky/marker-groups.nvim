local M = {}

local groups = require "marker-groups.groups"
local state = require "marker-groups.state"
local utils = require "marker-groups.pickers.utils"

function M.show_groups(opts)
  opts = opts or {}
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_conf, conf = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")
  if not (ok_pickers and ok_finders and ok_conf and ok_actions and ok_state and ok_previewers) then
    require("marker-groups.feedback").notify("telescope not available", vim.log.levels.WARN, {})
    return
  end

  local info = groups.list_groups()
  info = utils.filter_groups_for_action(info, opts)
  local entries = {}
  for _, g in ipairs(info) do
    local name = tostring(g.name or "")
    local text = groups.format_group_info(g, "short")
    table.insert(entries, { name = name, text = text })
  end

  if #entries == 0 then
    require("marker-groups.feedback").notify(utils.empty_groups_message(opts), vim.log.levels.WARN, {})
    return
  end

  local finder = finders.new_table {
    results = entries,
    entry_maker = function(item)
      return { value = item.name, display = item.text, ordinal = item.text }
    end,
  }

  local previewer = previewers.new_buffer_previewer {
    define_preview = function(self, entry)
      local data = utils.generate_group_markers_code_preview(entry.value, { max_width = 70 })
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, data.content)
      vim.bo[self.state.bufnr].filetype = data.filetype or "text"
    end,
  }

  local picker = pickers.new({}, {
    prompt_title = "Marker Groups",
    finder = finder,
    sorter = conf.values.generic_sorter {},
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, map)
      local function on_confirm()
        local entry = action_state.get_selected_entry()
        local name = entry and entry.value or nil
        if not name or name == "" then
          actions.close(prompt_bufnr)
          return
        end
        if opts.action == "delete" then
          if groups.delete_group_with_confirmation then
            groups.delete_group_with_confirmation(name, { skip_confirmation = true })
          else
            groups.delete_group(name, true)
          end
        else
          groups.select_group(name)
          require("marker-groups.feedback").notify(
            "Selected group: " .. tostring(name),
            vim.log.levels.INFO,
            { timeout = 3000 }
          )
        end
        actions.close(prompt_bufnr)
      end
      map("i", "<CR>", on_confirm)
      map("n", "<CR>", on_confirm)
      return true
    end,
  })

  picker:find()
end

function M.show_markers(opts)
  opts = opts or {}
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_conf, conf = pcall(require, "telescope.config")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")
  if not (ok_pickers and ok_finders and ok_conf and ok_previewers) then
    require("marker-groups.feedback").notify("telescope not available", vim.log.levels.WARN, {})
    return
  end

  local active = state.get_active_group()
  if not active then
    require("marker-groups.feedback").notify("No active group selected", vim.log.levels.WARN, {})
    return
  end

  local grp = state.get_group(active)
  local markers = (grp and grp.markers) or {}
  local entries = {}
  for _, m in ipairs(markers) do
    local file_name = vim.fn.fnamemodify(m.buffer_path, ":t")
    local line_info = m.start_line ~= m.end_line and (m.start_line .. "-" .. m.end_line) or m.start_line
    local text = string.format("%-20s %4s: %s", file_name, line_info, m.annotation)
    table.insert(entries, { text = text, marker = m })
  end

  local finder = finders.new_table {
    results = entries,
    entry_maker = function(item)
      return { value = item.marker, display = item.text, ordinal = item.text }
    end,
  }

  local previewer = previewers.new_buffer_previewer {
    title = "Code Context",
    define_preview = function(self, entry)
      local data = utils.generate_marker_preview(entry.value)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, data.content)
      vim.bo[self.state.bufnr].filetype = data.filetype or "text"
    end,
  }

  local picker = pickers.new({}, {
    prompt_title = "Markers - " .. active,
    finder = finder,
    sorter = conf.values.generic_sorter {},
    previewer = previewer,
  })

  picker:find()
end

return M
