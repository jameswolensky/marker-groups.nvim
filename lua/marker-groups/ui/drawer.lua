local M = {}

local api = vim.api
local config = require "marker-groups.config"
local state = require "marker-groups.state"
local feedback = require "marker-groups.feedback"

local _drawer_windows = {}

local function get_terminal_dimensions()
  return vim.o.columns, vim.o.lines
end

local function calculate_window_config()
  local drawer_config = config.get_value("drawer_config", {})
  local width = drawer_config.width or 60
  local side = drawer_config.side or "right"
  local border = drawer_config.border or "rounded"
  local title_pos = drawer_config.title_pos or "center"

  local columns, lines = get_terminal_dimensions()

  width = math.max(width, 30)
  width = math.min(width, math.floor(columns * 0.5))

  local height = lines - 2

  local col, row
  if side == "left" then
    col = 0
  else
    col = columns - width
  end
  row = 0

  return {
    width = width,
    height = height,
    col = col,
    row = row,
    border = border,
    title_pos = title_pos,
    side = side,
  }
end

local function read_file_lines(filepath)
  local lines = {}

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf) then
      local buf_name = api.nvim_buf_get_name(buf)
      if buf_name == filepath then
        lines = api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines
      end
    end
  end

  local file = io.open(filepath, "r")
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  end

  return lines
end

local function extract_marker_context(marker, context_lines, max_width)
  local file_lines = read_file_lines(marker.buffer_path)
  local context = {}

  if #file_lines == 0 then
    table.insert(context, " │ [File not found or empty]")
    return context
  end

  local context_start = math.max(1, marker.start_line - context_lines)
  local context_end = math.min(#file_lines, marker.end_line + context_lines)

  local max_line_num = context_end
  local line_num_width = string.len(tostring(max_line_num))

  for line_num = context_start, context_end do
    local is_marker_line = line_num >= marker.start_line and line_num <= marker.end_line
    local prefix = is_marker_line and " ► " or " │ "

    local line_num_str = string.format("%" .. line_num_width .. "d", line_num)
    local line_content = file_lines[line_num] or ""

    local available_width = max_width - string.len(prefix) - line_num_width - 3 -- ": " + some padding
    if string.len(line_content) > available_width then
      line_content = string.sub(line_content, 1, available_width - 3) .. "..."
    end

    local formatted_line = prefix .. line_num_str .. ": " .. line_content
    table.insert(context, formatted_line)
  end

  return context
end

local function create_marker_position_map(lines, markers)
  local position_map = {}
  local current_line = 1
  local marker_index = 1

  for line_idx, line in ipairs(lines) do
    if line:match "^[^%s].*:" and marker_index <= #markers then
      position_map[line_idx] = markers[marker_index]
      marker_index = marker_index + 1
    end
  end

  return position_map
end

local function get_filetype_from_path(filepath)
  local extension = filepath:match "%.([^%.]+)$"
  if not extension then
    return "text"
  end

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
    txt = "text",
  }

  return ext_to_filetype[extension] or "text"
end

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

