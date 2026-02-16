vim.g.mapleader = " "

-- Custom overrides (everything else uses LazyVim defaults)
vim.opt.cmdheight = 0
vim.opt.laststatus = 3
vim.opt.scrolloff = 10
vim.opt.inccommand = "split"
vim.opt.breakindent = true

-- Python tooling
vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"
