#!/usr/bin/env bash

set -e

DIALOG_BACKTITLE="Console / robot setup"
UBUNTU_VERSION=""
PYTHON_DEV_PACKAGE=""
VERSION_SET_BY_CLI=false
INSTALL_CURSOR=false
INSTALL_OPENCODE=false
INSTALL_CLAUDE=false
AGENTS_SET_BY_CLI=false
USE_DIALOG=true
NONINTERACTIVE=false
VIM_REPO_SSH="git@github.com:cpaxton/vim_config.git"
VIM_REPO_HTTPS="https://github.com/cpaxton/vim_config.git"
SSH_KEYFILE=""
USERNAME=""
USEREMAIL=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [UBUNTU_VERSION] [OPTIONS]

Console / robot setup: packages, vim config, git, conda, SSH key, optional CLI agents.

On a terminal, a checklist/menu is shown so you can choose options.
Flags skip those questions.

Ubuntu version (optional; auto-detected from /etc/os-release if omitted):
  20, 22, or 24

Options:
  --cursor       Install Cursor CLI
  --opencode     Install OpenCode CLI
  --claude       Install Claude Code CLI
  --agents       Install all of the CLI agents above
  --no-agents    Skip CLI agents
  --no-dialog    Plain prompts instead of whiptail menus
  -y, --yes      Non-interactive defaults (no agents unless flagged)
  -h, --help     Show this help

Examples:
  ./install.sh
  ./install.sh 20
  ./install.sh --agents
  ./install.sh 22 --cursor --opencode
  ./install.sh -y --no-agents
EOF
}

step() {
    echo
    echo "==> $*"
}

have_tty() {
    [ -t 0 ] && [ -t 1 ]
}

set_python_dev_package() {
    case "$UBUNTU_VERSION" in
        20) PYTHON_DEV_PACKAGE="libpython3.8-dev" ;;
        22) PYTHON_DEV_PACKAGE="libpython3.10-dev" ;;
        24) PYTHON_DEV_PACKAGE="libpython3.12-dev" ;;
        *)
            echo "Unsupported Ubuntu version: ${UBUNTU_VERSION:-unknown} (use 20, 22, or 24)."
            exit 1
            ;;
    esac
}

detect_ubuntu_version() {
    local id=""
    if [ -r /etc/os-release ]; then
        id="$(. /etc/os-release; printf '%s' "${VERSION_ID:-}")"
    fi
    case "$id" in
        20.04*) echo 20 ;;
        22.04*) echo 22 ;;
        24.04*) echo 24 ;;
        *) echo "" ;;
    esac
}

cancelled() {
    echo "Setup cancelled."
    exit 1
}

ensure_whiptail() {
    if [ "$USE_DIALOG" != true ]; then
        return 0
    fi
    if command -v whiptail >/dev/null 2>&1; then
        return 0
    fi
    echo "Installing whiptail for setup menus..."
    sudo apt update
    sudo apt install -y whiptail
}

dialog_msg() {
    local title="$1"
    local text="$2"
    local height="${3:-12}"
    local width="${4:-72}"
    if [ "$USE_DIALOG" = true ]; then
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "$title" \
            --msgbox "$text" "$height" "$width"
    else
        echo
        echo "--- $title ---"
        echo "$text"
        echo
        read -r -p "Press Enter to continue... " _
    fi
}

dialog_input() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local value=""
    if [ "$USE_DIALOG" = true ]; then
        value="$(whiptail --backtitle "$DIALOG_BACKTITLE" --title "$title" \
            --inputbox "$prompt" 10 70 "$default" 3>&1 1>&2 2>&3)" || cancelled
    else
        if [ -n "$default" ]; then
            read -r -p "$prompt [$default]: " value
            value="${value:-$default}"
        else
            read -r -p "$prompt: " value
        fi
    fi
    printf '%s' "$value"
}

