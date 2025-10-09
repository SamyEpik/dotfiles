-- lua/plugins/transparent.lua
return {
  {
    "xiyaowong/transparent.nvim",
    lazy = false, -- don't lazy-load (plugin author recommends this)
    config = function()
      -- Optional: make common popups/panels transparent too
      require("transparent").setup({
        extra_groups = { "NormalFloat", "NvimTreeNormal" },
      })
      -- Enable transparency on startup
      vim.cmd("TransparentEnable")
    end,
  },
}
