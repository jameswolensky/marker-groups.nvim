local M = {}

local function read_file_lines(path)
  local lines = {}
  local f = io.open(path, "r")
  if not f then
    return lines
  end
  for l in f:lines() do
    table.insert(lines, l)
  end
  f:close()
  return lines
end

local function get_buffer_lines_or_file(path)
  -- Try loaded buffers first
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      if vim.api.nvim_buf_get_name(buf) == path then
        return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      end
    end
  end
  return read_file_lines(path)
end

local function add_marker_block(lines_out, marker, ctx)
  local context = ctx or {}
  local context_lines = context.context_lines or 2
  local file_path = marker.buffer_path or ""
  local file_lines = get_buffer_lines_or_file(file_path)

  local start_line = math.max(marker.start_line - context_lines, 1)
  local end_line = math.min(marker.end_line + context_lines, #file_lines)

  table.insert(
    lines_out,
    string.format(
      "📍 %s:%s",
      vim.fn.fnamemodify(file_path, ":t"),
      (marker.start_line == marker.end_line) and tostring(marker.start_line)
        or (marker.start_line .. "-" .. marker.end_line)
    )
  )
  table.insert(lines_out, "   " .. file_path)
  table.insert(lines_out, "   " .. string.rep("\226\148\128", 52))

  for i = start_line, end_line do
    local prefix = (i >= marker.start_line and i <= marker.end_line) and "   ► " or "    │ "
    local content = file_lines[i] or ""
    table.insert(lines_out, string.format("%s%-4d: %s", prefix, i, content))
  end

  table.insert(lines_out, "   " .. string.rep("\226\148\132", 52))

  if marker.annotation and marker.annotation ~= "" then
    table.insert(lines_out, "   💬 " .. marker.annotation)
  end
  if marker.timestamp then
    table.insert(lines_out, "   🕒 " .. os.date("%Y-%m-%d %H:%M", marker.timestamp))
  end
end

function M.build_group_preview_lines(group_name, opts)
  local state = require "marker-groups.state"
  local group = state.get_group(group_name)
  local lines = {}

  local count = group and group.markers and #group.markers or 0
  table.insert(lines, string.format("📁 Group: %s (%d markers)", group_name, count))
  table.insert(lines, string.rep("\226\148\128", 55))
  table.insert(lines, "")

  if not group or not group.markers or count == 0 then
    table.insert(lines, "📝 No markers in this group")
    return lines
  end

  local max = math.min(opts and opts.max_markers or 5, count)
  for i = 1, max do
    add_marker_block(lines, group.markers[i], { context_lines = (opts and opts.context_lines) or 2 })
    table.insert(lines, "")
    table.insert(lines, string.rep("\226\148\128", 56))
    table.insert(lines, "")
  end

  return lines
end

return M
