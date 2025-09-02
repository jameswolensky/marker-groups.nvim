---
title: Installation
---

## Using lazy.nvim

```lua
{
  "jameswolensky/marker-groups.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required
    -- Optional pickers:
    -- "ibhagwan/fzf-lua",
    -- "folke/snacks.nvim",
    -- "nvim-mini/mini.nvim",
  },
  config = function()
    require("marker-groups").setup({
      -- Your configuration here
    })
  end,
}
```

## Using packer.nvim

```lua
use {
  "jameswolensky/marker-groups.nvim",
  requires = {
    "nvim-lua/plenary.nvim", -- Required
    -- Optional: picker backends
    -- "ibhagwan/fzf-lua",
    -- "folke/snacks.nvim",
    -- "nvim-mini/mini.nvim",
  },
  config = function()
    require("marker-groups").setup()
  end,
}
```


