local M = {}

local api = vim.api
local state = require "marker-groups.state"
local function format_delete_warning(marker_count)
  local count = tonumber(marker_count) or 0
  if count <= 0 then
    return ""
  end
  local noun = count == 1 and "marker" or "markers"
  return string.format(" - %d %s will be lost", count, noun)
end

local ErrorHandler = {}

function ErrorHandler.show_error(operation, error_msg, error_code)
  local formatted_msg = string.format("%s Failed: %s", operation, error_msg)
  if error_code then
    formatted_msg = formatted_msg .. string.format(" (Code: %s)", error_code)
  end
  vim.notify(formatted_msg, vim.log.levels.ERROR)
end

function ErrorHandler.show_success(operation, details)
  local formatted_msg = operation .. " Successful"
  if details then
    formatted_msg = formatted_msg .. ": " .. details
  end
  vim.notify(formatted_msg, vim.log.levels.INFO)
end

function ErrorHandler.show_warning(operation, warning_msg)
  local formatted_msg = string.format("%s Warning: %s", operation, warning_msg)
  vim.notify(formatted_msg, vim.log.levels.WARN)
end

function ErrorHandler.handle_result(operation, result, success_details)
  if result.success then
    ErrorHandler.show_success(operation, success_details)
  else
    ErrorHandler.show_error(operation, result.error or "Unknown error", result.code)
  end
  return result
end

local function validate_group_name(name)
  if not name or type(name) ~= "string" then
    return false, "", "Group name must be a string"
  end

  local error_handling = require "marker-groups.error_handling"
  local result = error_handling.validate_input(name, "group_name")
  if not result.success then
    return false, "", result.error or "Invalid group name"
  end

  local sanitized = result.value

  local reserved = { "default", "all", "none", "temp", "temporary" }
  local lower_name = sanitized:lower()
  for _, reserved_name in ipairs(reserved) do
    if lower_name == reserved_name and sanitized ~= "default" then
      return false, "", "'" .. sanitized .. "' is a reserved group name"
    end
  end

  return true, sanitized, nil
end

function M.create_group(name, description)
  local valid, validated_name, error_msg = validate_group_name(name)
  if not valid then
    return state.Result.error(error_msg, "INVALID_GROUP_NAME")
  end

  name = validated_name

  local existing = state.get_group(name)
  if existing then
    return state.Result.error("Group already exists: " .. name, "GROUP_EXISTS")
  end

  local result = state.create_group(name)
  if not result.success then
    return result
  end

  if description and description ~= "" then
    result.value.description = description
  end

  local success, persistence = pcall(require, "marker-groups.persistence")
  if success and persistence.save then
    pcall(persistence.save)
  end

  local feedback = require "marker-groups.feedback"
  -- Suppress noisy creation notice during persistence hydration
  if not vim.g.__marker_groups_hydrating then
    feedback.success("Group Creation", "Created group: " .. name)
  end

  return result
end

function M.create_group_interactive(opts)
  opts = opts or {}
  local prompt = opts.prompt or "Enter group name:"
  local default = opts.default_name or ""

  local input_ui = require "marker-groups.ui.input"
  input_ui.prompt_with_limit(
    {
      prompt = prompt .. " ",
      default = default,
      completion = function(arg_lead, cmd_line, cursor_pos)
        local suggestions = {
          "feature-" .. os.date "%Y%m%d",
          "bugfix-" .. os.date "%Y%m%d",
          "refactor-" .. os.date "%Y%m%d",
          "review-" .. os.date "%Y%m%d",
          "experiment-" .. os.date "%Y%m%d",
        }

        local matches = {}
        for _, suggestion in ipairs(suggestions) do
          if suggestion:match("^" .. vim.pesc(arg_lead)) then
            table.insert(matches, suggestion)
          end
        end

        return matches
      end,
    },
    require("marker-groups.config").get_internal "max_group_name_chars",
    function(input)
      if input and input ~= "" then
        local result = M.create_group(input)
        ErrorHandler.handle_result("Group Creation", result, result.success and ("Created group: " .. input) or nil)

        if result.success then
          if opts.auto_switch ~= false then
            local switch_result = M.select_group(input)
            if not switch_result.success then
              ErrorHandler.show_warning("Group Creation", "Created group but failed to switch: " .. switch_result.error)
            end
          end
        end
      else
        ErrorHandler.show_warning("Group Creation", "Group creation cancelled")
      end
    end
  )

  return state.Result.ok { message = "Interactive group creation started" }
end

