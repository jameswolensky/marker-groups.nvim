local M = {}

local api = vim.api
local state = require "marker-groups.state"
local error_handling = require "marker-groups.error_handling"

local ns_id = api.nvim_create_namespace "marker_groups"

local function get_current_buffer_info(buf)
  buf = buf or api.nvim_get_current_buf()
  local path = api.nvim_buf_get_name(buf)

  if path and path ~= "" and not vim.startswith(path, "/") then
    path = vim.fn.fnamemodify(path, ":p")
  end

  return buf, path
end

local function get_line_range()
  local selection = require("marker-groups.line_selection").make_range()
  return selection.lstart, selection.lend
end

function M.add_marker_range(start_line, end_line, annotation, group_name, target_buf)
  local buf, path = get_current_buffer_info(target_buf)

  if not api.nvim_buf_is_valid(buf) then
    return state.Result.error("Invalid buffer", "INVALID_BUFFER")
  end

  if not path or path == "" then
    return state.Result.error("Buffer has no file path (save the file first)", "INVALID_BUFFER")
  end

  if not start_line or not end_line then
    start_line, end_line = get_line_range()
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local line_count = api.nvim_buf_line_count(buf)
  if start_line < 1 or start_line > line_count or end_line < 1 or end_line > line_count then
    return state.Result.error("Line numbers out of range", "INVALID_LINE_RANGE")
  end

  local annotation_validation = error_handling.validate_input(annotation or "", "annotation")
  if not annotation_validation.success then
    return annotation_validation
  end
  local validated_annotation = annotation_validation.value

  local marker_data = {
    buffer_path = path,
    start_line = start_line,
    end_line = end_line,
    annotation = validated_annotation,
  }

  local result = state.add_marker(marker_data, group_name)
  if not result.success then
    return result
  end

  local marker = result.value

  local extmark_id = M.create_extmark(buf, marker)
  marker.extmark_id = extmark_id

  M.update_buffer_markers(buf)

  return state.Result.ok(marker)
end

function M.get_visual_selection_info()
  local ls = require "marker-groups.line_selection"
  local mode = api.nvim_get_mode().mode

  if ls._is_visual_mode(mode) then
    local range = ls.make_range()
    local start_line = range.lstart
    local end_line = range.lend

    local buf, path = get_current_buffer_info()
    local lines = api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
    local preview = table.concat(lines, " "):sub(1, 100)
    if #preview == 100 then
      preview = preview .. "..."
    end

    return {
      mode = mode,
      start_line = start_line,
      end_line = end_line,
      line_count = end_line - start_line + 1,
      buffer_path = path,
      preview = preview,
    }
  end

  return nil
end

local function validate_buffer(buf, path)
  if not api.nvim_buf_is_valid(buf) then
    return false, "Invalid buffer"
  end

  if not path or path == "" then
    return false, "Buffer has no file path (save the file first)"
  end

  return true, nil
end

function M.add_marker(annotation, group_name, target_buf)
  local buf, path = get_current_buffer_info(target_buf)

  local valid, error_msg = validate_buffer(buf, path)
  if not valid then
    return state.Result.error(error_msg, "INVALID_BUFFER")
  end

  local start_line, end_line = get_line_range()
  if not start_line or not end_line then
    local cursor_line = api.nvim_win_get_cursor(0)[1]
    start_line, end_line = cursor_line, cursor_line
  end

  local line_count = api.nvim_buf_line_count(buf)
  if start_line < 1 or start_line > line_count or end_line < 1 or end_line > line_count then
    return state.Result.error("Line numbers out of range", "INVALID_LINE_RANGE")
  end

  local annotation_validation = error_handling.validate_input(annotation or "", "annotation")
  if not annotation_validation.success then
    return annotation_validation
  end
  local validated_annotation = annotation_validation.value

  local marker_data = {
    buffer_path = path,
    start_line = start_line,
    end_line = end_line,
    annotation = validated_annotation,
  }

  local result = state.add_marker(marker_data, group_name)
  if not result.success then
    return result
  end

  local marker = result.value

  local extmark_id = nil
  local extmark_success, extmark_result = pcall(function()
    local extmark_opts = {
      strict = false,
      right_gravity = false,
    }

    if start_line ~= end_line then
      extmark_opts.end_line = end_line - 1
      extmark_opts.end_col = 0
      extmark_opts.end_right_gravity = false
    end

    return api.nvim_buf_set_extmark(buf, ns_id, start_line - 1, 0, extmark_opts)
  end)

  if extmark_success then
    extmark_id = extmark_result
    marker.extmark_id = extmark_id
  else
    marker.extmark_id = nil
    require("marker-groups.feedback").notify(
      "Extmark creation failed, continuing without line tracking: " .. tostring(extmark_result),
      vim.log.levels.DEBUG,
      {}
    )
  end

  M.update_buffer_markers(buf)

  return state.Result.ok(marker)
