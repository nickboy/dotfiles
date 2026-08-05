-- OSC52 clipboard: forced OSC 52 for SSH sessions only (deterministic even
-- when tmux servers hold a stale SSH_TTY env; local sessions — tmux or
-- herdr — use the system clipboard via pbcopy).
-- Uses Neovim's built-in OSC52 support (0.10+)
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      local is_remote = vim.env.SSH_CONNECTION ~= nil

      if is_remote then
        vim.g.clipboard = {
          name = "OSC 52",
          copy = {
            ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
            ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
          },
          paste = {
            ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
            ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
          },
        }
      end
    end,
  },
}
