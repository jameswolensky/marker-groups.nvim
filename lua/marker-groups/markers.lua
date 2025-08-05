---@class MarkerOperations
local M = {}

local api = vim.api
local state = require("marker-groups.state")

-- Create namespace for extmarks
local ns_id = api.nvim_create_namespace("marker_groups")

---Get current buffer info
---@return integer, string buffer_id, buffer_path
local function get_current_buffer_info()
  local buf = api.nvim_get_current_buf()
  local path = api.nvim_buf_get_name(buf)
  
  -- Convert to absolute path if relative
  if path and path ~= "" and not vim.startswith(path, "/") then
    path = vim.fn.fnamemodify(path, ":p")
  end
  
  return buf, path
end

---Get line range from current cursor or visual selection
---@return integer, integer start_line, end_line (1-indexed)
local function get_line_range()
  local mode = api.nvim_get_mode().mode
  
  -- Check for visual modes or recent visual selection
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Active visual mode - get selection range using getpos for reliability
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    
    -- getpos returns [bufnum, lnum, col, off] - we want lnum (index 2)
    local start_line = start_pos[2]
    local end_line = end_pos[2]
    
    -- Ensure proper ordering (start <= end)
    if start_line > 0 and end_line > 0 then
      return math.min(start_line, end_line), math.max(start_line, end_line)
    end
  end
  
  -- Not in visual mode, but check if there was a recent visual selection
  -- This handles the case where keymap was triggered just after exiting visual mode
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  if start_pos[2] > 0 and end_pos[2] > 0 then
    local start_line = start_pos[2]
    local end_line = end_pos[2]
    
    -- Only use visual marks if they represent a meaningful range
    -- and the marks are from the current buffer
    local current_buf = api.nvim_get_current_buf()
    if (start_pos[1] == 0 or start_pos[1] == current_buf) and 
       (end_pos[1] == 0 or end_pos[1] == current_buf) and
       (start_line ~= end_line or mode == "v" or mode == "V" or mode == "\22") then
      return math.min(start_line, end_line), math.max(start_line, end_line)
    end
  end
  
  -- Fallback to current cursor line
  local cursor = api.nvim_win_get_cursor(0)
  return cursor[1], cursor[1]
end

---Add marker from visual selection or range
---@param start_line? integer Starting line (1-indexed, optional - uses current if nil)
---@param end_line? integer Ending line (1-indexed, optional - uses current if nil)
---@param annotation? string Marker annotation text
---@param group_name? string Target group (defaults to active group)
---@return table Result object
function M.add_marker_range(start_line, end_line, annotation, group_name)
  local buf, path = get_current_buffer_info()
  
  -- Validate buffer (inline validation)
  if not api.nvim_buf_is_valid(buf) then
    return state.Result.error("Invalid buffer", "INVALID_BUFFER")
  end
  
  if not path or path == "" then
    return state.Result.error("Buffer has no file path (save the file first)", "INVALID_BUFFER")
  end
  
  -- Use provided lines or get from cursor/selection
  if not start_line or not end_line then
    start_line, end_line = get_line_range()
  end
  
  -- Ensure proper ordering
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  
  -- Validate line numbers
  local line_count = api.nvim_buf_line_count(buf)
  if start_line < 1 or start_line > line_count or end_line < 1 or end_line > line_count then
    return state.Result.error("Line numbers out of range", "INVALID_LINE_RANGE")
  end
  
  -- Create marker data
  local marker_data = {
    buffer_path = path,
    start_line = start_line,
    end_line = end_line,
    annotation = annotation or ""
  }
  
  -- Add to state
  local result = state.add_marker(marker_data, group_name)
  if not result.success then
    return result
  end
  
  local marker = result.value
  
  -- Create extmark for line tracking
  local extmark_id = M.create_extmark(buf, marker)
  marker.extmark_id = extmark_id
  
  -- Update UI
  M.update_buffer_markers(buf)
  
  return state.Result.ok(marker)
end

---Get visual selection info without creating marker
---@return table? Selection info or nil if not in visual mode
function M.get_visual_selection_info()
  local mode = api.nvim_get_mode().mode
  
  if mode == "v" or mode == "V" or mode == "\22" then
    local start_pos = api.nvim_buf_get_mark(0, "<")
    local end_pos = api.nvim_buf_get_mark(0, ">")
    
    local start_line = math.min(start_pos[1], end_pos[1])
    local end_line = math.max(start_pos[1], end_pos[1])
    
    local buf, path = get_current_buffer_info()
    
    -- Get selected text preview
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
      preview = preview
    }
  end
  
  return nil
