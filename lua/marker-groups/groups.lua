---@class MarkerGroupsGroups
local M = {}

local api = vim.api
local state = require("marker-groups.state")

---Error handling and user feedback utilities
local ErrorHandler = {
  ---Show error notification with consistent formatting
  ---@param operation string Operation name (e.g., "Group Creation", "Group Deletion")
  ---@param error_msg string Error message
  ---@param error_code? string Optional error code for debugging
  show_error = function(operation, error_msg, error_code)
    local formatted_msg = string.format("%s Failed: %s", operation, error_msg)
    if error_code then
      formatted_msg = formatted_msg .. string.format(" (Code: %s)", error_code)
    end
    vim.notify(formatted_msg, vim.log.levels.ERROR)
  end,
  
  ---Show success notification with consistent formatting
  ---@param operation string Operation name
  ---@param details? string Optional success details
  show_success = function(operation, details)
    local formatted_msg = operation .. " Successful"
    if details then
      formatted_msg = formatted_msg .. ": " .. details
    end
    vim.notify(formatted_msg, vim.log.levels.INFO)
  end,
  
  ---Show warning notification
  ---@param operation string Operation name
  ---@param warning_msg string Warning message
  show_warning = function(operation, warning_msg)
    local formatted_msg = string.format("%s Warning: %s", operation, warning_msg)
    vim.notify(formatted_msg, vim.log.levels.WARN)
  end,
  
  ---Handle result object and show appropriate notification
  ---@param operation string Operation name
  ---@param result table Result object from operation
  ---@param success_details? string Optional success details
  ---@return table The same result object (for chaining)
  handle_result = function(operation, result, success_details)
    if result.success then
      ErrorHandler.show_success(operation, success_details)
    else
      ErrorHandler.show_error(operation, result.error or "Unknown error", result.code)
    end
    return result
  end
}

---Validate group name
---@param name string Group name to validate
---@return boolean, string, string? valid, validated_name, error_message
local function validate_group_name(name)
  if not name or type(name) ~= "string" then
    return false, "", "Group name must be a string"
  end
  
  if name == "" then
    return false, "", "Group name cannot be empty"
  end
  
  if #name > 50 then
    return false, "", "Group name cannot exceed 50 characters"
  end
  
  -- Trim whitespace first
  name = vim.trim(name)
  if name == "" then
    return false, "", "Group name cannot be only whitespace"
  end
  
  -- Check for valid characters (alphanumeric, underscore, hyphen, space)
  if not name:match("^[%w%s_-]+$") then
    return false, "", "Group name can only contain letters, numbers, spaces, underscores, and hyphens"
  end
  
  -- Reserved names
  local reserved = { "default", "all", "none", "temp", "temporary" }
  local lower_name = name:lower()
  for _, reserved_name in ipairs(reserved) do
    if lower_name == reserved_name and name ~= "default" then
      return false, "", "'" .. name .. "' is a reserved group name"
    end
  end
  
  return true, name, nil
end

---Create a new marker group
---@param name string Group name
---@param description? string Optional description
---@return table Result object
function M.create_group(name, description)
  -- Validate name
  local valid, validated_name, error_msg = validate_group_name(name)
  if not valid then
    return state.Result.error(error_msg, "INVALID_GROUP_NAME")
  end
  
  -- Use validated (trimmed) name
  name = validated_name
  
  -- Check if group already exists
  local existing = state.get_group(name)
  if existing then
    return state.Result.error("Group already exists: " .. name, "GROUP_EXISTS")
  end
  
  -- Create group in state
  local result = state.create_group(name)
  if not result.success then
    return result
  end
  
  -- Update group with description if provided
  if description and description ~= "" then
    -- Note: This would require extending the state system to support descriptions
    -- For now, we'll just store it in the result
    result.value.description = description
  end
  
  -- Save state (if persistence is available)
  local success, persistence = pcall(require, "marker-groups.persistence")
  if success and persistence.save then
    pcall(persistence.save)
  end
  
  -- Notify user using enhanced feedback system
  local feedback = require("marker-groups.feedback")
  feedback.success("Group Creation", "Created group: " .. name)
  
  return result
end

