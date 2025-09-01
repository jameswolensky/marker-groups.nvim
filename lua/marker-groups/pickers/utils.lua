local M = {}

function M.get_filetype_from_path(file_path)
  local extension = file_path:match "%.([^%.]+)$"
  if not extension then
    return "text"
  end
  local map = {
    lua = "lua",
    py = "python",
    js = "javascript",
    ts = "typescript",
    go = "go",
    rs = "rust",
    c = "c",
    cpp = "cpp",
    h = "c",
    hpp = "cpp",
    java = "java",
    rb = "ruby",
    php = "php",
    sh = "bash",
    zsh = "bash",
    fish = "fish",
    vim = "vim",
    md = "markdown",
    txt = "text",
    json = "json",
    yaml = "yaml",
    yml = "yaml",
    toml = "toml",
    xml = "xml",
    html = "html",
    css = "css",
    scss = "scss",
    sass = "sass",
  }
  return map[extension:lower()] or "text"
end

function M.read_file_content(file_path)
  local bufnr = vim.fn.bufnr(file_path)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local fh = io.open(file_path, "r")
  if not fh then
    return {}
  end
  local lines = {}
  for line in fh:lines() do
    table.insert(lines, line)
  end
  fh:close()
  return lines
end

function M.generate_marker_preview(marker)
  local file_content = M.read_file_content(marker.buffer_path)

  local preview = {
    "📍 " .. vim.fn.fnamemodify(marker.buffer_path, ":t"),
    "═══════════════════════════════════",
    "",
    "📂 File: " .. marker.buffer_path,
    "📏 Lines: "
      .. marker.start_line
      .. ((marker.start_line ~= marker.end_line) and (" - " .. marker.end_line) or ""),
    "💬 Annotation: " .. (marker.annotation or ""),
    "",
    "📝 Code Context:",
    string.rep("─", 40),
  }

  if #file_content > 0 then
    local context_lines = 2
    local s = math.max(1, marker.start_line - context_lines)
    local e = math.min(#file_content, (marker.end_line or marker.start_line) + context_lines)
    for i = s, e do
      local is_marker = i >= marker.start_line and i <= (marker.end_line or marker.start_line)
      local prefix = is_marker and "► " or "  "
      local line_num = string.format("%4d", i)
      table.insert(preview, prefix .. line_num .. ": " .. (file_content[i] or ""))
    end
  end

  return {
    content = preview,
    filetype = M.get_filetype_from_path(marker.buffer_path),
  }
end

function M.navigate_to_marker(marker)
  local ok, err = pcall(function()
    vim.cmd("edit " .. vim.fn.fnameescape(marker.buffer_path))
    vim.api.nvim_win_set_cursor(0, { marker.start_line, 0 })
    vim.cmd "normal! zz"
  end)
  if ok then
    vim.notify(
      "Navigated to: " .. vim.fn.fnamemodify(marker.buffer_path, ":t") .. ":" .. marker.start_line,
      vim.log.levels.INFO
    )
  else
    vim.notify("Failed to navigate to marker: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.show_notification(message, level, duration)
  duration = duration or 5000
  vim.notify(message, level or vim.log.levels.INFO)
  vim.defer_fn(function() end, duration)
end

function M.generate_group_preview(group_info)
  local state = require "marker-groups.state"
  local name = group_info.name or "unknown"
  local marker_count = tonumber(group_info.marker_count or 0)

  local preview = {
    "📁 Group: " .. name .. (group_info.is_active and " (active)" or ""),
    "═══════════════════════════════════",
    "",
    "📊 Statistics:",
    "  • Markers: " .. tostring(marker_count),
    "  • Created: " .. (group_info.created_formatted or "unknown"),
    "  • Modified: " .. (group_info.modified_formatted or "unknown"),
    "",
  }

  -- Recent markers (up to 5)
  local group_full = state.get_group(name)
  local markers = group_full and group_full.markers or {}
  if marker_count > 0 and markers and #markers > 0 then
    table.insert(preview, "📌 Recent Markers:")
    local limit = math.min(5, #markers)
    for i = 1, limit do
      local m = markers[i]
      if m then
        local file_name = vim.fn.fnamemodify(m.buffer_path, ":t")
        local line_info = (m.start_line ~= m.end_line) and (m.start_line .. "-" .. m.end_line) or m.start_line
        table.insert(
          preview,
          string.format("  %d. %s:%s - %s", i, file_name, line_info, string.sub(m.annotation or "", 1, 30))
        )
      end
    end
    table.insert(preview, "")
  end

  table.insert(preview, "🎯 Actions:")
  table.insert(preview, "  • <Enter> - Delete this group")
  table.insert(preview, "  • <ESC> - Close picker")

  return preview
end

return M
