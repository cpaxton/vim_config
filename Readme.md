# Console Config

To setup a new computer, create a new SSH key [following these instructions.](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

Then just download and run the [install script](install.sh)
```
wget https://raw.githubusercontent.com/cpaxton/vim_config/master/install.sh
chmod +x install.sh
./install.sh
```

For older operating systems (Ubuntu 20.04 supported):
```
wget https://raw.githubusercontent.com/cpaxton/vim_config/master/install.sh
chmod +x install.sh
./install.sh 20
```

Then in `~/.bashrc` add:
```
source $HOME/.vim/aliases
```

Use [miniforge](https://github.com/conda-forge/miniforge) to install conda and mamba.


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
```bash
git clone https://github.com/github/copilot.vim.git \
  ~/.config/nvim/pack/github/start/copilot.vim
```

Then you just need to run the follwing command in neovim:
```
:Copilot setup
```

Follow instructions to authenticate.

