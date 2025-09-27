-- Override catppuccin configuration for terminal transparency
-- This enables Ghostty's beautiful transparency and blur effects in Neovim
return {
  "catppuccin/nvim",
  opts = {
    transparent_background = true,
    custom_highlights = function(colors)
      return {
        -- Floating windows (Lazy, Mason, etc.)
        NormalFloat = { bg = "NONE" },
        FloatBorder = { bg = "NONE" },
        FloatTitle = { bg = "NONE" },

        -- Telescope
        TelescopeNormal = { bg = "NONE" },
        TelescopeBorder = { bg = "NONE" },
        TelescopeTitle = { bg = "NONE" },

        -- Completion menu
        Pmenu = { bg = "NONE" },
        PmenuBorder = { bg = "NONE" },

        -- Lazy UI specifically
        LazyNormal = { bg = "NONE" },

        -- Any other popup/float backgrounds
        WhichKeyFloat = { bg = "NONE" },
        NotifyBackground = { bg = "NONE" },
      }
    end,
  },
}