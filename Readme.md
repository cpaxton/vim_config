# Console Config

Clone the repo:
```
git clone git@github.com:cpaxton/vim_config.git .vim --recursive
```

Then, from bash, run the [install script](install.sh)

Old instructions (what will happen in the script):
```
sudo apt install build-essential git git-lfs vim-gtk3 byobu
cd $HOME
git clone git@github.com:cpaxton/vim_config.git .vim --recursive
git config --global core.editor "vim"
ln -s $HOME/.vim/vimrc .vimrc
rm -r .byobu
ln -s $HOME/.vim/byobu $HOME/.byobu
```

In `~/.bashrc` add:
```
source $HOME/.vim/aliases
```

Create a new SSH key [following these instructions.](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

Use [miniforge](https://github.com/conda-forge/miniforge) to install conda and mamba.

## Other Stuff - April 2022

```
# Should I do this?
# Not actually sure
# sudo apt install python-is-python3
```

Symlink vimrc to `~/.vimrc`

Add `aliases` to bashrc


### Byobu config

```
set -g mouse on
set -g default-terminal "screen-256color"
```

### Github copilot

[Getting started](https://github.com/github/copilot.vim#getting-started)

Clone with:
```
git clone https://github.com/github/copilot.vim.git \
  ~/.config/nvim/pack/github/start/copilot.vim
```

### Configuring in NeoVim

Add to neovim config at `~/.config/nvim/init.vim`:
```
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath=&runtimepath
source ~/.vimrc
```