dialog_yesno() {
    local title="$1"
    local text="$2"
    if [ "$USE_DIALOG" = true ]; then
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "$title" \
            --yes-button "Yes" --no-button "No" --yesno "$text" 12 70
    else
        local reply
        read -r -p "$text [y/N] " reply
        case "$reply" in
            [yY]|[yY][eE][sS]) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

dialog_menu() {
    local title="$1"
    local text="$2"
    shift 2
    if [ "$USE_DIALOG" = true ]; then
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "$title" \
            --menu "$text" 16 72 4 "$@" 3>&1 1>&2 2>&3
    else
        echo >&2
        echo "$text" >&2
        local i=1
        local tags=()
        while [ "$#" -ge 2 ]; do
            echo "  $i) $2" >&2
            tags+=("$1")
            shift 2
            i=$((i + 1))
        done
        local choice
        read -r -p "Choose [1]: " choice
        choice="${choice:-1}"
        printf '%s' "${tags[$((choice - 1))]}"
    fi
}

dialog_checklist() {
    local title="$1"
    local text="$2"
    shift 2
    if [ "$USE_DIALOG" = true ]; then
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "$title" \
            --checklist "$text" 16 74 5 "$@" 3>&1 1>&2 2>&3
    else
        echo >&2
        echo "$text" >&2
        local selected=""
        while [ "$#" -ge 3 ]; do
            local tag="$1" desc="$2"
            shift 3
            local reply
            read -r -p "  $desc? [y/N] " reply
            case "$reply" in
                [yY]|[yY][eE][sS]) selected="$selected $tag" ;;
            esac
        done
        printf '%s' "$selected"
    fi
}

dialog_password() {
    local title="$1"
    local prompt="$2"
    if [ "$USE_DIALOG" = true ]; then
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "$title" \
            --passwordbox "$prompt" 10 70 3>&1 1>&2 2>&3
    else
        local value
        read -r -s -p "$prompt: " value
        echo
        printf '%s' "$value"
    fi
}

for arg in "$@"; do
    case "$arg" in
        20|22|24)
            UBUNTU_VERSION="$arg"
            VERSION_SET_BY_CLI=true
            ;;
        --cursor)
            INSTALL_CURSOR=true
            AGENTS_SET_BY_CLI=true
            ;;
        --opencode)
            INSTALL_OPENCODE=true
            AGENTS_SET_BY_CLI=true
            ;;
        --claude)
            INSTALL_CLAUDE=true
            AGENTS_SET_BY_CLI=true
            ;;
        --agents)
            INSTALL_CURSOR=true
            INSTALL_OPENCODE=true
            INSTALL_CLAUDE=true
            AGENTS_SET_BY_CLI=true
            ;;
        --no-agents)
            INSTALL_CURSOR=false
            INSTALL_OPENCODE=false
            INSTALL_CLAUDE=false
            AGENTS_SET_BY_CLI=true
            ;;
        --no-dialog)
            USE_DIALOG=false
            ;;
        -y|--yes)
            NONINTERACTIVE=true
            USE_DIALOG=false
            if [ "$AGENTS_SET_BY_CLI" != true ]; then
                AGENTS_SET_BY_CLI=true
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Invalid argument: $arg"
            usage
            exit 1
            ;;
    esac
done

if ! have_tty; then
    USE_DIALOG=false
    NONINTERACTIVE=true
    if [ "$AGENTS_SET_BY_CLI" != true ]; then
        AGENTS_SET_BY_CLI=true
    fi
fi

if [ "$VERSION_SET_BY_CLI" != true ]; then
    UBUNTU_VERSION="$(detect_ubuntu_version)"
fi

if [ "$USE_DIALOG" = true ]; then
    ensure_whiptail
fi

