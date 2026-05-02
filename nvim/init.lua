-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.filetype.add({
  extension = { uss = "css" },
})

vim.filetype.add({
  extension = {
    uxml = "xml",
  },
})
