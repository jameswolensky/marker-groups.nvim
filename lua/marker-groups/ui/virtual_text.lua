local M = {}

local api = vim.api
local config = require "marker-groups.config"
local feedback = require "marker-groups.feedback"

local _cached_namespaces = {}

local _update_timers = {}
local _hydrating = false

local function get_namespace(name)
  if not _cached_namespaces[name] then
    _cached_namespaces[name] = api.nvim_create_namespace(name)
  end
  return _cached_namespaces[name]
end

function M.setup_highlights()
  local bg = vim.o.background
  local colorscheme = vim.g.colors_name or "default"

  local highlights = {
    MarkerGroupsMarker = {
      light = { fg = "#0451A5", bg = "#F3F3F3" },
      dark = { fg = "#61AFEF", bg = "#2C323C" },
    },
    MarkerGroupsAnnotation = {
      light = { fg = "#0E8A00", italic = true },
      dark = { fg = "#98C379", italic = true },
    },
    MarkerGroupsContext = {
      light = { fg = "#6A6A6A" },
      dark = { fg = "#ABB2BF" },
    },
    MarkerGroupsMultilineStart = {
      light = { fg = "#AF00DB", bold = true },
      dark = { fg = "#C678DD", bold = true },
    },
    MarkerGroupsMultilineEnd = {
      light = { fg = "#AF00DB" },
      dark = { fg = "#C678DD" },
    },
  }

  local cfg = config.get()
  local hls = cfg.highlight_groups or {}
  local name_map = {
    MarkerGroupsMarker = hls.marker or "MarkerGroupsMarker",
    MarkerGroupsAnnotation = hls.annotation or "MarkerGroupsAnnotation",
    MarkerGroupsContext = hls.context or "MarkerGroupsContext",
    MarkerGroupsMultilineStart = hls.multiline_start or "MarkerGroupsMultilineStart",
    MarkerGroupsMultilineEnd = hls.multiline_end or "MarkerGroupsMultilineEnd",
  }

  for default_group, colors in pairs(highlights) do
    local hl_opts = bg == "light" and colors.light or colors.dark
    hl_opts.default = true

    api.nvim_set_hl(0, default_group, hl_opts)

    local custom_group = name_map[default_group]
    if custom_group ~= default_group then
      pcall(api.nvim_set_hl, 0, custom_group, { link = default_group, default = true })
    end
  end

  local group = api.nvim_create_augroup("MarkerGroupsHighlights", { clear = true })
  api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      M.setup_highlights()
    end,
    desc = "Update marker groups highlights on colorscheme change",
  })
end

local function format_annotation(annotation, max_length)
  if not annotation or annotation == "" then
    return "(no annotation)"
  end

  max_length = max_length or config.get_value("max_annotation_display", 50)

  local formatted = annotation:gsub("\n", " "):gsub("\r", " ")

  if #formatted > max_length then
    formatted = formatted:sub(1, max_length - 3) .. "..."
  end

  return formatted
end

local function create_marker_virtual_text(marker, marker_type, context_info)
  local cfg = config.get()
  local hls = cfg.highlight_groups or {}
  local hl_marker = hls.marker or "MarkerGroupsMarker"
  local hl_annotation = hls.annotation or "MarkerGroupsAnnotation"
  local hl_context = hls.context or "MarkerGroupsContext"
  local hl_ml_start = hls.multiline_start or "MarkerGroupsMultilineStart"
  local hl_ml_end = hls.multiline_end or "MarkerGroupsMultilineEnd"
  marker_type = marker_type or (marker.start_line == marker.end_line and "single" or "multiline_start")

  local annotation = format_annotation(marker.annotation)
  local virtual_text = {}

  table.insert(virtual_text, { " ", "Normal" })

  if marker_type == "single" then
    table.insert(virtual_text, { cfg.signs.marker .. " ", hl_marker })
    table.insert(virtual_text, { annotation, hl_annotation })
  elseif marker_type == "multiline_start" then
    table.insert(virtual_text, { cfg.signs.multiline_start .. " ", hl_ml_start })
    table.insert(virtual_text, { annotation, hl_annotation })
  elseif marker_type == "multiline_end" then
    table.insert(virtual_text, { cfg.signs.multiline_end .. " ", hl_ml_end })
    table.insert(virtual_text, { context_info or ("End: " .. format_annotation(annotation, 25)), hl_context })
  end

  if cfg.debug then
    local line_info = marker_type == "single" and string.format(" [L%d]", marker.start_line)
      or string.format(" [L%d-%d]", marker.start_line, marker.end_line)
    table.insert(virtual_text, { line_info, hl_context })
  end

  return virtual_text
