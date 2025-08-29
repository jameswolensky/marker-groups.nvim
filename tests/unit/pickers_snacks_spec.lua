local assert = require "luassert"

describe("snacks picker adapter", function()
  it("uses state.get_group_names() to build items and calls picker.pick", function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup { keymaps = { enabled = false } }
    local config = require "marker-groups.config"
    local state = require "marker-groups.state"
    state.initialize(config.get())

    local groups = require "marker-groups.groups"
    groups.create_group "a"
    groups.create_group "b"

    -- stub snacks API to only expose .pick (no .open)
    local pick_called = false
    package.loaded["snacks"] = {
      picker = {
        pick = function(opts)
          pick_called = true
          assert.is_table(opts)
          assert.is_table(opts.items)
          -- items must be tables with a text field
          local texts = {}
          for _, it in ipairs(opts.items) do
            assert.is_table(it)
            assert.is_string(it.text)
            texts[#texts + 1] = it.text
          end
          assert.is_true(vim.tbl_contains(texts, "default"))
          assert.is_true(vim.tbl_contains(texts, "a"))
          assert.is_true(vim.tbl_contains(texts, "b"))
          -- confirm must exist and be callable
          assert.is_function(opts.confirm)
        end,
      },
    }

    local snacks_adapter = require "marker-groups.pickers.snacks"
    assert.has_no.errors(function()
      snacks_adapter.show_groups {}
    end)
    assert.is_true(pick_called)
  end)

  it("binds <CR> to confirm selection of a group", function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup { keymaps = { enabled = false } }

    local confirm_bound = false
    package.loaded["snacks"] = {
      picker = {
        pick = function(opts)
          -- Require an explicit handler for <CR> so global mappings can't break confirm
          assert.is_table(opts.keys)
          local handler
          for _, k in ipairs(opts.keys) do
            if k[1] == "<CR>" and type(k[2]) == "function" then
              handler = k[2]
            end
          end
          assert.is_function(handler)
          -- Simulate pressing enter by calling the handler with a fake picker
          local picked
          local fake_picker = {
            current = function()
              return { text = "g1", value = "g1" }
            end,
            close = function()
              picked = true
            end,
          }
          -- ensure handler uses the selection
          handler(fake_picker)
          confirm_bound = picked == true
        end,
      },
    }

    local snacks_adapter = require "marker-groups.pickers.snacks"
    snacks_adapter.show_groups {}
    assert.is_true(confirm_bound)
  end)

  it("confirm handler selects group via groups.select_group", function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup { keymaps = { enabled = false } }
    local config = require "marker-groups.config"
    local state = require "marker-groups.state"
    state.initialize(config.get())

    local select_called, selected_name = false, nil
    -- monkey-patch groups.select_group
    package.loaded["marker-groups.groups"] = setmetatable({}, {
      __index = function(_, k)
        if k == "select_group" then
          return function(name)
            select_called = true
            selected_name = name
          end
        end
        return function() end
      end,
    })

    package.loaded["snacks"] = {
      picker = {
        pick = function(opts)
          -- simulate confirming an item
          opts.confirm({}, { text = "group-x", value = "group-x" })
        end,
      },
    }

    local snacks_adapter = require "marker-groups.pickers.snacks"
    snacks_adapter.show_groups {}
    assert.is_true(select_called)
    assert.equals("group-x", selected_name)
  end)

  it("show_markers provides item tables and jumps on confirm", function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup { keymaps = { enabled = false } }
    local config = require "marker-groups.config"
    local state = require "marker-groups.state"
    state.initialize(config.get())

    -- prepare group with markers
    local group = {
      name = "g",
      markers = {
        { buffer_path = "/tmp/a.txt", start_line = 3, end_line = 3, annotation = "a" },
      },
    }
    package.loaded["marker-groups.state"] = setmetatable({}, {
      __index = function(_, k)
        if k == "get_group" then
          return function()
            return group
          end
        end
        return function() end
      end,
    })

    local cmd_called, cursor_called = nil, nil
    vim.cmd = function(cmd)
      cmd_called = cmd
    end
    vim.api.nvim_win_set_cursor = function(_, pos)
      cursor_called = pos
    end

    package.loaded["snacks"] = {
      picker = {
        pick = function(opts)
          -- items should be tables with text
          assert.is_table(opts.items)
          assert.is_table(opts.items[1])
          assert.is_string(opts.items[1].text)
          -- simulate confirm
          opts.confirm({}, opts.items[1])
        end,
      },
    }

    local snacks_adapter = require "marker-groups.pickers.snacks"
    snacks_adapter.show_markers {}
    assert.matches("edit /tmp/a.txt", cmd_called)
    assert.same({ 3, 0 }, cursor_called)
  end)
end)
