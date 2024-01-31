#!/usr/bin/env bash

echo "Install basic dependencies..."
sudo apt update
sudo apt install -y build-essential git git-lfs vim-gtk3 byobu cmake htop feh python-is-python3 libpython3.10-dev

# cd $HOME
# rm -r $HOME/.vim
# git clone git@github.com:cpaxton/vim_config.git .vim --recursive

echo "Setting symbolic links"
ln -s $HOME/.vim/vimrc .vimrc
rm -r $HOME/.byobu
ln -s $HOME/.vim/byobu $HOME/.byobu

# Setup git properly
git config --global core.editor "vim"
