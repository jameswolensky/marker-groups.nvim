local assert = require "luassert"

describe("Configuration customization end-to-end", function()
  local config, state, drawer, vt

  before_each(function()
    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_config_test",
      signs = { marker = "★", multiline_start = "⟪", multiline_end = "⟫" },
      drawer_config = { width = 42, side = "left", border = "single", title_pos = "left" },
      context_lines = 4,
      max_annotation_display = 3,
      highlight_groups = {
        marker = "MGSpecMarker",
        annotation = "MGSpecAnnotation",
        context = "MGSpecContext",
        multiline_start = "MGSpecMLStart",
        multiline_end = "MGSpecMLEnd",
      },
      keymaps = { enabled = false },
      debug = true,
      log_level = "debug",
    }

    config = require "marker-groups.config"
    state = require "marker-groups.state"
    drawer = require "marker-groups.ui.drawer"
    vt = require "marker-groups.ui.virtual_text"

    state.initialize(config.get())
  end)

  it("applies core config values", function()
    assert.are.equal(42, config.get_value "drawer_config.width")
    assert.are.equal("left", config.get_value "drawer_config.side")
    assert.are.equal("single", config.get_value "drawer_config.border")
    assert.are.equal("left", config.get_value "drawer_config.title_pos")
    assert.are.equal(4, config.get_value "context_lines")
    assert.are.equal(3, config.get_value "max_annotation_display")
    assert.is_truthy(config.get_value("data_dir"):match "_mg_config_test$")
    assert.is_true(config.get_value "debug")
    assert.are.equal("debug", config.get_value "log_level")
    assert.is_false(config.get_value "keymaps.enabled")

    local signs = config.get_value "signs"
    assert.are.same({ marker = "★", multiline_start = "⟪", multiline_end = "⟫" }, signs)

    local hls = config.get_value "highlight_groups"
    assert.is_table(hls)
    assert.are.equal("MGSpecMarker", hls.marker)
    assert.are.equal("MGSpecAnnotation", hls.annotation)
    assert.are.equal("MGSpecContext", hls.context)
    assert.are.equal("MGSpecMLStart", hls.multiline_start)
    assert.are.equal("MGSpecMLEnd", hls.multiline_end)
  end)

  it("renders virtual text with custom signs and highlights", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line one", "line two", "line three" })
    local path = vim.fn.tempname()
    vim.api.nvim_buf_set_name(buf, path)

    local markers = require "marker-groups.markers"
    local m1 = state.add_marker { buffer_path = path, start_line = 2, end_line = 2, annotation = "abcdefghiJKLMNOP" }
    assert.is_true(m1.success)
    local m2 = state.add_marker { buffer_path = path, start_line = 1, end_line = 3, annotation = "multiline" }
    assert.is_true(m2.success)

    markers.refresh_extmarks(buf)
    vim.wait(50)

    local function hl_exists(name)
      local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
      return ok and type(hl) == "table"
    end
    assert.is_true(hl_exists "MGSpecMarker")
    assert.is_true(hl_exists "MGSpecAnnotation")
    assert.is_true(hl_exists "MGSpecContext")
    assert.is_true(hl_exists "MGSpecMLStart")
    assert.is_true(hl_exists "MGSpecMLEnd")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("drawer debug_info reflects configured drawer width/side", function()
    local info = drawer.debug_info()
    assert.is_table(info)
    local expected = math.min(42, math.floor(vim.o.columns * 0.5))
    assert.are.equal(expected, info.calculated_window.width)
    assert.are.equal("left", info.calculated_window.side)
    assert.are.equal("single", info.calculated_window.border)
    assert.are.equal("left", info.calculated_window.title_pos)
  end)

  it("keymaps can be enabled with custom prefix", function()
    local ok = config.update { keymaps = { enabled = true, prefix = "<leader>Q" } }
    assert.is_true(ok)

    local keymaps_mod = require "marker-groups.keymaps"
    assert.has_no.errors(function()
      keymaps_mod.setup()
    end)

    local maps = vim.api.nvim_get_keymap "n"
    local has_add = false
    local has_drawer = false
    for _, m in ipairs(maps) do
      if m.lhs == "<leader>Qa" then
        has_add = true
      end
      if m.lhs == "<leader>QV" then
        has_drawer = true
      end
    end
    assert.is_true(has_add)
    assert.is_true(has_drawer)
  end)

  it("persistence saves to configured data_dir", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x" })
    local path = vim.fn.tempname()
    vim.api.nvim_buf_set_name(buf, path)

    local st = require "marker-groups.state"
    local add = st.add_marker { buffer_path = path, start_line = 1, end_line = 1, annotation = "persist" }
    assert.is_true(add.success)

    local persistence = require "marker-groups.persistence"
    local save = persistence.save()
    assert.is_true(save.success)

    local dir = config.get_value "data_dir"
    local file = dir .. "/marker-groups.json"
    assert.is_true(vim.fn.filereadable(file) == 1)

    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
