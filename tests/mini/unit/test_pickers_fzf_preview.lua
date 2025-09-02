local MiniTest = require "mini.test"

local T = MiniTest.new_set()

T["fzf-lua preview handles string and table selections without builtin previewer"] = function()
  local called = false
  local has_builtin = false
  local preview_is_func = false
  local preview_nonempty1 = false
  local preview_nonempty2 = false

  package.loaded["fzf-lua"] = {
    fzf_exec = function(items, opts)
      called = true
      has_builtin = opts and opts.previewer == "builtin"
      if has_builtin then
        error "builtin previewer used"
      end
      preview_is_func = type(opts and opts.preview) == "function"
      if preview_is_func and items and #items > 0 then
        local d = items[1]
        local ok1, res1 = pcall(opts.preview, { d })
        local ok2, res2 = pcall(opts.preview, d)
        preview_nonempty1 = ok1 and type(res1) == "string" and #res1 > 0
        preview_nonempty2 = ok2 and type(res2) == "string" and #res2 > 0
      end
      return true
    end,
  }

  require("marker-groups.groups").create_group "dev"
  package.loaded["marker-groups.pickers.fzf_lua"] = nil
  require("marker-groups.pickers.fzf_lua").show_groups()

  assert(called == true, "fzf_exec was not called")
  assert(has_builtin == false, "builtin previewer should not be set")
  assert(preview_is_func == true, "preview should be a function")
  assert(preview_nonempty1 == true, "preview must be non-empty for table selection")
  assert(preview_nonempty2 == true, "preview must be non-empty for string selection")
end

return T
