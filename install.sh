#!/usr/bin/env bash

set -e

# Set default Ubuntu version to 24
UBUNTU_VERSION="24"
PYTHON_DEV_PACKAGE="libpython3.12-dev"

# Check for an optional Ubuntu version flag
if [ "$1" == "20" ]; then
    UBUNTU_VERSION="20"
    PYTHON_DEV_PACKAGE="libpython3.8-dev"
elif [ "$1" == "22"]; then
    UBUNTU_VERSION="22"
    PYTHON_DEV_PACKAGE="libpython3.10-dev"
elif [ "$1" != "" ]; then
    echo "Invalid argument. Please specify Ubuntu version: 20, 22 or leave blank for $UBUNTU_VERSION."
    exit 1
fi

echo "Installing for Ubuntu $UBUNTU_VERSION.04..."

echo "Install basic dependencies..."
sudo apt update
sudo apt install -y build-essential git git-lfs vim-gtk3 byobu cmake htop feh python-is-python3 $PYTHON_DEV_PACKAGE curl net-tools

# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh 

cd $HOME
rm -rf $HOME/.vim
git clone git@github.com:cpaxton/vim_config.git .vim --recursive

echo "Setting symbolic links"
if [ -f "$HOME/.vimrc" ]; then
    rm "$HOME/.vimrc"
fi
ln -s $HOME/.vim/vimrc $HOME/.vimrc
if [ -d "$HOME/.byobu" ]; then
    rm -rf "$HOME/.byobu"
fi
ln -s $HOME/.vim/byobu $HOME/.byobu

echo "Update bashrc to use aliases"
echo "source $HOME/.vim/aliases" >> $HOME/.bashrc

echo "Downloading and installing Miniforge for conda and mamba"

# Detect architecture
if [ "$(uname -m)" = "aarch64" ]; then
    ARCH="aarch64"
else
    ARCH="x86_64"
fi

# ----------------------------------------------------------
# Conda/mamba setup
# Download the appropriate Miniforge installer
wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${ARCH}.sh"

# Make the installer executable
chmod +x "Miniforge3-Linux-${ARCH}.sh"

# Run the installer
./Miniforge3-Linux-${ARCH}.sh -b

# Clean up the installer
rm "Miniforge3-Linux-${ARCH}.sh"

echo "Miniforge installation complete. Please restart your shell or run 'source ~/.bashrc' to use conda."

# ----------------------------------------------------------
# Git setup
# Setup git properly
git config --global core.editor "vim"
read -p "Enter your name for git:" USERNAME
read -p "Enter your email for git:" USEREMAIL
git config --global user.name "$USERNAME"
git config --global user.email "$USEREMAIL"
git config --global pull.rebase false

source ~/.bashrc

$HOME/miniforge3/bin/mamba init

source ~/.bashrc