function M.create_group_from_branch()
  local handle = io.popen "git rev-parse --abbrev-ref HEAD 2>/dev/null"
  if not handle then
    return state.Result.error("Failed to get git branch", "GIT_ERROR")
  end

  local branch = handle:read "*a"
  handle:close()

  if not branch or branch == "" then
    return state.Result.error("Not in a git repository or no branch found", "NO_GIT_BRANCH")
  end

  branch = vim.trim(branch)
  if branch == "HEAD" then
    return state.Result.error("Cannot create group from detached HEAD", "DETACHED_HEAD")
  end

  local group_name = branch:gsub("[^%w%s_-]", "-"):lower()

  local result = M.create_group(group_name, "Created from git branch: " .. branch)
  if result.success then
    local feedback = require "marker-groups.feedback"
    feedback.success("Group Creation", "Created group '" .. group_name .. "' from branch '" .. branch .. "'")

    M.select_group(group_name)
  end

  return result
end

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
        is_active = state.get_active_group() == name,
      }

      if group.created_at then
        info.created_formatted = os.date("%Y-%m-%d %H:%M", group.created_at)
      end

      if group.modified_at then
        info.modified_formatted = os.date("%Y-%m-%d %H:%M", group.modified_at)
      end

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

  table.sort(groups_info, function(a, b)
    return (a.modified_at or 0) > (b.modified_at or 0)
  end)

  return groups_info
end

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
    least_markers = nil,
  }

  for _, group_info in ipairs(groups_info) do
    stats.total_markers = stats.total_markers + group_info.marker_count

    if group_info.marker_count > 0 then
      stats.groups_with_markers = stats.groups_with_markers + 1
    else
      stats.empty_groups = stats.empty_groups + 1
    end

    if
      not stats.newest_group or (group_info.created_at and group_info.created_at > (stats.newest_group.created_at or 0))
    then
      stats.newest_group = group_info
    end

    if
      not stats.oldest_group
      or (group_info.created_at and group_info.created_at < (stats.oldest_group.created_at or math.huge))
    then
      stats.oldest_group = group_info
    end

    if not stats.most_markers or group_info.marker_count > stats.most_markers.marker_count then
      stats.most_markers = group_info
    end

    if not stats.least_markers or group_info.marker_count < stats.least_markers.marker_count then
      stats.least_markers = group_info
    end
  end

  return stats
end

function M.format_group_info(group_info, format)
  format = format or "short"

  if format == "short" then
    local count = tonumber(group_info.marker_count) or 0
    local marker_text = count .. " marker" .. (count ~= 1 and "s" or "")
    local active_indicator = group_info.is_active and " *" or ""
    return group_info.name .. " (" .. marker_text .. ")" .. active_indicator
  elseif format == "long" then
    local lines = {
      "Group: " .. group_info.name .. (group_info.is_active and " (active)" or ""),
      "  Markers: " .. group_info.marker_count,
      "  Created: " .. (group_info.created_formatted or "unknown"),
      "  Modified: " .. (group_info.modified_formatted or "unknown"),
      "  Age: " .. (group_info.age or "unknown"),
    }
    return table.concat(lines, "\n")
  elseif format == "table" then
    return string.format(
      "%-20s %8d %15s %s",
      group_info.name .. (group_info.is_active and "*" or ""),
      group_info.marker_count,
      group_info.age or "unknown",
      group_info.created_formatted or "unknown"
    )
  end

  return group_info.name
end

function M.show_groups(format)
  format = format or "table"
  local groups_info = M.list_groups()

  if #groups_info == 0 then
    return
  end

  local lines = {}

  if format == "table" then
    table.insert(lines, string.format("%-20s %8s %15s %s", "GROUP", "MARKERS", "AGE", "CREATED"))
    table.insert(lines, string.rep("-", 70))
  end

  for _, group_info in ipairs(groups_info) do
    local formatted = M.format_group_info(group_info, format)
    if format == "long" then
      for line in formatted:gmatch "[^\n]+" do
        table.insert(lines, line)
      end
    else
      table.insert(lines, formatted)
    end
  end
  if format == "table" then
    local stats = M.get_group_statistics()
    table.insert(lines, "")
    table.insert(lines, string.format("Total: %d groups, %d markers", stats.total_groups, stats.total_markers))
    table.insert(lines, string.format("Active: %s", stats.active_group))
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.cmd "split"
  api.nvim_win_set_buf(0, buf)
  api.nvim_buf_set_name(buf, "Marker Groups")

  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "filetype", "marker-groups")
end