end

function M.update_buffer_display(buf, markers)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local vt_ns = get_namespace "marker_groups_virtual_text"

  api.nvim_buf_clear_namespace(buf, vt_ns, 0, -1)

  table.sort(markers, function(a, b)
    return a.start_line < b.start_line
  end)

  for i, marker in ipairs(markers) do
    local success, err = pcall(function()
      if marker.start_line == marker.end_line then
        local virtual_text = create_marker_virtual_text(marker, "single")

        api.nvim_buf_set_extmark(buf, vt_ns, marker.start_line - 1, -1, {
          virt_text = virtual_text,
          virt_text_pos = "eol",
          hl_mode = "combine",
          priority = 1000 + i,
        })
      else
        local start_vt = create_marker_virtual_text(marker, "multiline_start")
        api.nvim_buf_set_extmark(buf, vt_ns, marker.start_line - 1, -1, {
          virt_text = start_vt,
          virt_text_pos = "eol",
          hl_mode = "combine",
          priority = 1000 + i,
        })

        if marker.end_line > marker.start_line then
          local end_vt =
            create_marker_virtual_text(marker, "multiline_end", "End: " .. format_annotation(marker.annotation, 30))
          api.nvim_buf_set_extmark(buf, vt_ns, marker.end_line - 1, -1, {
            virt_text = end_vt,
            virt_text_pos = "eol",
            hl_mode = "combine",
            priority = 1000 + i,
          })
        end
      end
    end)

    if not success and config.get().debug then
      vim.notify(
        string.format("Failed to create virtual text for marker %s: %s", marker.id or "unknown", err),
        vim.log.levels.WARN
      )
    end
  end
end

