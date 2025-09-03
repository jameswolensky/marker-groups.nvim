local M = {}

function M.setup()
  local groups = require "marker-groups.groups"
  local markers = require "marker-groups.markers"
  local config = require "marker-groups.config"

  vim.api.nvim_create_user_command("MarkerGroupsCreate", function(args)
    local name = args.args
    if name ~= "" then
      name = vim.fn.strcharpart(vim.trim(name), 0, config.get_internal "max_group_name_chars")
    end
    if name == "" then
      groups.create_group_interactive()
    else
      local result = groups.create_group(name)
      if not result.success then
        require("marker-groups.feedback").notify("Failed to create group: " .. result.error, vim.log.levels.ERROR, {})
      end
    end
  end, {
    nargs = "?",
    desc = "Create a new marker group",
    complete = function()
      return {}
    end,
  })

  vim.api.nvim_create_user_command("MarkerGroupsSelect", function(args)
    local name = args.args
    if name == "" then
      groups.select_group_interactive()
    else
      local result = groups.select_group(name)
      if not result.success then
        require("marker-groups.feedback").notify("Failed to select group: " .. result.error, vim.log.levels.ERROR, {})
      end
    end
  end, {
    nargs = "?",
    desc = "Select a marker group",
    complete = function()
      local group_names = {}
      local groups_info = groups.list_groups()
      for _, group in ipairs(groups_info) do
        table.insert(group_names, group.name)
      end
      return group_names
    end,
  })

  vim.api.nvim_create_user_command("MarkerGroupsList", function()
    groups.show_groups "long"
  end, {
    desc = "List all marker groups",
  })

  vim.api.nvim_create_user_command("MarkerGroupsRename", function(args)
    local parts = vim.split(args.args, " ", { plain = true })
    if #parts == 0 or args.args == "" then
      groups.rename_group_interactive()
    elseif #parts == 2 then
      local new_name = vim.fn.strcharpart(vim.trim(parts[2] or ""), 0, config.get_internal "max_group_name_chars")
      local result = groups.rename_group(parts[1], new_name)
      if not result.success then
        require("marker-groups.feedback").notify("Failed to rename group: " .. result.error, vim.log.levels.ERROR, {})
      end
    else
      require("marker-groups.feedback").notify(
        "Usage: MarkerGroupsRename [old_name] [new_name] or just MarkerGroupsRename for interactive",
        vim.log.levels.WARN,
        {}
      )
    end
  end, {
    nargs = "*",
    desc = "Rename a marker group",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local args = vim.split(cmd_line, " ", { plain = true })
      if #args <= 2 then
        local group_names = {}
        local groups_info = groups.list_groups()
        for _, group in ipairs(groups_info) do
          if group.name ~= "default" then
            table.insert(group_names, group.name)
          end
        end
        return group_names
      end
      return {}
    end,
  })

  vim.api.nvim_create_user_command("MarkerGroupsDelete", function(args)
    local parts = vim.split(args.args, " ", { plain = true })
    local name = ""
    local skip_confirmation = false

    for _, part in ipairs(parts) do
      if part == "--force" or part == "-f" then
        skip_confirmation = true
      elseif part ~= "" then
        name = part
      end
    end

    if name == "" then
      local result = groups.select_group_for_deletion { skip_confirmation = skip_confirmation }
      if not result.success then
        error(result.error)
      end
    else
      local result = groups.delete_group_with_confirmation(name, { skip_confirmation = skip_confirmation })
      if not result.success then
        error(result.error)
      end
    end
  end, {
    nargs = "*",
    desc = "Delete a marker group (use --force to skip confirmation)",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local args = vim.split(cmd_line, " ", { plain = true })

      local has_force = false
      for _, arg in ipairs(args) do
        if arg == "--force" or arg == "-f" then
          has_force = true
          break
        end
      end

      local completions = {}

      local groups_info = groups.list_groups()
      for _, group in ipairs(groups_info) do
        if group.name ~= "default" then
          table.insert(completions, group.name)
        end
      end

      if not has_force then
        table.insert(completions, "--force")
      end

      return completions
    end,
  })

  vim.api.nvim_create_user_command("MarkerAdd", function(args)
    local annotation = args.args
    if annotation ~= "" then
      annotation = vim.fn.strcharpart(vim.trim(annotation), 0, config.get_internal "max_annotation_chars")
    end
    local has_range = args.line1 and args.line2 and args.line1 ~= args.line2
    local range_start = has_range and math.min(args.line1, args.line2) or nil
    local range_end = has_range and math.max(args.line1, args.line2) or nil

    if annotation == "" then
      local input_ui = require "marker-groups.ui.input"
      input_ui.prompt_multiline(
        { title = "Marker annotation", default = "" },
        config.get_internal "max_annotation_chars",
        function(input)
          if input and input ~= "" then
            local result
            if range_start and range_end then
              result = markers.add_marker_range(range_start, range_end, input)
            end
            result = result or markers.add_marker(input)
            if not result.success then
              require("marker-groups.feedback").notify(
                "Failed to add marker: " .. result.error,
                vim.log.levels.ERROR,
                {}
              )
            else
              require("marker-groups.feedback").success("Marker Added", input)
            end
          end
        end
      )
    else
      local result
      if range_start and range_end then
        result = markers.add_marker_range(range_start, range_end, annotation)
      else
        result = markers.add_marker(annotation)
      end
      if not result.success then
        require("marker-groups.feedback").notify("Failed to add marker: " .. result.error, vim.log.levels.ERROR, {})
      else
        require("marker-groups.feedback").success("Marker Added", annotation)
      end
    end
  end, {
    nargs = "*",
    desc = "Add a marker at current line/selection",
    range = true,
  })

  vim.api.nvim_create_user_command("MarkerList", function()
    local current_markers = markers.get_current_buffer_markers()
    if #current_markers == 0 then
      return
    else
      local lines = { "Markers in current buffer:" }
      for _, marker in ipairs(current_markers) do
        local line_info = marker.start_line == marker.end_line and string.format("Line %d", marker.start_line)
          or string.format("Lines %d-%d", marker.start_line, marker.end_line)
        table.insert(lines, string.format("  %s: %s", line_info, marker.annotation))
      end
      require("marker-groups.feedback").notify(table.concat(lines, "\n"), vim.log.levels.INFO, {})
    end
  end, {
    desc = "List markers in current buffer",
  })

  vim.api.nvim_create_user_command("MarkerRemove", function()
    local marker = markers.get_marker_at_cursor()
    if not marker then
      require("marker-groups.feedback").notify("No marker found at cursor position", vim.log.levels.WARN, {})
      return
    end

    local before_count = #markers.get_current_buffer_markers()

    local result = markers.delete_marker(marker.id)
    if not result.success then
      require("marker-groups.feedback").notify("Failed to remove marker: " .. result.error, vim.log.levels.ERROR, {})
      return
    end

    local after_count = #markers.get_current_buffer_markers()
    if not (after_count < before_count) and before_count > 0 then
      local buffer_markers = markers.get_current_buffer_markers()
      if #buffer_markers > 0 then
        local fallback_marker = buffer_markers[#buffer_markers]
        markers.delete_marker(fallback_marker.id)
      end
    end

    require("marker-groups.feedback").success("Marker Deleted", marker.annotation)
  end, {
    desc = "Remove marker at current cursor position",
  })

  vim.api.nvim_create_user_command("MarkerEdit", function(args)
    local marker = markers.get_marker_at_cursor()
    if not marker then
      require("marker-groups.feedback").notify("No marker found at cursor position", vim.log.levels.WARN, {})
      return
    end

    local new_annotation = args.args
    if new_annotation ~= "" then
      new_annotation = vim.fn.strcharpart(vim.trim(new_annotation), 0, config.get_internal "max_annotation_chars")
    end
    if new_annotation == "" then
      local input_ui = require "marker-groups.ui.input"
      input_ui.prompt_multiline(
        { title = "Edit marker annotation", default = marker.annotation },
        config.get_internal "max_annotation_chars",
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
              require("marker-groups.feedback").success("Marker Edited", input)
            end
          end
        end
      )
    else
      local result = markers.edit_marker(marker.id, new_annotation)
      if not result.success then
        require("marker-groups.feedback").notify("Failed to edit marker: " .. result.error, vim.log.levels.ERROR, {})
      else
        require("marker-groups.feedback").success("Marker Edited", new_annotation)
      end
    end
  end, {
    nargs = "*",
    desc = "Edit annotation of marker at current cursor position",
  })

  vim.api.nvim_create_user_command("MarkerGroupsInfo", function()
    local info = groups.get_active_group_info()
    if info then
      local formatted = groups.format_group_info(info, "long")
      require("marker-groups.feedback").notify(formatted, vim.log.levels.INFO, {})
    else
      require("marker-groups.feedback").notify("No active group information available", vim.log.levels.WARN, {})
    end
  end, {
    desc = "Show information about active marker group",
  })

  vim.api.nvim_create_user_command("MarkerGroupsView", function()
    local drawer = require "marker-groups.ui.drawer"
    drawer.show_markers()
  end, {
    desc = "Open drawer viewer for active group markers",
  })

  vim.api.nvim_create_user_command("MarkerGroupsCloseDrawer", function()
    local drawer = require "marker-groups.ui.drawer"
    drawer.close_all()
  end, {
    desc = "Close all drawer marker viewer windows",
  })

  vim.api.nvim_create_user_command("MarkerGroupsDrawerWidth", function(args)
    local drawer = require "marker-groups.ui.drawer"

    if args.args == "" then
      local current_width = drawer.get_drawer_width()
      require("marker-groups.feedback").notify(
        "Current drawer width: " .. current_width .. " columns",
        vim.log.levels.INFO,
        {}
      )
    else
      local width = tonumber(args.args)
      if width then
        drawer.set_drawer_width(width)
      else
        require("marker-groups.feedback").notify(
          "Invalid width: " .. args.args .. ". Please provide a number.",
          vim.log.levels.ERROR,
          {}
        )
      end
    end
  end, {
    nargs = "?",
    desc = "Get or set the drawer width (30-120 columns)",
  })

  vim.api.nvim_create_user_command("MarkerGroupsPickerStatus", function()
    local pickers = require "marker-groups.pickers"
    pickers.show_picker_status()
  end, {
    desc = "Show picker backend status and availability",
  })
end

return M
