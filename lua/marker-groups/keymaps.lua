---@class MarkerGroupsKeymaps
local M = {}

---Setup default keymaps
function M.setup()
  local config = require("marker-groups.config")
  local groups = require("marker-groups.groups")
  local markers = require("marker-groups.markers")
  
  -- Only set up keymaps if enabled in config
  if not config.get_value("keymaps.enabled", true) then
    return
  end
  
  local function safe_call(func, operation)
    return function()
      local ok, result = pcall(func)
      if not ok then
        vim.notify(operation .. " failed: " .. tostring(result), vim.log.levels.ERROR)
      elseif result and not result.success then
        vim.notify(operation .. " failed: " .. tostring(result.error), vim.log.levels.ERROR)
      end
    end
  end
  
  -- Group management keymaps (using <leader>mg prefix for marker groups)
  vim.keymap.set('n', '<leader>mgc', safe_call(
    function() return groups.create_group_interactive() end,
    "Group creation"
  ), { desc = "Create marker group", silent = true })
  
  vim.keymap.set('n', '<leader>mgs', safe_call(
    function() return groups.select_group_interactive() end,
    "Group selection"
  ), { desc = "Select marker group", silent = true })
  
  vim.keymap.set('n', '<leader>mgl', safe_call(
    function() groups.show_groups("long") end,
    "Group listing"
  ), { desc = "List marker groups", silent = true })
  
  vim.keymap.set('n', '<leader>mgr', safe_call(
    function() return groups.rename_group_interactive() end,
    "Group renaming"
  ), { desc = "Rename marker group", silent = true })
  
  vim.keymap.set('n', '<leader>mgd', safe_call(
    function() return groups.select_group_for_deletion() end,
    "Group deletion"
  ), { desc = "Delete marker group", silent = true })
  
  vim.keymap.set('n', '<leader>mgi', safe_call(
    function() 
      local info = groups.get_active_group_info()
      if info then
        local formatted = groups.format_group_info(info, "long")
        vim.notify(formatted, vim.log.levels.INFO)
      else
        vim.notify("No active group information available", vim.log.levels.WARN)
      end
    end,
    "Group info"
  ), { desc = "Show active group info", silent = true })
  
  -- Group navigation keymaps
  vim.keymap.set('n', '<leader>mgn', safe_call(
    function() return groups.next_group() end,
    "Next group"
  ), { desc = "Next marker group", silent = true })
  
  vim.keymap.set('n', '<leader>mgp', safe_call(
    function() return groups.previous_group() end,
    "Previous group"
  ), { desc = "Previous marker group", silent = true })
  
  -- Marker management keymaps (using <leader>ma prefix for marker add, etc.)
  vim.keymap.set('n', '<leader>ma', function()
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
  end, { desc = "Add marker at cursor", silent = true })
  
  -- Visual mode - add marker from selection
  vim.keymap.set('v', '<leader>ma', function()
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
  end, { desc = "Add marker from selection", silent = true })
  
  vim.keymap.set('n', '<leader>ml', safe_call(
    function()
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
    end,
    "Marker listing"
  ), { desc = "List markers in buffer", silent = true })
  
  vim.keymap.set('n', '<leader>mj', safe_call(
    function()
      local marker = markers.get_marker_at_cursor()
      if marker then
        vim.notify(string.format("Marker: %s (Lines %d-%d)", 
          marker.annotation, marker.start_line, marker.end_line), vim.log.levels.INFO)
      else
        vim.notify("No marker at cursor", vim.log.levels.INFO)
      end
    end,
    "Marker info"
  ), { desc = "Show marker at cursor", silent = true })
  
  -- Utility keymaps
  vim.keymap.set('n', '<leader>mgx', safe_call(
    function() return groups.cleanup_empty_groups() end,
    "Group cleanup"
  ), { desc = "Cleanup empty groups", silent = true })
  
  -- Quick access to toggle last group
  vim.keymap.set('n', '<leader>mgt', safe_call(
    function() return groups.toggle_last_group() end,
    "Group toggle"
  ), { desc = "Toggle last group", silent = true })
  
  -- Create group from git branch (if in git repo)
  vim.keymap.set('n', '<leader>mgb', safe_call(
    function() return groups.create_group_from_branch() end,
    "Group from branch"
  ), { desc = "Create group from git branch", silent = true })
  
  -- Persistence keymaps (using <leader>mp prefix for marker persistence)
  vim.keymap.set('n', '<leader>mps', safe_call(
    function() 
      local persistence = require("marker-groups.persistence")
      return persistence.manual_save()
    end,
    "Manual save"
  ), { desc = "Save marker groups data", silent = true })
  
  vim.keymap.set('n', '<leader>mpl', safe_call(
    function() 
      local persistence = require("marker-groups.persistence")
      return persistence.manual_load()
    end,
    "Manual load"
  ), { desc = "Load marker groups data", silent = true })
  
  -- Floating window viewer keymap (using <leader>mv for marker view)
  vim.keymap.set('n', '<leader>mv', safe_call(
    function()
      local floating = require("marker-groups.ui.floating")
      floating.show_markers()
    end,
    "Floating viewer"
  ), { desc = "Open floating marker viewer", silent = true })
  
  -- Telescope integration keymaps (using <leader>mt prefix for marker telescope)
  vim.keymap.set('n', '<leader>mtg', safe_call(
    function()
      local telescope = require("marker-groups.telescope")
      telescope.show_groups()
    end,
    "Telescope groups"
  ), { desc = "Telescope: marker groups", silent = true })
  
  vim.keymap.set('n', '<leader>mtm', safe_call(
    function()
      local telescope = require("marker-groups.telescope")
      telescope.show_markers()
    end,
    "Telescope markers"
  ), { desc = "Telescope: markers in active group", silent = true })
end

return M