function M.select_group(name)
  if not name or name == "" then
    return M.select_group_interactive()
  end

  local group = state.get_group(name)
  if not group then
    return state.Result.error("Group does not exist: " .. name, "GROUP_NOT_FOUND")
  end

  local current_active = state.get_active_group()
  if current_active == name then
    return state.Result.ok { message = "Group already active", group_name = name }
  end

  local result = state.set_active_group(name)
  if not result.success then
    return result
  end

  local virtual_text = require "marker-groups.ui.virtual_text"
  virtual_text.update_all_buffers()

  return state.Result.ok { group_name = name, previous_group = current_active }
end

function M.select_group_interactive(opts)
  -- Delegate to unified pickers interface always
  local pickers = require "marker-groups.pickers"
  pickers.show_groups(opts)
  return state.Result.ok { message = "Picker group selector opened" }
end

function M.select_group_with_telescope(groups_info, opts)
  local telescope = require "telescope"
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

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
      group_info = group_info,
    })
  end

  pickers
    .new(opts, {
      prompt_title = opts.prompt or "Select Marker Group",
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry.value,
            display = entry.display,
            ordinal = entry.ordinal,
            group_info = entry.group_info,
          }
        end,
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
    })
    :find()

  return state.Result.ok { message = "Telescope group selector opened" }
end

function M.select_group_with_vim_ui(groups_info, opts)
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
    kind = "marker_group",
  }, function(selected)
    if selected then
      local group_name = name_map[selected]
      if group_name then
        M.select_group(group_name)
      end
    end
  end)

  return state.Result.ok { message = "Group selection UI opened" }
end

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

function M.rename_group(old_name, new_name)
  if not old_name or old_name == "" then
    return state.Result.error("Old group name cannot be empty", "INVALID_OLD_NAME")
  end

  local old_group = state.get_group(old_name)
  if not old_group then
    return state.Result.error("Group does not exist: " .. old_name, "GROUP_NOT_FOUND")
  end

  local valid, validated_name, error_msg = validate_group_name(new_name)
  if not valid then
    return state.Result.error(error_msg, "INVALID_NEW_NAME")
  end

  new_name = validated_name

  if old_name == new_name then
    return state.Result.ok { message = "Group name unchanged", group_name = old_name }
  end

  local existing_group = state.get_group(new_name)
  if existing_group then
    return state.Result.error("Group already exists: " .. new_name, "GROUP_EXISTS")
  end

  if old_name == "default" then
    return state.Result.error("Cannot rename the default group", "CANNOT_RENAME_DEFAULT")
  end

  local is_active_group = state.get_active_group() == old_name

  local rename_result = state.rename_group(old_name, new_name)
  if not rename_result.success then
    return rename_result
  end

  if is_active_group then
    local set_active_result = state.set_active_group(new_name)
    if set_active_result.success then
      local virtual_text = require "marker-groups.ui.virtual_text"
      virtual_text.update_all_buffers()
    end
  end

  local success, persistence = pcall(require, "marker-groups.persistence")
  if success and persistence.save then
    pcall(persistence.save)
  end

  local feedback = require "marker-groups.feedback"
  feedback.success("Group Rename", "Renamed '" .. old_name .. "' to '" .. new_name .. "'")

  return state.Result.ok {
    old_name = old_name,
    new_name = new_name,
    was_active = is_active_group,
    marker_count = #old_group.markers,
  }
end

function M.rename_group_interactive(old_name, opts)
  opts = opts or {}

  if not old_name or old_name == "" then
    local groups_info = M.list_groups()

    if #groups_info == 0 then
      vim.notify("No groups available to rename", vim.log.levels.WARN)
      return state.Result.error("No groups available", "NO_GROUPS")
    end

    local items = {}
    local name_map = {}

    for _, group_info in ipairs(groups_info) do
      if group_info.name ~= "default" then
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
      kind = "marker_group",
    }, function(selected)
      if selected then
        local selected_name = name_map[selected]
        if selected_name then
          M.rename_group_interactive(selected_name, opts)
        end
      end
    end)

    return state.Result.ok { message = "Group selection for rename opened" }
  end

  local prompt = opts.prompt or ("Rename '" .. old_name .. "' to:")
  local default = opts.default_new_name or ""

  local input_ui = require "marker-groups.ui.input"
  input_ui.prompt_with_limit(
    {
      prompt = prompt .. " ",
      default = default,
      completion = function(arg_lead, cmd_line, cursor_pos)
        local base_suggestions = {
          old_name .. "-new",
          old_name .. "-v2",
          old_name .. "-updated",
          "new-" .. old_name,
        }

        local matches = {}
        for _, suggestion in ipairs(base_suggestions) do
          if suggestion:match("^" .. vim.pesc(arg_lead)) then
            table.insert(matches, suggestion)
          end
        end

        return matches
      end,
    },
    require("marker-groups.config").get_internal "max_group_name_chars",
    function(input)
      if input and input ~= "" then
        local result = M.rename_group(old_name, input)
        if not result.success then
          vim.notify("Failed to rename group: " .. result.error, vim.log.levels.ERROR)
        end
      end
    end
  )

  return state.Result.ok { message = "Interactive rename started for " .. old_name }
