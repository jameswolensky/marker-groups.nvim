local M = {}

local config = require "marker-groups.config"
local feedback = require "marker-groups.feedback"

local function provider_available(name)
  if name == "telescope" then
    return pcall(require, "telescope")
  elseif name == "snacks" then
    local ok, snacks = pcall(require, "snacks")
    return ok and snacks and snacks.picker ~= nil
  elseif name == "mini" then
    return pcall(require, "mini.pick")
  elseif name == "vim" then
    return true
  end
  return false
end

local function resolve_provider()
  local wanted = config.get_value("picker.provider", "auto")
  if wanted ~= "auto" and wanted ~= "" then
    if provider_available(wanted) then
      return wanted
    end
    feedback.warn(
      "Picker",
      string.format("Configured provider '%s' not available. Falling back to auto.", tostring(wanted))
    )
  end

  if provider_available "telescope" then
    return "telescope"
  end
  if provider_available "snacks" then
    return "snacks"
  end
  if provider_available "mini" then
    return "mini"
  end
  return "vim"
end

function M.get_provider_name()
  return resolve_provider()
end

function M.show_groups(opts)
  opts = opts or {}
  local provider = resolve_provider()
  if provider == "telescope" then
    local telescope = require "marker-groups.telescope"
    return telescope.show_groups(opts)
  elseif provider == "snacks" then
    local snacks = require "marker-groups.pickers.snacks"
    return snacks.show_groups(opts)
  elseif provider == "mini" then
    local mini = require "marker-groups.pickers.mini"
    return mini.show_groups(opts)
  else
    local groups = require "marker-groups.groups"
    local infos = groups.list_groups()
    if #infos == 0 then
      feedback.warning("Groups", "No groups found")
      return require("marker-groups.state").Result.error("No groups", "NO_GROUPS")
    end
    return groups.select_group_with_vim_ui(infos, opts)
  end
end

function M.show_markers(opts)
  opts = opts or {}
  local provider = resolve_provider()
  if provider == "telescope" then
    local telescope = require "marker-groups.telescope"
    return telescope.show_markers(opts)
  elseif provider == "snacks" then
    local snacks = require "marker-groups.pickers.snacks"
    return snacks.show_markers(opts)
  elseif provider == "mini" then
    local mini = require "marker-groups.pickers.mini"
    return mini.show_markers(opts)
  else
    local markers = require "marker-groups.markers"
    local state = require "marker-groups.state"
    local active = state.get_active_group()
    local group = state.get_group(active)
    if not group or not group.markers or #group.markers == 0 then
      feedback.warning("Markers", "No markers in active group")
      return state.Result.error("No markers", "NO_MARKERS")
    end

    local items, map = {}, {}
    for _, m in ipairs(group.markers) do
      local label = string.format("%s:%d %s", vim.fn.fnamemodify(m.buffer_path or "", ":t"), m.start_line, m.annotation)
      table.insert(items, label)
      map[label] = m
    end

    vim.ui.select(items, { prompt = "Select marker:" }, function(choice)
      if not choice then
        return
      end
      local m = map[choice]
      if not m then
        return
      end
      vim.cmd("edit " .. vim.fn.fnameescape(m.buffer_path))
      pcall(vim.api.nvim_win_set_cursor, 0, { m.start_line, 0 })
    end)

    return state.Result.ok { message = "Markers selection UI opened" }
  end
end

return M
