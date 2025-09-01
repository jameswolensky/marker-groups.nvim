local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups.pickers.utils"] = nil
    end,
  },
}

T["get_filetype_from_path maps common extensions"] = function()
  local utils = require "marker-groups.pickers.utils"
  MiniTest.expect.equality("lua", utils.get_filetype_from_path "/tmp/file.lua")
  MiniTest.expect.equality("markdown", utils.get_filetype_from_path "README.md")
  MiniTest.expect.equality("text", utils.get_filetype_from_path "noext")
end

T["read_file_content reads from buffer if loaded, else filesystem"] = function()
  local utils = require "marker-groups.pickers.utils"
  local tmp = vim.fn.tempname()
  -- Write a file
  vim.fn.writefile({ "line1", "line2", "line3" }, tmp)

  -- Not loaded buffer case => filesystem
  local lines = utils.read_file_content(tmp)
  MiniTest.expect.equality(3, #lines)

  -- Load buffer and modify to ensure buffer path wins
  vim.cmd("edit " .. vim.fn.fnameescape(tmp))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "buf1", "buf2" })
  local buf_lines = utils.read_file_content(tmp)
  MiniTest.expect.equality(2, #buf_lines)
end

T["generate_marker_preview returns content and filetype"] = function()
  local utils = require "marker-groups.pickers.utils"
  local tmp = vim.fn.tempname() .. ".lua"
  vim.fn.writefile({ "local a = 1", "local b = 2", "return a + b" }, tmp)
  local marker = {
    buffer_path = tmp,
    start_line = 2,
    end_line = 2,
    annotation = "test",
  }
  local preview = utils.generate_marker_preview(marker)
  MiniTest.expect.equality("table", type(preview))
  MiniTest.expect.equality("table", type(preview.content))
  MiniTest.expect.equality("lua", preview.filetype)
  MiniTest.expect.equality(true, #preview.content > 0)
end

return T