---Create group with interactive input
---@param opts? table Options { prompt?, default_name?, auto_switch? }
---@return table Result object
function M.create_group_interactive(opts)
  opts = opts or {}
  local prompt = opts.prompt or "Enter group name:"
  local default = opts.default_name or ""
  
  -- Get input from user
  vim.ui.input({
    prompt = prompt .. " ",
    default = default,
    completion = function(arg_lead, cmd_line, cursor_pos)
      -- Provide some suggestions based on common patterns
      local suggestions = {
        "feature-" .. os.date("%Y%m%d"),
        "bugfix-" .. os.date("%Y%m%d"),
        "refactor-" .. os.date("%Y%m%d"),
        "review-" .. os.date("%Y%m%d"),
        "experiment-" .. os.date("%Y%m%d")
      }
      
      local matches = {}
      for _, suggestion in ipairs(suggestions) do
        if suggestion:match("^" .. vim.pesc(arg_lead)) then
          table.insert(matches, suggestion)
        end
      end
      
      return matches
    end
  }, function(input)
    if input and input ~= "" then
      local result = M.create_group(input)
      ErrorHandler.handle_result("Group Creation", result, 
        result.success and ("Created group: " .. input) or nil)
      
      if result.success then
        -- Auto-switch to new group if requested
        if opts.auto_switch ~= false then
          local switch_result = M.select_group(input)
          if not switch_result.success then
            ErrorHandler.show_warning("Group Creation", 
              "Created group but failed to switch: " .. switch_result.error)
          end
        end
      end
    else
      ErrorHandler.show_warning("Group Creation", "Group creation cancelled")
    end
  end)
  
  return state.Result.ok({ message = "Interactive group creation started" })
end

---Create group from current git branch
---@return table Result object
function M.create_group_from_branch()
  -- Get current git branch
  local handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
  if not handle then
    return state.Result.error("Failed to get git branch", "GIT_ERROR")
  end
  
  local branch = handle:read("*a")
  handle:close()
  
  if not branch or branch == "" then
    return state.Result.error("Not in a git repository or no branch found", "NO_GIT_BRANCH")
  end
  
  -- Clean up branch name
  branch = vim.trim(branch)
  if branch == "HEAD" then
    return state.Result.error("Cannot create group from detached HEAD", "DETACHED_HEAD")
  end
  
  -- Convert branch name to valid group name
  local group_name = branch:gsub("[^%w%s_-]", "-"):lower()
  
  -- Create group
  local result = M.create_group(group_name, "Created from git branch: " .. branch)
  if result.success then
    vim.notify("Created group '" .. group_name .. "' from branch '" .. branch .. "'", vim.log.levels.INFO)
    
    -- Auto-switch to new group
    M.select_group(group_name)
  end
  
  return result
end

---List all available groups with metadata
---@return table[] Array of group info
function M.list_groups()
  local group_names = state.get_group_names()
  local groups_info = {}
  
  for _, name in ipairs(group_names) do
    local group = state.get_group(name)
    if group then
      local info = {
        name = name,
        marker_count = #group.markers,
        created_at = group.created_at,
        modified_at = group.modified_at,
        is_active = state.get_active_group() == name
      }
      
      -- Add formatted timestamps
      if group.created_at then
        info.created_formatted = os.date("%Y-%m-%d %H:%M", group.created_at)
      end
      
      if group.modified_at then
        info.modified_formatted = os.date("%Y-%m-%d %H:%M", group.modified_at)
      end
      
      -- Calculate age
      if group.created_at then
        local age_seconds = os.time() - group.created_at
        local age_days = math.floor(age_seconds / 86400)
        local age_hours = math.floor((age_seconds % 86400) / 3600)
        
        if age_days > 0 then
          info.age = age_days .. " day" .. (age_days > 1 and "s" or "") .. " ago"
        elseif age_hours > 0 then
          info.age = age_hours .. " hour" .. (age_hours > 1 and "s" or "") .. " ago"
        else
          info.age = "less than an hour ago"
        end
      end
      
      table.insert(groups_info, info)
    end
  end
  
  -- Sort by last modified (most recent first)
  table.sort(groups_info, function(a, b)
    return (a.modified_at or 0) > (b.modified_at or 0)
  end)
  
  return groups_info
end

---Get detailed statistics about all groups
---@return table Statistics object
function M.get_group_statistics()
  local groups_info = M.list_groups()
  local stats = {
    total_groups = #groups_info,
    total_markers = 0,
    active_group = state.get_active_group(),
    groups_with_markers = 0,
    empty_groups = 0,
    newest_group = nil,
    oldest_group = nil,
    most_markers = nil,
    least_markers = nil
  }
  
  for _, group_info in ipairs(groups_info) do
    stats.total_markers = stats.total_markers + group_info.marker_count
    
    if group_info.marker_count > 0 then
      stats.groups_with_markers = stats.groups_with_markers + 1
    else
      stats.empty_groups = stats.empty_groups + 1
    end
    
    -- Track newest/oldest
    if not stats.newest_group or (group_info.created_at and group_info.created_at > (stats.newest_group.created_at or 0)) then
      stats.newest_group = group_info
    end
    
    if not stats.oldest_group or (group_info.created_at and group_info.created_at < (stats.oldest_group.created_at or math.huge)) then
      stats.oldest_group = group_info
    end
    
    -- Track most/least markers
    if not stats.most_markers or group_info.marker_count > stats.most_markers.marker_count then
      stats.most_markers = group_info
    end
    
    if not stats.least_markers or group_info.marker_count < stats.least_markers.marker_count then
      stats.least_markers = group_info
    end
  end
  
  return stats