function M.show_markers()
  local active_group = state.get_active_group()
  local group = state.get_group(active_group)

  if M.has_open_windows() then
    M.close_all()
  end

  local valid, error_msg = validate_display_conditions(active_group, group)
  if not valid then
    feedback.warning("Drawer Viewer", error_msg)
    return nil, nil
  end

  local win_config = calculate_window_config()

  local buf = api.nvim_create_buf(false, true)
  if not buf then
    feedback.error("Drawer Viewer", "Failed to create buffer")
    return nil, nil
  end

  local buf_opts = {
    bufhidden = "wipe",
    buftype = "nofile",
    swapfile = false,
    modifiable = false,
  }

  for opt, value in pairs(buf_opts) do
    api.nvim_buf_set_option(buf, opt, value)
  end

  local filetypes = {}
  local markers_mod = require "marker-groups.markers"
  local sorted_markers = markers_mod.list_markers(active_group)
  for _, marker in ipairs(sorted_markers) do
    local ft = get_filetype_from_path(marker.buffer_path)
    filetypes[ft] = (filetypes[ft] or 0) + 1
  end

  local dominant_filetype = "text"
  local max_count = 0
  for ft, count in pairs(filetypes) do
    if count > max_count then
      max_count = count
      dominant_filetype = ft
    end
  end

  M.setup_syntax_highlighting(buf, dominant_filetype, sorted_markers)

  local current_win = api.nvim_get_current_win()
  local split_cmd = win_config.side == "left" and "topleft vsplit" or "botright vsplit"

  vim.cmd(split_cmd)
  local win = api.nvim_get_current_win()

  api.nvim_win_set_buf(win, buf)

  api.nvim_win_set_width(win, win_config.width)

  if not win then
    feedback.error("Drawer Viewer", "Failed to create drawer window")
    api.nvim_buf_delete(buf, { force = true })
    return nil, nil
  end

  local win_options = {
    wrap = true,
    cursorline = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    colorcolumn = "",
    winhl = "Normal:Normal,CursorLine:CursorLine",
    winfixwidth = true,
  }

  for opt, value in pairs(win_options) do
    api.nvim_win_set_option(win, opt, value)
  end

  local base_name = string.format("Markers: %s (%d)", active_group, #sorted_markers)
  local unique_name = base_name
  local counter = 1

  while vim.fn.bufexists(unique_name) == 1 do
    unique_name = string.format("%s [%d]", base_name, counter)
    counter = counter + 1
  end

  local ok, err = pcall(api.nvim_buf_set_name, buf, unique_name)
  if not ok then
    local fallback_name = string.format("Markers: %s (%d) [%d]", active_group, #group.markers, os.time())
    pcall(api.nvim_buf_set_name, buf, fallback_name)
  end

  local content_lines = {}
  local content_marker_positions = {}
  local first_marker_line = nil
  local context_lines = config.get_value("context_lines", 2)

  local marker_count = #sorted_markers
  local marker_noun = marker_count == 1 and "marker" or "markers"
  table.insert(content_lines, string.format("📁 Group: %s (%d %s)", active_group, marker_count, marker_noun))
  table.insert(content_lines, string.rep("═", math.min(win_config.width - 4, 80)))
  table.insert(content_lines, "")

  for i, marker in ipairs(sorted_markers) do
    local marker_start_line = #content_lines + 1

    local line_range = marker.start_line == marker.end_line and tostring(marker.start_line)
      or marker.start_line .. "-" .. marker.end_line

    local header = string.format("📍 %s:%s", vim.fn.fnamemodify(marker.buffer_path, ":t"), line_range)
    table.insert(content_lines, header)

    content_marker_positions[marker_start_line] = marker
    if not first_marker_line then
      first_marker_line = marker_start_line
    end

    table.insert(content_lines, string.format("   %s", marker.buffer_path))

    table.insert(content_lines, "   ┌" .. string.rep("─", math.min(win_config.width - 8, 70)) .. "┐")

    local context = extract_marker_context(marker, context_lines, win_config.width - 8)
    for _, context_line in ipairs(context) do
      table.insert(content_lines, "   " .. context_line)
    end

    table.insert(content_lines, "   └" .. string.rep("─", math.min(win_config.width - 8, 70)) .. "┘")

    local display_annotation = marker.annotation or ""
    if display_annotation:find "\n" then
      local first = true
      for line in (display_annotation .. "\n"):gmatch "(.-)\n" do
        if first then
          table.insert(content_lines, string.format("   💬 %s", line))
          first = false
        else
          table.insert(content_lines, string.format("      %s", line))
        end
      end
    else
      table.insert(content_lines, string.format("   💬 %s", display_annotation))
    end

    if marker.timestamp then
      local time_str = os.date("%Y-%m-%d %H:%M", marker.timestamp)
      table.insert(content_lines, string.format("   🕒 %s", time_str))
    end

    if i < #sorted_markers then
      table.insert(content_lines, "")
      table.insert(content_lines, string.rep("─", math.min(win_config.width - 4, 80)))
      table.insert(content_lines, "")
    end
  end

  table.insert(content_lines, "")
  table.insert(content_lines, string.rep("═", math.min(win_config.width - 4, 80)))
  table.insert(
    content_lines,
    "🎯 Navigation: [j/k] move • [Enter] jump • [E] edit • [D] delete • [q/Esc] close"
  )

  api.nvim_buf_set_option(buf, "modifiable", true)
  local ok, err = pcall(api.nvim_buf_set_lines, buf, 0, -1, false, content_lines)
  if not ok then
    feedback.error("Drawer Viewer", "Failed to populate buffer: " .. tostring(err))
    api.nvim_win_close(win, true)
    return nil, nil
  end
  api.nvim_buf_set_option(buf, "modifiable", false)

  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "buflisted", false)

  pcall(function()
    if vim.diagnostic and vim.diagnostic.enable then
      vim.diagnostic.enable(false, { bufnr = buf })
    end
  end)
  pcall(function()
    vim.b[buf].ale_enabled = 0
  end)

  _drawer_windows[win] = {
    buffer = buf,
    group = active_group,
    marker_count = #group.markers,
    created_at = os.time(),
    is_drawer = true,
    marker_positions = content_marker_positions,
  }

  M.setup_window_keybindings(buf, win, content_marker_positions)

  M.setup_syntax_auto_refresh(buf)

  M.setup_drawer_auto_updates(win, buf)

  if first_marker_line then
    pcall(api.nvim_win_set_cursor, win, { first_marker_line, 0 })
    pcall(vim.cmd, "normal! zz")
  end

  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      M.cleanup_drawer_auto_updates(win)
      _drawer_windows[win] = nil
    end,
  })

  feedback.success(
    "Drawer Viewer",
    "Opened viewer for group '" .. active_group .. "' with " .. #group.markers .. " markers"
  )
  return buf, win
