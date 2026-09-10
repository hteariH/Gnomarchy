return {
  {
    "shaunsingh/nord.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark",
      transparent = false,
    },
    config = function(_, opts)
      pcall(require, "nord")
      vim.cmd("colorscheme nord")
    end,
  },
}
