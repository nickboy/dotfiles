-- dropbar: the hand-written BufModifiedSet bridge for Neovim 0.13 is gone.
-- Upstream commit 808ba31cde89aec8833e9789f5e04557cd31c9e1 (2026-05-31,
-- "feat(configs): support specifying event pattern in config") added
-- `{ event = "OptionSet", pattern = "modified" }` to the default
-- bar.update_events.buf. This file overrides that list, so the entry is
-- mirrored below rather than inherited.
return {
  -- Breadcrumb navigation bar (like VS Code breadcrumbs)
  {
    "Bekaboo/dropbar.nvim",
    event = "LazyFile",
    opts = {
      bar = {
        update_events = {
          win = { "CursorMoved", "WinResized" },
          buf = {
            { event = "OptionSet", pattern = "modified" },
            "FileChangedShellPost",
            "TextChanged",
            "ModeChanged",
          },
          global = { "DirChanged", "VimResized" },
        },
        sources = function(buf, _)
          local sources = require("dropbar.sources")
          local utils = require("dropbar.utils")
          if vim.bo[buf].ft == "markdown" then
            return { sources.markdown }
          end
          if vim.bo[buf].buftype == "terminal" then
            return { sources.terminal }
          end
          return {
            utils.source.fallback({
              sources.lsp,
              sources.treesitter,
            }),
          }
        end,
      },
    },
    config = function(_, opts)
      require("dropbar").setup(opts)
    end,
  },

  -- Inline git blame (like VS Code GitLens)
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 300,
      },
      current_line_blame_formatter = "<author>, <author_time:%R> • <summary>",
    },
    keys = {
      { "<leader>uB", "<cmd>Gitsigns toggle_current_line_blame<cr>", desc = "Toggle Git Blame" },
    },
  },

  -- Peek definition/references (like VS Code Alt+F12)
  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
    opts = {
      border = {
        enable = true,
      },
      theme = {
        enable = true,
        mode = "auto",
      },
    },
    keys = {
      { "gD", "<cmd>Glance definitions<cr>", desc = "Glance Definition" },
      { "gR", "<cmd>Glance references<cr>", desc = "Glance References" },
      { "gY", "<cmd>Glance type_definitions<cr>", desc = "Glance Type Definition" },
      { "gM", "<cmd>Glance implementations<cr>", desc = "Glance Implementations" },
    },
  },
}
