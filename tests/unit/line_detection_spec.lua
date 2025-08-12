local assert = require "luassert"

describe("line and range detection (strict marks-based)", function()
  local markers
  local state
  local config

  local function setup_buffer(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local temp_file = "/tmp/test-line-detection-" .. math.random(1000, 9999) .. ".lua"
    vim.api.nvim_buf_set_name(buf, temp_file)
    vim.api.nvim_set_current_buf(buf)

    return buf, temp_file
  end

  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    markers = require "marker-groups.markers"
    state = require "marker-groups.state"
    config = require "marker-groups.config"

    state.initialize(config.get())
  end)

  after_each(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match "/tmp/test%-line%-detection%-" then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end)

  it("detects single-line by explicit range", function()
    setup_buffer { "A", "B", "C", "D", "E" }

    local res = markers.add_marker_range(3, 3, "single-visual")
    assert.is_true(res.success)

    local group = state.get_group "default"
    assert.are.equal(1, #group.markers)
    assert.are.equal(3, group.markers[1].start_line)
    assert.are.equal(3, group.markers[1].end_line)
  end)

  it("detects multi-line by explicit range", function()
    setup_buffer { "A", "B", "C", "D", "E" }

    local res = markers.add_marker_range(2, 4, "visual-multi")
    assert.is_true(res.success)

    local group = state.get_group "default"
    assert.are.equal(1, #group.markers)
    assert.are.equal(2, group.markers[1].start_line)
    assert.are.equal(4, group.markers[1].end_line)
  end)

  it("adds multiple explicit ranges consecutively (latest range respected)", function()
    setup_buffer { "A", "B", "C", "D", "E" }

    local r1 = markers.add_marker_range(1, 1, "first")
    assert.is_true(r1.success)

    local r2 = markers.add_marker_range(3, 5, "second")
    assert.is_true(r2.success)

    local group = state.get_group "default"
    assert.are.equal(2, #group.markers)
    assert.are.equal(3, group.markers[2].start_line)
    assert.are.equal(5, group.markers[2].end_line)
  end)

  it("charwise-like explicit range spans full lines", function()
    setup_buffer { "A", "B", "C", "D", "E" }
    local r = markers.add_marker_range(3, 4, "visual-char")
    assert.is_true(r.success)

    local group = state.get_group "default"
    assert.are.equal(1, #group.markers)
    assert.are.equal(3, group.markers[1].start_line)
    assert.are.equal(4, group.markers[1].end_line)
  end)

  it("reversed explicit range is normalized", function()
    setup_buffer { "A", "B", "C", "D", "E" }
    local res = markers.add_marker_range(4, 2, "visual-reversed")
    assert.is_true(res.success)

    local group = state.get_group "default"
    assert.are.equal(1, #group.markers)
    assert.are.equal(2, group.markers[1].start_line)
    assert.are.equal(4, group.markers[1].end_line)
  end)

  it("consecutive explicit ranges use the latest selection range", function()
    setup_buffer { "A", "B", "C", "D", "E", "F" }
    local r1 = markers.add_marker_range(1, 2, "first-visual")
    assert.is_true(r1.success)

    local r2 = markers.add_marker_range(4, 5, "second-visual")
    assert.is_true(r2.success)

    local group = state.get_group "default"
    assert.are.equal(2, #group.markers)
    assert.are.equal(1, group.markers[1].start_line)
    assert.are.equal(2, group.markers[1].end_line)
    assert.are.equal(4, group.markers[2].start_line)
    assert.are.equal(5, group.markers[2].end_line)
  end)

  it("explicit single-line results in single-line marker", function()
    setup_buffer { "A", "B", "C" }
    local res = markers.add_marker_range(2, 2, "visual-single")
    assert.is_true(res.success)

    local group = state.get_group "default"
    assert.are.equal(1, #group.markers)
    assert.are.equal(2, group.markers[1].start_line)
    assert.are.equal(2, group.markers[1].end_line)
  end)
end)