# ----------------------------------------------------------
# Interactive choices (all up front when possible)
if [ "$NONINTERACTIVE" != true ]; then
    if [ "$USE_DIALOG" = true ]; then
        dialog_msg "Welcome" \
            "This sets up a new computer or robot:\n\n  • packages, vim, byobu, git, uv, miniforge\n  • SSH key if missing (optional GitHub add)\n  • optional CLI agents (Cursor, OpenCode, Claude)\n\nYou will pick options on the next screens." \
            16 72
    fi

    if [ -z "$UBUNTU_VERSION" ]; then
        UBUNTU_VERSION="$(dialog_menu "Ubuntu version" \
            "Could not auto-detect this OS. Choose the Ubuntu release:" \
            24 "Ubuntu 24.04 LTS (default)" \
            22 "Ubuntu 22.04 LTS" \
            20 "Ubuntu 20.04 LTS")" || cancelled
    fi

    EXISTING_NAME="$(git config --global user.name 2>/dev/null || true)"
    EXISTING_EMAIL="$(git config --global user.email 2>/dev/null || true)"
    USERNAME="$(dialog_input "Git identity" "Name for git commits:" "$EXISTING_NAME")"
    USEREMAIL="$(dialog_input "Git identity" "Email for git commits (also used as the SSH key comment):" "$EXISTING_EMAIL")"
    if [ -z "$USERNAME" ] || [ -z "$USEREMAIL" ]; then
        echo "Git name and email are required."
        exit 1
    fi

    if [ "$AGENTS_SET_BY_CLI" != true ]; then
        AGENT_CHOICES="$(dialog_checklist "CLI coding agents" \
            "Space to select, Tab to OK. None are required.\nThese are optional terminal coding agents." \
            cursor "Cursor CLI  (then: agent login)" OFF \
            opencode "OpenCode" OFF \
            claude "Claude Code" OFF)" || cancelled
        case "$AGENT_CHOICES" in *cursor*) INSTALL_CURSOR=true ;; esac
        case "$AGENT_CHOICES" in *opencode*) INSTALL_OPENCODE=true ;; esac
        case "$AGENT_CHOICES" in *claude*) INSTALL_CLAUDE=true ;; esac
    fi

    AGENT_SUMMARY="none"
    AGENT_LIST=""
    [ "$INSTALL_CURSOR" = true ] && AGENT_LIST="${AGENT_LIST}Cursor, "
    [ "$INSTALL_OPENCODE" = true ] && AGENT_LIST="${AGENT_LIST}OpenCode, "
    [ "$INSTALL_CLAUDE" = true ] && AGENT_LIST="${AGENT_LIST}Claude Code, "
    if [ -n "$AGENT_LIST" ]; then
        AGENT_SUMMARY="${AGENT_LIST%, }"
    fi

    SUMMARY="Ubuntu:        ${UBUNTU_VERSION}.04
Git name:      $USERNAME
Git email:     $USEREMAIL
CLI agents:    $AGENT_SUMMARY
SSH:           generate a key if this machine has none
Clone:         HTTPS (works before the key is on GitHub)

~/.vim will be replaced if it already exists."

    if ! dialog_yesno "Confirm setup" "$SUMMARY"$'\n\n'"Continue?"; then
        cancelled
    fi
else
    if [ -z "$UBUNTU_VERSION" ]; then
        echo "Could not auto-detect Ubuntu version. Pass 20, 22, or 24."
        exit 1
    fi
    USERNAME="$(git config --global user.name 2>/dev/null || true)"
    USEREMAIL="$(git config --global user.email 2>/dev/null || true)"
    if [ -z "$USERNAME" ]; then
        USERNAME="$(whoami)"
    fi
    if [ -z "$USEREMAIL" ]; then
        USEREMAIL="$(whoami)@$(hostname)"
    fi
    echo "Non-interactive install for Ubuntu ${UBUNTU_VERSION}.04 as $USERNAME <$USEREMAIL>"
fi

set_python_dev_package

step "Installing packages for Ubuntu ${UBUNTU_VERSION}.04"
sudo apt update
sudo apt install -y \
    build-essential git git-lfs vim-gtk3 byobu cmake htop feh \
    python-is-python3 "$PYTHON_DEV_PACKAGE" curl wget net-tools \
    openssh-client whiptail

