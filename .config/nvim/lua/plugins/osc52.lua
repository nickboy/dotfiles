-- OSC52 clipboard for remote SSH sessions
-- Uses Neovim's built-in OSC52 support (0.10+, you have 0.12.0-dev)
-- Only activates when SSH_CONNECTION or TMUX is detected
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      local is_remote = vim.env.SSH_CONNECTION ~= nil
      local is_tmux = vim.env.TMUX ~= nil

      if is_remote or is_tmux then
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
