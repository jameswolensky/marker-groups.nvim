---@class MarkerGroupsFloating
---Floating window viewer for displaying markers with code context.
---This module provides a rich UI for viewing all markers in the active group
---with syntax-highlighted code context and navigation capabilities.
local M = {}

local api = vim.api
local config = require("marker-groups.config")
local state = require("marker-groups.state")
local feedback = require("marker-groups.feedback")

---@type table<number, table> Cache of open floating windows and their metadata
local _floating_windows = {}

---Get the current terminal dimensions for window sizing calculations
---@return number columns, number lines Terminal width and height
local function get_terminal_dimensions()
  return vim.o.columns, vim.o.lines
end

---Calculate optimal floating window dimensions based on configuration and terminal size
---@return table window_config Window configuration with width, height, col, row
local function calculate_window_config()
  local float_config = config.get_value("float_config", {})
  local width_ratio = float_config.width or 0.8
  local height_ratio = float_config.height or 0.8
  local border = float_config.border or "rounded"
  local title_pos = float_config.title_pos or "center"
  
  local columns, lines = get_terminal_dimensions()
  
  -- Calculate dimensions
  local width = math.floor(columns * width_ratio)
  local height = math.floor(lines * height_ratio)
  
  -- Ensure minimum size
  width = math.max(width, 60)
  height = math.max(height, 20)
  
  -- Ensure we don't exceed terminal size
  width = math.min(width, columns - 4)
  height = math.min(height, lines - 4)
  
  -- Center the window
  local col = math.floor((columns - width) / 2)
  local row = math.floor((lines - height) / 2)
  
  return {
    width = width,
    height = height,
    col = col,
    row = row,
    border = border,
    title_pos = title_pos
  }
end

---Read file content into a table of lines
---@param filepath string Path to the file to read
---@return table lines Array of file lines, empty if file cannot be read
local function read_file_lines(filepath)
  local lines = {}
  
  -- First try to get from a loaded buffer
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf) then
      local buf_name = api.nvim_buf_get_name(buf)
      if buf_name == filepath then
        lines = api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines
      end
    end
  end
  
  -- If not in a buffer, read from disk
  local file = io.open(filepath, "r")
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  end
  
  return lines
end

