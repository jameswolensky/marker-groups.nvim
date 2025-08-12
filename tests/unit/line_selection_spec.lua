local assert = require "luassert"

describe("line_selection.make_range", function()
  before_each(function()
    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_marker_groups_ls_test",
      keymaps = { enabled = false },
      log_level = "error",
    }
  end)

  it("returns cursor line for normal mode", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    local ls = require "marker-groups.line_selection"
    local r = ls.make_range()
    assert.are.same({ lstart = 2, lend = 2 }, { lstart = r.lstart, lend = r.lend })
  end)

  it("returns visual range for visual mode", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d" })
    vim.api.nvim_set_current_buf(buf)

    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd "normal! vjj"

    local ls = require "marker-groups.line_selection"
    local r = ls.make_range()
    assert.truthy(r.lstart >= 2 and r.lend >= r.lstart)
  end)
end)
