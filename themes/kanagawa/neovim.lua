return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "wave",
      transparent = false,
    },
    config = function(_, opts)
      pcall(require, "kanagawa")
      vim.cmd("colorscheme kanagawa")
    end,
  },
}
