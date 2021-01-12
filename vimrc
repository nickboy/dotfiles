set nocompatible              " be iMproved, required
filetype off                  " required

call plug#begin('~/.vim/plugged')

" for Java development environment
Plug 'artur-shaik/vim-javacomplete2'

Plug 'terryma/vim-smooth-scroll'
" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
Plug 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
Plug 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
" Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
Plug 'rstacruz/sparkup', {'rtp': 'vim/'}
Plug 'Lokaltog/vim-powerline'
" Show boockmark sign in front of the line
Plug 'kshenoy/vim-signature'
Plug 'myusuf3/numbers.vim'
call plug#end()


set runtimepath+=~/.vim_runtime

source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/filetypes.vim
source ~/.vim_runtime/vimrcs/plugins_config.vim
source ~/.vim_runtime/vimrcs/extended.vim

try
source ~/.vim_runtime/my_configs.vim
catch
endtry


"Highlight current row
set cursorline
set hlsearch

"Enable vim settings immediately
autocmd BufWritePost $MYVIMRC source $MYVIMRC

"Wild menu
set wildmenu