end

function M.rename_active_group(new_name)
  local active_group = state.get_active_group()
  if not active_group then
    return state.Result.error("No active group to rename", "NO_ACTIVE_GROUP")
  end

  return M.rename_group(active_group, new_name)
end

function M.batch_rename_groups(pattern, replacement, opts)
  opts = opts or {}
  local dry_run = opts.dry_run or false
  local case_sensitive = opts.case_sensitive ~= false

  if not pattern or pattern == "" then
    return state.Result.error("Pattern cannot be empty", "INVALID_PATTERN")
  end

  if not replacement then
    replacement = ""
  end

  local groups_info = M.list_groups()
  local rename_candidates = {}

  for _, group_info in ipairs(groups_info) do
    local group_name = group_info.name

    if group_name ~= "default" then
      local match_name = case_sensitive and group_name or group_name:lower()
      local match_pattern = case_sensitive and pattern or pattern:lower()

      if match_name:find(match_pattern, 1, true) then
        local new_name = group_name:gsub(vim.pesc(pattern), replacement)
        table.insert(rename_candidates, {
          old_name = group_name,
          new_name = new_name,
          group_info = group_info,
        })
      end
    end
  end

  if #rename_candidates == 0 then
    return state.Result.ok {
      message = "No groups match pattern",
      pattern = pattern,
      candidates = rename_candidates,
    }
  end

  if dry_run then
    return state.Result.ok {
      message = "Dry run completed",
      pattern = pattern,
      replacement = replacement,
      candidates = rename_candidates,
    }
  end

  local results = {
    successful = {},
    failed = {},
  }

  for _, candidate in ipairs(rename_candidates) do
    local result = M.rename_group(candidate.old_name, candidate.new_name)
    if result.success then
      table.insert(results.successful, candidate)
    else
      table.insert(results.failed, {
        candidate = candidate,
        error = result.error,
      })
    end
  end

  local total = #results.successful + #results.failed

  return state.Result.ok {
    pattern = pattern,
    replacement = replacement,
    results = results,
    total_candidates = #rename_candidates,
  }
end

function M.delete_group(group_name, force)
  force = force or false

  if not group_name or group_name == "" then
    return state.Result.error("Group name cannot be empty", "INVALID_GROUP_NAME")
  end

  local group = state.get_group(group_name)
  if not group then
    return state.Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end

  if group_name == "default" and not force then
    return state.Result.error("Cannot delete the default group", "CANNOT_DELETE_DEFAULT")
  end

  local is_active_group = state.get_active_group() == group_name
  local marker_count = #group.markers

  local delete_result = state.delete_group(group_name)
  if not delete_result.success then
    return delete_result
  end

  if is_active_group then
    local switch_result = state.set_active_group "default"
    if switch_result.success then
      local virtual_text = require "marker-groups.ui.virtual_text"
      virtual_text.update_all_buffers()
    end
  end

  local success, persistence = pcall(require, "marker-groups.persistence")
  if success and persistence.save then
    pcall(persistence.save)
  end

  local feedback = require "marker-groups.feedback"
  feedback.success("Group Deletion", string.format("Deleted '%s' (%d markers)", group_name, marker_count))

  return state.Result.ok {
    group_name = group_name,
    was_active = is_active_group,
    marker_count = marker_count,
  }
end

