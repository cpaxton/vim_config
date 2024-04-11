#!/usr/bin/env bash

echo "Install basic dependencies..."
sudo apt update
sudo apt install -y build-essential git git-lfs vim-gtk3 byobu cmake htop feh python-is-python3 libpython3.10-dev net-tools

cd $HOME
rm -r $HOME/.vim
git clone git@github.com:cpaxton/vim_config.git .vim --recursive

echo "Setting symbolic links"
rm $HOME/.vimrc
ln -s $HOME/.vim/vimrc $HOME/.vimrc
rm -r $HOME/.byobu
ln -s $HOME/.vim/byobu $HOME/.byobu

# Setup git properly
git config --global core.editor "vim"

echo "Update bashrc to use aliases"
echo "source $HOME/.vim/aliases" >> $HOME/.bashrc

echo "Download miniforge for conda and mamba"
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
sh Miniforge3-Linux-x86_64.sh

read -p "Enter your name for git:" USERNAME
read -p "Enter your email for git:" USEREMAIL
git config --global user.name "$USERNAME"
git config --global user.email "$USEREMAIL"
