local assert = require "luassert"

describe("telescope headless integration", function()
  local state
  local groups
  local markers

  before_each(function()
    package.loaded["telescope"] = nil
    package.loaded["marker-groups.telescope"] = nil

    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_telescope_test",
      keymaps = { enabled = false },
      picker = { provider = "telescope" },
    }

    local config = require "marker-groups.config"
    state = require "marker-groups.state"
    groups = require "marker-groups.groups"
    markers = require "marker-groups.markers"
    state.initialize(config.get())

    groups.create_group "g1"
    groups.create_group "g2"
  end)

  it("lists group names and selects with Enter", function()
    -- Provide complete stubs for telescope modules
    local captured_results
    local captured_handler

    package.loaded["telescope"] = { _version = "test" }
    package.loaded["telescope.finders"] = {
      new_table = function(tbl)
        return tbl
      end,
    }
    package.loaded["telescope.config"] = {
      values = {
        generic_sorter = function(_)
          return function() end
        end,
      },
    }
    package.loaded["telescope.previewers"] = {
      new_buffer_previewer = function(_)
        return {}
      end,
    }
    package.loaded["telescope.actions.state"] = {
      get_selected_entry = function()
        return { value = { name = "g2", marker_count = 0 } }
      end,
    }
    package.loaded["telescope.actions"] = {
      select_default = {
        replace = function(_, handler)
          captured_handler = handler
        end,
      },
      close = function(_) end,
    }
    package.loaded["telescope.pickers"] = {
      new = function(opts, spec)
        assert.is_table(spec)
        assert.is_table(spec.finder)
        captured_results = spec.finder.results
        -- Trigger attach_mappings so our actions.select_default:replace gets the handler
        if spec.attach_mappings then
          spec.attach_mappings(0, function() end)
        end
        return { find = function() end }
      end,
    }

    local telescope_mod = require "marker-groups.telescope"
    telescope_mod.show_groups {}

    -- Ensure groups were listed
    local names = vim.tbl_map(function(e)
      return e.name
    end, captured_results or {})
    table.sort(names)
    assert.same({ "default", "g1", "g2" }, names)

    -- Simulate pressing Enter
    assert.is_function(captured_handler)
    captured_handler()

    local active = state.get_active_group()
    assert.equals("g2", active)
  end)

  it("shows markers for active group", function()
    -- Prepare a temp file and add a marker to g2
    local tmp = vim.fn.tempname() .. ".txt"
    vim.fn.writefile({ "one", "two", "three" }, tmp)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp))
    groups.select_group "g2"
    local add_res = markers.add_marker("tel test", "g2")
    assert.is_true(add_res.success)

    package.loaded["telescope"] = { _version = "test" }
    package.loaded["telescope.finders"] = {
      new_table = function(tbl)
        return tbl
      end,
    }
    package.loaded["telescope.config"] = { values = {
      generic_sorter = function(_)
        return function() end
      end,
    } }
    package.loaded["telescope.previewers"] = {
      new_buffer_previewer = function(_)
        return {}
      end,
    }
    local telescope_mod = require "marker-groups.telescope"

    local pickers = require "telescope.pickers"
    local old_new = pickers.new
    local displayed
    pickers.new = function(opts, spec)
      assert.is_table(spec)
      assert.is_table(spec.finder)
      displayed = spec.finder.results
      return { find = function() end }
    end

    telescope_mod.show_markers {}
    assert.is_true(#displayed >= 1)
    pickers.new = old_new
  end)

  it("deletes selected group via vim.ui confirmation flow", function()
    -- Create and then delete g2 using UI flow
    assert.is_truthy(state.get_group "g2")
    local ui_calls = 0
    local original_ui_select = vim.ui.select
    vim.ui.select = function(items, opts, cb)
      ui_calls = ui_calls + 1
      if ui_calls == 1 then
        local choice
        for _, it in ipairs(items) do
          if it:match "^g2 " then
            choice = it
            break
          end
        end
        cb(choice)
      else
        cb "Yes"
      end
    end

    local groups_mod = require "marker-groups.groups"
    local res = groups_mod.select_group_for_deletion {}
    assert.is_true(res.success)
    vim.ui.select = original_ui_select
    assert.is_nil(state.get_group "g2")
  end)
end)
