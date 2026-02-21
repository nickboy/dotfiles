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

          -- Tab line
          TabLine = { bg = "NONE" },

          -- Status line
          StatusLine = { bg = "NONE" },
          StatusLineNC = { bg = "NONE" },
        }
      end,
      integrations = {
        lualine = {
          all = function(colors)
            return {
              normal = {
                a = { bg = "NONE", fg = colors.blue, gui = "bold" },
                b = { bg = "NONE", fg = colors.blue },
                c = { bg = "NONE", fg = colors.text },
              },
              insert = {
                a = { bg = "NONE", fg = colors.green, gui = "bold" },
                b = { bg = "NONE", fg = colors.green },
                c = { bg = "NONE", fg = colors.text },
              },
              terminal = {
                a = { bg = "NONE", fg = colors.green, gui = "bold" },
                b = { bg = "NONE", fg = colors.green },
                c = { bg = "NONE", fg = colors.text },
              },
              command = {
                a = { bg = "NONE", fg = colors.peach, gui = "bold" },
                b = { bg = "NONE", fg = colors.peach },
                c = { bg = "NONE", fg = colors.text },
              },
              visual = {
                a = { bg = "NONE", fg = colors.mauve, gui = "bold" },
                b = { bg = "NONE", fg = colors.mauve },
                c = { bg = "NONE", fg = colors.text },
              },
              replace = {
                a = { bg = "NONE", fg = colors.red, gui = "bold" },
                b = { bg = "NONE", fg = colors.red },
                c = { bg = "NONE", fg = colors.text },
              },
              inactive = {
                a = { bg = "NONE", fg = colors.overlay0 },
                b = { bg = "NONE", fg = colors.overlay0 },
                c = { bg = "NONE", fg = colors.overlay0 },
              },
            }
          end,
        },
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
        rainbow_delimiters = true,
        dropbar = {
          enabled = true,
          color_mode = "fg",
        },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local theme = require("catppuccin.utils.lualine")()
      for _, mode_colors in pairs(theme) do
        for section, _ in pairs(mode_colors) do
          mode_colors[section].bg = "NONE"
        end
      end
      opts.options = opts.options or {}
      opts.options.theme = theme
      opts.options.section_separators = { left = "", right = "" }
      opts.options.component_separators = { left = "", right = "" }
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      -- Force-clear bg on ALL lualine highlight groups after setup
      for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
        if type(name) == "string" and name:find("^lualine_") then
          local hl = vim.api.nvim_get_hl(0, { name = name })
          if hl and not hl.link and hl.bg then
            hl.bg = nil
            hl.ctermbg = nil
            vim.api.nvim_set_hl(0, name, hl)
          end
        end
      end
    end,
  },
  {
    "akinsho/bufferline.nvim",
    opts = {
      highlights = require("catppuccin.special.bufferline").get_theme(),
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
