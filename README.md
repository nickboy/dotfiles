#Dotfiles

Download dotfiles
```
git clone https://github.com/nickboy/dotfiles.git
```

Install zsh
MAC
```
brew install zsh 
```

Linux
[https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)

Install oh-my-zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

```

Install powerlevel10k

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

[Optional as we moved to NeoVim]Install Awesome Vimrc

```bash
git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh
```

Install Neovim
```bash
brew install neovim
```

Install vim-plug
```bash
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
```

Copy dotfiles to home directory
```bash
cd ~/dotfiles
rake
```

Install font
Mac
```bash
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```
