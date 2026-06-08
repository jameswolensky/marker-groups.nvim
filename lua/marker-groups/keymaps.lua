local M = {}

local function safe_call(func, operation)
  return function()
    local ok, result = pcall(func)
    if not ok then
      require("marker-groups.feedback").notify(operation .. " failed: " .. tostring(result), vim.log.levels.ERROR, {})
      return
    end

    local result_type = type(result)
    if result_type == "table" then
      if result.success == false then
        require("marker-groups.feedback").notify(
          operation .. " failed: " .. tostring(result.error),
          vim.log.levels.ERROR,
          {}
        )
      end
    elseif result_type == "boolean" then
      if result == false then
        require("marker-groups.feedback").notify(operation .. " failed", vim.log.levels.ERROR, {})
      end
    end
  end
end

local function compute_lhs(prefix, entry)
  if type(entry) == "string" then
    return prefix .. entry
  end
  if type(entry) == "table" then
    if entry.lhs and entry.lhs ~= "" then
      return entry.lhs
    end
    if entry.suffix and entry.suffix ~= "" then
      return prefix .. entry.suffix
    end
  end
  return nil
end

local function modes_from(entry, default)
  if type(entry) == "table" and entry.mode then
    return entry.mode
  end
  return default or "n"
end

local function desc_from(entry, default)
  if type(entry) == "table" and entry.desc then
    return entry.desc
  end
  return default
end

