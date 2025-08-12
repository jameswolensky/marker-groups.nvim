---
title: Installation
---

## Using lazy.nvim

```lua
{
  "jameswolensky/marker-groups.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required
    "nvim-telescope/telescope.nvim", -- Optional: for fuzzy search
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
    "nvim-telescope/telescope.nvim", -- Optional
  },
  config = function()
    require("marker-groups").setup()
  end,
}
```