end

function M.edit_marker(marker_id, new_annotation)
  local annotation_validation = error_handling.validate_input(new_annotation, "annotation")
  if not annotation_validation.success then
    return annotation_validation
  end
  local validated_annotation = annotation_validation.value

  local marker, group_name = state.get_marker(marker_id)
  if not marker then
    return state.Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end

  local now = os.time()
  if now <= (marker.timestamp or 0) then
    now = (marker.timestamp or 0) + 1
  end
  local updated_data = vim.tbl_extend("force", {}, marker, {
    annotation = validated_annotation,
    timestamp = now,
  })

  local remove_result = state.remove_marker(marker_id)
  if not remove_result.success then
    return remove_result
  end

  local add_result = state.add_marker(updated_data, group_name)
  if not add_result.success then
    state.add_marker(marker, group_name)
    return state.Result.error("Failed to update marker: " .. add_result.error, "UPDATE_FAILED")
  end

  local buf = vim.fn.bufnr(marker.buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end

  return state.Result.ok(add_result.value)
end

function M.delete_marker(marker_id)
  local marker, group_name = state.get_marker(marker_id)
  if not marker then
    return state.Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end

  local result = state.remove_marker(marker_id)
  if not result.success then
    return result
  end

  local buf = vim.fn.bufnr(marker.buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) and marker.extmark_id then
    pcall(api.nvim_buf_del_extmark, buf, ns_id, marker.extmark_id)
  end

  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end

  return result
end

function M.get_marker_at_cursor(group_name)
  local buf, path = get_current_buffer_info()
  local cursor = api.nvim_win_get_cursor(0)
  local line = cursor[1]

  return M.get_marker_at_line(path, line, group_name)
end

function M.get_marker_at_line(file_path, line, group_name)
  local group = state.get_group(group_name)
  if not group then
    return nil
  end

  local normalized_path = vim.fn.fnamemodify(file_path, ":p")

  for _, marker in ipairs(group.markers) do
    local marker_path = vim.fn.fnamemodify(marker.buffer_path, ":p")
    if marker_path == normalized_path and line >= marker.start_line and line <= marker.end_line then
      return marker
    end
  end

  return nil
end

function M.list_markers(group_name, filter)
  local group = state.get_group(group_name)
  if not group then
    return {}
  end

  local markers = vim.deepcopy(group.markers)

  if filter then
    if filter.buffer_path then
      local filter_path = vim.fn.fnamemodify(filter.buffer_path, ":p")
      markers = vim.tbl_filter(function(marker)
        local marker_path = vim.fn.fnamemodify(marker.buffer_path, ":p")
        return marker_path == filter_path
      end, markers)
    end

    if filter.start_line then
      markers = vim.tbl_filter(function(marker)
        return marker.end_line >= filter.start_line
      end, markers)
    end

    if filter.end_line then
      markers = vim.tbl_filter(function(marker)
        return marker.start_line <= filter.end_line
      end, markers)
    end
  end

  table.sort(markers, function(a, b)
    if a.buffer_path ~= b.buffer_path then
      return a.buffer_path < b.buffer_path
    end
    return a.start_line < b.start_line
  end)

  return markers
end

function M.get_current_buffer_markers(group_name)
  local buf, path = get_current_buffer_info()
  if not path or path == "" then
    return {}
  end

  return M.list_markers(group_name, { buffer_path = path })
end

function M.get_markers_in_range(file_path, start_line, end_line, group_name)
  local group = state.get_group(group_name)
  if not group then
    return {}
  end

  local normalized_path = vim.fn.fnamemodify(file_path, ":p")
  local intersecting = {}

  for _, marker in ipairs(group.markers) do
    local marker_path = vim.fn.fnamemodify(marker.buffer_path, ":p")
    if marker_path == normalized_path then
      if not (marker.end_line < start_line or marker.start_line > end_line) then
        table.insert(intersecting, marker)
      end
    end
  end

  table.sort(intersecting, function(a, b)
    return a.start_line < b.start_line
  end)

  return intersecting
end

function M.split_marker(marker_id, split_line)
  local marker, group_name = state.get_marker(marker_id)
  if not marker then
    return state.Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end

  if split_line <= marker.start_line or split_line >= marker.end_line then
    return state.Result.error("Split line must be within marker range", "INVALID_SPLIT_LINE")
  end

  if marker.start_line == marker.end_line then
    return state.Result.error("Cannot split single-line marker", "CANNOT_SPLIT_SINGLE_LINE")
  end

  local first_marker = vim.tbl_extend("force", {}, marker, {
    end_line = split_line - 1,
    annotation = marker.annotation .. " (part 1)",
  })

  local second_marker = vim.tbl_extend("force", {}, marker, {
    start_line = split_line,
    annotation = marker.annotation .. " (part 2)",
  })

  local remove_result = state.remove_marker(marker_id)
  if not remove_result.success then
    return remove_result
  end

  local first_result = state.add_marker(first_marker, group_name)
  if not first_result.success then
    state.add_marker(marker, group_name)
    return state.Result.error("Failed to create first part: " .. first_result.error, "SPLIT_FAILED")
  end

  local second_result = state.add_marker(second_marker, group_name)
  if not second_result.success then
    state.remove_marker(first_result.value.id)
    state.add_marker(marker, group_name)
    return state.Result.error("Failed to create second part: " .. second_result.error, "SPLIT_FAILED")
  end

  local buf = vim.fn.bufnr(marker.buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end

  return state.Result.ok {
    first = first_result.value,
    second = second_result.value,
  }
end

function M.merge_markers(marker_ids, new_annotation)
  if not marker_ids or #marker_ids < 2 then
    return state.Result.error("Need at least 2 markers to merge", "INSUFFICIENT_MARKERS")
  end

  local markers = {}
  local group_name = nil
  local buffer_path = nil

  for _, id in ipairs(marker_ids) do
    local marker, gname = state.get_marker(id)
    if not marker then
      return state.Result.error("Marker not found: " .. id, "MARKER_NOT_FOUND")
    end

    if group_name == nil then
      group_name = gname
      buffer_path = marker.buffer_path
    elseif group_name ~= gname or buffer_path ~= marker.buffer_path then
      return state.Result.error("All markers must be in the same group and file", "MARKERS_NOT_COMPATIBLE")
    end

    table.insert(markers, marker)
  end

  table.sort(markers, function(a, b)
    return a.start_line < b.start_line
  end)

  local merged_start = markers[1].start_line
  local merged_end = markers[1].end_line

  for i = 2, #markers do
    local marker = markers[i]
    merged_end = math.max(merged_end, marker.end_line)
  end

  local merged_annotation = new_annotation
    or (
      "Merged: "
      .. table.concat(
        vim.tbl_map(function(m)
          return m.annotation
        end, markers),
        " + "
      )
    )

  local merged_marker = {
    buffer_path = buffer_path,
    start_line = merged_start,
    end_line = merged_end,
    annotation = merged_annotation,
  }

  for _, id in ipairs(marker_ids) do
    local remove_result = state.remove_marker(id)
    if not remove_result.success then
      return state.Result.error("Failed to remove marker " .. id, "MERGE_CLEANUP_FAILED")
    end
  end

  local add_result = state.add_marker(merged_marker, group_name)
  if not add_result.success then
    for _, marker in ipairs(markers) do
      state.add_marker(marker, group_name)
    end
    return state.Result.error("Failed to create merged marker: " .. add_result.error, "MERGE_FAILED")
  end

  local buf = vim.fn.bufnr(buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end

  return state.Result.ok(add_result.value)
end

function M.get_buffer_marker_stats(group_name)
  local markers = M.get_current_buffer_markers(group_name)

  local stats = {
    total_markers = #markers,
    single_line = 0,
    multi_line = 0,
    total_lines_covered = 0,
    longest_marker = nil,
    shortest_marker = nil,
  }

  for _, marker in ipairs(markers) do
    local line_span = marker.end_line - marker.start_line + 1
    stats.total_lines_covered = stats.total_lines_covered + line_span

    if marker.start_line == marker.end_line then
      stats.single_line = stats.single_line + 1
    else
      stats.multi_line = stats.multi_line + 1
    end

    if
      not stats.longest_marker or line_span > (stats.longest_marker.end_line - stats.longest_marker.start_line + 1)
    then
      stats.longest_marker = marker
    end

    if
      not stats.shortest_marker or line_span < (stats.shortest_marker.end_line - stats.shortest_marker.start_line + 1)
    then
      stats.shortest_marker = marker
    end
  end

  return stats
end

function M.update_buffer_markers(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local path = api.nvim_buf_get_name(buf)
  if not path or path == "" then
    return
  end

  local markers = M.list_markers(nil, { buffer_path = path })

  require("marker-groups.ui.virtual_text").update_buffer_display(buf, markers)
end

function M.sync_extmarks(buf)
  if not api.nvim_buf_is_valid(buf) then
    return state.Result.error("Invalid buffer", "INVALID_BUFFER")
  end

  local path = api.nvim_buf_get_name(buf)
  local markers = M.list_markers(nil, { buffer_path = path })
  local sync_results = {
    updated = 0,
    failed = 0,
    total = #markers,
  }

  for _, marker in ipairs(markers) do
    if marker.extmark_id then
      local success, extmark_info = pcall(function()
        return api.nvim_buf_get_extmark_by_id(buf, ns_id, marker.extmark_id, {
          details = true,
        })
      end)

      if success and extmark_info and #extmark_info >= 2 then
        local new_start_line = extmark_info[1] + 1
        local details = extmark_info[3] or {}
        local new_end_line = details.end_row and (details.end_row + 1) or new_start_line

        if new_start_line ~= marker.start_line or new_end_line ~= marker.end_line then
          local updated_marker_data = vim.tbl_extend("force", {}, marker, {
            start_line = new_start_line,
            end_line = new_end_line,
          })

          local remove_result = state.remove_marker(marker.id)
          if remove_result.success then
            local add_result = state.add_marker(updated_marker_data)
            if add_result.success then
              sync_results.updated = sync_results.updated + 1
              require("marker-groups.feedback").notify(
                string.format(
                  "Marker '%s' moved from line %d-%d to %d-%d",
                  marker.annotation:sub(1, 20),
                  marker.start_line,
                  marker.end_line,
                  new_start_line,
                  new_end_line
                ),
                vim.log.levels.DEBUG,
                {}
              )
            else
              sync_results.failed = sync_results.failed + 1
            end
          else
            sync_results.failed = sync_results.failed + 1
          end
        end
      else
        local recreated_id = M.create_extmark(buf, marker)
        if recreated_id then
          pcall(function()
            local state = require "marker-groups.state"
            state.update_marker(marker.id, { extmark_id = recreated_id })
          end)
          sync_results.updated = sync_results.updated + 1
          require("marker-groups.feedback").notify(
            string.format("Marker '%s' extmark recreated", marker.annotation:sub(1, 20)),
            vim.log.levels.DEBUG,
            {}
          )
        else
          require("marker-groups.feedback").notify(
            string.format("Marker '%s' extmark missing and could not be recreated", marker.annotation:sub(1, 20)),
            vim.log.levels.DEBUG,
            {}
          )
        end
      end
    end
  end

  if sync_results.updated > 0 then
    M.update_buffer_markers(buf)
  end

  return state.Result.ok(sync_results)
end

function M.setup_line_tracking(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local group = api.nvim_create_augroup("MarkerGroupsLineTracking_" .. buf, { clear = true })

  api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    group = group,
    callback = function()
      vim.defer_fn(function()
        if api.nvim_buf_is_valid(buf) then
          M.sync_extmarks(buf)
        end
      end, 100)
    end,
  })

  api.nvim_create_autocmd({ "TextChangedP" }, {
    buffer = buf,
    group = group,
    callback = function()
      vim.defer_fn(function()
        if api.nvim_buf_is_valid(buf) then
          M.sync_extmarks(buf)
        end
      end, 50)
    end,
  })

  api.nvim_create_autocmd("BufDelete", {
    buffer = buf,
    group = group,
    callback = function()
      api.nvim_del_augroup_by_id(group)
    end,
  })
end

function M.setup_global_line_tracking()
  local group = api.nvim_create_augroup("MarkerGroupsGlobalTracking", { clear = true })

  api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufEnter" }, {
    group = group,
    callback = function(args)
      local buf = args.buf
      if api.nvim_buf_is_valid(buf) then
        local path = api.nvim_buf_get_name(buf)
        if path and path ~= "" then
          local markers = M.list_markers(nil, { buffer_path = path })
          if #markers > 0 then
            M.setup_line_tracking(buf)
            M.refresh_extmarks(buf)
          end
        end
      end
    end,
  })

  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.sync_all_buffers()
    end,
  })
