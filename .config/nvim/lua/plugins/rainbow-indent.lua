-- Rainbow brackets + indent guides.
--
-- Migration note: two plugins were retired in favour of snacks.nvim's built-in
-- `indent` module, which provides both indent guides and scope highlighting:
--   * lukas-reineke/indent-blankline.nvim -> snacks.indent.indent (guides)
--   * nvim-mini/mini.indentscope          -> snacks.indent.scope  (scope)
-- Both are disabled below. The LazyVim extra
-- `lazyvim.plugins.extras.ui.mini-indentscope` is still listed in lazyvim.json
-- and sets `snacks.indent.scope.enabled = false`, so this file re-enables it
-- explicitly (user specs are merged after extras, so this wins).
--
-- rainbow-delimiters is untouched: it colours brackets, not indentation, and
-- shares the Rainbow* highlight groups defined here.

local highlight = {
  "RainbowRed",
  "RainbowYellow",
  "RainbowBlue",
  "RainbowOrange",
  "RainbowGreen",
  "RainbowViolet",
  "RainbowCyan",
}

-- Catppuccin Mocha palette. Re-applied on every colorscheme change because
-- `:colorscheme` clears user-defined highlight groups.
local function set_rainbow_highlights()
  vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#f38ba8" })
  vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#f9e2af" })
  vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#89b4fa" })
  vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#fab387" })
  vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#a6e3a1" })
  vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#cba6f7" })
  vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#94e2d5" })
end

return {
  -- Rainbow delimiters (colored brackets + provides shared highlight names)
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "LazyFile",
    config = function()
      local rainbow = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow.strategy["global"],
        },
        query = {
          [""] = "rainbow-delimiters",
        },
        highlight = highlight,
      }
    end,
  },

  -- Indent guides + scope via snacks.indent (VS Code-style indent guides)
  {
    "snacks.nvim",
    opts = {
      indent = {
        enabled = true,
        indent = { char = "│", hl = highlight },
        scope = { enabled = true },
      },
    },
    init = function()
      set_rainbow_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("RainbowIndentHighlights", { clear = true }),
        callback = set_rainbow_highlights,
        desc = "Re-apply Rainbow* highlight groups after colorscheme change",
      })
    end,
  },

  -- Retired: replaced by snacks.indent (see header)
  { "lukas-reineke/indent-blankline.nvim", enabled = false },
  { "nvim-mini/mini.indentscope", enabled = false },
}
