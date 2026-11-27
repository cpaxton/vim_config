# Console Config

Bootstrap an Ubuntu machine with my vim config, shell aliases, byobu setup, miniforge, and optional desktop/dev apps.

## Fresh install

Download and run the [install script](install.sh):

```bash
wget https://raw.githubusercontent.com/cpaxton/vim_config/master/install.sh
chmod +x install.sh
./install.sh
```

The installer clones over SSH when GitHub accepts your key. If no key exists,
it offers to generate an ed25519 key on a terminal, prints the public key, and
waits while you add it at [github.com/settings/ssh/new](https://github.com/settings/ssh/new).
If you skip that, it clones over HTTPS and leaves `origin` on HTTPS so the
install can finish without a GitHub key. Submodule URLs also use HTTPS, so a
fresh clone does not need SSH access.

Generated keys have no passphrase so unattended `git pull` works; keep the
private key protected by your login and disk encryption.

Use `--ssh-key` to generate a key non-interactively, or `--no-ssh-key` to skip
SSH setup entirely:

```bash
./install.sh --no-ssh-key
```

You can still override the clone URL explicitly:

```bash
REPO_URL=https://github.com/cpaxton/vim_config.git ./install.sh
```

The Ubuntu version is detected automatically. For older releases, pass it explicitly (20.04 is supported):

```bash
./install.sh 20
```

That installs the base config. Add optional apps with `--all` or by name:

```bash
./install.sh --all
```

## Optional apps

Run `./install.sh --list` to see the available apps. Currently:

| App | Installed from |
| --- | --- |
| `uv` | Astral's official installer (also part of the base setup) |
| `discord` | Official Discord `.deb` |
| `dropbox` | Latest official package, or Dropbox's daemon tarball on older Ubuntu |
| `obsidian` | Latest GitHub release |
| `opencode` | Official v2 installer |
| `codex` | Official Codex CLI installer |
| `cursor` | Official Cursor CLI installer |
| `claude` | Official Claude Code installer |

On Ubuntu 22.04 and older, Dropbox's current `.deb` requires GTK 4.8+, which those
releases do not ship. The installer uses Dropbox's official daemon tarball in that
case and installs the current CLI under `/usr/local/bin`.

Install specific apps alongside the base config:

```bash
./install.sh discord obsidian
```

If the config is already set up and you only want the apps, skip the base setup:

```bash
./install.sh --apps-only uv
./install.sh --apps-only codex
```

For unattended runs, set `GIT_NAME` and `GIT_EMAIL`; the installer skips the git identity prompts when stdin is not a terminal.

## Options

| Option | Description |
| --- | --- |
| `--ssh-key` | Generate an SSH key if needed and use SSH when GitHub accepts it |
| `--no-ssh-key` | Skip SSH key setup and clone over HTTPS |
| `--all` | Install every app |
| `--apps-only` | Skip the config setup and only install the named apps |
| `--list` | List the available apps |
| `-h`, `--help` | Show usage |

You can also pass a Ubuntu version (`20`, `22`, `24`, or `26`) to override auto-detection.

## What the script does

- Detects the Ubuntu version and installs the matching Python dev package
- Installs the base apt packages (build tools, git, vim-gtk3, byobu, etc.)
- Installs [uv](https://github.com/astral-sh/uv)
- Generates a GitHub SSH key when needed and switches `origin` to SSH once GitHub accepts it
- Clones this repo to `~/.vim` over SSH or HTTPS, or updates it if it already exists
- Symlinks `~/.vimrc` and `~/.byobu`
- Adds `source $HOME/.vim/aliases` to `~/.bashrc` if it is not already there
- Installs [miniforge](https://github.com/conda-forge/miniforge) for conda and mamba (x86_64 or aarch64)
- Configures git (editor, name, email, pull strategy, and `push.autoSetupRemote`)

Restart your shell when it finishes.


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
