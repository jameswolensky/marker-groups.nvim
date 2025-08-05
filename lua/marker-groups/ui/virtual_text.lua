---@class MarkerGroupsVirtualText
---Comprehensive virtual text system for marker visualization
local M = {}

local api = vim.api
local config = require("marker-groups.config")

-- Cache namespaces for performance
local _cached_namespaces = {}

-- Debounce cache for performance optimization
local _update_timers = {}

---Get or create namespace with caching
---@param name string Namespace name
---@return integer namespace_id
local function get_namespace(name)
  if not _cached_namespaces[name] then
    _cached_namespaces[name] = api.nvim_create_namespace(name)
  end
  return _cached_namespaces[name]
end

---Setup highlight groups for virtual text
---Intelligently detects color scheme and applies appropriate colors
function M.setup_highlights()
  local bg = vim.o.background
  local colorscheme = vim.g.colors_name or "default"
  
  -- Define highlight groups with adaptive colors
  local highlights = {
    MarkerGroupsMarker = {
      -- Icon/marker symbol
      light = { fg = "#0451A5", bg = "#F3F3F3" },
      dark = { fg = "#61AFEF", bg = "#2C323C" }
    },
    MarkerGroupsAnnotation = {
      -- Annotation text
      light = { fg = "#0E8A00", italic = true },
      dark = { fg = "#98C379", italic = true }
    },
    MarkerGroupsContext = {
      -- Context and secondary text
      light = { fg = "#6A6A6A" },
      dark = { fg = "#ABB2BF" }
    },
    MarkerGroupsMultilineStart = {
      -- Multi-line start indicator
      light = { fg = "#AF00DB", bold = true },
      dark = { fg = "#C678DD", bold = true }
    },
    MarkerGroupsMultilineEnd = {
      -- Multi-line end indicator
      light = { fg = "#AF00DB" },
      dark = { fg = "#C678DD" }
    }
  }
  
  -- Apply highlights based on background
  for group_name, colors in pairs(highlights) do
    local hl_opts = bg == "light" and colors.light or colors.dark
    hl_opts.default = true  -- Allow user override
    api.nvim_set_hl(0, group_name, hl_opts)
  end
  
  -- Set up autocommand to refresh highlights on colorscheme change
  local group = api.nvim_create_augroup("MarkerGroupsHighlights", { clear = true })
  api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      M.setup_highlights()
    end,
    desc = "Update marker groups highlights on colorscheme change"
  })
end

---Format annotation text for display
---@param annotation string
---@param max_length? integer
---@return string
local function format_annotation(annotation, max_length)
  if not annotation or annotation == "" then
    return "(no annotation)"
  end
  
  max_length = max_length or config.get_value("max_annotation_display", 50)
  
  -- Replace newlines with spaces
  local formatted = annotation:gsub("\n", " "):gsub("\r", " ")
  
  -- Truncate if too long
  if #formatted > max_length then
    formatted = formatted:sub(1, max_length - 3) .. "..."
  end
  
  return formatted
end

---Create virtual text for a marker
---@param marker table Marker object
---@param marker_type? string Type: "single", "multiline_start", "multiline_end"
---@param context_info? string Additional context information
---@return table Virtual text configuration
local function create_marker_virtual_text(marker, marker_type, context_info)
  local cfg = config.get()
  marker_type = marker_type or (marker.start_line == marker.end_line and "single" or "multiline_start")
  
  local annotation = format_annotation(marker.annotation)
  local virtual_text = {}
  
  -- Add spacing
  table.insert(virtual_text, { " ", "Normal" })
  
  -- Add appropriate icon and highlighting based on type
  if marker_type == "single" then
    table.insert(virtual_text, { cfg.signs.marker .. " ", "MarkerGroupsMarker" })
    table.insert(virtual_text, { annotation, "MarkerGroupsAnnotation" })
  elseif marker_type == "multiline_start" then
    table.insert(virtual_text, { cfg.signs.multiline_start .. " ", "MarkerGroupsMultilineStart" })
    table.insert(virtual_text, { annotation, "MarkerGroupsAnnotation" })
  elseif marker_type == "multiline_end" then
    table.insert(virtual_text, { cfg.signs.multiline_end .. " ", "MarkerGroupsMultilineEnd" })
    table.insert(virtual_text, { context_info or ("End: " .. format_annotation(annotation, 25)), "MarkerGroupsContext" })
  end
  
  -- Add line information for debugging if enabled
  if cfg.debug then
    local line_info = marker_type == "single" 
      and string.format(" [L%d]", marker.start_line)
      or string.format(" [L%d-%d]", marker.start_line, marker.end_line)
    table.insert(virtual_text, { line_info, "MarkerGroupsContext" })
  end
  
  return virtual_text
end

