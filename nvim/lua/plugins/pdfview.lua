return {
  {
    "basola21/PDFview",
    lazy = false,
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      local map = vim.keymap.set
      map("n", "<leader>jj", "<cmd>lua require('pdfview.renderer').next_page()<CR>", { desc = "PDFview: Next page" })
      map(
        "n",
        "<leader>kk",
        "<cmd>lua require('pdfview.renderer').previous_page()<CR>",
        { desc = "PDFview: Previous page" }
      )
    end,
  },
}
