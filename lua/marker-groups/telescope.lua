local M = {}

local feedback = require "marker-groups.feedback"

local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  function M.show_groups()
    feedback.warning(
      "Telescope Integration",
      "Telescope is not available. Please install telescope.nvim to use this feature."
    )
  end

  function M.show_markers()
    feedback.warning(
      "Telescope Integration",
      "Telescope is not available. Please install telescope.nvim to use this feature."
    )
  end

  function M.is_available()
    return false
  end

  function M.get_status()
    return {
      available = false,
      reason = "telescope.nvim is not installed",
      suggestions = {
        "Install Telescope with your package manager:",
        "  Lazy: { 'nvim-telescope/telescope.nvim' }",
        "  Packer: use 'nvim-telescope/telescope.nvim'",
      },
    }
  end

  return M
end

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local previewers = require "telescope.previewers"

local state = require "marker-groups.state"
local groups = require "marker-groups.groups"
local config = require "marker-groups.config"

function M.is_available()
  return true
end

function M.get_status()
  local telescope_version = "unknown"
  if telescope and telescope._version then
    telescope_version = telescope._version
  end

  return {
    available = true,
    version = telescope_version,
    pickers_available = {
      groups = true,
      markers = true,
    },
  }
end

local function format_date(timestamp)
  if not timestamp then
    return "Unknown"
  end
  return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function relative_time(timestamp)
  if not timestamp then
    return "unknown time"
  end

  local now = os.time()
  local diff = now - timestamp

  if diff < 60 then
    return "just now"
  elseif diff < 3600 then
    local minutes = math.floor(diff / 60)
    return minutes .. " minute" .. (minutes == 1 and "" or "s") .. " ago"
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return hours .. " hour" .. (hours == 1 and "" or "s") .. " ago"
  else
    local days = math.floor(diff / 86400)
    return days .. " day" .. (days == 1 and "" or "s") .. " ago"
  end
end

local function make_group_entry(group)
  local display =
    string.format("%-20s %3d markers  %s", group.name, group.marker_count, relative_time(group.modified_at))

  if group.is_active then
    display = "* " .. display
  else
    display = "  " .. display
  end

  return {
    value = group,
    display = display,
    ordinal = group.name .. " " .. tostring(group.marker_count),
  }
end

local function make_marker_entry(marker)
  local file_name = vim.fn.fnamemodify(marker.buffer_path, ":t")
  local line_info = marker.start_line

  if marker.start_line ~= marker.end_line then
    line_info = marker.start_line .. "-" .. marker.end_line
  end

  local annotation = marker.annotation
  if string.len(annotation) > 40 then
    annotation = string.sub(annotation, 1, 37) .. "..."
  end

  local display = string.format("%-25s:%4s  %s", file_name, tostring(line_info), annotation)

  return {
    value = marker,
    display = display,
    ordinal = file_name .. ":" .. tostring(line_info) .. " " .. marker.annotation,
  }
end

function M.show_groups(opts)
  opts = opts or {}

  local state_data = state.get_state()
  if not state_data or not state_data.marker_groups then
    feedback.warning("Telescope Groups", "No groups available")
    return
  end

  local active_group = state.get_active_group()

  local group_array = {}
  for name, group in pairs(state_data.marker_groups) do
    table.insert(group_array, {
      name = name,
      marker_count = #group.markers,
      created_at = group.created_at,
      modified_at = group.modified_at,
      is_active = (name == active_group),
    })
  end

  table.sort(group_array, function(a, b)
    if a.is_active ~= b.is_active then
      return a.is_active
    end
    return a.name < b.name
  end)

  if #group_array == 0 then
    feedback.warning("Telescope Groups", "No groups found")
    return
  end

  pickers
    .new(opts, {
      prompt_title = "Marker Groups",
      finder = finders.new_table {
        results = group_array,
        entry_maker = make_group_entry,
      },
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer {
        title = "Group Info",
        define_preview = function(self, entry, status)
          local group = entry.value
          local group_data = state_data.marker_groups[group.name]

          local preview_text = {
            "📁 Group: " .. group.name,
            "═══════════════════════════════════",
            "",
            "📊 Statistics:",
            "  • Markers: " .. group.marker_count,
            "  • Created: " .. format_date(group.created_at),
            "  • Modified: " .. format_date(group.modified_at),
            "  • Age: " .. relative_time(group.created_at),
            "",
          }

          if group.is_active then
            table.insert(preview_text, "✨ This is the active group")
            table.insert(preview_text, "")
          end

          if group.marker_count > 0 and group_data and group_data.markers then
            table.insert(preview_text, "📌 Recent Markers:")

            local marker_count = math.min(5, group.marker_count)
            for i = 1, marker_count do
              local marker = group_data.markers[i]
              if marker then
                local file_name = vim.fn.fnamemodify(marker.buffer_path, ":t")
                local line_info = marker.start_line
                if marker.start_line ~= marker.end_line then
                  line_info = marker.start_line .. "-" .. marker.end_line
                end

                table.insert(
                  preview_text,
                  string.format("  %d. %s:%s - %s", i, file_name, line_info, string.sub(marker.annotation, 1, 30))
                )
              end
            end

            if group.marker_count > 5 then
              table.insert(preview_text, "  ... and " .. (group.marker_count - 5) .. " more")
            end
          else
            table.insert(preview_text, "📝 No markers in this group")
          end

          table.insert(preview_text, "")
          table.insert(preview_text, "🎯 Press <Enter> to select this group")

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_text)
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection then
            local group_name = selection.value.name
            local result = groups.select_group(group_name)

            if result.success then
              feedback.success(
                "Telescope Groups",
                "Selected group: " .. group_name .. " (" .. selection.value.marker_count .. " markers)"
              )
            else
              feedback.error("Telescope Groups", "Failed to select group: " .. result.error)
            end
          end
        end)

        return true
      end,
    })
    :find()
