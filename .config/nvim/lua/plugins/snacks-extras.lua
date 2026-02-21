return {
  {
    "snacks.nvim",
    opts = {
      scroll = {
        enabled = true,
        animate = {
          duration = { step = 8, total = 250 },
          easing = "outCubic",
        },
        animate_repeat = {
          delay = 80,
          duration = { step = 5, total = 50 },
          easing = "linear",
        },
      },
    },
  },
}
