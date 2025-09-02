local M = {}

local logger = require "marker-groups.utils.logger"
local state = require "marker-groups.state"
local config = require "marker-groups.config"
local feedback = require "marker-groups.feedback"

function M.set_debug_mode(enable)
  local current_config = config.get()
  local current_debug = config.get_value("debug", false)

  if enable == nil then
    enable = not current_debug
  end

  current_config.debug = enable
  config.update(current_config)

  if enable then
    logger.set_level "debug"
    logger.info("Debug mode enabled", true)
  else
    logger.info("Debug mode disabled", true)
  end

  return enable
end

function M.is_debug_mode()
  return config.get_value("debug", false)
end

function M.dump_state()
  local state_data = state.get_state()
  local active_group = state.get_active_group()
  local group_names = state.get_group_names()
  local all_groups = {}
  for _, name in ipairs(group_names) do
    all_groups[name] = state.get_group(name)
  end

  local dump = {
    timestamp = os.date "%Y-%m-%d %H:%M:%S",
    neovim_version = vim.version(),
    plugin_info = {
      debug_mode = M.is_debug_mode(),
      log_level = logger.get_level(),
      active_group = active_group,
      total_groups = vim.tbl_count(all_groups),
    },
    configuration = config.get(),
    state = {
      raw_state = state_data,
      groups_summary = {},
      marker_counts = {},
      total_markers = 0,
    },
    performance = {},
    environment = {
      nvim_version = vim.version(),
      has_telescope = pcall(require, "telescope"),
      data_dir = config.get_value "data_dir",
      os = vim.loop.os_uname(),
    },
  }

  local total_markers = 0
  for group_name, group_data in pairs(all_groups) do
    local marker_count = #(group_data.markers or {})
    total_markers = total_markers + marker_count

    dump.state.groups_summary[group_name] = {
      marker_count = marker_count,
      created_at = group_data.created_at,
      modified_at = group_data.modified_at,
      is_active = (group_name == active_group),
    }

    dump.state.marker_counts[group_name] = marker_count
  end

  dump.state.total_markers = total_markers

  local start_time = vim.loop.hrtime()
  for i = 1, 100 do
    config.get_value "data_dir"
  end
  local end_time = vim.loop.hrtime()
  dump.performance.config_access_100x = (end_time - start_time) / 1000000

  return dump
end

function M.show_state()
  local dump = M.dump_state()

  local lines = {
    "🔍 Marker Groups Debug State",
    "═══════════════════════════",
    "",
    "📊 Overview:",
    "  • Debug Mode: " .. (dump.plugin_info.debug_mode and "✅ ON" or "❌ OFF"),
    "  • Log Level: " .. dump.plugin_info.log_level,
    "  • Active Group: " .. (dump.plugin_info.active_group or "none"),
    "  • Total Groups: " .. dump.plugin_info.total_groups,
    "  • Total Markers: " .. dump.state.total_markers,
    "",
    "🏷️  Groups:",
  }

  for group_name, group_info in pairs(dump.state.groups_summary) do
    local status = group_info.is_active and " (ACTIVE)" or ""
    table.insert(lines, string.format("  • %s: %d markers%s", group_name, group_info.marker_count, status))
  end

  table.insert(lines, "")
  table.insert(lines, "⚡ Performance:")
  table.insert(lines, string.format("  • Config access (100x): %.2fms", dump.performance.config_access_100x))

  table.insert(lines, "")
  table.insert(lines, "🌍 Environment:")
  table.insert(
    lines,
    "  • Neovim: "
      .. dump.neovim_version.major
      .. "."
      .. dump.neovim_version.minor
      .. "."
      .. dump.neovim_version.patch
  )

  table.insert(lines, "  • OS: " .. dump.environment.os.sysname)

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)

  logger.debug "State dump generated and displayed"
  return dump
end

function M.write_state_dump(filepath)
  local dump = M.dump_state()

  if not filepath then
    local data_dir = config.get_value "data_dir"
    filepath = data_dir .. "/debug-state-" .. os.date "%Y%m%d-%H%M%S" .. ".json"
  end

  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")

  local file = io.open(filepath, "w")
  if not file then
    local error_msg = "Failed to write state dump to: " .. filepath
    logger.error(error_msg, true)
    return filepath
  end

  file:write(vim.json.encode(dump))
  file:close()

  local success_msg = "State dump written to: " .. filepath
  logger.info(success_msg, true)
  feedback.success("Debug", success_msg)

  return filepath
end