end

---Validate buffer and path
---@param buf integer
---@param path string
---@return boolean, string? valid, error_message
local function validate_buffer(buf, path)
  if not api.nvim_buf_is_valid(buf) then
    return false, "Invalid buffer"
  end
  
  if not path or path == "" then
    return false, "Buffer has no file path (save the file first)"
  end
  
  -- Allow any named buffer for testing/temporary files
  -- In headless mode or testing, we may have temporary buffers
  
  return true, nil
end

---Add a marker at current position or visual selection
---@param annotation? string Marker annotation text
---@param group_name? string Target group (defaults to active group)
---@return table Result object
function M.add_marker(annotation, group_name)
  local buf, path = get_current_buffer_info()
  
  -- Validate buffer
  local valid, error_msg = validate_buffer(buf, path)
  if not valid then
    return state.Result.error(error_msg, "INVALID_BUFFER")
  end
  
  -- Get line range
  local start_line, end_line = get_line_range()
  
  -- Validate line numbers
  local line_count = api.nvim_buf_line_count(buf)
  if start_line < 1 or start_line > line_count or end_line < 1 or end_line > line_count then
    return state.Result.error("Line numbers out of range", "INVALID_LINE_RANGE")
  end
  
  -- Create marker data
  local marker_data = {
    buffer_path = path,
    start_line = start_line,
    end_line = end_line,
    annotation = annotation or ""
  }
  
  -- Add to state
  local result = state.add_marker(marker_data, group_name)
  if not result.success then
    return result
  end
  
  local marker = result.value
  
  -- Create extmark for line tracking
  local extmark_id = nil
  local extmark_success, extmark_result = pcall(function()
    -- Configure extmark based on marker type
    local extmark_opts = {
      strict = false,
      right_gravity = false
    }
    
    -- For multi-line markers, set end position
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
    -- Continue without extmark for headless mode or other edge cases
    marker.extmark_id = nil
    vim.notify("Extmark creation failed, continuing without line tracking: " .. tostring(extmark_result), vim.log.levels.DEBUG)
  end
  
  -- Update UI
  M.update_buffer_markers(buf)
  
  return state.Result.ok(marker)
end

---Edit a marker's annotation
---@param marker_id string Marker UUID
---@param new_annotation string New annotation text
---@return table Result object
function M.edit_marker(marker_id, new_annotation)
  if not new_annotation or type(new_annotation) ~= "string" then
    return state.Result.error("Annotation must be a non-empty string", "INVALID_ANNOTATION")
  end
  
  -- Find marker
  local marker, group_name = state.get_marker(marker_id)
  if not marker then
    return state.Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end
  
  -- Create updated marker (immutable design - remove old, add new)
  local updated_data = vim.tbl_extend("force", {}, marker, {
    annotation = new_annotation,
    timestamp = os.time()  -- Update timestamp
  })
  
  -- Remove old marker
  local remove_result = state.remove_marker(marker_id)
  if not remove_result.success then
    return remove_result
  end
  
  -- Add updated marker
  local add_result = state.add_marker(updated_data, group_name)
  if not add_result.success then
    -- If adding fails, try to restore the old marker
    state.add_marker(marker, group_name)
    return state.Result.error("Failed to update marker: " .. add_result.error, "UPDATE_FAILED")
  end
  
  -- Update UI for the buffer if it's currently open
  local buf = vim.fn.bufnr(marker.buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end
  
  return state.Result.ok(add_result.value)
end

---Delete a marker
---@param marker_id string Marker UUID
---@return table Result object
function M.delete_marker(marker_id)
  -- Find marker first to get buffer info
  local marker, group_name = state.get_marker(marker_id)
  if not marker then
    return state.Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end
  
  -- Remove from state
  local result = state.remove_marker(marker_id)
  if not result.success then
    return result
  end
  
  -- Remove extmark if buffer is loaded
  local buf = vim.fn.bufnr(marker.buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) and marker.extmark_id then
    pcall(api.nvim_buf_del_extmark, buf, ns_id, marker.extmark_id)
  end
  
  -- Update UI for the buffer
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end
  
  return result
end

---Get marker at current cursor position
---@param group_name? string Group to search (defaults to active group)
---@return table? Marker or nil if not found
function M.get_marker_at_cursor(group_name)
  local buf, path = get_current_buffer_info()
  local cursor = api.nvim_win_get_cursor(0)
  local line = cursor[1]
  
  return M.get_marker_at_line(path, line, group_name)
end

---Get marker at specific line in file
---@param file_path string Full file path
---@param line integer Line number (1-indexed)
---@param group_name? string Group to search (defaults to active group)
---@return table? Marker or nil if not found
function M.get_marker_at_line(file_path, line, group_name)
  local group = state.get_group(group_name)
  if not group then
    return nil
  end
  
  -- Normalize file path for comparison
  local normalized_path = vim.fn.fnamemodify(file_path, ":p")
  
  for _, marker in ipairs(group.markers) do
    local marker_path = vim.fn.fnamemodify(marker.buffer_path, ":p")
    if marker_path == normalized_path and 
       line >= marker.start_line and 
       line <= marker.end_line then
      return marker
    end
  end
  
  return nil
end

---List all markers in a group
---@param group_name? string Group name (defaults to active group)
---@param filter? table Optional filter { buffer_path?, start_line?, end_line? }
---@return table[] Array of markers
function M.list_markers(group_name, filter)
  local group = state.get_group(group_name)
  if not group then
    return {}
  end
  
  local markers = vim.deepcopy(group.markers)
  
  -- Apply filters if provided
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
  
  -- Sort by file path, then by line number
  table.sort(markers, function(a, b)
    if a.buffer_path ~= b.buffer_path then
      return a.buffer_path < b.buffer_path
    end
    return a.start_line < b.start_line
  end)
  
  return markers
end

---Get markers for current buffer
---@param group_name? string Group name (defaults to active group)
---@return table[] Array of markers for current buffer
function M.get_current_buffer_markers(group_name)
  local buf, path = get_current_buffer_info()
  if not path or path == "" then
    return {}
  end
  
  return M.list_markers(group_name, { buffer_path = path })
end

---Find markers that intersect with a line range
---@param file_path string Full file path
---@param start_line integer Starting line (1-indexed)
---@param end_line integer Ending line (1-indexed)
---@param group_name? string Group to search (defaults to active group)
---@return table[] Array of intersecting markers
function M.get_markers_in_range(file_path, start_line, end_line, group_name)
  local group = state.get_group(group_name)
  if not group then
    return {}
  end
  
  -- Normalize file path for comparison
  local normalized_path = vim.fn.fnamemodify(file_path, ":p")
  local intersecting = {}
  
  for _, marker in ipairs(group.markers) do
    local marker_path = vim.fn.fnamemodify(marker.buffer_path, ":p")
    if marker_path == normalized_path then
      -- Check if ranges intersect
      if not (marker.end_line < start_line or marker.start_line > end_line) then
        table.insert(intersecting, marker)
      end
    end
  end
  
  -- Sort by start line
  table.sort(intersecting, function(a, b)
    return a.start_line < b.start_line
  end)
  
  return intersecting
end

---Split a multi-line marker at a specific line
---@param marker_id string Marker UUID
---@param split_line integer Line number to split at (1-indexed)
---@return table Result with created markers
function M.split_marker(marker_id, split_line)
  -- Find marker
  local marker, group_name = state.get_marker(marker_id)
  if not marker then
    return state.Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end
  
  -- Validate split line
  if split_line <= marker.start_line or split_line >= marker.end_line then
    return state.Result.error("Split line must be within marker range", "INVALID_SPLIT_LINE")
  end
  
  -- Only split multi-line markers
  if marker.start_line == marker.end_line then
    return state.Result.error("Cannot split single-line marker", "CANNOT_SPLIT_SINGLE_LINE")
  end
  
  -- Create two new markers
  local first_marker = vim.tbl_extend("force", {}, marker, {
    end_line = split_line - 1,
    annotation = marker.annotation .. " (part 1)"
  })
  
  local second_marker = vim.tbl_extend("force", {}, marker, {
    start_line = split_line,
    annotation = marker.annotation .. " (part 2)"
  })
  
  -- Remove original marker
  local remove_result = state.remove_marker(marker_id)
  if not remove_result.success then
    return remove_result
  end
  
  -- Add new markers
  local first_result = state.add_marker(first_marker, group_name)
  if not first_result.success then
    -- Try to restore original
    state.add_marker(marker, group_name)
    return state.Result.error("Failed to create first part: " .. first_result.error, "SPLIT_FAILED")
  end
  
  local second_result = state.add_marker(second_marker, group_name)
  if not second_result.success then
    -- Clean up and restore
    state.remove_marker(first_result.value.id)
    state.add_marker(marker, group_name)
    return state.Result.error("Failed to create second part: " .. second_result.error, "SPLIT_FAILED")
  end
  
  -- Update UI for the buffer if it's loaded
  local buf = vim.fn.bufnr(marker.buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end
  
  return state.Result.ok({
    first = first_result.value,
    second = second_result.value
  })
end

---Merge adjacent or overlapping markers
---@param marker_ids string[] Array of marker UUIDs to merge
---@param new_annotation? string Annotation for merged marker
---@return table Result with merged marker
function M.merge_markers(marker_ids, new_annotation)
  if not marker_ids or #marker_ids < 2 then
    return state.Result.error("Need at least 2 markers to merge", "INSUFFICIENT_MARKERS")
  end
  
  -- Get all markers
  local markers = {}
  local group_name = nil
  local buffer_path = nil
  
  for _, id in ipairs(marker_ids) do
    local marker, gname = state.get_marker(id)
    if not marker then
      return state.Result.error("Marker not found: " .. id, "MARKER_NOT_FOUND")
    end
    
    -- Ensure all markers are in the same group and file
    if group_name == nil then
      group_name = gname
      buffer_path = marker.buffer_path
    elseif group_name ~= gname or buffer_path ~= marker.buffer_path then
      return state.Result.error("All markers must be in the same group and file", "MARKERS_NOT_COMPATIBLE")
    end
    
    table.insert(markers, marker)
  end
  
  -- Sort by start line
  table.sort(markers, function(a, b)
    return a.start_line < b.start_line
  end)
  
  -- Check for gaps or overlaps, and merge
  local merged_start = markers[1].start_line
  local merged_end = markers[1].end_line
  
  for i = 2, #markers do
    local marker = markers[i]
    -- Extend range to include this marker
    merged_end = math.max(merged_end, marker.end_line)
  end
  
  -- Create merged marker
  local merged_annotation = new_annotation or 
    ("Merged: " .. table.concat(vim.tbl_map(function(m) return m.annotation end, markers), " + "))
  
  local merged_marker = {
    buffer_path = buffer_path,
    start_line = merged_start,
    end_line = merged_end,
    annotation = merged_annotation
  }
  
  -- Remove all original markers
  for _, id in ipairs(marker_ids) do
    local remove_result = state.remove_marker(id)
    if not remove_result.success then
      return state.Result.error("Failed to remove marker " .. id, "MERGE_CLEANUP_FAILED")
    end
  end
  
  -- Add merged marker
  local add_result = state.add_marker(merged_marker, group_name)
  if not add_result.success then
    -- Try to restore original markers (best effort)
    for _, marker in ipairs(markers) do
      state.add_marker(marker, group_name)
    end
    return state.Result.error("Failed to create merged marker: " .. add_result.error, "MERGE_FAILED")
  end
  
  -- Update UI
  local buf = vim.fn.bufnr(buffer_path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    M.update_buffer_markers(buf)
  end
  
  return state.Result.ok(add_result.value)
end

---Get statistics about markers in current buffer
---@param group_name? string Group name (defaults to active group)
---@return table Statistics
function M.get_buffer_marker_stats(group_name)
  local markers = M.get_current_buffer_markers(group_name)
  
  local stats = {
    total_markers = #markers,
    single_line = 0,
    multi_line = 0,
    total_lines_covered = 0,
    longest_marker = nil,
    shortest_marker = nil
  }
  
  for _, marker in ipairs(markers) do
    local line_span = marker.end_line - marker.start_line + 1
    stats.total_lines_covered = stats.total_lines_covered + line_span
    
    if marker.start_line == marker.end_line then
      stats.single_line = stats.single_line + 1
    else
      stats.multi_line = stats.multi_line + 1
    end
    
    if not stats.longest_marker or line_span > (stats.longest_marker.end_line - stats.longest_marker.start_line + 1) then
      stats.longest_marker = marker
    end
    
    if not stats.shortest_marker or line_span < (stats.shortest_marker.end_line - stats.shortest_marker.start_line + 1) then
      stats.shortest_marker = marker
    end
  end
  
  return stats
end

---Update marker display for a buffer
---@param buf integer Buffer handle
function M.update_buffer_markers(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  -- Clear existing virtual text
  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  
  local path = api.nvim_buf_get_name(buf)
  if not path or path == "" then
    return
  end
  
  -- Get markers for this buffer
  local markers = M.list_markers(nil, { buffer_path = path })
  
  -- Update virtual text display
  require("marker-groups.ui.virtual_text").update_buffer_display(buf, markers)
end

---Synchronize extmarks with current marker positions
---@param buf integer Buffer handle
---@return table Result with sync information
function M.sync_extmarks(buf)
  if not api.nvim_buf_is_valid(buf) then
    return state.Result.error("Invalid buffer", "INVALID_BUFFER")
  end
  
  local path = api.nvim_buf_get_name(buf)
  local markers = M.list_markers(nil, { buffer_path = path })
  local sync_results = {
    updated = 0,
    failed = 0,
    total = #markers
  }
  
  for _, marker in ipairs(markers) do
    if marker.extmark_id then
      -- Get current extmark position with details
      local success, extmark_info = pcall(function()
        return api.nvim_buf_get_extmark_by_id(buf, ns_id, marker.extmark_id, { 
          details = true 
        })
      end)
      
      if success and extmark_info and #extmark_info >= 2 then
        local new_start_line = extmark_info[1] + 1  -- Convert to 1-indexed
        local details = extmark_info[3] or {}
        local new_end_line = details.end_row and (details.end_row + 1) or new_start_line
        
        -- Check if position changed
        if new_start_line ~= marker.start_line or new_end_line ~= marker.end_line then
          -- Update marker position in state
          local updated_marker_data = vim.tbl_extend("force", {}, marker, {
            start_line = new_start_line,
            end_line = new_end_line,
            timestamp = os.time()  -- Update timestamp to show it moved
          })
          
          -- Remove old marker and add updated one
          local remove_result = state.remove_marker(marker.id)
          if remove_result.success then
            local add_result = state.add_marker(updated_marker_data)
            if add_result.success then
              sync_results.updated = sync_results.updated + 1
              vim.notify(string.format("Marker '%s' moved from line %d-%d to %d-%d", 
                marker.annotation:sub(1, 20), 
                marker.start_line, marker.end_line, 
                new_start_line, new_end_line), vim.log.levels.DEBUG)
            else
              sync_results.failed = sync_results.failed + 1
            end
          else
            sync_results.failed = sync_results.failed + 1
          end
        end
      else
        -- Extmark was deleted or invalid - remove marker
        M.delete_marker(marker.id)
        sync_results.updated = sync_results.updated + 1
        vim.notify(string.format("Marker '%s' removed (extmark deleted)", 
          marker.annotation:sub(1, 20)), vim.log.levels.DEBUG)
      end
    end
  end
  
  -- Update UI if any changes occurred
  if sync_results.updated > 0 then
    M.update_buffer_markers(buf)
  end
  
  return state.Result.ok(sync_results)
end

---Setup automatic line tracking for a buffer
---@param buf integer Buffer handle
function M.setup_line_tracking(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  -- Set up autocmds for this buffer to track changes
  local group = api.nvim_create_augroup("MarkerGroupsLineTracking_" .. buf, { clear = true })
  
  -- Sync on text changes (with debouncing)
  api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    buffer = buf,
    group = group,
    callback = function()
      vim.defer_fn(function()
        if api.nvim_buf_is_valid(buf) then
          M.sync_extmarks(buf)
        end
      end, 100)  -- 100ms debounce
    end
  })
  
  -- Also sync on undo/redo
  api.nvim_create_autocmd({"TextChangedP"}, {
    buffer = buf,
    group = group,
    callback = function()
      vim.defer_fn(function()
        if api.nvim_buf_is_valid(buf) then
          M.sync_extmarks(buf)
        end
      end, 50)  -- Faster for undo/redo
    end
  })
  
  -- Clean up when buffer is deleted
  api.nvim_create_autocmd("BufDelete", {
    buffer = buf,
    group = group,
    callback = function()
      api.nvim_del_augroup_by_id(group)
    end
  })
end

---Setup global line tracking for all buffers with markers
function M.setup_global_line_tracking()
  -- Set up autocmds for all current and future buffers
  local group = api.nvim_create_augroup("MarkerGroupsGlobalTracking", { clear = true })
  
  -- Set up tracking when a buffer is opened/focused
  api.nvim_create_autocmd({"BufRead", "BufNewFile", "BufEnter"}, {
    group = group,
    callback = function(args)
      local buf = args.buf
      if api.nvim_buf_is_valid(buf) then
        local path = api.nvim_buf_get_name(buf)
        if path and path ~= "" then
          -- Check if this buffer has markers
          local markers = M.list_markers(nil, { buffer_path = path })
          if #markers > 0 then
            M.setup_line_tracking(buf)
            M.refresh_extmarks(buf)
          end
        end
      end
    end
  })
  
  -- Clean up global tracking if needed
  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      -- Save all marker states before exit
      M.sync_all_buffers()
    end
  })
end

---Sync extmarks for all loaded buffers
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
    error_buffers = error_count
  }
end

---Force refresh markers after major buffer changes
---@param buf integer Buffer handle
function M.handle_major_change(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  -- Refresh extmarks completely
  M.refresh_extmarks(buf)
  
  -- Update UI
  M.update_buffer_markers(buf)
  
  -- Emit event for external listeners
  local state = require("marker-groups.state")
  state.emit("buffer_major_change", {
    buffer = buf,
    path = api.nvim_buf_get_name(buf)
  })
end

---Handle specific types of buffer modifications
---@param buf integer Buffer handle
---@param change_type string Type of change: "lines_added", "lines_deleted", "text_modified"
---@param change_data table? Additional data about the change
function M.handle_buffer_change(buf, change_type, change_data)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  local path = api.nvim_buf_get_name(buf)
  local markers = M.list_markers(nil, { buffer_path = path })
  
  if #markers == 0 then
    return  -- No markers to update
  end
  
  -- Handle different types of changes
  if change_type == "lines_added" and change_data then
    -- Lines were inserted - markers below need to shift down
    local insert_line = change_data.line or 1
    local line_count = change_data.count or 1
    
    vim.notify(string.format("Lines added at %d (count: %d), updating %d markers", 
      insert_line, line_count, #markers), vim.log.levels.DEBUG)
    
  elseif change_type == "lines_deleted" and change_data then
    -- Lines were deleted - markers below need to shift up
    local delete_line = change_data.line or 1
    local line_count = change_data.count or 1
    
    vim.notify(string.format("Lines deleted at %d (count: %d), updating %d markers", 
      delete_line, line_count, #markers), vim.log.levels.DEBUG)
    
  end
  
  -- Always sync extmarks after any change
  M.sync_extmarks(buf)
end

---Create or recreate extmark for a marker
---@param buf integer Buffer handle
---@param marker table Marker object
---@return integer? extmark_id or nil if failed
function M.create_extmark(buf, marker)
  if not api.nvim_buf_is_valid(buf) then
    return nil
  end
  
  local success, extmark_id = pcall(function()
    local extmark_opts = {
      strict = false,
      right_gravity = false
    }
    
    -- For multi-line markers, set end position
    if marker.start_line ~= marker.end_line then
      extmark_opts.end_line = marker.end_line - 1
      extmark_opts.end_col = 0
      extmark_opts.end_right_gravity = false
    end
    
    return api.nvim_buf_set_extmark(buf, ns_id, marker.start_line - 1, 0, extmark_opts)
  end)
  
  return success and extmark_id or nil
end

---Refresh extmarks for all markers in a buffer
---@param buf integer Buffer handle
function M.refresh_extmarks(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  local path = api.nvim_buf_get_name(buf)
  local markers = M.list_markers(nil, { buffer_path = path })
  
  -- Clear all existing extmarks
  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  
  -- Recreate extmarks for all markers
  for _, marker in ipairs(markers) do
    local extmark_id = M.create_extmark(buf, marker)
    if extmark_id then
      -- Update marker with new extmark ID (this would need state update)
      marker.extmark_id = extmark_id
    end
  end
  
  -- Update UI
  M.update_buffer_markers(buf)
end

---Get debug information about markers
---@return table Debug info
function M.debug_info()
  local buf, path = get_current_buffer_info()
  local current_markers = {}
  local extmark_count = 0
  
  if path and path ~= "" then
    current_markers = M.list_markers(nil, { buffer_path = path })
  end
  
  -- Count extmarks in current buffer
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
    active_group = state.get_active_group()
  }
end

return M