end

function M.setup_syntax_highlighting(buf_id, dominant_filetype, markers)
  api.nvim_buf_set_option(buf_id, "filetype", "marker-groups-drawer")

  api.nvim_buf_call(buf_id, function()
    vim.cmd "syntax on"
  end)

  M.setup_marker_highlights(buf_id)

  api.nvim_buf_call(buf_id, function()
    vim.cmd [[
      highlight default MarkerFloatingHeader guifg=#61AFEF gui=bold ctermfg=75 cterm=bold
      highlight default MarkerFloatingPath guifg=#98C379 ctermfg=114
      highlight default MarkerFloatingAnnotation guifg=#E06C75 gui=italic ctermfg=204 cterm=italic
      highlight default MarkerFloatingTimestamp guifg=#D19A66 ctermfg=173
      highlight default MarkerFloatingBorder guifg=#5C6370 ctermfg=59
      highlight default MarkerFloatingContext guifg=#ABB2BF ctermfg=145
      highlight default MarkerFloatingMarkerLine guifg=#C678DD gui=bold ctermfg=176 cterm=bold
    ]]
  end)
end

function M.setup_marker_highlights(buf_id)
  api.nvim_buf_call(buf_id, function()
    vim.cmd [[syntax match MarkerFloatingHeader /^📍.*$/]]

    vim.cmd [[syntax match MarkerFloatingPath /^   \/.*$/]]

    vim.cmd [[syntax match MarkerFloatingAnnotation /^   💬.*$/]]

    vim.cmd [[syntax match MarkerFloatingTimestamp /^   🕒.*$/]]

    vim.cmd [[syntax match MarkerFloatingBorder /[┌┐└┘─│═]/]]

    vim.cmd [[syntax match MarkerFloatingMarkerLine /.*►.*$/]]

    vim.cmd [[syntax match MarkerFloatingContext /.*│.*$/]]
  end)
end

function M.setup_syntax_auto_refresh(buf_id)
  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    buffer = buf_id,
    callback = function()
      api.nvim_buf_call(buf_id, function()
        vim.cmd "syntax sync fromstart"
      end)
    end,
    desc = "Refresh syntax highlighting for marker floating window",
  })
end

function M.setup_window_keybindings(buf_id, win_id, marker_positions)
  local keymap_opts = { noremap = true, silent = true }

  api.nvim_buf_set_keymap(buf_id, "n", "j", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.navigate_to_next_marker(win_id, marker_positions, "down")
    end,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "k", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.navigate_to_next_marker(win_id, marker_positions, "up")
    end,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "<Down>", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.navigate_to_next_marker(win_id, marker_positions, "down")
    end,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "<Up>", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.navigate_to_next_marker(win_id, marker_positions, "up")
    end,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.jump_to_current_marker(win_id, marker_positions)
    end,
  })

  local close_callback = function()
    if api.nvim_win_is_valid(win_id) then
      api.nvim_win_close(win_id, true)
      feedback.success("Drawer Viewer", "Closed marker viewer")
    end
  end

  api.nvim_buf_set_keymap(buf_id, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = close_callback,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    callback = close_callback,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "gg", "gg", keymap_opts)
  api.nvim_buf_set_keymap(buf_id, "n", "G", "G", keymap_opts)
  api.nvim_buf_set_keymap(buf_id, "n", "<C-u>", "<C-u>", keymap_opts)
  api.nvim_buf_set_keymap(buf_id, "n", "<C-d>", "<C-d>", keymap_opts)

  api.nvim_buf_set_keymap(buf_id, "n", "E", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.edit_current_marker(win_id, marker_positions)
    end,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "D", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.delete_current_marker(win_id, marker_positions)
    end,
  })

  api.nvim_buf_set_keymap(buf_id, "n", "<leader>md", "", {
    noremap = true,
    silent = true,
    callback = function()
      feedback.info("Drawer Viewer", "Use 'D' to delete from the drawer; '<leader>md' works in file buffers")
    end,
  })