git config --global core.editor "vim"
git config --global user.name "$USERNAME"
git config --global user.email "$USEREMAIL"
git config --global pull.rebase false
git config --global push.autoSetupRemote true

# ----------------------------------------------------------
# SSH key for GitHub (generate if missing)
# Follows: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
ensure_ssh_key() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        SSH_KEYFILE="$HOME/.ssh/id_ed25519"
        echo "Found existing SSH key: $SSH_KEYFILE"
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
        SSH_KEYFILE="$HOME/.ssh/id_rsa"
        echo "Found existing SSH key: $SSH_KEYFILE"
    elif [ -f "$HOME/.ssh/id_ecdsa" ]; then
        SSH_KEYFILE="$HOME/.ssh/id_ecdsa"
        echo "Found existing SSH key: $SSH_KEYFILE"
    else
        SSH_KEYFILE="$HOME/.ssh/id_ed25519"
        local comment="${USEREMAIL:-$(whoami)@$(hostname)}"
        local passphrase=""
        if [ "$NONINTERACTIVE" = true ]; then
            echo "Generating ed25519 SSH key with empty passphrase..."
            ssh-keygen -t ed25519 -C "$comment" -f "$SSH_KEYFILE" -N ""
        else
            passphrase="$(dialog_password "SSH key" \
                "Passphrase for the new key. Leave empty on robots / headless machines so git pull does not prompt.")" || cancelled
            ssh-keygen -t ed25519 -C "$comment" -f "$SSH_KEYFILE" -N "$passphrase"
        fi
    fi
    chmod 600 "$SSH_KEYFILE"

    if [ ! -f "$HOME/.ssh/config" ] || ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
        cat >> "$HOME/.ssh/config" <<EOF
Host github.com
  AddKeysToAgent yes
  IdentityFile $SSH_KEYFILE
  IdentitiesOnly yes
EOF
        chmod 600 "$HOME/.ssh/config"
    fi

    touch "$HOME/.ssh/known_hosts"
    chmod 600 "$HOME/.ssh/known_hosts"
    if ! grep -q "github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
        ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
    fi
}

github_ssh_ok() {
    local out
    [ -n "$SSH_KEYFILE" ] || return 1
    out="$(ssh -i "$SSH_KEYFILE" -o IdentitiesOnly=yes -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)" || true
    echo "$out" | grep -qi "successfully authenticated"
}

show_github_pubkey() {
    local hint="Open https://github.com/settings/ssh/new
Suggested title: $(hostname)

After saving the key, choose Check again.
Or skip and clone over HTTPS."
    if [ "$USE_DIALOG" = true ] && command -v whiptail >/dev/null 2>&1; then
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "Add this key to GitHub" \
            --msgbox "$hint" 14 72
        whiptail --backtitle "$DIALOG_BACKTITLE" --title "Public key" \
            --textbox "${SSH_KEYFILE}.pub" 12 78
    else
        echo
        echo "$hint"
        echo "----------------------------------------"
        cat "${SSH_KEYFILE}.pub"
        echo "----------------------------------------"
    fi
}

step "Checking SSH key for GitHub"
ensure_ssh_key

eval "$(ssh-agent -s)" >/dev/null
ssh-add "$SSH_KEYFILE" 2>/dev/null || ssh-add "$SSH_KEYFILE"
export GIT_SSH_COMMAND="ssh -i $SSH_KEYFILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

if github_ssh_ok; then
    echo "GitHub SSH authentication succeeded."
elif [ "$NONINTERACTIVE" = true ]; then
    echo "GitHub SSH not configured yet. Cloning over HTTPS."
    echo "Add this key later: https://github.com/settings/ssh/new"
    cat "${SSH_KEYFILE}.pub"