function M.clear_buffer_display(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local vt_ns = get_namespace "marker_groups_virtual_text"
  api.nvim_buf_clear_namespace(buf, vt_ns, 0, -1)
end

local _virtual_text_enabled = true

function M.toggle_display(enabled)
  local new_state = enabled ~= nil and enabled or not _virtual_text_enabled
  _virtual_text_enabled = new_state

  if new_state then
    M.update_all_buffers()
    vim.notify("Marker virtual text enabled", vim.log.levels.INFO)
  else
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(buf) then
        M.clear_buffer_display(buf)
      end
    end
    vim.notify("Marker virtual text disabled", vim.log.levels.INFO)
  end
end

function M.is_enabled()
  return _virtual_text_enabled
end

function M.debug_info()
  local info = {
    enabled = M.is_enabled(),
    namespace_cache = vim.tbl_keys(_cached_namespaces),
    highlight_groups = {},
    loaded_buffers_with_markers = 0,
  }

  do
    local cfg = config.get()
    local hls = cfg.highlight_groups or {}
    local groups = {
      hls.marker or "MarkerGroupsMarker",
      hls.annotation or "MarkerGroupsAnnotation",
      hls.context or "MarkerGroupsContext",
      hls.multiline_start or "MarkerGroupsMultilineStart",
      hls.multiline_end or "MarkerGroupsMultilineEnd",
    }
    for _, group in ipairs(groups) do
      local hl = api.nvim_get_hl(0, { name = group })
      info.highlight_groups[group] = hl
    end
  end

  local state = require "marker-groups.state"
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

function M.refresh_buffer(buf, immediate)
  buf = buf or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local buf_path = api.nvim_buf_get_name(buf)
  if not buf_path or buf_path == "" then
    return
  end

  if not immediate then
    if _update_timers[buf] then
      _update_timers[buf]:stop()
    end

    _update_timers[buf] = vim.defer_fn(function()
      _update_timers[buf] = nil
      M.refresh_buffer(buf, true)
    end, 100)
    return
  end

  local markers = require("marker-groups.markers").list_markers(nil, {
    buffer_path = buf_path,
  })

  M.update_buffer_display(buf, markers)
end

function M.force_refresh_all()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      M.refresh_buffer(buf, true)
    end
  end
end

function M.update_all_buffers()
  if not M.is_enabled() then
    return
  end

  local state = require "marker-groups.state"
  local active_group = state.get_group()

  if not active_group then
    return
  end

  local markers_by_buffer = {}
  for _, marker in ipairs(active_group.markers) do
    local path = marker.buffer_path
    if not markers_by_buffer[path] then
      markers_by_buffer[path] = {}
    end
    table.insert(markers_by_buffer[path], marker)
  end

  for path, markers in pairs(markers_by_buffer) do
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
      M.update_buffer_display(buf, markers)
    end
  end

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      local buf_path = api.nvim_buf_get_name(buf)
      if buf_path and buf_path ~= "" and not markers_by_buffer[buf_path] then
        M.clear_buffer_display(buf)
      end
    end
  end
end

function M.setup_auto_updates()
  local state = require "marker-groups.state"

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
          buffer_path = data.marker.buffer_path,
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
          buffer_path = data.marker.buffer_path,
        })
        M.update_buffer_display(buf, markers)
      end
    end)
  end)

  state.on("group_created", function(data)
    vim.schedule(function()
      -- Suppress noisy create notification to avoid confusion during hydration and normal use
      -- Visual updates are handled elsewhere; no notification needed here.
      return
    end)
  end)

  state.on("group_renamed", function(data)
    vim.schedule(function()
      M.update_all_buffers()
      feedback.notify("Group renamed: " .. data.old_name .. " -> " .. data.new_name, feedback.levels.DEBUG)
    end)
  end)

  state.on("group_deleted", function(data)
    vim.schedule(function()
      M.update_all_buffers()
      feedback.notify("Group deleted: " .. data.group_name, feedback.levels.DEBUG)
    end)
  end)

  -- Distinguish persisted groups from newly created ones to avoid misleading logs
  state.on("group_loaded", function(data)
    vim.schedule(function()
      if require("marker-groups.config").get_value("debug", false) then
        feedback.notify("Group loaded: " .. data.group_name, feedback.levels.DEBUG)
      end
    end)
  end)

  state.on("buffer_major_change", function(data)
    vim.schedule(function()
      if api.nvim_buf_is_valid(data.buffer) then
        local markers = require("marker-groups.markers").list_markers(nil, {
          buffer_path = data.path,
        })
        M.update_buffer_display(data.buffer, markers)
      end
    end)
  end)

  state.on("state_initialized", function(data)
    vim.schedule(function()
      M.update_all_buffers()
      feedback.notify("Marker groups UI synchronized with state", feedback.levels.DEBUG)
      -- Suppress noisy create logs briefly during hydration sequence
      _hydrating = true
      vim.defer_fn(function()
        _hydrating = false
      end, 600)
    end)
  end)

  M.setup_buffer_autocmds()
end

function M.setup_buffer_autocmds()
  local group = api.nvim_create_augroup("MarkerGroupsVirtualText", { clear = true })

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
    desc = "Update marker virtual text on buffer enter",
  })

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
    desc = "Update marker virtual text after buffer save",
  })

  api.nvim_create_autocmd("BufUnload", {
    group = group,
    callback = function(args)
      local buf = args.buf
      if api.nvim_buf_is_valid(buf) then
        M.clear_buffer_display(buf)
      end
    end,
    desc = "Clear marker virtual text on buffer unload",
  })

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
    desc = "Update marker virtual text on window enter",
  })

  api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      if M.is_enabled() then
        local buf = api.nvim_get_current_buf()
        if api.nvim_buf_is_valid(buf) then
          vim.defer_fn(function()
            M.refresh_buffer(buf)
          end, 50)
        end
      end
    end,
    desc = "Update marker virtual text on mode change",
  })
end

function M.clear_buffer_autocmds()
  pcall(api.nvim_del_augroup_by_name, "MarkerGroupsVirtualText")
end

return M
