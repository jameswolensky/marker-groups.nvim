local assert = require "luassert"

describe("extmark recreation and persistence", function()
  local markers, state

  before_each(function()
    local unique_dir = "/tmp/marker-groups-test-" .. os.time() .. "-" .. math.random(100000, 999999)
    require("marker-groups").setup {
      data_dir = unique_dir,
      log_level = "error",
    }

    markers = require "marker-groups.markers"
    state = require "marker-groups.state"

    vim.cmd "enew"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "l1",
      "l2",
      "l3",
      "l4",
      "l5",
      "l6",
      "l7",
    })
    local temp_path = "/tmp/test-extmark-recreate-" .. os.time() .. "-" .. math.random(1000, 9999) .. ".txt"
    vim.cmd("write " .. temp_path)
  end)

  after_each(function()
    pcall(function()
      vim.cmd "bwipeout!"
    end)
  end)

  it("keeps a multi-line marker after sync, save, and reload even if extmark id was stale", function()
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(buf)

    local add1 = markers.add_marker_range(1, 6, "multi")
    assert.is_true(add1.success)
    local add2 = markers.add_marker_range(7, 7, "single")
    assert.is_true(add2.success)

    local list_before = markers.list_markers(nil, { buffer_path = path })
    assert.are.equal(2, #list_before)
    local multi = nil
    for _, m in ipairs(list_before) do
      if m.start_line == 1 and m.end_line == 6 then
        multi = m
        break
      end
    end
    assert.is_truthy(multi)

    local upd = state.update_marker(multi.id, { extmark_id = 9999999 })
    assert.is_true(upd.success)

    local sync = markers.sync_extmarks(buf)
    assert.is_true(sync.success)

    local list_after_sync = markers.list_markers(nil, { buffer_path = path })
    assert.are.equal(2, #list_after_sync)
    local multi_after = nil
    for _, m in ipairs(list_after_sync) do
      if m.start_line == 1 and m.end_line == 6 then
        multi_after = m
        break
      end
    end
    assert.is_truthy(multi_after)

    local persistence = require "marker-groups.persistence"
    local saved = persistence.save()
    assert.is_true(saved.success)

    require("marker-groups").reload()

    markers = require "marker-groups.markers"
    state = require "marker-groups.state"

    local list_after_reload = markers.list_markers(nil, { buffer_path = path })
    assert.are.equal(2, #list_after_reload)
    local found_multi = false
    local found_single = false
    for _, m in ipairs(list_after_reload) do
      if m.start_line == 1 and m.end_line == 6 then
        found_multi = true
      end
      if m.start_line == 7 and m.end_line == 7 then
        found_single = true
      end
    end
    assert.is_true(found_multi)
    assert.is_true(found_single)
  end)
end)
