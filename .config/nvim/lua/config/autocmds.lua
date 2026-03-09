-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function set_transparent_bg()
  local groups = { "Normal", "NormalNC", "NormalFloat", "SnacksNormal",
    "SnacksNormalNC", "StatusLine", "StatusLineNC" }
  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = set_transparent_bg,
})

-- Apply immediately since this file loads on VeryLazy (after the
-- initial colorscheme has already been set)
set_transparent_bg()