---Update buffer display with markers
---@param buf integer Buffer handle
---@param markers table[] Array of markers for this buffer
function M.update_buffer_display(buf, markers)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  -- Get namespace for virtual text (different from extmarks)
  local vt_ns = get_namespace("marker_groups_virtual_text")
  
  -- Clear existing virtual text
  api.nvim_buf_clear_namespace(buf, vt_ns, 0, -1)
  
  -- Sort markers by line number for consistent display
  table.sort(markers, function(a, b)
    return a.start_line < b.start_line
  end)
  
  -- Add virtual text for each marker with enhanced error handling
  for i, marker in ipairs(markers) do
    local success, err = pcall(function()
      -- Handle multi-line markers
      if marker.start_line == marker.end_line then
        -- Single line marker
        local virtual_text = create_marker_virtual_text(marker, "single")
        
        api.nvim_buf_set_extmark(buf, vt_ns, marker.start_line - 1, -1, {
          virt_text = virtual_text,
          virt_text_pos = "eol",
          hl_mode = "combine",
          priority = 1000 + i  -- Higher priority for better visibility
        })
      else
        -- Multi-line marker - show on start and end lines
        
        -- Start line
        local start_vt = create_marker_virtual_text(marker, "multiline_start")
        api.nvim_buf_set_extmark(buf, vt_ns, marker.start_line - 1, -1, {
          virt_text = start_vt,
          virt_text_pos = "eol",
          hl_mode = "combine",
          priority = 1000 + i
        })
        
        -- End line (only if different from start)
        if marker.end_line > marker.start_line then
          local end_vt = create_marker_virtual_text(marker, "multiline_end", 
            "End: " .. format_annotation(marker.annotation, 30))
          api.nvim_buf_set_extmark(buf, vt_ns, marker.end_line - 1, -1, {
            virt_text = end_vt,
            virt_text_pos = "eol",
            hl_mode = "combine",
            priority = 1000 + i
          })
        end
      end
    end)
    
    -- Log errors in debug mode
    if not success and config.get().debug then
      vim.notify(string.format("Failed to create virtual text for marker %s: %s", 
        marker.id or "unknown", err), vim.log.levels.WARN)
    end
  end
end

