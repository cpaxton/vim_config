## Other Stuff - April 2022

```
# Should I do this?
# Not actually sure
# sudo apt install python-is-python3
```

Symlink vimrc to `~/.vimrc`

Add `aliases` to bashrc

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
