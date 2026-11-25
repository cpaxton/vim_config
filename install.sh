#!/usr/bin/env bash

set -eo pipefail

REPO_URL="git@github.com:cpaxton/vim_config.git"
INSTALL_DIR="$HOME/.vim"

detect_ubuntu_version() {
    local version_id=""
    if [[ -r /etc/os-release ]]; then
        version_id="$(. /etc/os-release && printf '%s' "${VERSION_ID:-}")"
    fi
    if [[ -n "$version_id" ]]; then
        printf '%s\n' "${version_id%%.*}"
    else
        printf '24\n'
    fi
}

UBUNTU_VERSION="$(detect_ubuntu_version)"

APP_ORDER=(discord dropbox obsidian opencode codex)
declare -A APP_INSTALL=(
    [discord]=install_discord
    [dropbox]=install_dropbox
    [obsidian]=install_obsidian
    [opencode]=install_opencode
    [codex]=install_codex
)

list_apps() {
    cat <<'EOF'
discord    Discord desktop client
dropbox    Dropbox desktop client
obsidian   Obsidian notes (latest .deb from GitHub)
opencode   opencode CLI
codex      OpenAI Codex CLI
EOF
}

usage() {
    cat <<EOF
Usage: ./install.sh [options] [ubuntu-version] [app...]

Set up the console config, then install any apps you name.

Ubuntu version (default: auto-detected):
  20, 22, 24, 26   Override the detected Ubuntu release

Apps:
$(list_apps)

Options:
  --all         Install every app
  --apps-only   Skip the config setup; only install the named apps
  --list        Print the available apps and exit
  -h, --help    Show this help

Examples:
  ./install.sh                          # config only
  ./install.sh 22                       # config for Ubuntu 22.04
  ./install.sh discord obsidian         # config + those apps
  ./install.sh --all                    # config + every app
  ./install.sh --apps-only codex        # just install Codex
EOF
}

info() {
    echo "==> $*"
}

install_deb() {
    local url="$1" deb
    deb="$(mktemp --suffix=.deb)"
    info "Downloading $url"
    curl -fL --progress-bar -o "$deb" "$url"
    sudo apt-get install -y "$deb"
    rm -f "$deb"
}

install_discord() {
    info "Installing Discord"
    install_deb "https://discord.com/api/download?platform=linux&format=deb"
}

install_dropbox() {
    info "Installing Dropbox"
    local pkg
    pkg="$(curl -fsSL https://linux.dropbox.com/packages/ubuntu/ \
        | grep -oE 'dropbox_[0-9.]+_amd64\.deb' \
        | sort -Vu \
        | tail -n1)"
    if [[ -z "$pkg" ]]; then
        echo "Could not find the latest Dropbox package." >&2
        return 1
    fi
    install_deb "https://linux.dropbox.com/packages/ubuntu/$pkg"
}

install_obsidian() {
    info "Installing Obsidian"
    local url
    url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
        | grep -oE 'https://[^"]+_amd64\.deb' \
        | sed -n '1p')"
    if [[ -z "$url" ]]; then
        echo "Could not find the latest Obsidian release." >&2
        return 1
    fi
    install_deb "$url"
}

install_opencode() {
    info "Installing opencode"
    curl -fsSL https://opencode.ai/v2/install | bash
}

install_codex() {
    info "Installing Codex CLI"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
}

python_dev_package() {
    local version=""

    if command -v python3 >/dev/null 2>&1; then
        version="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
    fi

    if [[ -z "$version" ]]; then
        case "$UBUNTU_VERSION" in
            20) version="3.8" ;;
            22) version="3.10" ;;
            24) version="3.12" ;;
            26) version="3.14" ;;
            *) return 0 ;;
        esac
    fi

    printf 'libpython%s-dev\n' "$version"
}

