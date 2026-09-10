return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark",
      transparent = false,
    },
    config = function(_, opts)
      pcall(require, "gruvbox")
      vim.cmd("colorscheme gruvbox")
    end,
  },
}
