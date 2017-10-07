#Dotfiles

Download dotfiles

git clone https://github.com/nickboy/dotfiles.git

Install zsh

Install oh-my-zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

```

Install powerlevel9k

```bash
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
```

Install Awesome Vimrc

```bash
git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh
```

Install Vundle
```bash
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```

Copy dotfiles to home directory
```bash
cd ~/dotfiles
rake
```

Update Vim 8.0
Mac
```bash
brew install vim --with-override-system-vi
```
Ubuntu
```bash
sudo add-apt-repository ppa:jonathonf/vim
sudo apt-get update
sudo apt-get install vim
```