end

---Format group info for display
---@param group_info table Group information
---@param format? string Format style: "short", "long", "table"
---@return string Formatted string
function M.format_group_info(group_info, format)
  format = format or "short"
  
  if format == "short" then
    local marker_text = group_info.marker_count .. " marker" .. (group_info.marker_count ~= 1 and "s" or "")
    local active_indicator = group_info.is_active and " *" or ""
    return group_info.name .. " (" .. marker_text .. ")" .. active_indicator
    
  elseif format == "long" then
    local lines = {
      "Group: " .. group_info.name .. (group_info.is_active and " (active)" or ""),
      "  Markers: " .. group_info.marker_count,
      "  Created: " .. (group_info.created_formatted or "unknown"),
      "  Modified: " .. (group_info.modified_formatted or "unknown"),
      "  Age: " .. (group_info.age or "unknown")
    }
    return table.concat(lines, "\n")
    
  elseif format == "table" then
    return string.format("%-20s %8d %15s %s", 
      group_info.name .. (group_info.is_active and "*" or ""),
      group_info.marker_count,
      group_info.age or "unknown",
      group_info.created_formatted or "unknown")
  end
  
  return group_info.name
end

---Display groups in a formatted list
---@param format? string Display format: "short", "long", "table"
function M.show_groups(format)
  format = format or "table"
  local groups_info = M.list_groups()
  
  if #groups_info == 0 then
    vim.notify("No marker groups found", vim.log.levels.INFO)
    return
  end
  
  local lines = {}
  
  if format == "table" then
    table.insert(lines, string.format("%-20s %8s %15s %s", "GROUP", "MARKERS", "AGE", "CREATED"))
    table.insert(lines, string.rep("-", 70))
  end
  
  for _, group_info in ipairs(groups_info) do
    table.insert(lines, M.format_group_info(group_info, format))
  end
  
  -- Add statistics summary
  if format == "table" then
    local stats = M.get_group_statistics()
    table.insert(lines, "")
    table.insert(lines, string.format("Total: %d groups, %d markers", stats.total_groups, stats.total_markers))
    table.insert(lines, string.format("Active: %s", stats.active_group))
  end
  
  -- Display in a scratch buffer
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Open in a split
  vim.cmd("split")
  api.nvim_win_set_buf(0, buf)
  api.nvim_buf_set_name(buf, "Marker Groups")
  
  -- Set buffer options for better display
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "filetype", "marker-groups")
  
  vim.notify("Showing " .. #groups_info .. " marker groups", vim.log.levels.INFO)
end

---Select and switch to a marker group
---@param name? string Group name (if nil, shows selection UI)
---@return table Result object
function M.select_group(name)
  -- If no name provided, show selection UI
  if not name or name == "" then
    return M.select_group_interactive()
  end
  
  -- Validate group exists
  local group = state.get_group(name)
  if not group then
    return state.Result.error("Group does not exist: " .. name, "GROUP_NOT_FOUND")
  end
  
  -- Get current active group for comparison
  local current_active = state.get_active_group()
  if current_active == name then
    vim.notify("Already using group: " .. name, vim.log.levels.INFO)
    return state.Result.ok({ message = "Group already active", group_name = name })
  end
  
  -- Set active group in state
  local result = state.set_active_group(name)
  if not result.success then
    return result
  end
  
  -- Update UI for all buffers
  local virtual_text = require("marker-groups.ui.virtual_text")
  virtual_text.update_all_buffers()
  
  -- Notify user using enhanced feedback system
  local feedback = require("marker-groups.feedback")
  feedback.success("Group Selection", "Switched to group: " .. name)
  
  return state.Result.ok({ group_name = name, previous_group = current_active })
end

---Interactive group selection with UI
---@param opts? table Options { prompt?, show_markers?, include_stats? }
---@return table Result object
function M.select_group_interactive(opts)
  opts = opts or {}
  local prompt = opts.prompt or "Select marker group:"
  
  local groups_info = M.list_groups()
  
  if #groups_info == 0 then
    vim.notify("No marker groups available", vim.log.levels.WARN)
    return state.Result.error("No groups available", "NO_GROUPS")
  end
  
  -- Check if Telescope is available
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    return M.select_group_with_telescope(groups_info, opts)
  else
    return M.select_group_with_vim_ui(groups_info, opts)
  end
end

---Select group using Telescope
---@param groups_info table[] Group information array
---@param opts table Options
---@return table Result object
function M.select_group_with_telescope(groups_info, opts)
  local telescope = require('telescope')
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Create picker entries
  local entries = {}
  for _, group_info in ipairs(groups_info) do
    local display_text = M.format_group_info(group_info, "short")
    if opts.include_stats then
      display_text = display_text .. " | " .. (group_info.age or "unknown age")
    end
    
    table.insert(entries, {
      value = group_info.name,
      display = display_text,
      ordinal = group_info.name,
      group_info = group_info
    })
  end
  
  -- Create and start picker
  pickers.new(opts, {
    prompt_title = opts.prompt or "Select Marker Group",
    finder = finders.new_table {
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.value,
          display = entry.display,
          ordinal = entry.ordinal,
          group_info = entry.group_info
        }
      end
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          M.select_group(selection.value)
        end
      end)
      return true
    end,
  }):find()
  
  return state.Result.ok({ message = "Telescope group selector opened" })