---Clear all virtual text from buffer
---@param buf integer Buffer handle
function M.clear_buffer_display(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  local vt_ns = get_namespace("marker_groups_virtual_text")
  api.nvim_buf_clear_namespace(buf, vt_ns, 0, -1)
end

-- Internal state for virtual text enabled/disabled
local _virtual_text_enabled = true

---Toggle virtual text display for all buffers
---@param enabled? boolean If provided, set enabled state; otherwise toggle
function M.toggle_display(enabled)
  local new_state = enabled ~= nil and enabled or not _virtual_text_enabled
  _virtual_text_enabled = new_state
  
  if new_state then
    M.update_all_buffers()
    vim.notify("Marker virtual text enabled", vim.log.levels.INFO)
  else
    -- Clear all buffers
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(buf) then
        M.clear_buffer_display(buf)
      end
    end
    vim.notify("Marker virtual text disabled", vim.log.levels.INFO)
  end
end

---Check if virtual text is enabled
---@return boolean
function M.is_enabled()
  return _virtual_text_enabled
end

---Get debug information about virtual text state
---@return table Debug information
function M.debug_info()
  local info = {
    enabled = M.is_enabled(),
    namespace_cache = vim.tbl_keys(_cached_namespaces),
    highlight_groups = {},
    loaded_buffers_with_markers = 0
  }
  
  -- Check highlight groups
  for _, group in ipairs({"MarkerGroupsMarker", "MarkerGroupsAnnotation", "MarkerGroupsContext", 
                          "MarkerGroupsMultilineStart", "MarkerGroupsMultilineEnd"}) do
    local hl = api.nvim_get_hl(0, { name = group })
    info.highlight_groups[group] = hl
  end
  
  -- Count buffers with markers
  local state = require("marker-groups.state")
  local active_group = state.get_group()
  if active_group then
    local paths = {}
    for _, marker in ipairs(active_group.markers) do
      paths[marker.buffer_path] = true
    end
    for path in pairs(paths) do
      local buf = vim.fn.bufnr(path)
      if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
        info.loaded_buffers_with_markers = info.loaded_buffers_with_markers + 1
      end
    end
  end
  
  return info
end

---Refresh virtual text for specific buffer with debouncing
---@param buf? integer Buffer handle (defaults to current buffer)
---@param immediate? boolean Skip debouncing for immediate update
function M.refresh_buffer(buf, immediate)
  buf = buf or api.nvim_get_current_buf()
  
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  
  local buf_path = api.nvim_buf_get_name(buf)
  if not buf_path or buf_path == "" then
    return
  end
  
  -- Debounce updates to avoid excessive refreshes
  if not immediate then
    if _update_timers[buf] then
      _update_timers[buf]:stop()
    end
    
    _update_timers[buf] = vim.defer_fn(function()
      _update_timers[buf] = nil
      M.refresh_buffer(buf, true)  -- Immediate on actual execution
    end, 100)  -- 100ms debounce
    return
  end
  
  -- Get markers for this buffer
  local markers = require("marker-groups.markers").list_markers(nil, { 
    buffer_path = buf_path 
  })
  
  M.update_buffer_display(buf, markers)
end

---Force immediate refresh of all buffers (bypasses debouncing)
function M.force_refresh_all()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      M.refresh_buffer(buf, true)
    end
  end
end

---Update all loaded buffers that have markers
function M.update_all_buffers()
  -- Skip if virtual text is disabled
  if not M.is_enabled() then
    return
  end
  
  local state = require("marker-groups.state")
  local active_group = state.get_group()
  
  if not active_group then
    return
  end
  
  -- Group markers by buffer path
  local markers_by_buffer = {}
  for _, marker in ipairs(active_group.markers) do
    local path = marker.buffer_path
    if not markers_by_buffer[path] then
      markers_by_buffer[path] = {}
    end
    table.insert(markers_by_buffer[path], marker)
  end
  
  -- Update each loaded buffer
  for path, markers in pairs(markers_by_buffer) do
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
      M.update_buffer_display(buf, markers)
    end
  end
  
  -- Clear buffers that no longer have markers
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      local buf_path = api.nvim_buf_get_name(buf)
      if buf_path and buf_path ~= "" and not markers_by_buffer[buf_path] then
        M.clear_buffer_display(buf)
      end
    end
  end
end

---Setup automatic updates on group changes
function M.setup_auto_updates()
  local state = require("marker-groups.state")
  
  -- Listen for state changes and update UI
  state.on("active_group_changed", function(data)
    vim.schedule(function()
      M.update_all_buffers()
    end)
  end)
  
  state.on("marker_added", function(data)
    vim.schedule(function()
      local buf = vim.fn.bufnr(data.marker.buffer_path)
      if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
        local markers = require("marker-groups.markers").list_markers(nil, { 
          buffer_path = data.marker.buffer_path 
        })
        M.update_buffer_display(buf, markers)
      end
    end)
  end)
  
  state.on("marker_removed", function(data)
    vim.schedule(function()
      local buf = vim.fn.bufnr(data.marker.buffer_path)
      if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
        local markers = require("marker-groups.markers").list_markers(nil, { 
          buffer_path = data.marker.buffer_path 
        })
        M.update_buffer_display(buf, markers)
      end
    end)
  end)
  
  -- Listen for group management events
  state.on("group_created", function(data)
    vim.schedule(function()
      -- No immediate UI update needed, but log for debugging
      vim.notify("Group created: " .. data.group_name, vim.log.levels.DEBUG)
    end)
  end)
  
  state.on("group_deleted", function(data)
    vim.schedule(function()
      -- Clear UI for deleted group if it was active
      M.update_all_buffers()
      vim.notify("Group deleted: " .. data.group_name, vim.log.levels.DEBUG)
    end)
  end)
  
  -- Listen for buffer-specific events
  state.on("buffer_major_change", function(data)
    vim.schedule(function()
      if api.nvim_buf_is_valid(data.buffer) then
        local markers = require("marker-groups.markers").list_markers(nil, { 
          buffer_path = data.path 
        })
        M.update_buffer_display(data.buffer, markers)
      end
    end)
  end)
  
  -- State initialization event
  state.on("state_initialized", function(data)
    vim.schedule(function()
      M.update_all_buffers()
      vim.notify("Marker groups UI synchronized with state", vim.log.levels.DEBUG)
    end)
  end)
  
  -- Set up buffer-specific autocmds for additional responsiveness
  M.setup_buffer_autocmds()
end

---Setup buffer-specific autocmds for enhanced marker updates
function M.setup_buffer_autocmds()
  local group = api.nvim_create_augroup("MarkerGroupsVirtualText", { clear = true })
  
  -- Update virtual text when entering a buffer
  api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      local buf = args.buf
      if M.is_enabled() and api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          M.refresh_buffer(buf)
        end)
      end
    end,
    desc = "Update marker virtual text on buffer enter"
  })
  
  -- Update virtual text when a buffer is written (saved)
  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local buf = args.buf
      if M.is_enabled() and api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          M.refresh_buffer(buf)
        end)
      end
    end,
    desc = "Update marker virtual text after buffer save"
  })
  
  -- Clear virtual text when buffer is unloaded
  api.nvim_create_autocmd("BufUnload", {
    group = group,
    callback = function(args)
      local buf = args.buf
      if api.nvim_buf_is_valid(buf) then
        M.clear_buffer_display(buf)
      end
    end,
    desc = "Clear marker virtual text on buffer unload"
  })
  
  -- Update virtual text when window changes (useful for split views)
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if M.is_enabled() then
        local buf = api.nvim_get_current_buf()
        if api.nvim_buf_is_valid(buf) then
          vim.schedule(function()
            M.refresh_buffer(buf)
          end)
        end
      end
    end,
    desc = "Update marker virtual text on window enter"
  })
  
  -- Handle vim mode changes that might affect display
  api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      if M.is_enabled() then
        local buf = api.nvim_get_current_buf()
        if api.nvim_buf_is_valid(buf) then
          -- Small delay to avoid rapid updates during mode transitions
          vim.defer_fn(function()
            M.refresh_buffer(buf)
          end, 50)
        end
      end
    end,
    desc = "Update marker virtual text on mode change"
  })
end

---Clear all buffer autocmds (useful for cleanup)
function M.clear_buffer_autocmds()
  pcall(api.nvim_del_augroup_by_name, "MarkerGroupsVirtualText")
end

return M