end

function M.jump_to_current_marker(win_id, marker_positions)
  if not api.nvim_win_is_valid(win_id) then
    return
  end

  local cursor = api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]

  local target_marker = nil
  local closest_line = 0

  for line_num, marker in pairs(marker_positions) do
    if line_num <= current_line and line_num > closest_line then
      closest_line = line_num
      target_marker = marker
    end
  end

  if not target_marker then
    feedback.warning("Drawer Viewer", "No marker found for current position")
    return
  end

  api.nvim_win_close(win_id, true)

  local jump_success = M.jump_to_marker_location(target_marker)
  if jump_success then
    local filename = vim.fn.fnamemodify(target_marker.buffer_path, ":t")
    feedback.success(
      "Drawer Viewer",
      string.format("Jumped to %s:%d - %s", filename, target_marker.start_line, target_marker.annotation)
    )
  end
end

function M.jump_to_marker_location(marker)
  if not marker or not marker.buffer_path or not marker.start_line then
    feedback.error("Drawer Viewer", "Invalid marker data")
    return false
  end

  if vim.fn.filereadable(marker.buffer_path) == 0 then
    feedback.error("Drawer Viewer", "File not found: " .. marker.buffer_path)
    return false
  end

  local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(marker.buffer_path))
  if not ok then
    feedback.error("Drawer Viewer", "Failed to open file: " .. tostring(err))
    return false
  end

  local line_count = api.nvim_buf_line_count(0)
  if marker.start_line > line_count then
    feedback.warning("Drawer Viewer", "Line number exceeds file length")
    api.nvim_win_set_cursor(0, { line_count, 0 })
  else
    api.nvim_win_set_cursor(0, { marker.start_line, 0 })
  end

  vim.cmd "normal! zz"

  return true
end

function M.delete_current_marker(win_id, marker_positions)
  if not api.nvim_win_is_valid(win_id) then
    return
  end

  local cursor = api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]

  local target_marker = nil
  local closest_line = 0

  for line_num, marker in pairs(marker_positions) do
    if line_num <= current_line and line_num > closest_line then
      closest_line = line_num
      target_marker = marker
    end
  end

  if not target_marker then
    feedback.warning("Drawer Viewer", "No marker found at current position")
    return
  end

  local neighbor_focus_id = nil
  do
    local marker_lines = {}
    for line_num, _ in pairs(marker_positions) do
      table.insert(marker_lines, line_num)
    end
    table.sort(marker_lines)
    local idx = nil
    for i, ln in ipairs(marker_lines) do
      if ln == closest_line then
        idx = i
        break
      end
    end
    if idx then
      if marker_lines[idx + 1] then
        neighbor_focus_id = marker_positions[marker_lines[idx + 1]].id
      elseif marker_lines[idx - 1] then
        neighbor_focus_id = marker_positions[marker_lines[idx - 1]].id
      end
    end
  end

  local markers = require "marker-groups.markers"
  local result = markers.delete_marker(target_marker.id)

  if not result.success then
    feedback.error("Drawer Viewer", "Failed to delete marker: " .. result.error)
    return
  end

  local filename = vim.fn.fnamemodify(target_marker.buffer_path, ":t")
  feedback.success(
    "Drawer Viewer",
    string.format("Deleted marker from %s:%d - %s", filename, target_marker.start_line, target_marker.annotation)
  )

  M.refresh_current_drawer(neighbor_focus_id)
end

function M.edit_current_marker(win_id, marker_positions)
  if not api.nvim_win_is_valid(win_id) then
    return
  end

  local cursor = api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]

  local target_marker = nil
  local closest_line = 0

  for line_num, marker in pairs(marker_positions) do
    if line_num <= current_line and line_num > closest_line then
      closest_line = line_num
      target_marker = marker
    end
  end

  if not target_marker then
    feedback.warning("Drawer Viewer", "No marker found at current position")
    return
  end

  local input_ui = require "marker-groups.ui.input"
  input_ui.prompt_multiline(
    { title = "Edit annotation", default = target_marker.annotation, width = 70, height = 12 },
    require("marker-groups.config").get_internal "max_annotation_chars",
    function(input)
      if not input or input == "" then
        return
      end
      local markers = require "marker-groups.markers"
      local result = markers.edit_marker(target_marker.id, input)
      if not result.success then
        feedback.error("Drawer Viewer", "Failed to edit marker: " .. result.error)
        return
      end
      feedback.success("Drawer Viewer", "Updated marker annotation")
      M.refresh_current_drawer(target_marker.id)
    end
  )