function M.delete_group_with_confirmation(group_name, opts)
  opts = opts or {}
  local skip_confirmation = opts.skip_confirmation or false
  local force = opts.force or false

  if not group_name or group_name == "" then
    return M.select_group_for_deletion(opts)
  end

  local group = state.get_group(group_name)
  if not group then
    return state.Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end

  if group_name == "default" and not force then
    vim.notify("Cannot delete the default group", vim.log.levels.ERROR)
    return state.Result.error("Cannot delete the default group", "CANNOT_DELETE_DEFAULT")
  end

  local marker_count = #group.markers
  local is_active = state.get_active_group() == group_name

  if skip_confirmation then
    return M.delete_group(group_name, force)
  end

  local confirm_message = string.format(
    "Delete group '%s'?\n\n"
      .. "This will permanently delete:\n"
      .. "• %d marker%s\n"
      .. "%s\n"
      .. "This action cannot be undone.",
    group_name,
    marker_count,
    marker_count == 1 and "" or "s",
    is_active and "• The currently active group (will switch to default)" or ""
  )

  vim.ui.select({ "Yes", "No" }, {
    prompt = confirm_message,
    format_item = function(item)
      return item
    end,
    kind = "confirmation",
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

  return state.Result.ok { message = "Confirmation dialog opened for " .. group_name }
end

function M.select_group_for_deletion(opts)
  opts = opts or {}

  local groups_info = M.list_groups()

  if #groups_info == 0 then
    vim.notify("No groups available to delete", vim.log.levels.WARN)
    return state.Result.error("No groups available", "NO_GROUPS")
  end

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
        warning = warning .. format_delete_warning(group_info.marker_count)
      end

      display_text = display_text .. warning

      table.insert(items, display_text)
      name_map[display_text] = group_info.name
    end
  end

  if #items == 0 then
    local message = opts.force and "No groups available to delete"
      or "No deletable groups (default group cannot be deleted)"
    vim.notify(message, vim.log.levels.WARN)
    return state.Result.error("No deletable groups", "NO_DELETABLE_GROUPS")
  end

  vim.ui.select(items, {
    prompt = "Select group to delete:",
    format_item = function(item)
      return item
    end,
    kind = "marker_group",
  }, function(selected)
    if selected then
      local selected_name = name_map[selected]
      if selected_name then
        M.delete_group_with_confirmation(selected_name, opts)
      end
    end
  end)

  return state.Result.ok { message = "Group selection for deletion opened" }
end

function M.delete_active_group(opts)
  local active_group = state.get_active_group()
  if not active_group then
    return state.Result.error("No active group to delete", "NO_ACTIVE_GROUP")
  end

  return M.delete_group_with_confirmation(active_group, opts)
end

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

  for _, group_info in ipairs(groups_info) do
    local group_name = group_info.name

    if group_name ~= "default" or force then
      local match_name = case_sensitive and group_name or group_name:lower()
      local match_pattern = case_sensitive and pattern or pattern:lower()

      if match_name:find(match_pattern, 1, true) then
        table.insert(delete_candidates, group_info)
      end
    end
  end

  if #delete_candidates == 0 then
    return state.Result.ok {
      message = "No groups match pattern",
      pattern = pattern,
      candidates = delete_candidates,
    }
  end

  local total_markers = 0
  local active_groups = 0

  for _, candidate in ipairs(delete_candidates) do
    total_markers = total_markers + candidate.marker_count
    if candidate.is_active then
      active_groups = active_groups + 1
    end
  end

  if dry_run then
    return state.Result.ok {
      message = "Dry run completed",
      pattern = pattern,
      candidates = delete_candidates,
      total_markers = total_markers,
      active_groups = active_groups,
    }
  end

  if not skip_confirmation then
    local confirm_message = string.format(
      "Batch delete %d groups matching '%s'?\n\n"
        .. "This will permanently delete:\n"
        .. "• %d groups\n"
        .. "• %d total markers\n"
        .. "%s\n"
        .. "This action cannot be undone.",
      #delete_candidates,
      pattern,
      #delete_candidates,
      total_markers,
      active_groups > 0 and ("• " .. active_groups .. " active group(s) (will switch to default)") or ""
    )

    vim.ui.select({ "Yes", "No" }, {
      prompt = confirm_message,
      format_item = function(item)
        return item
      end,
      kind = "confirmation",
    }, function(choice)
      if choice == "Yes" then
        M.batch_delete_groups(pattern, vim.tbl_extend("force", opts, { skip_confirmation = true }))
      else
      end
    end)

    return state.Result.ok { message = "Batch deletion confirmation opened" }
  end

  local results = {
    successful = {},
    failed = {},
  }

  for _, candidate in ipairs(delete_candidates) do
    local result = M.delete_group(candidate.name, force)
    if result.success then
      table.insert(results.successful, candidate)
    else
      table.insert(results.failed, {
        candidate = candidate,
        error = result.error,
      })
    end
  end

  local total = #results.successful + #results.failed
  vim.notify(
    string.format(
      "Batch delete completed: %d successful, %d failed out of %d",
      #results.successful,
      #results.failed,
      total
    ),
    vim.log.levels.INFO
  )

  return state.Result.ok {
    pattern = pattern,
    results = results,
    total_candidates = #delete_candidates,
    total_markers_deleted = total_markers,
  }
end

return M
