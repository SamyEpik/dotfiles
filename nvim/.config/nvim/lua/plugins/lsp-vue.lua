return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Volar
        vue_ls = {
          filetypes = { "vue" },
        },

        -- TypeScript/JavaScript LSP (must exist, but should NOT attach to vue)
        ts_ls = { filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" } },
      },
    },
  },
}