end

---Select group using vim.ui.select
---@param groups_info table[] Group information array  
---@param opts table Options
---@return table Result object
function M.select_group_with_vim_ui(groups_info, opts)
  -- Create display items
  local items = {}
  local name_map = {}
  
  for _, group_info in ipairs(groups_info) do
    local display_text = M.format_group_info(group_info, "short")
    if opts.include_stats then
      display_text = display_text .. " (" .. (group_info.age or "unknown age") .. ")"
    end
    
    table.insert(items, display_text)
    name_map[display_text] = group_info.name
  end
  
  vim.ui.select(items, {
    prompt = opts.prompt or "Select marker group:",
    format_item = function(item)
      return item
    end,
    kind = "marker_group"
  }, function(selected)
    if selected then
      local group_name = name_map[selected]
      if group_name then
        M.select_group(group_name)
      end
    end
  end)
  
  return state.Result.ok({ message = "Group selection UI opened" })
end

---Get current active group info
---@return table? Group info or nil
function M.get_active_group_info()
  local active_name = state.get_active_group()
  if not active_name then
    return nil
  end
  
  local groups_info = M.list_groups()
  for _, group_info in ipairs(groups_info) do
    if group_info.name == active_name then
      return group_info
    end
  end
  
  return nil
end

---Switch to next group in list
---@return table Result object
function M.next_group()
  local groups_info = M.list_groups()
  local current_active = state.get_active_group()
  
  if #groups_info <= 1 then
    return state.Result.error("Need at least 2 groups to switch", "INSUFFICIENT_GROUPS")
  end
  
  -- Find current group index
  local current_index = 1
  for i, group_info in ipairs(groups_info) do
    if group_info.name == current_active then
      current_index = i
      break
    end
  end
  
  -- Get next group (wrap around)
  local next_index = current_index + 1
  if next_index > #groups_info then
    next_index = 1
  end
  
  local next_group_name = groups_info[next_index].name
  return M.select_group(next_group_name)
end

---Switch to previous group in list
---@return table Result object
function M.previous_group()
  local groups_info = M.list_groups()
  local current_active = state.get_active_group()
  
  if #groups_info <= 1 then
    return state.Result.error("Need at least 2 groups to switch", "INSUFFICIENT_GROUPS")
  end
  
  -- Find current group index
  local current_index = 1
  for i, group_info in ipairs(groups_info) do
    if group_info.name == current_active then
      current_index = i
      break
    end
  end
  
  -- Get previous group (wrap around)
  local prev_index = current_index - 1
  if prev_index < 1 then
    prev_index = #groups_info
  end
  
  local prev_group_name = groups_info[prev_index].name
  return M.select_group(prev_group_name)
end

---Quick switch between last two used groups
---@return table Result object
function M.toggle_last_group()
  -- This would require tracking last used group in state
  -- For now, implement as next_group
  return M.next_group()
end

