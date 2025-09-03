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

local function _extract_marker_context_lines(file_lines, marker, context_lines, max_width)
  local context = {}
  if not file_lines or #file_lines == 0 then
    table.insert(context, " │ [File not found or empty]")
    return context
  end

  local start_line = math.max(1, tonumber(marker.start_line) or 1)
  local end_line = tonumber(marker.end_line) or start_line
  local ctx_start = math.max(1, start_line - (context_lines or 2))
  local ctx_end = math.min(#file_lines, end_line + (context_lines or 2))

  local max_line_num = ctx_end
  local line_num_width = #tostring(max_line_num)

  for ln = ctx_start, ctx_end do
    local is_marker_line = ln >= start_line and ln <= end_line
    local prefix = is_marker_line and " ► " or " │ "

    local line_num_str = string.format("%" .. line_num_width .. "d", ln)
    local content = file_lines[ln] or ""

    if max_width and max_width > 0 then
      local available = max_width - #prefix - line_num_width - 3
      if available > 3 and #content > available then
        content = string.sub(content, 1, available - 3) .. "..."
      end
    end

    table.insert(context, prefix .. line_num_str .. ": " .. content)
  end

  return context
end

function M.generate_group_markers_code_preview(group_name, opts)
  opts = opts or {}
  local state = require "marker-groups.state"
  local ok_cfg, cfg = pcall(require, "marker-groups.config")

  local group = group_name and state.get_group(group_name) or nil
  local markers = (group and group.markers) or {}

  local context_lines = (ok_cfg and cfg.get_value and cfg.get_value("context_lines", 2)) or 2
  local border_width = math.max(10, tonumber(opts.max_width) or 70)

  local out = {}
  local count = #markers
  local noun = (count == 1) and "marker" or "markers"
  table.insert(out, string.format("📁 Group: %s (%d %s)", tostring(group_name or "unknown"), count, noun))
  table.insert(out, string.rep("═", 80))
  table.insert(out, "")

  if count == 0 then
    table.insert(out, "No markers in group")
    return { content = out, filetype = "text" }
  end

  for i, m in ipairs(markers) do
    local start_line = tonumber(m.start_line) or 1
    local end_line = tonumber(m.end_line) or start_line
    local range = (start_line == end_line) and tostring(start_line) or (start_line .. "-" .. end_line)
    table.insert(out, string.format("📍 %s:%s", vim.fn.fnamemodify(m.buffer_path or "", ":t"), range))
    table.insert(out, string.format("   %s", tostring(m.buffer_path or "")))

    table.insert(out, "   ┌" .. string.rep("─", border_width) .. "┐")
    local file_lines = M.read_file_content(m.buffer_path or "")
    local ctx_lines = _extract_marker_context_lines(file_lines, m, context_lines, border_width)
    for _, line in ipairs(ctx_lines) do
      table.insert(out, "   " .. line)
    end
    table.insert(out, "   └" .. string.rep("─", border_width) .. "┘")

    local annotation = tostring(m.annotation or "")
    if annotation:find "\n" then
      local first = true
      for line in (annotation .. "\n"):gmatch "(.-)\n" do
        if first then
          table.insert(out, "   💬 " .. line)
          first = false
        else
          table.insert(out, "      " .. line)
        end
      end
    else
      table.insert(out, "   💬 " .. annotation)
    end

    if m.timestamp then
      local time_str = os.date("%Y-%m-%d %H:%M", m.timestamp)
      table.insert(out, "   🕒 " .. time_str)
    end

    if i < #markers then
      table.insert(out, "")
      table.insert(out, string.rep("─", 80))
      table.insert(out, "")
    end
  end

  return { content = out, filetype = "text" }
end

function M.filter_groups_for_action(groups_info, opts)
  opts = opts or {}
  local action = opts.action
  if action ~= "delete" or opts.force then
    return groups_info
  end
  local filtered = {}
  for _, info in ipairs(groups_info or {}) do
    if info.name ~= "default" then
      table.insert(filtered, info)
    end
  end
  return filtered
end

function M.empty_groups_message(opts)
  local action = opts and opts.action or nil
  if action == "delete" then
    return "No groups available to delete"
  end
  return "No marker groups available"
end

return M
