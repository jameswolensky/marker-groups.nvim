---@class MarkerGroupsCommands
local M = {}

---Setup user commands
function M.setup()
  local groups = require("marker-groups.groups")
  local markers = require("marker-groups.markers")
  
  -- Group management commands
  vim.api.nvim_create_user_command("MarkerGroupsCreate", function(args)
    local name = args.args
    if name == "" then
      groups.create_group_interactive()
    else
      local result = groups.create_group(name)
      if not result.success then
        vim.notify("Failed to create group: " .. result.error, vim.log.levels.ERROR)
      end
    end
  end, {
    nargs = "?",
    desc = "Create a new marker group",
    complete = function() return {} end
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsSelect", function(args)
    local name = args.args
    if name == "" then
      groups.select_group_interactive()
    else
      local result = groups.select_group(name)
      if not result.success then
        vim.notify("Failed to select group: " .. result.error, vim.log.levels.ERROR)
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
    end
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsList", function()
    groups.show_groups("long")
  end, {
    desc = "List all marker groups"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsRename", function(args)
    local parts = vim.split(args.args, " ", { plain = true })
    if #parts == 0 or args.args == "" then
      groups.rename_group_interactive()
    elseif #parts == 2 then
      local result = groups.rename_group(parts[1], parts[2])
      if not result.success then
        vim.notify("Failed to rename group: " .. result.error, vim.log.levels.ERROR)
      end
    else
      vim.notify("Usage: MarkerGroupsRename [old_name] [new_name] or just MarkerGroupsRename for interactive", vim.log.levels.WARN)
    end
  end, {
    nargs = "*",
    desc = "Rename a marker group",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local args = vim.split(cmd_line, " ", { plain = true })
      if #args <= 2 then
        -- Complete with existing group names for first argument
        local group_names = {}
        local groups_info = groups.list_groups()
        for _, group in ipairs(groups_info) do
          if group.name ~= "default" then -- Can't rename default
            table.insert(group_names, group.name)
          end
        end
        return group_names
      end
      return {}
    end
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsDelete", function(args)
    local name = args.args
    if name == "" then
      groups.select_group_for_deletion()
    else
      groups.delete_group_with_confirmation(name)
    end
  end, {
    nargs = "?",
    desc = "Delete a marker group",
    complete = function()
      local group_names = {}
      local groups_info = groups.list_groups()
      for _, group in ipairs(groups_info) do
        if group.name ~= "default" then -- Can't delete default
          table.insert(group_names, group.name)
        end
      end
      return group_names
    end
  })
  
  -- Marker management commands
  vim.api.nvim_create_user_command("MarkerAdd", function(args)
    local annotation = args.args
    if annotation == "" then
      vim.ui.input({ prompt = "Marker annotation: " }, function(input)
        if input and input ~= "" then
          local result = markers.add_marker(input)
          if not result.success then
            vim.notify("Failed to add marker: " .. result.error, vim.log.levels.ERROR)
          else
            vim.notify("Added marker: " .. input, vim.log.levels.INFO)
          end
        end
      end)
    else
      local result = markers.add_marker(annotation)
      if not result.success then
        vim.notify("Failed to add marker: " .. result.error, vim.log.levels.ERROR)
      else
        vim.notify("Added marker: " .. annotation, vim.log.levels.INFO)
      end
    end
  end, {
    nargs = "*",
    desc = "Add a marker at current line/selection",
    range = true
  })
  
  vim.api.nvim_create_user_command("MarkerList", function()
    local current_markers = markers.get_current_buffer_markers()
    if #current_markers == 0 then
      vim.notify("No markers in current buffer", vim.log.levels.INFO)
    else
      local lines = { "Markers in current buffer:" }
      for _, marker in ipairs(current_markers) do
        local line_info = marker.start_line == marker.end_line 
          and string.format("Line %d", marker.start_line)
          or string.format("Lines %d-%d", marker.start_line, marker.end_line)
        table.insert(lines, string.format("  %s: %s", line_info, marker.annotation))
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end
  end, {
    desc = "List markers in current buffer"
  })
  
  -- Navigation commands
  vim.api.nvim_create_user_command("MarkerGroupsNext", function()
    local result = groups.next_group()
    if not result.success then
      vim.notify("Failed to switch to next group: " .. result.error, vim.log.levels.ERROR)
    end
  end, {
    desc = "Switch to next marker group"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsPrevious", function()
    local result = groups.previous_group()
    if not result.success then
      vim.notify("Failed to switch to previous group: " .. result.error, vim.log.levels.ERROR)
    end
  end, {
    desc = "Switch to previous marker group"
  })
  
  -- Utility commands
  vim.api.nvim_create_user_command("MarkerGroupsInfo", function()
    local info = groups.get_active_group_info()
    if info then
      local formatted = groups.format_group_info(info, "long")
      vim.notify(formatted, vim.log.levels.INFO)
    else
      vim.notify("No active group information available", vim.log.levels.WARN)
    end
  end, {
    desc = "Show information about active marker group"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsCleanup", function()
    groups.cleanup_empty_groups()
  end, {
    desc = "Clean up empty marker groups"
  })
  
  -- Persistence commands
  vim.api.nvim_create_user_command("MarkerGroupsSave", function()
    local persistence = require("marker-groups.persistence")
    persistence.manual_save()
  end, {
    desc = "Manually save marker groups data"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsLoad", function()
    local persistence = require("marker-groups.persistence")
    persistence.manual_load()
  end, {
    desc = "Manually load marker groups data from disk"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsDebugPersistence", function()
    local persistence = require("marker-groups.persistence")
    local info = persistence.debug_info()
    
    local lines = {
      "Persistence Debug Information:",
      string.format("  Data directory: %s", info.data_dir),
      string.format("  Data file: %s", info.data_file),
      string.format("  Directory exists: %s", info.data_dir_exists),
      string.format("  Data file exists: %s", info.data_file_exists),
      string.format("  Data file valid JSON: %s", info.data_file_valid),
      "",
      "Backup files:"
    }
    
    for i, backup in ipairs(info.backups) do
      table.insert(lines, string.format("  Backup %d: %s", i, backup.path))
      table.insert(lines, string.format("    Exists: %s, Valid JSON: %s, Size: %d bytes", 
        backup.exists, backup.valid_json, backup.size_bytes or -1))
    end
    
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show persistence system debug information"
  })

  -- Floating window viewer command
  vim.api.nvim_create_user_command("MarkerGroupsView", function()
    local floating = require("marker-groups.ui.floating")
    floating.show_markers()
  end, {
    desc = "Open floating window viewer for active group markers"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsCloseFloating", function()
    local floating = require("marker-groups.ui.floating")
    floating.close_all()
  end, {
    desc = "Close all floating marker viewer windows"
  })

  -- Telescope integration commands
  vim.api.nvim_create_user_command("MarkerGroupsTelescope", function()
    local telescope = require("marker-groups.telescope")
    telescope.show_groups()
  end, {
    desc = "Open Telescope picker for marker groups"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsTelescopeMarkers", function()
    local telescope = require("marker-groups.telescope")
    telescope.show_markers()
  end, {
    desc = "Open Telescope picker for markers in active group"
  })
  
  vim.api.nvim_create_user_command("MarkerGroupsTelescopeStatus", function()
    local telescope = require("marker-groups.telescope")
    local status = telescope.get_status()
    
    local lines = {
      "📡 Telescope Integration Status:",
      "═══════════════════════════════════",
      "",
      "Available: " .. (status.available and "✅ Yes" or "❌ No")
    }
    
    if status.available then
      table.insert(lines, "Version: " .. (status.version or "unknown"))
      table.insert(lines, "")
      table.insert(lines, "🔍 Available Pickers:")
      table.insert(lines, "  • Groups picker: " .. (status.pickers_available.groups and "✅" or "❌"))
      table.insert(lines, "  • Markers picker: " .. (status.pickers_available.markers and "✅" or "❌"))
    else
      table.insert(lines, "Reason: " .. (status.reason or "unknown"))
      table.insert(lines, "")
      table.insert(lines, "💡 To enable Telescope integration:")
      if status.suggestions then
        for _, suggestion in ipairs(status.suggestions) do
          table.insert(lines, "  " .. suggestion)
        end
      end
    end
    
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show Telescope integration status and installation guidance"
  })

  -- Development command
  vim.api.nvim_create_user_command("MarkerGroupsReload", function()
    require("marker-groups").reload()
  end, {
    desc = "Reload marker-groups plugin (development)"
  })
end

return M