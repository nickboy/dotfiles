syntax on
set tabstop=4 softtabstop=4
set shiftwidth=4
set expandtab
set smartindent
set relativenumber
set nu
set signcolumn=yes "Add a column on the left of the line for symbols"
set incsearch "Incremental search"
"set hidden For history buffer"

"For backup"
set noswapfile
set nobackup
set undodir=~/.vim/undodir
set undofile


"Plugins, using vim-plug for managing plugins https://github.com/junegunn/vim-plug"
call plug#begin('~/.vim/plugged')

"Telescope https://github.com/nvim-telescope/telescope.nvim"
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

"Color theme"
Plug 'gruvbox-community/gruvbox'

"Fuzzy Search"
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

"COC"
Plug 'neoclide/coc.nvim', {'branch': 'release'}

"NerdTree"
Plug 'scrooloose/nerdtree'
"Plug 'tsony-tsonev/nerdtree-git-plugin'""
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'ryanoasis/vim-devicons'

Plug 'airblade/vim-gitgutter'


"Switch between Tmux window"
Plug 'christoomey/vim-tmux-navigator'

"Neovim LSP"
"Plug 'neovim/nvim-lspconfig'"

call plug#end()


"Setup color scheme"
colorscheme gruvbox
highlight Normal guibg=none


" coc config
let g:coc_global_extensions = [
  \ 'coc-snippets',
  \ 'coc-pairs',
  \ 'coc-tsserver',
  \ 'coc-eslint', 
  \ 'coc-prettier', 
  \ 'coc-json', 
  \ 'coc-python', 
  \ 'coc-git', 
  \ 'coc-java', 
  \ ]


"NerdTree config
nmap <C-n> :NERDTreeToggle<CR>
vmap ++ <plug>NERDCommenterToggle
nmap ++ <plug>NERDCommenterToggle
