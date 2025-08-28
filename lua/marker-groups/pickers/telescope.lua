local T = {}

function T.name()
  return "telescope"
end
T.module_name = "telescope"

function T.is_ready()
  return package.loaded["telescope"] ~= nil or vim.fn.exists ":Telescope" == 2
end

function T.show_groups(opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local state = require "marker-groups.state"
  local groups = state.get_group_names() or {}

  return pickers
    .new(opts or {}, {
      prompt_title = "Marker Groups",
      finder = finders.new_table(groups),
      sorter = conf.generic_sorter(opts or {}),
      attach_mappings = function(prompt_bufnr, map)
        local actions = require "telescope.actions"
        local state = require "telescope.actions.state"
        map({ "i", "n" }, "<CR>", function()
          local entry = state.get_selected_entry()
          if entry and entry[1] then
            require("marker-groups.groups").set_active_group(entry[1])
            actions.close(prompt_bufnr)
          end
        end)
        return true
      end,
    })
    :find()
end

function T.show_markers(opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local g = require("marker-groups.state").get_group()
  local items = {}
  for _, m in ipairs(g and g.markers or {}) do
    local r = (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
    table.insert(items, {
      display = string.format("%s:%s %s", vim.fn.fnamemodify(m.buffer_path, ":t"), r, m.annotation or ""),
      ordinal = m.buffer_path .. ":" .. r .. ":" .. (m.annotation or ""),
      value = m,
    })
  end

  return pickers
    .new(opts or {}, {
      prompt_title = "Markers",
      finder = finders.new_table {
        results = items,
        entry_maker = function(e)
          return e
        end,
      },
      sorter = conf.generic_sorter(opts or {}),
      attach_mappings = function(prompt_bufnr, map)
        local actions = require "telescope.actions"
        local state = require "telescope.actions.state"
        map({ "i", "n" }, "<CR>", function()
          local entry = state.get_selected_entry()
          local m = entry and entry.value
          if m then
            vim.cmd("edit " .. m.buffer_path)
            vim.api.nvim_win_set_cursor(0, { m.start_line, 0 })
            actions.close(prompt_bufnr)
          end
        end)
        return true
      end,
    })
    :find()
end

return T
