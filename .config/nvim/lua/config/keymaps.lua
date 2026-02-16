-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Open URL under cursor in terminal mode (for Claude Code panel)
vim.keymap.set("t", "gx", function()
  local line = vim.api.nvim_get_current_line()
  local url = line:match("https?://[%w_.~!*'();:@&=+$,/?#%%[%]%-]+")
  if url then
    vim.ui.open(url)
  else
    vim.api.nvim_feedkeys("gx", "n", false)
  end
end, { desc = "Open URL under cursor" })
