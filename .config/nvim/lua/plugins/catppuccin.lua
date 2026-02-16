return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = true,
      show_end_of_buffer = true,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
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

          -- Lazy UI
          LazyNormal = { bg = "NONE" },

          -- Other popups/floats
          WhichKeyFloat = { bg = "NONE" },
          NotifyBackground = { bg = "NONE" },

          -- Line numbers
          LineNr = { bg = "NONE", fg = colors.overlay1, bold = true },
          LineNrAbove = { bg = "NONE", fg = colors.overlay0, bold = true },
          LineNrBelow = { bg = "NONE", fg = colors.overlay0, bold = true },
          CursorLineNr = { bg = "NONE", fg = colors.yellow, bold = true },

          -- Sign column (git signs, diagnostics)
          SignColumn = { bg = "NONE" },
          GitSignsAdd = { bg = "NONE", fg = colors.green, bold = true },
          GitSignsChange = { bg = "NONE", fg = colors.yellow, bold = true },
          GitSignsDelete = { bg = "NONE", fg = colors.red, bold = true },
        }
      end,
      integrations = {
        cmp = true,
        gitsigns = true,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        telescope = {
          enabled = true,
          style = "nvchad",
        },
        which_key = true,
        dashboard = true,
        neogit = true,
        markdown = true,
        noice = true,
        hop = true,
        illuminate = {
          enabled = true,
          lsp = false,
        },
        lsp_trouble = true,
        mason = true,
        neotest = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        semantic_tokens = true,
        treesitter_context = true,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