end

function M.show_help_popup(parent_win_id)
  local help_lines = {
    "📖 Drawer Marker Viewer - Help",
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
    "  E           Edit current marker annotation",
    "  D           Delete current marker",
    "  q, Esc      Close viewer",
    "",
    "Press any key to close help...",
  }

  local help_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
  api.nvim_buf_set_option(help_buf, "modifiable", false)
  api.nvim_buf_set_option(help_buf, "bufhidden", "wipe")

  local help_width = 40
  local help_height = #help_lines + 2
  local parent_config = api.nvim_win_get_config(parent_win_id)

  local help_col = parent_config.col + math.floor((parent_config.width - help_width) / 2)
  local help_row = parent_config.row + math.floor((parent_config.height - help_height) / 2)

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
    zindex = 150,
  })

  api.nvim_buf_set_keymap(help_buf, "n", "<buffer>", "", {
    noremap = true,
    silent = true,
    callback = function()
      if api.nvim_win_is_valid(help_win) then
        api.nvim_win_close(help_win, true)
      end
      if api.nvim_win_is_valid(parent_win_id) then
        api.nvim_set_current_win(parent_win_id)
      end
    end,
  })

  for i = 32, 126 do
    local char = string.char(i)
    api.nvim_buf_set_keymap(help_buf, "n", char, "", {
      noremap = true,
      silent = true,
      callback = function()
        if api.nvim_win_is_valid(help_win) then
          api.nvim_win_close(help_win, true)
        end
        if api.nvim_win_is_valid(parent_win_id) then
          api.nvim_set_current_win(parent_win_id)
        end
      end,
    })
  end
end

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
    row = win_config.row,
  }

  local ok, _ = pcall(api.nvim_win_set_config, win_id, new_config)
  return ok
end

function M.setup_auto_resize()
  api.nvim_create_autocmd("VimResized", {
    group = api.nvim_create_augroup("MarkerGroupsDrawerResize", { clear = true }),
    desc = "Resize drawer marker viewer windows",
    callback = function()
      for win_id, _ in pairs(_drawer_windows) do
        M.resize_window(win_id)
      end
    end,
  })
end

function M.close_all()
  local wins = api.nvim_list_wins()
  for win_id, _ in pairs(_drawer_windows) do
    if api.nvim_win_is_valid(win_id) then
      if #wins > 1 then
        api.nvim_win_close(win_id, true)
      end
    end
  end
  _drawer_windows = {}
end

function M.has_open_windows()
  for win_id, _ in pairs(_drawer_windows) do
    if api.nvim_win_is_valid(win_id) then
      return true
    end
  end
  return false
end

function M.debug_info()
  local win_config = calculate_window_config()
  local active_group = state.get_active_group()
  local group = state.get_group(active_group)

  return {
    terminal_size = { width = vim.o.columns, height = vim.o.lines },
    calculated_window = win_config,
    active_group = active_group,
    marker_count = group and #group.markers or 0,
    open_windows = vim.tbl_count(_drawer_windows),
    config = config.get_value("drawer_config", {}),
  }
end

function M.toggle_drawer()
  if M.has_open_windows() then
    M.close_all()
    feedback.success("Drawer Viewer", "Closed marker drawer")
    return nil, nil
  else
    return M.show_markers()
  end
end

function M.set_drawer_width(width)
  width = math.max(width, 30)
  width = math.min(width, 120)

  local config_module = require "marker-groups.config"
  config_module.update {
    drawer_config = {
      width = width,
    },
  }

  for win_id, win_info in pairs(_drawer_windows) do
    if win_info.is_drawer and api.nvim_win_is_valid(win_id) then
      pcall(api.nvim_win_set_width, win_id, width)
    end
  end
end

function M.get_drawer_width()
  return config.get_value("drawer_config.width", 60)
end

