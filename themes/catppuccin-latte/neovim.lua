return {
  {
    "catppuccin/nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "latte",
      transparent = false,
    },
    config = function(_, opts)
      pcall(require, "catppuccin")
      vim.cmd("colorscheme catppuccin")
    end,
  },
}
