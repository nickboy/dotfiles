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

  -- Peek definition/references (like VS Code Alt+F12).
  --
  -- Was dnlhc/glance.nvim until 2026-08-16. Same capability, but glance had
  -- gone 425 days without a commit while sitting directly on the LSP API —
  -- the part of Neovim that moved most across 0.11-0.13 — and this config
  -- tracks bob nightly. goto-preview is the same idea with roughly half the
  -- staleness (233 days) and more users, so it is the safer place to be when
  -- the next LSP rename lands.
  --
  -- It is NOT a drop-in visually: glance drew a split with a candidate list
  -- down the side, goto-preview stacks floating windows. gR (references) is
  -- where that shows most — a picker now, not a persistent list. Keys are
  -- unchanged on purpose so the muscle memory survives the swap.
  {
    "rmagatti/goto-preview",
    event = "LspAttach",
    opts = {
      width = 120,
      height = 20,
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
      default_mappings = false,
      focus_on_open = true,
      dismiss_on_move = false,
      stack_floating_preview_windows = true,
      preview_window_title = { enable = true, position = "left" },
      references = {
        -- snacks, not the telescope default: LazyVim's picker here is
        -- snacks.picker, and pointing this at telescope would drag in a
        -- second picker just to list references.
        provider = "snacks",
      },
      -- glance closed on `q` from inside the peek window. goto-preview has
      -- no such binding, so map it per preview buffer rather than burning a
      -- global key (gP is Neovim's own paste-before-and-move-cursor).
      -- bufnr here is the TARGET FILE's buffer, not a scratch one — goto-preview
      -- loads the real file and shows it in a float. So this map lands on a
      -- buffer that outlives the preview, and with same_file_float_preview on
      -- (the default) that can be the buffer you are editing: close the peek
      -- and `q` no longer starts macro recording. buffer_entered also re-runs
      -- this hook for every buffer entered while inside a preview, so browsing
      -- references stamps it on each file in turn. post_close_hook undoes it.
      post_open_hook = function(bufnr, _)
        vim.keymap.set("n", "q", function()
          require("goto-preview").close_all_win()
        end, { buffer = bufnr, desc = "Close preview windows" })
      end,
      post_close_hook = function(bufnr, _)
        -- pcall: the buffer may already be wiped (bufhidden = "wipe"), and the
        -- hook fires from several sites, so a missing mapping is expected.
        pcall(vim.keymap.del, "n", "q", { buffer = bufnr })
      end,
    },
    keys = {
      -- stylua: ignore start
      { "gD", function() require("goto-preview").goto_preview_definition() end, desc = "Peek Definition" },
      { "gR", function() require("goto-preview").goto_preview_references() end, desc = "Peek References" },
      { "gY", function() require("goto-preview").goto_preview_type_definition() end, desc = "Peek Type Definition" },
      { "gM", function() require("goto-preview").goto_preview_implementation() end, desc = "Peek Implementation" },
      -- stylua: ignore end
    },
  },
}