function M.setup()
  local config = require "marker-groups.config"
  local groups = require "marker-groups.groups"
  local markers = require "marker-groups.markers"

  if not config.get_value("keymaps.enabled", true) then
    return
  end

  local function map(entry, default_mode, lhs, rhs, default_desc)
    if entry == false then
      return
    end
    local opts = { silent = true, desc = desc_from(entry, default_desc) }
    vim.keymap.set(modes_from(entry, default_mode), lhs, rhs, opts)
  end

  local prefix = config.get_value("keymaps.prefix", "<leader>m")
  local km = config.get_value("keymaps.mappings", {})

  map(
    km.group and km.group.create,
    "n",
    compute_lhs(prefix, km.group and km.group.create),
    safe_call(function()
      return groups.create_group_interactive()
    end, "Group creation"),
    "Create marker group"
  )

  map(
    km.group and km.group.select,
    "n",
    compute_lhs(prefix, km.group and km.group.select),
    safe_call(function()
      return require("marker-groups.pickers").show_groups()
    end, "Group selection"),
    "Select marker group"
  )

  map(
    km.group and km.group.list,
    "n",
    compute_lhs(prefix, km.group and km.group.list),
    safe_call(function()
      groups.show_groups "long"
    end, "Group listing"),
    "List marker groups"
  )

  map(
    km.group and km.group.rename,
    "n",
    compute_lhs(prefix, km.group and km.group.rename),
    safe_call(function()
      return groups.rename_group_interactive()
    end, "Group renaming"),
    "Rename marker group"
  )

  map(
    km.group and km.group.delete,
    "n",
    compute_lhs(prefix, km.group and km.group.delete),
    safe_call(function()
      return require("marker-groups.pickers").delete_groups()
    end, "Group deletion"),
    "Delete marker group"
  )

  map(
    km.group and km.group.info,
    "n",
    compute_lhs(prefix, km.group and km.group.info),
    safe_call(function()
      local info = groups.get_active_group_info()
      if info then
        local formatted = groups.format_group_info(info, "long")
        require("marker-groups.feedback").notify(formatted, vim.log.levels.INFO, {})
      else
        require("marker-groups.feedback").notify("No active group information available", vim.log.levels.WARN, {})
      end
    end, "Group info"),
    "Show active group info"
  )

  map(
    km.group and km.group.from_branch,
    "n",
    compute_lhs(prefix, km.group and km.group.from_branch),
    safe_call(function()
      return groups.create_group_from_branch()
    end, "Group from branch"),
    "Create group from git branch"
  )

  local add_entry = km.marker and km.marker.add
  if add_entry ~= false then
    local add_lhs_n = compute_lhs(prefix, add_entry)
    if add_lhs_n then
      vim.keymap.set(modes_from(add_entry, { "n", "v" }), add_lhs_n, function()
        local ls = require "marker-groups.line_selection"
        local input_ui = require "marker-groups.ui.input"
        local range = ls.make_range()
        local target_buf = vim.api.nvim_get_current_buf()
        input_ui.prompt_multiline(
          { title = "Marker annotation", default = "" },
          require("marker-groups.config").get_internal "max_annotation_chars",
          function(input)
            if input and input ~= "" then
              local result = markers.add_marker_range(range.lstart, range.lend, input, nil, target_buf)
              if not result.success then
                require("marker-groups.feedback").notify(
                  "Failed to add marker: " .. result.error,
                  vim.log.levels.ERROR,
                  {}
                )
              else
                require("marker-groups.feedback").notify("Added marker: " .. input, vim.log.levels.INFO, {})
              end
            end
          end
        )
      end, { desc = desc_from(add_entry, "Add marker"), silent = true })
    end
  end

  map(
    km.marker and km.marker.list,
    "n",
    compute_lhs(prefix, km.marker and km.marker.list),
    safe_call(function()
      local current_markers = markers.get_current_buffer_markers()
      if #current_markers == 0 then
        require("marker-groups.feedback").notify("No markers in current buffer", vim.log.levels.INFO, {})
      else
        local lines = { "Markers in current buffer:" }
        for _, marker in ipairs(current_markers) do
          local line_info = marker.start_line == marker.end_line and string.format("Line %d", marker.start_line)
            or string.format("Lines %d-%d", marker.start_line, marker.end_line)
          table.insert(lines, string.format("  %s: %s", line_info, marker.annotation))
        end
        require("marker-groups.feedback").notify(table.concat(lines, "\n"), vim.log.levels.INFO, {})
      end
    end, "Marker listing"),
    "List markers in buffer"
  )

  map(
    km.marker and km.marker.info,
    "n",
    compute_lhs(prefix, km.marker and km.marker.info),
    safe_call(function()
      local marker = markers.get_marker_at_cursor()
      if marker then
        require("marker-groups.feedback").notify(
          string.format("Marker: %s (Lines %d-%d)", marker.annotation, marker.start_line, marker.end_line),
          vim.log.levels.INFO,
          {}
        )
      else
        require("marker-groups.feedback").notify("No marker at cursor", vim.log.levels.INFO, {})
      end
    end, "Marker info"),
    "Show marker at cursor"
  )

  map(
    km.marker and km.marker.delete,
    "n",
    compute_lhs(prefix, km.marker and km.marker.delete),
    safe_call(function()
      local marker = markers.get_marker_at_cursor()
      if not marker then
        require("marker-groups.feedback").notify("No marker found at cursor position", vim.log.levels.WARN, {})
        return
      end
      local result = markers.delete_marker(marker.id)
      if not result.success then
        require("marker-groups.feedback").notify("Failed to remove marker: " .. result.error, vim.log.levels.ERROR, {})
      else
        require("marker-groups.feedback").notify("Removed marker: " .. marker.annotation, vim.log.levels.INFO, {})
      end
    end, "Marker deletion"),
    "Delete marker at cursor"
  )

  map(
    km.marker and km.marker.edit,
    "n",
    compute_lhs(prefix, km.marker and km.marker.edit),
    safe_call(function()
      local marker = markers.get_marker_at_cursor()
      if not marker then
        require("marker-groups.feedback").notify("No marker found at cursor position", vim.log.levels.WARN, {})
        return
      end
      local input_ui = require "marker-groups.ui.input"
      input_ui.prompt_multiline(
        { title = "Edit marker annotation", default = marker.annotation },
        require("marker-groups.config").get_internal "max_annotation_chars",
        function(input)
          if input and input ~= "" then
            local result = markers.edit_marker(marker.id, input)
            if not result.success then
              require("marker-groups.feedback").notify(
                "Failed to edit marker: " .. result.error,
                vim.log.levels.ERROR,
                {}
              )
            else
              require("marker-groups.feedback").notify("Updated marker annotation: " .. input, vim.log.levels.INFO, {})
            end
          end
        end
      )
    end, "Marker editing"),
    "Edit marker annotation at cursor"
  )

  map(
    km.view and km.view.toggle,
    "n",
    compute_lhs(prefix, km.view and km.view.toggle),
    safe_call(function()
      local drawer = require "marker-groups.ui.drawer"
      drawer.toggle_drawer()
    end, "Drawer viewer"),
    "Toggle drawer marker viewer"
  )
