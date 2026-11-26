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

latest_dropbox_deb() {
    curl -fsSL https://linux.dropbox.com/packages/ubuntu/ \
        | grep -oE 'dropbox_[0-9.]+_amd64\.deb' \
        | sort -Vu \
        | tail -n1
}

dropbox_deb_compatible() {
    local gtk4
    gtk4="$(apt-cache policy libgtk-4-1 2>/dev/null | awk '/Candidate:/ { print $2 }')"
    if [[ -z "$gtk4" || "$gtk4" == "(none)" ]]; then
        return 1
    fi
    dpkg --compare-versions "$gtk4" ge "4.8.0"
}

disable_dropbox_repo() {
    local source_list="/etc/apt/sources.list.d/dropbox.list"
    if [[ -f "$source_list" ]] && grep -q 'linux.dropbox.com' "$source_list"; then
        info "Disabling stale Dropbox apt repository"
        sudo sed -i '/linux\.dropbox\.com/ s/^deb/# deb/' "$source_list"
    fi
    if [[ ! -e /etc/default/dropbox-repo ]]; then
        echo "# Dropbox is installed from the official package or tarball; keep the stale apt repo disabled." |
            sudo tee /etc/default/dropbox-repo >/dev/null
    fi
}

install_dropbox_cli() {
    local pkg="$1" tmpdir icon size dep
    local deps=()

    for dep in python3-gi gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 gir1.2-glib-2.0 gir1.2-pango-1.0 lsb-release; do
        dpkg -s "$dep" >/dev/null 2>&1 || deps+=("$dep")
    done
    if ((${#deps[@]})); then
        info "Installing Dropbox CLI dependencies"
        sudo apt update
        sudo apt install -y "${deps[@]}"
    fi

    tmpdir="$(mktemp -d)"

    info "Downloading the current Dropbox CLI"
    curl -fL --progress-bar -o "$tmpdir/dropbox.deb" \
        "https://linux.dropbox.com/packages/ubuntu/$pkg"
    dpkg-deb -x "$tmpdir/dropbox.deb" "$tmpdir/extract"

    # The packaged script uses /usr/bin/env python3, which can pick up a
    # conda/venv Python that does not have the system gi bindings.
    sed '1s|^#!/usr/bin/env python3|#!/usr/bin/python3|' \
        "$tmpdir/extract/usr/bin/dropbox" |
        sudo tee /usr/local/bin/dropbox >/dev/null
    sudo chmod 0755 /usr/local/bin/dropbox

    if [[ -f "$tmpdir/extract/usr/share/applications/dropbox.desktop" ]]; then
        sudo install -Dm0644 "$tmpdir/extract/usr/share/applications/dropbox.desktop" \
            /usr/local/share/applications/dropbox.desktop
    fi
    for icon in "$tmpdir"/extract/usr/share/icons/hicolor/*/apps/dropbox.png; do
        [[ -f "$icon" ]] || continue
        size="$(basename "$(dirname "$(dirname "$icon")")")"
        sudo install -Dm0644 "$icon" "/usr/local/share/icons/hicolor/$size/apps/dropbox.png"
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        sudo gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor 2>/dev/null || true
    fi

    rm -rf "$tmpdir"
}

install_dropbox_tarball() {
    local pkg="$1" tmpdir was_running=0

    tmpdir="$(mktemp -d)"
    info "Downloading the latest Dropbox daemon"
    curl -fL --progress-bar -o "$tmpdir/dropbox.tar.gz" \
        "https://www.dropbox.com/download?plat=lnx.x86_64"
    tar xzf "$tmpdir/dropbox.tar.gz" -C "$tmpdir"

    if pgrep -f "^$HOME/\.dropbox-dist/.*/dropbox$" >/dev/null 2>&1; then
        was_running=1
        info "Stopping the running Dropbox daemon"
        pkill -f "^$HOME/\.dropbox-dist/.*/dropbox$" 2>/dev/null || true
        sleep 1
    fi

    mkdir -p "$HOME/.dropbox-dist"
    cp -a "$tmpdir/.dropbox-dist/." "$HOME/.dropbox-dist/"
    rm -rf "$tmpdir"

    install_dropbox_cli "$pkg"

    if ((was_running)); then
        if [[ -f "$HOME/.dropbox/info.json" ]]; then
            info "Restarting Dropbox"
            timeout 20 /usr/local/bin/dropbox start >/dev/null 2>&1 || true
        else
            info "Dropbox was stopped for the update; start it with 'dropbox start -i'."
        fi
    else
        info "Dropbox installed. Run 'dropbox start -i' to sign in and start it."
    fi
}

install_dropbox() {
    info "Installing Dropbox"
    disable_dropbox_repo

    local pkg
    pkg="$(latest_dropbox_deb)"
    if [[ -z "$pkg" ]]; then
        echo "Could not find the latest Dropbox package." >&2
        return 1
    fi

    if dropbox_deb_compatible; then
        install_deb "https://linux.dropbox.com/packages/ubuntu/$pkg"
        info "Dropbox installed. Run 'dropbox start -i' if it is not already running."
    else
        info "The current Dropbox .deb needs GTK 4.8+; using Dropbox's official tarball instead"
        install_dropbox_tarball "$pkg"
    fi
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

    # Use the system Python, not a conda/venv Python that may be on PATH.
    if [[ -x /usr/bin/python3 ]]; then
        version="$(/usr/bin/python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
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
        if apt-cache show "$python_dev" >/dev/null 2>&1; then
            packages+=("$python_dev")
        else
            info "Skipping $python_dev (not available for Ubuntu $UBUNTU_VERSION)"
        fi
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
    if [[ -d "$INSTALL_DIR/.git" ]] && ((${#SELECTED[@]})); then
        info "Config already exists; running setup too (use --apps-only to skip it)"
    fi
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