else
    while true; do
        show_github_pubkey
        SSH_WAIT="$(dialog_menu "GitHub SSH" \
            "vim_config will clone over HTTPS either way. Private repos need this key on GitHub." \
            retry "I added the key - check again" \
            skip "Skip for now")" || cancelled
        if [ "$SSH_WAIT" = "skip" ]; then
            echo "Continuing without GitHub SSH."
            break
        fi
        if github_ssh_ok; then
            dialog_msg "GitHub SSH" "Authentication succeeded."
            break
        fi
        dialog_msg "GitHub SSH" \
            "Still not authenticated. Wait a few seconds after saving the key, then try again."
    done
fi

if [ "$INSTALL_CURSOR" = true ]; then
    step "Installing Cursor CLI"
    curl https://cursor.com/install -fsS | bash || echo "Warning: Cursor CLI install failed."
fi

if [ "$INSTALL_OPENCODE" = true ]; then
    step "Installing OpenCode"
    curl -fsSL https://opencode.ai/install | bash || echo "Warning: OpenCode install failed."
fi

if [ "$INSTALL_CLAUDE" = true ]; then
    step "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash || echo "Warning: Claude Code install failed."
fi

step "Installing UV"
curl -LsSf https://astral.sh/uv/install.sh | sh

step "Cloning vim_config over HTTPS"
VIM_CLONE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/vim_config.XXXXXX")"
# Rewrite git@github.com: submodule URLs to HTTPS so --recursive works
# even when this machine's key is not on GitHub yet.
git -c url."https://github.com/".insteadOf="git@github.com:" \
    clone --recursive "$VIM_REPO_HTTPS" "$VIM_CLONE_TMP/vim_config"
rm -rf "$HOME/.vim"
mv "$VIM_CLONE_TMP/vim_config" "$HOME/.vim"
rmdir "$VIM_CLONE_TMP" 2>/dev/null || rm -rf "$VIM_CLONE_TMP"

if github_ssh_ok; then
    git -C "$HOME/.vim" remote set-url origin "$VIM_REPO_SSH"
    echo "Set ~/.vim origin to SSH."
fi

step "Linking vimrc and byobu"
if [ -f "$HOME/.vimrc" ]; then
    rm "$HOME/.vimrc"
fi
ln -s "$HOME/.vim/vimrc" "$HOME/.vimrc"
if [ -d "$HOME/.byobu" ]; then
    rm -rf "$HOME/.byobu"
fi
ln -s "$HOME/.vim/byobu" "$HOME/.byobu"

if ! grep -q '\.vim/aliases' "$HOME/.bashrc" 2>/dev/null; then
    echo 'source $HOME/.vim/aliases' >> "$HOME/.bashrc"
fi

step "Installing Miniforge (conda / mamba)"
if [ "$(uname -m)" = "aarch64" ]; then
    ARCH="aarch64"
else
    ARCH="x86_64"
fi

cd "$HOME"
wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${ARCH}.sh"
chmod +x "Miniforge3-Linux-${ARCH}.sh"
./Miniforge3-Linux-${ARCH}.sh -b
rm "Miniforge3-Linux-${ARCH}.sh"

set +e
source "$HOME/.bashrc"
"$HOME/miniforge3/bin/mamba" init
source "$HOME/.bashrc"
set -e

DONE_TEXT="Setup complete.

Restart your shell, or run:
  source ~/.bashrc
"
[ "$INSTALL_CURSOR" = true ] && DONE_TEXT="${DONE_TEXT}
Cursor CLI:   agent login"
[ "$INSTALL_OPENCODE" = true ] && DONE_TEXT="${DONE_TEXT}
OpenCode:     opencode auth login"
[ "$INSTALL_CLAUDE" = true ] && DONE_TEXT="${DONE_TEXT}
Claude Code:  claude"

if [ "$USE_DIALOG" = true ]; then
    dialog_msg "Done" "$DONE_TEXT" 16 70
else
    echo
    echo "$DONE_TEXT"
fi