---Extract code context around a marker with line numbers and highlighting
---@param marker table Marker object with buffer_path, start_line, end_line
---@param context_lines number Number of context lines above and below
---@param max_width number Maximum width for line formatting
---@return table context_lines Formatted context lines with prefixes and line numbers
local function extract_marker_context(marker, context_lines, max_width)
  local file_lines = read_file_lines(marker.buffer_path)
  local context = {}
  
  if #file_lines == 0 then
    table.insert(context, " │ [File not found or empty]")
    return context
  end
  
  -- Calculate context range
  local context_start = math.max(1, marker.start_line - context_lines)
  local context_end = math.min(#file_lines, marker.end_line + context_lines)
  
  -- Determine line number padding
  local max_line_num = context_end
  local line_num_width = string.len(tostring(max_line_num))
  
  -- Extract context lines with formatting
  for line_num = context_start, context_end do
    local is_marker_line = line_num >= marker.start_line and line_num <= marker.end_line
    local prefix = is_marker_line and " ► " or " │ "
    
    -- Format line number with consistent width
    local line_num_str = string.format("%" .. line_num_width .. "d", line_num)
    local line_content = file_lines[line_num] or ""
    
    -- Truncate long lines to fit window
    local available_width = max_width - string.len(prefix) - line_num_width - 3 -- ": " + some padding
    if string.len(line_content) > available_width then
      line_content = string.sub(line_content, 1, available_width - 3) .. "..."
    end
    
    local formatted_line = prefix .. line_num_str .. ": " .. line_content
    table.insert(context, formatted_line)
  end
  
  return context
end

---Create a marker position tracking system for navigation
---@param lines table Array of buffer lines
---@param markers table Array of marker objects
---@return table position_map Map of line numbers to marker objects
local function create_marker_position_map(lines, markers)
  local position_map = {}
  local current_line = 1
  local marker_index = 1
  
  -- Scan through lines to find marker headers and associate them with markers
  for line_idx, line in ipairs(lines) do
    -- Look for file path patterns that indicate a new marker
    if line:match("^[^%s].*:") and marker_index <= #markers then
      position_map[line_idx] = markers[marker_index]
      marker_index = marker_index + 1
    end
  end
  
  return position_map
end

---Get appropriate filetype for syntax highlighting based on file extension
---@param filepath string Path to the source file
---@return string filetype Neovim filetype for syntax highlighting
local function get_filetype_from_path(filepath)
  local extension = filepath:match("%.([^%.]+)$")
  if not extension then
    return "text"
  end
  
  -- Common mappings
  local ext_to_filetype = {
    lua = "lua",
    js = "javascript",
    ts = "typescript",
    jsx = "javascriptreact",
    tsx = "typescriptreact",
    py = "python",
    rb = "ruby",
    go = "go",
    rs = "rust",
    c = "c",
    cpp = "cpp",
    cc = "cpp",
    cxx = "cpp",
    h = "c",
    hpp = "cpp",
    java = "java",
    php = "php",
    sh = "sh",
    bash = "bash",
    zsh = "zsh",
    vim = "vim",
    json = "json",
    yaml = "yaml",
    yml = "yaml",
    xml = "xml",
    html = "html",
    css = "css",
    scss = "scss",
    sass = "sass",
    md = "markdown",
    txt = "text"
  }
  
  return ext_to_filetype[extension] or "text"
end

---Validate that we have markers to display
---@param active_group string Name of the active group
---@param group table Group object from state
---@return boolean valid True if we can proceed with display
---@return string? error_msg Error message if validation fails
local function validate_display_conditions(active_group, group)
  if not active_group then
    return false, "No active group found"
  end
  
  if not group then
    return false, "Active group '" .. active_group .. "' not found"
  end
  
  if not group.markers or #group.markers == 0 then
    return false, "No markers in group '" .. active_group .. "'"
  end
  
  return true, nil
end

---Show floating window with all markers from the active group
---@return number? buf_id Buffer ID of the floating window (nil if failed)
---@return number? win_id Window ID of the floating window (nil if failed)
function M.show_markers()
  local active_group = state.get_active_group()
  local group = state.get_group(active_group)
  
  -- Validate display conditions
  local valid, error_msg = validate_display_conditions(active_group, group)
  if not valid then
    feedback.warning("Floating Viewer", error_msg)
    return nil, nil
  end
  
  -- Calculate window configuration
  local win_config = calculate_window_config()
  
  -- Create buffer for floating window
  local buf = api.nvim_create_buf(false, true)
  if not buf then
    feedback.error("Floating Viewer", "Failed to create buffer")
    return nil, nil
  end
  
  -- Set buffer options
  local buf_opts = {
    bufhidden = "wipe",
    buftype = "nofile",
    swapfile = false,
    modifiable = false,
  }
  
  for opt, value in pairs(buf_opts) do
    api.nvim_buf_set_option(buf, opt, value)
  end
  
  -- Determine filetype for syntax highlighting (use most common type from markers)
  local filetypes = {}
  for _, marker in ipairs(group.markers) do
    local ft = get_filetype_from_path(marker.buffer_path)
    filetypes[ft] = (filetypes[ft] or 0) + 1
  end
  
  -- Find most common filetype
  local dominant_filetype = "text"
  local max_count = 0
  for ft, count in pairs(filetypes) do
    if count > max_count then
      max_count = count
      dominant_filetype = ft
    end
  end
  
  -- Set up syntax highlighting
  M.setup_syntax_highlighting(buf, dominant_filetype, group.markers)
  
  -- Create the floating window
  local win_opts = {
    relative = "editor",
    width = win_config.width,
    height = win_config.height,
    col = win_config.col,
    row = win_config.row,
    style = "minimal",
    border = win_config.border,
    title = " Markers: " .. active_group .. " (" .. #group.markers .. ") ",
    title_pos = win_config.title_pos,
    focusable = true,
    zindex = 100
  }
  
  local win = api.nvim_open_win(buf, true, win_opts)
  if not win then
    feedback.error("Floating Viewer", "Failed to create floating window")
    api.nvim_buf_delete(buf, { force = true })
    return nil, nil
  end
  
  -- Set window options for better UX
  local win_options = {
    wrap = true,
    cursorline = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    colorcolumn = "",
    winhl = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:CursorLine"
  }
  
  for opt, value in pairs(win_options) do
    api.nvim_win_set_option(win, opt, value)
  end
  
  -- Track the window
  _floating_windows[win] = {
    buffer = buf,
    group = active_group,
    marker_count = #group.markers,
    created_at = os.time()
  }
  
  -- Populate the buffer with marker content
  local content_lines = {}
  local marker_positions = {}
  local context_lines = config.get_value("context_lines", 2)
  
  -- Header
  table.insert(content_lines, string.format("📁 Group: %s (%d markers)", active_group, #group.markers))
  table.insert(content_lines, string.rep("═", math.min(win_config.width - 4, 80)))
  table.insert(content_lines, "")
  
  -- Process each marker
  for i, marker in ipairs(group.markers) do
    local marker_start_line = #content_lines + 1
    
    -- Marker header with file path and line range
    local line_range = marker.start_line == marker.end_line 
      and tostring(marker.start_line)
      or marker.start_line .. "-" .. marker.end_line
    
    local header = string.format("📍 %s:%s", 
      vim.fn.fnamemodify(marker.buffer_path, ":t"), line_range)
    table.insert(content_lines, header)
    
    -- Store marker position for navigation
    marker_positions[marker_start_line] = marker
    
    -- File path (full path)
    table.insert(content_lines, string.format("   %s", marker.buffer_path))
    
    -- Code context box
    table.insert(content_lines, "   ┌" .. string.rep("─", math.min(win_config.width - 8, 70)) .. "┐")
    
    -- Extract and format code context
    local context = extract_marker_context(marker, context_lines, win_config.width - 8)
    for _, context_line in ipairs(context) do
      table.insert(content_lines, "   " .. context_line)
    end
    
    table.insert(content_lines, "   └" .. string.rep("─", math.min(win_config.width - 8, 70)) .. "┘")
    
    -- Annotation
    table.insert(content_lines, string.format("   💬 %s", marker.annotation))
    
    -- Timestamp (if available)
    if marker.timestamp then
      local time_str = os.date("%Y-%m-%d %H:%M", marker.timestamp)
      table.insert(content_lines, string.format("   🕒 %s", time_str))
    end
    
    -- Separator between markers
    if i < #group.markers then
      table.insert(content_lines, "")
      table.insert(content_lines, string.rep("─", math.min(win_config.width - 4, 80)))
      table.insert(content_lines, "")
    end
  end
  
  -- Footer with help
  table.insert(content_lines, "")
  table.insert(content_lines, string.rep("═", math.min(win_config.width - 4, 80)))
  table.insert(content_lines, "🎯 Navigation: [j/k] move • [Enter] jump to marker • [q/Esc] close")
  
  -- Set buffer content
  api.nvim_buf_set_option(buf, "modifiable", true)
  local ok, err = pcall(api.nvim_buf_set_lines, buf, 0, -1, false, content_lines)
  if not ok then
    feedback.error("Floating Viewer", "Failed to populate buffer: " .. tostring(err))
    api.nvim_win_close(win, true)
    return nil, nil
  end
  api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Store marker positions for navigation
  _floating_windows[win].marker_positions = marker_positions
  
  -- Set up keybindings for the floating window
  M.setup_window_keybindings(buf, win, marker_positions)
  
  -- Set up syntax auto-refresh
  M.setup_syntax_auto_refresh(buf)
  
  -- Set up window cleanup on close
  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      _floating_windows[win] = nil
    end
  })
  
  feedback.success("Floating Viewer", "Opened viewer for group '" .. active_group .. "' with " .. #group.markers .. " markers")
  return buf, win
end

---Set up enhanced syntax highlighting for the floating window buffer
---@param buf_id number Buffer ID
---@param dominant_filetype string The most common filetype among markers
---@param markers table Array of marker objects
function M.setup_syntax_highlighting(buf_id, dominant_filetype, markers)
  -- Set the buffer filetype for basic syntax highlighting
  api.nvim_buf_set_option(buf_id, "filetype", dominant_filetype)
  
  -- Enable syntax highlighting
  api.nvim_buf_call(buf_id, function()
    vim.cmd("syntax on")
  end)
  
  -- Set up additional highlighting for marker-specific elements
  M.setup_marker_highlights(buf_id)
  
  -- Apply highlight groups for different sections
  api.nvim_buf_call(buf_id, function()
    -- Create highlight groups for different elements
    vim.cmd([[
      highlight default MarkerFloatingHeader guifg=#61AFEF gui=bold ctermfg=75 cterm=bold
      highlight default MarkerFloatingPath guifg=#98C379 ctermfg=114
      highlight default MarkerFloatingAnnotation guifg=#E06C75 gui=italic ctermfg=204 cterm=italic
      highlight default MarkerFloatingTimestamp guifg=#D19A66 ctermfg=173
      highlight default MarkerFloatingBorder guifg=#5C6370 ctermfg=59
      highlight default MarkerFloatingContext guifg=#ABB2BF ctermfg=145
      highlight default MarkerFloatingMarkerLine guifg=#C678DD gui=bold ctermfg=176 cterm=bold
    ]])
  end)
end

---Set up marker-specific highlighting patterns
---@param buf_id number Buffer ID
function M.setup_marker_highlights(buf_id)
  api.nvim_buf_call(buf_id, function()
    -- Highlight file headers (📍 pattern)
    vim.cmd([[syntax match MarkerFloatingHeader /^📍.*$/]])
    
    -- Highlight file paths
    vim.cmd([[syntax match MarkerFloatingPath /^   \/.*$/]])
    
    -- Highlight annotations (💬 pattern)
    vim.cmd([[syntax match MarkerFloatingAnnotation /^   💬.*$/]])
    
    -- Highlight timestamps (🕒 pattern)
    vim.cmd([[syntax match MarkerFloatingTimestamp /^   🕒.*$/]])
    
    -- Highlight borders and separators
    vim.cmd([[syntax match MarkerFloatingBorder /[┌┐└┘─│═]/]])
    
    -- Highlight marker lines (lines with ►)
    vim.cmd([[syntax match MarkerFloatingMarkerLine /.*►.*$/]])
    
    -- Highlight context lines (lines with │)
    vim.cmd([[syntax match MarkerFloatingContext /.*│.*$/]])
  end)
end

---Set up auto-refresh for syntax highlighting when window is updated
---@param buf_id number Buffer ID
function M.setup_syntax_auto_refresh(buf_id)
  -- Create autocmd to refresh syntax when buffer is modified
  api.nvim_create_autocmd({"BufEnter", "WinEnter"}, {
    buffer = buf_id,
    callback = function()
      api.nvim_buf_call(buf_id, function()
        vim.cmd("syntax sync fromstart")
      end)
    end,
    desc = "Refresh syntax highlighting for marker floating window"
  })
end

---Set up keybindings for a floating marker viewer window
---@param buf_id number Buffer ID
---@param win_id number Window ID
---@param marker_positions table Map of line numbers to marker objects
function M.setup_window_keybindings(buf_id, win_id, marker_positions)
  local keymap_opts = { noremap = true, silent = true }
  
  -- Navigation keybindings (j/k for up/down)
  api.nvim_buf_set_keymap(buf_id, 'n', 'j', 'j', keymap_opts)
  api.nvim_buf_set_keymap(buf_id, 'n', 'k', 'k', keymap_opts)
  api.nvim_buf_set_keymap(buf_id, 'n', '<Down>', 'j', keymap_opts)
  api.nvim_buf_set_keymap(buf_id, 'n', '<Up>', 'k', keymap_opts)
  
  -- Jump to marker (Enter)
  api.nvim_buf_set_keymap(buf_id, 'n', '<CR>', '', {
    noremap = true,
    silent = true,
    callback = function()
      M.jump_to_current_marker(win_id, marker_positions)
    end
  })
  
  -- Close window (q and Escape)
  local close_callback = function()
    if api.nvim_win_is_valid(win_id) then
      api.nvim_win_close(win_id, true)
      feedback.success("Floating Viewer", "Closed marker viewer")
    end
  end
  
  api.nvim_buf_set_keymap(buf_id, 'n', 'q', '', {
    noremap = true,
    silent = true,
    callback = close_callback
  })
  
  api.nvim_buf_set_keymap(buf_id, 'n', '<Esc>', '', {
    noremap = true,
    silent = true,
    callback = close_callback
  })
  
  -- Additional navigation shortcuts
  api.nvim_buf_set_keymap(buf_id, 'n', 'gg', 'gg', keymap_opts)  -- Go to top
  api.nvim_buf_set_keymap(buf_id, 'n', 'G', 'G', keymap_opts)   -- Go to bottom
  api.nvim_buf_set_keymap(buf_id, 'n', '<C-u>', '<C-u>', keymap_opts)  -- Page up
  api.nvim_buf_set_keymap(buf_id, 'n', '<C-d>', '<C-d>', keymap_opts)  -- Page down
  
  -- Help (show keybindings)
  api.nvim_buf_set_keymap(buf_id, 'n', '?', '', {
    noremap = true,
    silent = true,
    callback = function()
      M.show_help_popup(win_id)
    end
  })
end

---Jump to the marker nearest to the current cursor position
---@param win_id number Window ID of the floating window
---@param marker_positions table Map of line numbers to marker objects
function M.jump_to_current_marker(win_id, marker_positions)
  if not api.nvim_win_is_valid(win_id) then
    return
  end
  
  local cursor = api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  -- Find the nearest marker position at or above the current line
  local target_marker = nil
  local closest_line = 0
  
  for line_num, marker in pairs(marker_positions) do
    if line_num <= current_line and line_num > closest_line then
      closest_line = line_num
      target_marker = marker
    end
  end
  
  if not target_marker then
    feedback.warning("Floating Viewer", "No marker found for current position")
    return
  end
  
  -- Close the floating window
  api.nvim_win_close(win_id, true)
  
  -- Jump to the marker's file and location
  local jump_success = M.jump_to_marker_location(target_marker)
  if jump_success then
    local filename = vim.fn.fnamemodify(target_marker.buffer_path, ":t")
    feedback.success("Floating Viewer", 
      string.format("Jumped to %s:%d - %s", filename, target_marker.start_line, target_marker.annotation))
  end
end

---Jump to a specific marker's location in its file
---@param marker table Marker object with buffer_path, start_line, end_line
---@return boolean success True if the jump was successful
function M.jump_to_marker_location(marker)
  -- Validate marker
  if not marker or not marker.buffer_path or not marker.start_line then
    feedback.error("Floating Viewer", "Invalid marker data")
    return false
  end
  
  -- Check if file exists
  if vim.fn.filereadable(marker.buffer_path) == 0 then
    feedback.error("Floating Viewer", "File not found: " .. marker.buffer_path)
    return false
  end
  
  -- Open/switch to the file
  local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(marker.buffer_path))
  if not ok then
    feedback.error("Floating Viewer", "Failed to open file: " .. tostring(err))
    return false
  end
  
  -- Jump to the marker line
  local line_count = api.nvim_buf_line_count(0)
  if marker.start_line > line_count then
    feedback.warning("Floating Viewer", "Line number exceeds file length")
    -- Go to last line instead
    api.nvim_win_set_cursor(0, { line_count, 0 })
  else
    api.nvim_win_set_cursor(0, { marker.start_line, 0 })
  end
  
  -- Center the view and highlight the area
  vim.cmd("normal! zz")
  
  -- If it's a multi-line marker, select the range
  if marker.end_line and marker.end_line > marker.start_line then
    -- Enter visual line mode and select the range
    vim.cmd("normal! V")
    api.nvim_win_set_cursor(0, { marker.end_line, 0 })
  end
  
  return true
end

---Show a help popup with available keybindings
---@param parent_win_id number Parent window ID for positioning
function M.show_help_popup(parent_win_id)
  local help_lines = {
    "📖 Floating Marker Viewer - Help",
    "═══════════════════════════════════",
    "",
    "Navigation:",
    "  j, ↓        Move down",
    "  k, ↑        Move up", 
    "  gg          Go to top",
    "  G           Go to bottom",
    "  Ctrl+u      Page up",
    "  Ctrl+d      Page down",
    "",
    "Actions:",
    "  Enter       Jump to marker location",
    "  q, Esc      Close viewer",
    "  ?           Show this help",
    "",
    "Press any key to close help..."
  }
  
  -- Create help buffer
  local help_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
  api.nvim_buf_set_option(help_buf, "modifiable", false)
  api.nvim_buf_set_option(help_buf, "bufhidden", "wipe")
  
  -- Calculate help window position (smaller, centered on parent)
  local help_width = 40
  local help_height = #help_lines + 2
  local parent_config = api.nvim_win_get_config(parent_win_id)
  
  local help_col = parent_config.col + math.floor((parent_config.width - help_width) / 2)
  local help_row = parent_config.row + math.floor((parent_config.height - help_height) / 2)
  
  -- Create help window
  local help_win = api.nvim_open_win(help_buf, true, {
    relative = "editor",
    width = help_width,
    height = help_height,
    col = help_col,
    row = help_row,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
    zindex = 150  -- Above the main floating window
  })
  
  -- Close help on any key press
  api.nvim_buf_set_keymap(help_buf, 'n', '<buffer>', '', {
    noremap = true,
    silent = true,
    callback = function()
      if api.nvim_win_is_valid(help_win) then
        api.nvim_win_close(help_win, true)
      end
      -- Return focus to parent window
      if api.nvim_win_is_valid(parent_win_id) then
        api.nvim_set_current_win(parent_win_id)
      end
    end
  })
  
  -- Also close on any character input
  for i = 32, 126 do  -- Printable ASCII characters
    local char = string.char(i)
    api.nvim_buf_set_keymap(help_buf, 'n', char, '', {
      noremap = true,
      silent = true,
      callback = function()
        if api.nvim_win_is_valid(help_win) then
          api.nvim_win_close(help_win, true)
        end
        if api.nvim_win_is_valid(parent_win_id) then
          api.nvim_set_current_win(parent_win_id)
        end
      end
    })
  end
end

---Update window size and position when terminal is resized
---@param win_id number Window ID to resize
function M.resize_window(win_id)
  if not api.nvim_win_is_valid(win_id) then
    return false
  end
  
  local win_config = calculate_window_config()
  local new_config = {
    relative = "editor",
    width = win_config.width,
    height = win_config.height,
    col = win_config.col,
    row = win_config.row
  }
  
  local ok, _ = pcall(api.nvim_win_set_config, win_id, new_config)
  return ok
end

---Set up auto-resize for all floating windows on terminal resize
function M.setup_auto_resize()
  api.nvim_create_autocmd("VimResized", {
    group = api.nvim_create_augroup("MarkerGroupsFloatingResize", { clear = true }),
    desc = "Resize floating marker viewer windows",
    callback = function()
      for win_id, _ in pairs(_floating_windows) do
        M.resize_window(win_id)
      end
    end
  })
end

---Close all floating marker viewer windows
function M.close_all()
  for win_id, _ in pairs(_floating_windows) do
    if api.nvim_win_is_valid(win_id) then
      api.nvim_win_close(win_id, true)
    end
  end
  _floating_windows = {}
end

---Check if any floating marker viewer windows are currently open
---@return boolean has_open_windows True if there are open floating windows
function M.has_open_windows()
  for win_id, _ in pairs(_floating_windows) do
    if api.nvim_win_is_valid(win_id) then
      return true
    end
  end
  return false
end

---Get debug information about the floating window system
---@return table debug_info Information about window state and configuration
function M.debug_info()
  local win_config = calculate_window_config()
  local active_group = state.get_active_group()
  local group = state.get_group(active_group)
  
  return {
    terminal_size = { width = vim.o.columns, height = vim.o.lines },
    calculated_window = win_config,
    active_group = active_group,
    marker_count = group and #group.markers or 0,
    open_windows = vim.tbl_count(_floating_windows),
    config = config.get_value("float_config", {})
  }
end

return M