function M.navigate_to_next_marker(win_id, marker_positions, direction)
  if not api.nvim_win_is_valid(win_id) then
    return
  end

  local cursor = api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]

  local marker_lines = {}
  for line_num, _ in pairs(marker_positions) do
    table.insert(marker_lines, line_num)
  end
  table.sort(marker_lines)

  if #marker_lines == 0 then
    return
  end

  local target_line = nil

  if direction == "down" then
    for _, line_num in ipairs(marker_lines) do
      if line_num > current_line then
        target_line = line_num
        break
      end
    end
    if not target_line then
      target_line = marker_lines[1]
    end
  else -- direction == "up"
    for i = #marker_lines, 1, -1 do
      local line_num = marker_lines[i]
      if line_num < current_line then
        target_line = line_num
        break
      end
    end
    if not target_line then
      target_line = marker_lines[#marker_lines]
    end
  end

  if target_line then
    api.nvim_win_set_cursor(win_id, { target_line, 0 })
    vim.cmd "normal! zz"
  end
end

function M.refresh_current_drawer(focus_marker_id)
  local target_win = nil
  for win_id, win_info in pairs(_drawer_windows) do
    if win_info.is_drawer and api.nvim_win_is_valid(win_id) then
      target_win = win_id
      api.nvim_win_close(win_id, true)
      break
    end
  end
  vim.defer_fn(function()
    local state = require "marker-groups.state"
    local active = state.get_active_group()
    local group = active and state.get_group(active) or nil
    if not group or not group.markers or #group.markers == 0 then
      return
    end

    local buf, win = M.show_markers()
    if focus_marker_id and win and api.nvim_win_is_valid(win) then
      local info = _drawer_windows[win]
      if info and info.marker_positions then
        local focus_line = nil
        for line_num, marker in pairs(info.marker_positions) do
          if marker.id == focus_marker_id then
            focus_line = line_num
            break
          end
        end
        if focus_line then
          api.nvim_win_set_cursor(win, { focus_line, 0 })
          vim.cmd "normal! zz"
        end
      end
    end
  end, 100)
end

local function get_active_drawer_info()
  local current_win = api.nvim_get_current_win()
  if _drawer_windows[current_win] then
    return current_win, _drawer_windows[current_win].marker_positions
  end
  for win_id, info in pairs(_drawer_windows) do
    if info.is_drawer and api.nvim_win_is_valid(win_id) then
      return win_id, info.marker_positions
    end
  end
  return nil, nil
end

function M.setup_drawer_auto_updates(win_id, buf_id)
  if not M._drawer_update_listeners then
    M._drawer_update_listeners = {}
  end

  local state = require "marker-groups.state"

  local unsubscribe_functions = {}

  unsubscribe_functions.marker_added = state.on("marker_added", function(data)
    vim.schedule(function()
      if api.nvim_win_is_valid(win_id) and api.nvim_buf_is_valid(buf_id) then
        local active_group = state.get_active_group()
        if data.group_name == active_group then
          M.refresh_current_drawer()
        end
      end
    end)
  end)

  unsubscribe_functions.marker_removed = state.on("marker_removed", function(data)
    vim.schedule(function()
      if api.nvim_win_is_valid(win_id) and api.nvim_buf_is_valid(buf_id) then
        local active_group = state.get_active_group()
        if data.group_name == active_group then
          M.refresh_current_drawer()
        end
      end
    end)
  end)

  unsubscribe_functions.active_group_changed = state.on("active_group_changed", function(data)
    vim.schedule(function()
      if api.nvim_win_is_valid(win_id) and api.nvim_buf_is_valid(buf_id) then
        M.refresh_current_drawer()
      end
    end)
  end)

  unsubscribe_functions.group_deleted = state.on("group_deleted", function(data)
    vim.schedule(function()
      if api.nvim_win_is_valid(win_id) and api.nvim_buf_is_valid(buf_id) then
        local active_group = state.get_active_group()
        if not active_group or data.group_name == active_group then
          api.nvim_win_close(win_id, true)
          feedback.info("Drawer Viewer", "Closed drawer - active group was deleted")
        end
      end
    end)
  end)

  M._drawer_update_listeners[win_id] = unsubscribe_functions
end

function M.cleanup_drawer_auto_updates(win_id)
  if not M._drawer_update_listeners or not M._drawer_update_listeners[win_id] then
    return
  end

  local unsubscribe_functions = M._drawer_update_listeners[win_id]

  for event_name, unsubscribe_fn in pairs(unsubscribe_functions) do
    if type(unsubscribe_fn) == "function" then
      unsubscribe_fn()
    end
  end

  M._drawer_update_listeners[win_id] = nil
end

M.calculate_window_config = calculate_window_config

return M
