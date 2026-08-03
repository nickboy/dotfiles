-- Editor side of vim-herdr-navigation (herdr plugin, SHA-pinned install).
-- Sourced from the installed plugin so it never drifts from the herdr side;
-- silently no-ops on machines without herdr. Outside herdr it falls back to
-- tmux ($TMUX) or plain wincmd, so it is safe to load unconditionally and
-- it replaces LazyVim's default <C-h/j/k/l> window maps with aware ones.
local matches = vim.fn.glob(
  vim.fn.expand("~/.config/herdr/plugins/github/vim-herdr-navigation-*/editor/nvim.lua"),
  false,
  true
)
if #matches > 0 then
  dofile(matches[1])
end
