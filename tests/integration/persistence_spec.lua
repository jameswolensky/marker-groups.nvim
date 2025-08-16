local assert = require "luassert"

describe("marker persistence on edits", function()
  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    vim.cmd "enew"
    local lines = { "hello world", "second line", "third line" }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    local temp_file = "/tmp/test-marker-persist-" .. os.time() .. "-" .. math.random(1000, 9999) .. ".txt"
    vim.cmd("write " .. temp_file)
  end)

  after_each(function()
    local markers = require "marker-groups.markers"
    local current_markers = markers.get_current_buffer_markers()
    for _, m in ipairs(current_markers) do
      markers.delete_marker(m.id)
    end
  end)

  it("keeps a single-line marker after deleting a character on that line", function()
    local markers = require "marker-groups.markers"

    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    local add_result = markers.add_marker "persist test"
    assert.is_true(add_result.success)

    local before = markers.get_current_buffer_markers()
    assert.is_true(#before > 0)

    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_idx = cursor[1]
    local line_text = vim.api.nvim_buf_get_lines(0, line_idx - 1, line_idx, false)[1]
    local new_text = string.sub(line_text, 2)
    vim.api.nvim_buf_set_lines(0, line_idx - 1, line_idx, false, { new_text })

    local sync = markers.sync_extmarks(0)
    assert.is_true(sync.success)

    local after = markers.get_current_buffer_markers()
    assert.are.equal(#before, #after)

    local found
    for _, m in ipairs(after) do
      if m.annotation == "persist test" then
        found = m
        break
      end
    end
    assert.is_truthy(found)
    assert.are.equal(2, found.start_line)
    assert.are.equal(2, found.end_line)
  end)

  it("auto-saves JSON reflecting add/edit/delete marker and group ops", function()
    local state = require "marker-groups.state"
    local markers = require "marker-groups.markers"
    local persistence = require "marker-groups.persistence"

    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "error",
    }

    local function read_json()
      local data_file = vim.fn.stdpath "data" .. "/marker-groups/marker-groups.json"
      local f = io.open(data_file, "r")
      if not f then
        return nil
      end
      local s = f:read "*a"
      f:close()
      return s
    end

    pcall(function()
      os.remove(vim.fn.stdpath "data" .. "/marker-groups/marker-groups.json")
    end)

    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    local a1 = markers.add_marker "m1"
    assert.is_true(a1.success)

    vim.wait(100)
    local s1 = read_json()
    assert.is_truthy(s1)
    assert.is_truthy(s1:find '"default"')
    assert.is_truthy(s1:find '"annotation":"m1"')

    local mlist = markers.get_current_buffer_markers()
    local mid = mlist[#mlist].id
    local e1 = markers.edit_marker(mid, "m1-edit")
    assert.is_true(e1.success)
    vim.wait(100)
    local s2 = read_json()
    assert.is_truthy(s2:find '"annotation":"m1%-edit"')

    local d1 = markers.delete_marker(e1.value.id)
    assert.is_true(d1.success)
    vim.wait(100)
    local s3 = read_json()
    assert.is_falsy(s3:find '"annotation":"m1%-edit"')

    local groups = require "marker-groups.groups"
    local g1 = groups.create_group "autosave-test"
    assert.is_true(g1.success)
    groups.select_group "autosave-test"
    vim.wait(100)
    local s4 = read_json()
    assert.is_truthy(s4:find '"autosave%-test"')

    local gr = groups.rename_group("autosave-test", "autosave-renamed")
    assert.is_true(gr.success)
    vim.wait(100)
    local s5 = read_json()
    assert.is_falsy(s5:find '"autosave%-test"%s*:')
    assert.is_truthy(s5:find '"autosave%-renamed"%s*:')

    local gd = groups.delete_group("autosave-renamed", true)
    assert.is_true(gd.success)
    vim.wait(100)
    local s6 = read_json()
    assert.is_falsy(s6:find '"autosave%-renamed"%s*:')
  end)
end)
