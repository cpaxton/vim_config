# Console Config

Download and run the [install script](install.sh) on a new computer or robot:

```
wget https://raw.githubusercontent.com/cpaxton/vim_config/master/install.sh
chmod +x install.sh
./install.sh
```

On a terminal, a **checklist / menu** walks you through git name, optional CLI agents, and the SSH key. Ubuntu 20.04 / 22.04 / 24.04 is auto-detected (or pass `20`, `22`, or `24`). Flags skip those screens:

```
./install.sh --cursor              # Cursor CLI
./install.sh --opencode            # OpenCode
./install.sh --claude              # Claude Code
./install.sh --agents              # all of the above
./install.sh 22 --cursor --opencode
./install.sh --no-agents           # skip agents
./install.sh --no-dialog           # plain prompts instead of menus
./install.sh -y --no-agents       # non-interactive (robots)
```

The script installs packages, vim/byobu, git, uv, and miniforge (conda/mamba). It also:

- Clones this repo over **HTTPS** so a new machine does not need a GitHub SSH key yet. Submodules (Vundle, YouCompleteMe, …) are also fetched over HTTPS. `vim-gtk3` may print `update-alternatives` man-page warnings; those are harmless.
- Generates an SSH key if none exists (ed25519, [GitHub's recommended flow](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)), shows the public key, and lets you add it at [GitHub SSH keys](https://github.com/settings/ssh/new) (or skip and add later). If GitHub accepts the key, `origin` is switched to SSH. Leave the passphrase empty on robots so `git pull` is non-interactive.

After install, `~/.bashrc` sources `$HOME/.vim/aliases` (the script appends this if it is missing). Restart the shell or run:

```
source $HOME/.bashrc
```

Use [miniforge](https://github.com/conda-forge/miniforge) to install conda and mamba if you are not using `install.sh`.


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