end

function M.defaults()
  local cfg = require "marker-groups.config"
  local groups = require "marker-groups.groups"
  local markers = require "marker-groups.markers"

  if not cfg.get_value("keymaps.enabled", true) then
    return {}
  end

  local prefix = cfg.get_value("keymaps.prefix", "<leader>m")
  local km = cfg.get_value("keymaps.mappings", {})

  local keys = {}

  local function add(entry, default_mode, lhs, rhs, default_desc)
    if not entry or entry == false or not lhs then
      return
    end
    table.insert(keys, {
      lhs,
      rhs,
      mode = modes_from(entry, default_mode),
      desc = desc_from(entry, default_desc),
      silent = true,
    })
  end

  add(
    km.group and km.group.create,
    "n",
    compute_lhs(prefix, km.group and km.group.create),
    safe_call(function()
      return groups.create_group_interactive()
    end, "Group creation"),
    "Create marker group"
  )

  add(
    km.group and km.group.select,
    "n",
    compute_lhs(prefix, km.group and km.group.select),
    safe_call(function()
      return groups.select_group_interactive()
    end, "Group selection"),
    "Select marker group"
  )

  add(
    km.group and km.group.list,
    "n",
    compute_lhs(prefix, km.group and km.group.list),
    safe_call(function()
      groups.show_groups "long"
    end, "Group listing"),
    "List marker groups"
  )

  add(
    km.group and km.group.rename,
    "n",
    compute_lhs(prefix, km.group and km.group.rename),
    safe_call(function()
      return groups.rename_group_interactive()
    end, "Group renaming"),
    "Rename marker group"
  )

  add(
    km.group and km.group.delete,
    "n",
    compute_lhs(prefix, km.group and km.group.delete),
    safe_call(function()
      return groups.select_group_for_deletion()
    end, "Group deletion"),
    "Delete marker group"
  )

  add(
    km.group and km.group.info,
    "n",
    compute_lhs(prefix, km.group and km.group.info),
    safe_call(function()
      local info = groups.get_active_group_info()
      if info then
        local formatted = groups.format_group_info(info, "long")
        require("marker-groups.feedback").notify(formatted, vim.log.levels.INFO, {})
      else
        require("marker-groups.feedback").notify("No active group information available", vim.log.levels.WARN, {})
      end
    end, "Group info"),
    "Show active group info"
  )

  add(
    km.group and km.group.from_branch,
    "n",
    compute_lhs(prefix, km.group and km.group.from_branch),
    safe_call(function()
      return groups.create_group_from_branch()
    end, "Group from branch"),
    "Create group from git branch"
  )

  local add_entry = km.marker and km.marker.add
  if add_entry ~= false then
    local add_lhs = compute_lhs(prefix, add_entry)
    if add_lhs then
      table.insert(keys, {
        add_lhs,
        function()
          local ls = require "marker-groups.line_selection"
          local range = ls.make_range()
          vim.ui.input({ prompt = "Marker annotation: " }, function(input)
            if input and input ~= "" then
              local result = markers.add_marker_range(range.lstart, range.lend, input)
              if not result.success then
                require("marker-groups.feedback").notify(
                  "Failed to add marker: " .. result.error,
                  vim.log.levels.ERROR,
                  {}
                )
              else
                require("marker-groups.feedback").notify("Added marker: " .. input, vim.log.levels.INFO, {})
              end
            end
          end)
        end,
        mode = modes_from(add_entry, { "n", "v" }),
        desc = desc_from(add_entry, "Add marker"),
        silent = true,
      })
    end
  end

  add(
    km.marker and km.marker.list,
    "n",
    compute_lhs(prefix, km.marker and km.marker.list),
    safe_call(function()
      local current_markers = markers.get_current_buffer_markers()
      if #current_markers == 0 then
        require("marker-groups.feedback").notify("No markers in current buffer", vim.log.levels.INFO, {})
      else
        local lines = { "Markers in current buffer:" }
        for _, marker in ipairs(current_markers) do
          local line_info = marker.start_line == marker.end_line and string.format("Line %d", marker.start_line)
            or string.format("Lines %d-%d", marker.start_line, marker.end_line)
          table.insert(lines, string.format("  %s: %s", line_info, marker.annotation))
        end
        require("marker-groups.feedback").notify(table.concat(lines, "\n"), vim.log.levels.INFO, {})
      end
    end, "Marker listing"),
    "List markers in buffer"
  )

  add(
    km.marker and km.marker.info,
    "n",
    compute_lhs(prefix, km.marker and km.marker.info),
    safe_call(function()
      local marker = markers.get_marker_at_cursor()
      if marker then
        require("marker-groups.feedback").notify(
          string.format("Marker: %s (Lines %d-%d)", marker.annotation, marker.start_line, marker.end_line),
          vim.log.levels.INFO,
          {}
        )
      else
        require("marker-groups.feedback").notify("No marker at cursor", vim.log.levels.INFO, {})
      end
    end, "Marker info"),
    "Show marker at cursor"
  )

  add(
    km.marker and km.marker.delete,
    "n",
    compute_lhs(prefix, km.marker and km.marker.delete),
    safe_call(function()
      local marker = markers.get_marker_at_cursor()
      if not marker then
        require("marker-groups.feedback").notify("No marker found at cursor position", vim.log.levels.WARN, {})
        return
      end
      local result = markers.delete_marker(marker.id)
      if not result.success then
        require("marker-groups.feedback").notify("Failed to remove marker: " .. result.error, vim.log.levels.ERROR, {})
      else
        require("marker-groups.feedback").notify("Removed marker: " .. marker.annotation, vim.log.levels.INFO, {})
      end
    end, "Marker deletion"),
    "Delete marker at cursor"
  )

  add(
    km.marker and km.marker.edit,
    "n",
    compute_lhs(prefix, km.marker and km.marker.edit),
    safe_call(function()
      local marker = markers.get_marker_at_cursor()
      if not marker then
        require("marker-groups.feedback").notify("No marker found at cursor position", vim.log.levels.WARN, {})
        return
      end
      vim.ui.input({ prompt = "Edit marker annotation: ", default = marker.annotation }, function(input)
        if input and input ~= "" then
          local result = markers.edit_marker(marker.id, input)
          if not result.success then
            require("marker-groups.feedback").notify(
              "Failed to edit marker: " .. result.error,
              vim.log.levels.ERROR,
              {}
            )
          else
            require("marker-groups.feedback").notify("Updated marker annotation: " .. input, vim.log.levels.INFO, {})
          end
        end
      end)
    end, "Marker editing"),
    "Edit marker annotation at cursor"
  )

  add(
    km.view and km.view.toggle,
    "n",
    compute_lhs(prefix, km.view and km.view.toggle),
    safe_call(function()
      local drawer = require "marker-groups.ui.drawer"
      drawer.toggle_drawer()
    end, "Drawer viewer"),
    "Toggle drawer marker viewer"
  )

  return keys
end

return M