end

function M.sync_all_buffers()
  local synced_count = 0
  local error_count = 0

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      local path = api.nvim_buf_get_name(buf)
      if path and path ~= "" then
        local markers = M.list_markers(nil, { buffer_path = path })
        if #markers > 0 then
          local result = M.sync_extmarks(buf)
          if result.success then
            synced_count = synced_count + 1
          else
            error_count = error_count + 1
          end
        end
      end
    end
  end

  return {
    synced_buffers = synced_count,
    error_buffers = error_count,
  }
end

function M.handle_major_change(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  M.refresh_extmarks(buf)

  M.update_buffer_markers(buf)

  local state = require "marker-groups.state"
  state.emit("buffer_major_change", {
    buffer = buf,
    path = api.nvim_buf_get_name(buf),
  })
end

function M.handle_buffer_change(buf, change_type, change_data)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local path = api.nvim_buf_get_name(buf)
  local markers = M.list_markers(nil, { buffer_path = path })

  if #markers == 0 then
    return
  end

  if change_type == "lines_added" and change_data then
    local insert_line = change_data.line or 1
    local line_count = change_data.count or 1

    require("marker-groups.feedback").notify(
      string.format("Lines added at %d (count: %d), updating %d markers", insert_line, line_count, #markers),
      vim.log.levels.DEBUG,
      {}
    )
  elseif change_type == "lines_deleted" and change_data then
    local delete_line = change_data.line or 1
    local line_count = change_data.count or 1

    require("marker-groups.feedback").notify(
      string.format("Lines deleted at %d (count: %d), updating %d markers", delete_line, line_count, #markers),
      vim.log.levels.DEBUG,
      {}
    )
  end

  M.sync_extmarks(buf)
end

function M.create_extmark(buf, marker)
  if not api.nvim_buf_is_valid(buf) then
    return nil
  end

  local success, extmark_id = pcall(function()
    local extmark_opts = {
      strict = false,
      right_gravity = false,
    }

    if marker.start_line ~= marker.end_line then
      extmark_opts.end_line = marker.end_line - 1
      extmark_opts.end_col = 0
      extmark_opts.end_right_gravity = false
    end

    return api.nvim_buf_set_extmark(buf, ns_id, marker.start_line - 1, 0, extmark_opts)
  end)

  return success and extmark_id or nil
end

function M.refresh_extmarks(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local path = api.nvim_buf_get_name(buf)
  local markers = M.list_markers(nil, { buffer_path = path })

  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  for _, marker in ipairs(markers) do
    local extmark_id = M.create_extmark(buf, marker)
    if extmark_id then
      marker.extmark_id = extmark_id

      pcall(function()
        local state = require "marker-groups.state"
        state.update_marker(marker.id, { extmark_id = extmark_id })
      end)
    end
  end

  M.update_buffer_markers(buf)
end

function M.debug_info()
  local buf, path = get_current_buffer_info()
  local current_markers = {}
  local extmark_count = 0

  if path and path ~= "" then
    current_markers = M.list_markers(nil, { buffer_path = path })
  end

  if api.nvim_buf_is_valid(buf) then
    local extmarks = api.nvim_buf_get_extmarks(buf, ns_id, 0, -1, {})
    extmark_count = #extmarks
  end

  return {
    current_buffer = buf,
    current_path = path,
    markers_in_buffer = #current_markers,
    extmarks_in_buffer = extmark_count,
    namespace_id = ns_id,
    active_group = state.get_active_group(),
  }
end

function M.clear_buffer_markers(buf, group_name)
  buf = buf or api.nvim_get_current_buf()
  group_name = group_name or state.get_active_group()

  if not group_name then
    return state.Result.error("No active group", "NO_ACTIVE_GROUP")
  end

  local buffer_path = api.nvim_buf_get_name(buf)
  if buffer_path == "" then
    return state.Result.error("Buffer has no file path", "NO_FILE_PATH")
  end

  local markers = M.get_current_buffer_markers(group_name)
  if not markers.success then
    return markers
  end

  local cleared_count = 0
  for _, marker in ipairs(markers.value) do
    local result = M.delete_marker(marker.id)
    if result.success then
      cleared_count = cleared_count + 1
    end
  end

  return state.Result.success("Cleared " .. cleared_count .. " markers", cleared_count)
end

function M.get_buffer_markers(buf, group_name)
  return M.get_current_buffer_markers(group_name)
end

return M