---Rename a marker group
---@param old_name string Current group name
---@param new_name string New group name
---@return table Result object
function M.rename_group(old_name, new_name)
  -- Validate old group exists
  if not old_name or old_name == "" then
    return state.Result.error("Old group name cannot be empty", "INVALID_OLD_NAME")
  end
  
  local old_group = state.get_group(old_name)
  if not old_group then
    return state.Result.error("Group does not exist: " .. old_name, "GROUP_NOT_FOUND")
  end
  
  -- Validate new name
  local valid, validated_name, error_msg = validate_group_name(new_name)
  if not valid then
    return state.Result.error(error_msg, "INVALID_NEW_NAME")
  end
  
  new_name = validated_name
  
  -- Check if new name is the same as old name
  if old_name == new_name then
    return state.Result.ok({ message = "Group name unchanged", group_name = old_name })
  end
  
  -- Check if new name conflicts with existing group
  local existing_group = state.get_group(new_name)
  if existing_group then
    return state.Result.error("Group already exists: " .. new_name, "GROUP_EXISTS")
  end
  
  -- Protect default group from being renamed
  if old_name == "default" then
    return state.Result.error("Cannot rename the default group", "CANNOT_RENAME_DEFAULT")
  end
  
  -- Check if this is the active group
  local is_active_group = state.get_active_group() == old_name
  
  -- Create new group with same data but new name
  local new_group_data = vim.tbl_extend("force", {}, old_group, {
    name = new_name,
    modified_at = os.time()
  })
  
  -- Remove old group and add new group (atomic operation simulation)
  local remove_result = state.delete_group(old_name)
  if not remove_result.success then
    return state.Result.error("Failed to remove old group: " .. remove_result.error, "RENAME_FAILED")
  end
  
  -- Create new group
  local create_result = state.create_group(new_name)
  if not create_result.success then
    -- Try to restore old group
    state.create_group(old_name)
    return state.Result.error("Failed to create new group: " .. create_result.error, "RENAME_FAILED")
  end
  
  -- Restore markers to new group
  for _, marker in ipairs(old_group.markers) do
    local add_result = state.add_marker(marker, new_name)
    if not add_result.success then
      vim.notify("Warning: Failed to restore marker " .. marker.id .. " to renamed group", vim.log.levels.WARN)
    end
  end
  
  -- If this was the active group, set new group as active
  if is_active_group then
    local set_active_result = state.set_active_group(new_name)
    if set_active_result.success then
      -- Update UI for all buffers
      local virtual_text = require("marker-groups.ui.virtual_text")
      virtual_text.update_all_buffers()
    end
  end
  
  -- Save state
  local success, persistence = pcall(require, "marker-groups.persistence")
  if success and persistence.save then
    pcall(persistence.save)
  end
  
  -- Notify user
  vim.notify("Renamed group '" .. old_name .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
  
  return state.Result.ok({ 
    old_name = old_name, 
    new_name = new_name, 
    was_active = is_active_group,
    marker_count = #old_group.markers
  })
end

---Rename group with interactive input
---@param old_name? string Current group name (if nil, will prompt to select)
---@param opts? table Options { prompt?, default_new_name? }
---@return table Result object
function M.rename_group_interactive(old_name, opts)
  opts = opts or {}
  
  -- If no old name provided, let user select a group first
  if not old_name or old_name == "" then
    local groups_info = M.list_groups()
    
    if #groups_info == 0 then
      vim.notify("No groups available to rename", vim.log.levels.WARN)
      return state.Result.error("No groups available", "NO_GROUPS")
    end
    
    -- Show group selection for renaming
    local items = {}
    local name_map = {}
    
    for _, group_info in ipairs(groups_info) do
      if group_info.name ~= "default" then  -- Don't allow renaming default
        local display_text = M.format_group_info(group_info, "short")
        table.insert(items, display_text)
        name_map[display_text] = group_info.name
      end
    end
    
    if #items == 0 then
      vim.notify("No renameable groups available (default group cannot be renamed)", vim.log.levels.WARN)
      return state.Result.error("No renameable groups", "NO_RENAMEABLE_GROUPS")
    end
    
    vim.ui.select(items, {
      prompt = "Select group to rename:",
      format_item = function(item)
        return item
      end,
      kind = "marker_group"
    }, function(selected)
      if selected then
        local selected_name = name_map[selected]
        if selected_name then
          M.rename_group_interactive(selected_name, opts)
        end
      end
    end)
    
    return state.Result.ok({ message = "Group selection for rename opened" })
  end
  
  -- Get new name from user
  local prompt = opts.prompt or ("Rename '" .. old_name .. "' to:")
  local default = opts.default_new_name or ""
  
  vim.ui.input({
    prompt = prompt .. " ",
    default = default,
    completion = function(arg_lead, cmd_line, cursor_pos)
      -- Provide suggestions based on the old name
      local base_suggestions = {
        old_name .. "-new",
        old_name .. "-v2",
        old_name .. "-updated",
        "new-" .. old_name
      }
      
      local matches = {}
      for _, suggestion in ipairs(base_suggestions) do
        if suggestion:match("^" .. vim.pesc(arg_lead)) then
          table.insert(matches, suggestion)
        end
      end
      
      return matches
    end
  }, function(input)
    if input and input ~= "" then
      local result = M.rename_group(old_name, input)
      if not result.success then
        vim.notify("Failed to rename group: " .. result.error, vim.log.levels.ERROR)
      end
    end
  end)
  
  return state.Result.ok({ message = "Interactive rename started for " .. old_name })
end

---Rename current active group
---@param new_name string New name for active group
---@return table Result object
function M.rename_active_group(new_name)
  local active_group = state.get_active_group()
  if not active_group then
    return state.Result.error("No active group to rename", "NO_ACTIVE_GROUP")
  end
  
  return M.rename_group(active_group, new_name)
end

---Batch rename groups using a pattern
---@param pattern string Pattern to match (simple string match)
---@param replacement string Replacement text
---@param opts? table Options { dry_run?, case_sensitive? }
---@return table Result object with rename results
function M.batch_rename_groups(pattern, replacement, opts)
  opts = opts or {}
  local dry_run = opts.dry_run or false
  local case_sensitive = opts.case_sensitive ~= false  -- Default to true
  
  if not pattern or pattern == "" then
    return state.Result.error("Pattern cannot be empty", "INVALID_PATTERN")
  end
  
  if not replacement then
    replacement = ""
  end
  
  local groups_info = M.list_groups()
  local rename_candidates = {}
  
  -- Find matching groups
  for _, group_info in ipairs(groups_info) do
    local group_name = group_info.name
    
    -- Skip default group
    if group_name ~= "default" then
      local match_name = case_sensitive and group_name or group_name:lower()
      local match_pattern = case_sensitive and pattern or pattern:lower()
      
      if match_name:find(match_pattern, 1, true) then  -- Plain text search
        local new_name = group_name:gsub(vim.pesc(pattern), replacement)
        table.insert(rename_candidates, {
          old_name = group_name,
          new_name = new_name,
          group_info = group_info
        })
      end
    end
  end
  
  if #rename_candidates == 0 then
    return state.Result.ok({ 
      message = "No groups match pattern",
      pattern = pattern,
      candidates = rename_candidates
    })
  end
  
  -- If dry run, just return candidates
  if dry_run then
    return state.Result.ok({
      message = "Dry run completed",
      pattern = pattern,
      replacement = replacement,
      candidates = rename_candidates
    })
  end
  
  -- Perform renames
  local results = {
    successful = {},
    failed = {}
  }
  
  for _, candidate in ipairs(rename_candidates) do
    local result = M.rename_group(candidate.old_name, candidate.new_name)
    if result.success then
      table.insert(results.successful, candidate)
    else
      table.insert(results.failed, {
        candidate = candidate,
        error = result.error
      })
    end
  end
  
  local total = #results.successful + #results.failed
  vim.notify(string.format("Batch rename completed: %d successful, %d failed out of %d", 
    #results.successful, #results.failed, total), vim.log.levels.INFO)
  
  return state.Result.ok({
    pattern = pattern,
    replacement = replacement,
    results = results,
    total_candidates = #rename_candidates
  })
end

---Delete a marker group with safety checks
---@param group_name string Group name to delete
---@param force? boolean Skip safety checks if true
---@return table Result object
function M.delete_group(group_name, force)
  force = force or false
  
  -- Validate group name
  if not group_name or group_name == "" then
    return state.Result.error("Group name cannot be empty", "INVALID_GROUP_NAME")
  end
  
  -- Check if group exists
  local group = state.get_group(group_name)
  if not group then
    return state.Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end
  
  -- Protect default group
  if group_name == "default" and not force then
    return state.Result.error("Cannot delete the default group", "CANNOT_DELETE_DEFAULT")
  end
  
  -- Check if this is the active group
  local is_active_group = state.get_active_group() == group_name
  local marker_count = #group.markers
  
  -- Delete the group from state
  local delete_result = state.delete_group(group_name)
  if not delete_result.success then
    return delete_result
  end
  
  -- If this was the active group, switch to default
  if is_active_group then
    local switch_result = state.set_active_group("default")
    if switch_result.success then
      -- Update UI for all buffers
      local virtual_text = require("marker-groups.ui.virtual_text")
      virtual_text.update_all_buffers()
      
      vim.notify("Switched to default group after deleting active group", vim.log.levels.INFO)
    end
  end
  
  -- Save state
  local success, persistence = pcall(require, "marker-groups.persistence")
  if success and persistence.save then
    pcall(persistence.save)
  end
  
  -- Notify user
  vim.notify(string.format("Deleted group '%s' (%d markers)", group_name, marker_count), vim.log.levels.INFO)
  
  return state.Result.ok({
    group_name = group_name,
    was_active = is_active_group,
    marker_count = marker_count
  })
end

---Delete group with confirmation dialog
---@param group_name? string Group name (if nil, will prompt to select)
---@param opts? table Options { skip_confirmation?, force? }
---@return table Result object
function M.delete_group_with_confirmation(group_name, opts)
  opts = opts or {}
  local skip_confirmation = opts.skip_confirmation or false
  local force = opts.force or false
  
  -- If no group name provided, let user select
  if not group_name or group_name == "" then
    return M.select_group_for_deletion(opts)
  end
  
  -- Get group info for confirmation
  local group = state.get_group(group_name)
  if not group then
    return state.Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end
  
  -- Protect default group
  if group_name == "default" and not force then
    vim.notify("Cannot delete the default group", vim.log.levels.ERROR)
    return state.Result.error("Cannot delete the default group", "CANNOT_DELETE_DEFAULT")
  end
  
  local marker_count = #group.markers
  local is_active = state.get_active_group() == group_name
  
  -- Skip confirmation if requested
  if skip_confirmation then
    return M.delete_group(group_name, force)
  end
  
  -- Show confirmation dialog
  local confirm_message = string.format(
    "Delete group '%s'?\n\n" ..
    "This will permanently delete:\n" ..
    "• %d marker%s\n" ..
    "%s\n" ..
    "This action cannot be undone.",
    group_name,
    marker_count,
    marker_count == 1 and "" or "s",
    is_active and "• The currently active group (will switch to default)" or ""
  )
  
  vim.ui.select({"Yes", "No"}, {
    prompt = confirm_message,
    format_item = function(item)
      return item
    end,
    kind = "confirmation"
  }, function(choice)
    if choice == "Yes" then
      local result = M.delete_group(group_name, force)
      if not result.success then
        vim.notify("Failed to delete group: " .. result.error, vim.log.levels.ERROR)
      end
    else
      vim.notify("Group deletion cancelled", vim.log.levels.INFO)
    end
  end)
  
  return state.Result.ok({ message = "Confirmation dialog opened for " .. group_name })
end

---Select group for deletion
---@param opts? table Options
---@return table Result object
function M.select_group_for_deletion(opts)
  opts = opts or {}
  
  local groups_info = M.list_groups()
  
  if #groups_info == 0 then
    vim.notify("No groups available to delete", vim.log.levels.WARN)
    return state.Result.error("No groups available", "NO_GROUPS")
  end
  
  -- Create list excluding default group (unless force is true)
  local items = {}
  local name_map = {}
  
  for _, group_info in ipairs(groups_info) do
    if group_info.name ~= "default" or opts.force then
      local display_text = M.format_group_info(group_info, "short")
      local warning = ""
      
      if group_info.is_active then
        warning = " (ACTIVE - will switch to default)"
      end
      
      if group_info.marker_count > 0 then
        warning = warning .. string.format(" ⚠️  %d markers will be lost", group_info.marker_count)
      end
      
      display_text = display_text .. warning
      
      table.insert(items, display_text)
      name_map[display_text] = group_info.name
    end
  end
  
  if #items == 0 then
    local message = opts.force and "No groups available to delete" or "No deletable groups (default group cannot be deleted)"
    vim.notify(message, vim.log.levels.WARN)
    return state.Result.error("No deletable groups", "NO_DELETABLE_GROUPS")
  end
  
  vim.ui.select(items, {
    prompt = "Select group to delete:",
    format_item = function(item)
      return item
    end,
    kind = "marker_group"
  }, function(selected)
    if selected then
      local selected_name = name_map[selected]
      if selected_name then
        M.delete_group_with_confirmation(selected_name, opts)
      end
    end
  end)
  
  return state.Result.ok({ message = "Group selection for deletion opened" })
end

---Delete current active group
---@param opts? table Options { skip_confirmation?, force? }
---@return table Result object
function M.delete_active_group(opts)
  local active_group = state.get_active_group()
  if not active_group then
    return state.Result.error("No active group to delete", "NO_ACTIVE_GROUP")
  end
  
  return M.delete_group_with_confirmation(active_group, opts)
end

---Batch delete groups using a pattern
---@param pattern string Pattern to match
---@param opts? table Options { dry_run?, case_sensitive?, skip_confirmation?, force? }
---@return table Result object
function M.batch_delete_groups(pattern, opts)
  opts = opts or {}
  local dry_run = opts.dry_run or false
  local case_sensitive = opts.case_sensitive ~= false
  local skip_confirmation = opts.skip_confirmation or false
  local force = opts.force or false
  
  if not pattern or pattern == "" then
    return state.Result.error("Pattern cannot be empty", "INVALID_PATTERN")
  end
  
  local groups_info = M.list_groups()
  local delete_candidates = {}
  
  -- Find matching groups
  for _, group_info in ipairs(groups_info) do
    local group_name = group_info.name
    
    -- Skip default group unless forced
    if group_name ~= "default" or force then
      local match_name = case_sensitive and group_name or group_name:lower()
      local match_pattern = case_sensitive and pattern or pattern:lower()
      
      if match_name:find(match_pattern, 1, true) then
        table.insert(delete_candidates, group_info)
      end
    end
  end
  
  if #delete_candidates == 0 then
    return state.Result.ok({
      message = "No groups match pattern",
      pattern = pattern,
      candidates = delete_candidates
    })
  end
  
  -- Calculate total markers that will be lost
  local total_markers = 0
  local active_groups = 0
  
  for _, candidate in ipairs(delete_candidates) do
    total_markers = total_markers + candidate.marker_count
    if candidate.is_active then
      active_groups = active_groups + 1
    end
  end
  
  -- If dry run, just return candidates
  if dry_run then
    return state.Result.ok({
      message = "Dry run completed",
      pattern = pattern,
      candidates = delete_candidates,
      total_markers = total_markers,
      active_groups = active_groups
    })
  end
  
  -- Show confirmation for batch delete
  if not skip_confirmation then
    local confirm_message = string.format(
      "Batch delete %d groups matching '%s'?\n\n" ..
      "This will permanently delete:\n" ..
      "• %d groups\n" ..
      "• %d total markers\n" ..
      "%s\n" ..
      "This action cannot be undone.",
      #delete_candidates,
      pattern,
      #delete_candidates,
      total_markers,
      active_groups > 0 and ("• " .. active_groups .. " active group(s) (will switch to default)") or ""
    )
    
    vim.ui.select({"Yes", "No"}, {
      prompt = confirm_message,
      format_item = function(item)
        return item
      end,
      kind = "confirmation"
    }, function(choice)
      if choice == "Yes" then
        -- Proceed with deletion
        M.batch_delete_groups(pattern, vim.tbl_extend("force", opts, { skip_confirmation = true }))
      else
        vim.notify("Batch deletion cancelled", vim.log.levels.INFO)
      end
    end)
    
    return state.Result.ok({ message = "Batch deletion confirmation opened" })
  end
  
  -- Perform deletions
  local results = {
    successful = {},
    failed = {}
  }
  
  for _, candidate in ipairs(delete_candidates) do
    local result = M.delete_group(candidate.name, force)
    if result.success then
      table.insert(results.successful, candidate)
    else
      table.insert(results.failed, {
        candidate = candidate,
        error = result.error
      })
    end
  end
  
  local total = #results.successful + #results.failed
  vim.notify(string.format("Batch delete completed: %d successful, %d failed out of %d",
    #results.successful, #results.failed, total), vim.log.levels.INFO)
  
  return state.Result.ok({
    pattern = pattern,
    results = results,
    total_candidates = #delete_candidates,
    total_markers_deleted = total_markers
  })
end

---Clean up empty groups (groups with no markers)
---@param opts? table Options { skip_confirmation?, exclude_active? }
---@return table Result object
function M.cleanup_empty_groups(opts)
  opts = opts or {}
  local skip_confirmation = opts.skip_confirmation or false
  local exclude_active = opts.exclude_active ~= false  -- Default to true
  
  local groups_info = M.list_groups()
  local empty_groups = {}
  local active_group = state.get_active_group()
  
  -- Find empty groups
  for _, group_info in ipairs(groups_info) do
    if group_info.name ~= "default" and group_info.marker_count == 0 then
      if not exclude_active or not group_info.is_active then
        table.insert(empty_groups, group_info)
      end
    end
  end
  
  if #empty_groups == 0 then
    vim.notify("No empty groups to clean up", vim.log.levels.INFO)
    return state.Result.ok({ message = "No empty groups found", cleaned = {} })
  end
  
  -- Show confirmation
  if not skip_confirmation then
    local group_names = {}
    for _, group in ipairs(empty_groups) do
      table.insert(group_names, group.name)
    end
    
    local confirm_message = string.format(
      "Clean up %d empty groups?\n\n" ..
      "Groups to delete:\n%s\n\n" ..
      "This action cannot be undone.",
      #empty_groups,
      "• " .. table.concat(group_names, "\n• ")
    )
    
    vim.ui.select({"Yes", "No"}, {
      prompt = confirm_message,
      format_item = function(item)
        return item
      end,
      kind = "confirmation"
    }, function(choice)
      if choice == "Yes" then
        M.cleanup_empty_groups(vim.tbl_extend("force", opts, { skip_confirmation = true }))
      else
        vim.notify("Cleanup cancelled", vim.log.levels.INFO)
      end
    end)
    
    return state.Result.ok({ message = "Cleanup confirmation opened" })
  end
  
  -- Perform cleanup
  local cleaned = {}
  local failed = {}
  
  for _, group_info in ipairs(empty_groups) do
    local result = M.delete_group(group_info.name)
    if result.success then
      table.insert(cleaned, group_info.name)
    else
      table.insert(failed, { name = group_info.name, error = result.error })
    end
  end
  
  vim.notify(string.format("Cleanup completed: %d groups deleted, %d failed",
    #cleaned, #failed), vim.log.levels.INFO)
  
  return state.Result.ok({
    cleaned = cleaned,
    failed = failed,
    total_candidates = #empty_groups
  })
end

return M