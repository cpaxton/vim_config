# Console Config

Clone the repo:
```
git clone git@github.com:cpaxton/vim_config.git .vim --recursive
```

Then, from bash, run the [install script](install.sh)

Old instructions (what will happen in the script):
```
sudo apt install build-essential git git-lfs vim-gtk3 byobu python-is-python3 cmake g++ libpython3.10-dev
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

#### Dependencies

It's a bit tricky to set this up on ubuntu 20.04. You need Vim 9 and Node.js 18+.


```bash
# First, add the unofficial PPA repository:
sudo add-apt-repository ppa:jonathonf/vim
# Update the package cache:
sudo apt update
# Install the latest Vim version:
sudo apt install vim
```

Now we need to install node.js 18+. We can do this with: 
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

You can verify that it worked with:
```bash
node -v
```

This should result in something like:
```
v18.19.1
```

If not, you have a problem.

#### Cloning the Github Copilot Repo

For neovim, clone with:
```
git clone https://github.com/github/copilot.vim.git \
  ~/.config/nvim/pack/github/start/copilot.vim
```

#### Configuring in NeoVim

Add to neovim config at `~/.config/nvim/init.vim`:
```
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath=&runtimepath
source ~/.vimrc
```
