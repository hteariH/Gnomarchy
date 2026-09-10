return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = false,
    },
    config = function(_, opts)
      pcall(require, "tokyonight")
      vim.cmd("colorscheme tokyonight")
    end,
  },
}