setup_base() {
    info "Installing for Ubuntu $UBUNTU_VERSION"
    info "Installing basic dependencies"
    sudo apt update

    local packages=(
        build-essential
        git
        git-lfs
        vim-gtk3
        byobu
        cmake
        htop
        feh
        python-is-python3
        curl
        net-tools
        unzip
    )
    local python_dev
    python_dev="$(python_dev_package)"
    if [[ -n "$python_dev" ]]; then
        packages+=("$python_dev")
    fi
    sudo apt install -y "${packages[@]}"

    if ! command -v uv >/dev/null 2>&1; then
        info "Installing uv"
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

    info "Cloning the config"
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "$INSTALL_DIR already exists, updating it"
        git -C "$INSTALL_DIR" pull --ff-only ||
            echo "warning: could not fast-forward $INSTALL_DIR, leaving it as is"
        git -C "$INSTALL_DIR" submodule update --init --recursive
    else
        if [[ -e "$INSTALL_DIR" ]]; then
            mv "$INSTALL_DIR" "$INSTALL_DIR.bak.$(date +%s)"
        fi
        git clone --recursive "$REPO_URL" "$INSTALL_DIR"
    fi

    info "Setting symbolic links"
    ln -sfn "$INSTALL_DIR/vimrc" "$HOME/.vimrc"
    if [[ -e "$HOME/.byobu" && ! -L "$HOME/.byobu" ]]; then
        mv "$HOME/.byobu" "$HOME/.byobu.bak.$(date +%s)"
    fi
    ln -sfn "$INSTALL_DIR/byobu" "$HOME/.byobu"

    if ! grep -qF "source $INSTALL_DIR/aliases" "$HOME/.bashrc" 2>/dev/null; then
        info "Adding aliases to ~/.bashrc"
        echo "source $INSTALL_DIR/aliases" >>"$HOME/.bashrc"
    fi

    if [[ ! -d "$HOME/miniforge3" ]]; then
        local arch="x86_64"
        if [[ "$(uname -m)" == "aarch64" ]]; then
            arch="aarch64"
        fi

        local installer="$HOME/Miniforge3-Linux-${arch}.sh"
        info "Downloading miniforge for conda and mamba"
        curl -fL -o "$installer" \
            "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${arch}.sh"
        sh "$installer" -b
        rm -f "$installer"
    fi

    # Setup git properly
    git config --global core.editor "vim"
    if [[ -z "$(git config --global user.name)" ]]; then
        read -rp "Enter your name for git: " USERNAME
        git config --global user.name "$USERNAME"
    fi
    if [[ -z "$(git config --global user.email)" ]]; then
        read -rp "Enter your email for git: " USEREMAIL
        git config --global user.email "$USEREMAIL"
    fi
    git config --global pull.rebase false
    git config --global push.autoSetupRemote true

    source "$HOME/.bashrc"

    if [[ -x "$HOME/miniforge3/bin/mamba" ]]; then
        "$HOME/miniforge3/bin/mamba" init
    fi

    source "$HOME/.bashrc"
}

SELECTED=()
INSTALL_ALL=0
APPS_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        20 | 22 | 24 | 26) UBUNTU_VERSION="$1" ;;
        --all) INSTALL_ALL=1 ;;
        --apps-only) APPS_ONLY=1 ;;
        --list)
            list_apps
            exit 0
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --)
            shift
            SELECTED+=("$@")
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *) SELECTED+=("$1") ;;
    esac
    shift
done

if ((INSTALL_ALL)); then
    SELECTED+=("${APP_ORDER[@]}")
fi

# Drop duplicate app names while keeping the order they were given in.
if ((${#SELECTED[@]})); then
    mapfile -t SELECTED < <(printf '%s\n' "${SELECTED[@]}" | awk '!seen[$0]++')
fi

for app in "${SELECTED[@]}"; do
    if [[ -z "${APP_INSTALL[$app]:-}" ]]; then
        echo "Unknown app: $app" >&2
        echo "Available apps: ${APP_ORDER[*]}" >&2
        exit 1
    fi
done

if ((APPS_ONLY)) && ((${#SELECTED[@]} == 0)); then
    echo "No apps specified. Try: ./install.sh --apps-only discord" >&2
    exit 1
fi

if ((APPS_ONLY == 0)); then
    setup_base
fi

for app in "${SELECTED[@]}"; do
    "${APP_INSTALL[$app]}"
done

if ((${#SELECTED[@]})); then
    info "Done. Installed: ${SELECTED[*]}"
else
    info "Done."
fi