function M.inspect_group(group_name)
  if not group_name then
    group_name = state.get_active_group()
  end

  if not group_name then
    feedback.error("Debug", "No active group to inspect")
    return
  end

  local group_data = state.get_group(group_name)
  if not group_data then
    feedback.error("Debug", "Group not found: " .. group_name)
    return
  end

  local lines = {
    "🔍 Group Inspection: " .. group_name,
    string.rep("═", 25 + string.len(group_name)),
    "",
    "📋 Basic Info:",
    "  • Name: " .. group_name,
    "  • Markers: " .. #(group_data.markers or {}),
    "  • Created: " .. (group_data.created_at and os.date("%Y-%m-%d %H:%M:%S", group_data.created_at) or "unknown"),
    "  • Modified: "
      .. (group_data.modified_at and os.date("%Y-%m-%d %H:%M:%S", group_data.modified_at) or "unknown"),
    "  • Is Active: " .. (group_name == state.get_active_group() and "✅" or "❌"),
    "",
  }

  if group_data.markers and #group_data.markers > 0 then
    table.insert(lines, "📌 Markers:")
    for i, marker in ipairs(group_data.markers) do
      local file_name = vim.fn.fnamemodify(marker.buffer_path or "unknown", ":t")
      local line_info = marker.start_line or "?"
      if marker.end_line and marker.end_line ~= marker.start_line then
        line_info = line_info .. "-" .. marker.end_line
      end

      table.insert(
        lines,
        string.format("  %d. %s:%s - %s", i, file_name, line_info, marker.annotation or "no annotation")
      )
    end
  else
    table.insert(lines, "📌 No markers in this group")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  logger.debug("Inspected group: " .. group_name)
end

function M.validate_state()
  local validation = {
    timestamp = os.date "%Y-%m-%d %H:%M:%S",
    valid = true,
    errors = {},
    warnings = {},
    info = {},
  }

  local function add_error(message)
    table.insert(validation.errors, message)
    validation.valid = false
    logger.error("State validation error: " .. message)
  end

  local function add_warning(message)
    table.insert(validation.warnings, message)
    logger.warn("State validation warning: " .. message)
  end

  local function add_info(message)
    table.insert(validation.info, message)
    logger.debug("State validation info: " .. message)
  end

  local state_data = state.get_state()
  if not state_data then
    add_error "Plugin state is not available"
    return validation
  end

  local active_group = state.get_active_group()
  if not active_group then
    add_warning "No active group set"
  else
    local group_exists = state.get_group(active_group)
    if not group_exists then
      add_error("Active group '" .. active_group .. "' does not exist in state")
    else
      add_info("Active group '" .. active_group .. "' is valid")
    end
  end

  local group_names = state.get_group_names()
  local all_groups = {}
  for _, name in ipairs(group_names) do
    all_groups[name] = state.get_group(name)
  end
  local group_count = 0
  local marker_count = 0

  for group_name, group_data in pairs(all_groups) do
    group_count = group_count + 1

    if type(group_data) ~= "table" then
      add_error("Group '" .. group_name .. "' has invalid data type")
    else
      if not group_data.markers then
        add_warning("Group '" .. group_name .. "' missing markers array")
        group_data.markers = {}
      end

      if not group_data.created_at then
        add_warning("Group '" .. group_name .. "' missing created_at timestamp")
      end

      for i, marker in ipairs(group_data.markers) do
        marker_count = marker_count + 1

        if not marker.buffer_path then
          add_error("Marker " .. i .. " in group '" .. group_name .. "' missing buffer_path")
        end

        if not marker.start_line then
          add_error("Marker " .. i .. " in group '" .. group_name .. "' missing start_line")
        end

        if not marker.annotation then
          add_warning("Marker " .. i .. " in group '" .. group_name .. "' missing annotation")
        end
      end

      add_info("Group '" .. group_name .. "' has " .. #group_data.markers .. " markers")
    end
  end

  add_info("Validated " .. group_count .. " groups with " .. marker_count .. " total markers")

  return validation
end

function M.show_validation()
  local validation = M.validate_state()

  local lines = {
    "🔍 Plugin State Validation",
    "═══════════════════════════",
    "",
    "Status: " .. (validation.valid and "✅ VALID" or "❌ INVALID"),
    "Timestamp: " .. validation.timestamp,
    "",
  }

  if #validation.errors > 0 then
    table.insert(lines, "❌ Errors (" .. #validation.errors .. "):")
    for _, error in ipairs(validation.errors) do
      table.insert(lines, "  • " .. error)
    end
    table.insert(lines, "")
  end

  if #validation.warnings > 0 then
    table.insert(lines, "⚠️  Warnings (" .. #validation.warnings .. "):")
    for _, warning in ipairs(validation.warnings) do
      table.insert(lines, "  • " .. warning)
    end
    table.insert(lines, "")
  end

  if #validation.info > 0 then
    table.insert(lines, "ℹ️  Info (" .. #validation.info .. "):")
    for _, info in ipairs(validation.info) do
      table.insert(lines, "  • " .. info)
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  return validation
end

function M.register_commands() end

return M