end

function M.show_markers(opts)
  opts = opts or {}

  local active_group = state.get_active_group()
  local group = state.get_group(active_group)

  if not group then
    feedback.warning("Telescope Markers", "No active group found")
    return
  end

  if not group.markers or #group.markers == 0 then
    feedback.warning("Telescope Markers", "No markers in group: " .. active_group)
    return
  end

  pickers
    .new(opts, {
      prompt_title = "Markers: " .. active_group,
      finder = finders.new_table {
        results = group.markers,
        entry_maker = make_marker_entry,
      },
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer {
        title = "Marker Preview",
        define_preview = function(self, entry, status)
          local marker = entry.value

          local file_lines = {}
          local file_content_available = false

          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
              local buf_name = vim.api.nvim_buf_get_name(buf)
              if buf_name == marker.buffer_path then
                file_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                file_content_available = true
                break
              end
            end
          end

          if not file_content_available then
            local file = io.open(marker.buffer_path, "r")
            if file then
              for line in file:lines() do
                table.insert(file_lines, line)
              end
              file:close()
              file_content_available = true
            end
          end

          local file_extension = marker.buffer_path:match "%.([^%.]+)$"
          if file_extension then
            local drawer = require "marker-groups.ui.drawer"
            if drawer and drawer.get_filetype_from_path then
              local filetype = drawer.get_filetype_from_path(marker.buffer_path)
              vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", filetype)
            else
              local ft_map = {
                lua = "lua",
                js = "javascript",
                ts = "typescript",
                py = "python",
                rb = "ruby",
                go = "go",
                rs = "rust",
                c = "c",
                cpp = "cpp",
                java = "java",
                php = "php",
                sh = "bash",
                vim = "vim",
                json = "json",
                yaml = "yaml",
                md = "markdown",
                html = "html",
                css = "css",
              }
              local filetype = ft_map[file_extension] or "text"
              vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", filetype)
            end
          end

          local preview_text = {
            "📍 " .. vim.fn.fnamemodify(marker.buffer_path, ":t"),
            "═══════════════════════════════════",
            "",
            "📂 File: " .. marker.buffer_path,
            "📏 Lines: "
              .. marker.start_line
              .. (marker.start_line ~= marker.end_line and " - " .. marker.end_line or ""),
            "💬 Annotation: " .. marker.annotation,
          }

          if marker.timestamp then
            table.insert(preview_text, "🕒 Created: " .. format_date(marker.timestamp))
          end

          table.insert(preview_text, "")
          table.insert(preview_text, "📝 Code Context:")
          table.insert(preview_text, string.rep("─", 40))

          if file_content_available and #file_lines > 0 then
            local context_lines = config.get_value("context_lines", 2)
            local context_start = math.max(1, marker.start_line - context_lines)
            local context_end = math.min(#file_lines, marker.end_line + context_lines)

            for i = context_start, context_end do
              local is_marker_line = i >= marker.start_line and i <= marker.end_line
              local prefix = is_marker_line and "► " or "  "

              local line_num = string.format("%4d", i)
              local line_content = file_lines[i] or ""

              if string.len(line_content) > 80 then
                line_content = string.sub(line_content, 1, 77) .. "..."
              end

              table.insert(preview_text, prefix .. line_num .. ": " .. line_content)
            end
          else
            table.insert(preview_text, "  ⚠️  Could not read file content")
            table.insert(preview_text, "  File may not exist or is not readable")
          end

          table.insert(preview_text, "")
          table.insert(preview_text, string.rep("─", 40))
          table.insert(preview_text, "🎯 Press <Enter> to jump to this marker")

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_text)
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection then
            local marker = selection.value

            if vim.fn.filereadable(marker.buffer_path) == 0 then
              feedback.error("Telescope Markers", "File not found: " .. marker.buffer_path)
              return
            end

            local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(marker.buffer_path))
            if not ok then
              feedback.error("Telescope Markers", "Failed to open file: " .. tostring(err))
              return
            end

            local line_count = vim.api.nvim_buf_line_count(0)
            if marker.start_line > line_count then
              feedback.warning("Telescope Markers", "Line number exceeds file length")
              vim.api.nvim_win_set_cursor(0, { line_count, 0 })
            else
              vim.api.nvim_win_set_cursor(0, { marker.start_line, 0 })
            end

            vim.cmd "normal! zz"

            local file_name = vim.fn.fnamemodify(marker.buffer_path, ":t")
            feedback.success(
              "Telescope Markers",
              string.format("Jumped to %s:%d - %s", file_name, marker.start_line, marker.annotation)
            )
          end
        end)

        return true
      end,
    })
    :find()
end

return M
