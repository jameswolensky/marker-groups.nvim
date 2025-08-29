-- Headless repro for Snacks groups Enter selection mapping
for k, _ in pairs(package.loaded) do
  if k:match "^marker%-groups" then
    package.loaded[k] = nil
  end
end

require("marker-groups").setup {
  keymaps = { enabled = false },
  picker = { provider = "snacks" },
}

-- stub snacks to capture opts
package.loaded["snacks"] = {
  picker = {
    pick = function(opts)
      local has_handler = false
      if opts and opts.keys then
        for _, k in ipairs(opts.keys) do
          if k[1] == "<CR>" and type(k[2]) == "function" then
            has_handler = true
          end
        end
      end
      if has_handler then
        print "ENTER_HANDLER:yes"
      else
        print "ENTER_HANDLER:no"
      end
    end,
  },
}

-- ensure there is at least one additional group to list
local groups = require "marker-groups.groups"
groups.create_group "g1"

-- invoke the picker
require("marker-groups.picker").show_groups()
