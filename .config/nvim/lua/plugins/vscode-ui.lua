return {
  -- Breadcrumb navigation bar (like VS Code breadcrumbs)
  {
    "Bekaboo/dropbar.nvim",
    event = "LazyFile",
    opts = {
      bar = {
        -- Neovim 0.13 removed BufModifiedSet; bridge added in config() below.
        update_events = {
          win = { "CursorMoved", "WinResized" },
          buf = { "FileChangedShellPost", "TextChanged", "ModeChanged" },
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
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "modified",
        group = vim.api.nvim_create_augroup("DropbarModifiedBridge", { clear = true }),
        callback = function(args)
          require("dropbar.utils").bar.exec("update", { buf = args.buf })
        end,
        desc = "dropbar: replacement for removed BufModifiedSet (Neovim 0.13+)",
      })
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
