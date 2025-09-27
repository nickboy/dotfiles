-- Override catppuccin configuration for terminal transparency
-- This enables Ghostty's beautiful transparency and blur effects in Neovim
return {
  "catppuccin/nvim",
  opts = {
    transparent_background = true,
    -- Catppuccin's built-in option to make code blocks stand out while keeping transparency
    show_end_of_buffer = true,
    term_colors = true,
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


        -- Line numbers - make them more visible with brighter colors
        LineNr = { bg = "NONE", fg = colors.overlay1, bold = true },
        LineNrAbove = { bg = "NONE", fg = colors.overlay0, bold = true },
        LineNrBelow = { bg = "NONE", fg = colors.overlay0, bold = true },
        CursorLineNr = { bg = "NONE", fg = colors.yellow, bold = true },

        -- Sign column (for git signs, diagnostics)
        SignColumn = { bg = "NONE" },
        GitSignsAdd = { bg = "NONE", fg = colors.green, bold = true },
        GitSignsChange = { bg = "NONE", fg = colors.yellow, bold = true },
        GitSignsDelete = { bg = "NONE", fg = colors.red, bold = true },
      }
    end,
  },
}