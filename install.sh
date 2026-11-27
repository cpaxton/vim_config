#!/usr/bin/env bash

set -eo pipefail

SSH_REPO_URL="git@github.com:cpaxton/vim_config.git"
HTTPS_REPO_URL="https://github.com/cpaxton/vim_config.git"
REPO_URL_EXPLICIT=0
if [[ -n "${REPO_URL:-}" ]]; then
    REPO_URL_EXPLICIT=1
fi
REPO_URL="${REPO_URL:-$SSH_REPO_URL}"
SSH_KEY_SETUP="${SSH_KEY_SETUP:-auto}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.vim}"

SSH_KEYFILE=""
SSH_AUTH_OK=0

TEMP_PATHS=()
cleanup() {
    local path
    for path in "${TEMP_PATHS[@]}"; do
        [[ -n "$path" ]] && rm -rf "$path"
    done
}
trap cleanup EXIT

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

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "This installer targets Ubuntu Linux; detected $(uname -s)." >&2
    exit 1
fi

if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        echo "warning: this installer targets Ubuntu; detected ${PRETTY_NAME:-${ID:-unknown}}." >&2
    fi
fi

detect_arch() {
    case "$(uname -m)" in
        x86_64) printf 'amd64\n' ;;
        aarch64 | arm64) printf 'arm64\n' ;;
        *) uname -m ;;
    esac
}
ARCH="$(detect_arch)"

GIT_REPO_CONFIG=()

APP_ORDER=(uv discord dropbox obsidian opencode codex cursor claude)
declare -A APP_INSTALL=(
    [uv]=install_uv
    [discord]=install_discord
    [dropbox]=install_dropbox
    [obsidian]=install_obsidian
    [opencode]=install_opencode
    [codex]=install_codex
    [cursor]=install_cursor
    [claude]=install_claude
)

list_apps() {
    cat <<'EOF'
uv         uv Python package manager (also installed by the base setup)
discord    Discord desktop client
dropbox    Dropbox desktop client
obsidian   Obsidian notes (latest .deb from GitHub)
opencode   opencode CLI
codex      OpenAI Codex CLI
cursor     Cursor CLI
claude     Claude Code CLI
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
  --ssh-key     Generate an SSH key if needed and use SSH when GitHub accepts it
  --no-ssh-key  Skip SSH key setup and clone over HTTPS
  --all         Install every app
  --apps-only   Skip the config setup; only install the named apps
  --list        Print the available apps and exit
  -h, --help    Show this help

By default, SSH setup is automatic: an existing key is used when GitHub
accepts it; otherwise the installer offers to create a key on a terminal and
falls back to HTTPS.

Examples:
  ./install.sh                          # config only
  ./install.sh 22                       # config for Ubuntu 22.04
  ./install.sh discord obsidian         # config + those apps
  ./install.sh --all                    # config + every app
  ./install.sh --no-ssh-key             # always clone over HTTPS
  ./install.sh --apps-only uv           # just install uv
  ./install.sh --apps-only codex        # just install Codex
EOF
}

info() {
    echo "==> $*"
}

install_deb() {
    local url="$1" deb deb_arch
    deb="$(mktemp --suffix=.deb)"
    TEMP_PATHS+=("$deb")
    info "Downloading $url"
    curl -fL --progress-bar -o "$deb" "$url" || return 1

    deb_arch="$(dpkg-deb -f "$deb" Architecture 2>/dev/null || true)"
    if [[ -n "$deb_arch" && "$deb_arch" != "$ARCH" && "$deb_arch" != all ]]; then
        echo "Downloaded package is for $deb_arch, but this machine is $ARCH." >&2
        return 1
    fi

    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb" || return 1
    rm -f "$deb"
}

install_discord() {
    info "Installing Discord"
    if [[ "$ARCH" != amd64 ]]; then
        echo "Discord's Linux .deb is x86_64-only (detected $ARCH)." >&2
        return 1
    fi
    install_deb "https://discord.com/api/download?platform=linux&format=deb" || return 1
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
    if [[ -f "$source_list" ]] && grep -qE '^[[:space:]]*deb[[:space:]].*linux\.dropbox\.com' "$source_list"; then
        info "Disabling stale Dropbox apt repository"
        sudo sed -i '/linux\.dropbox\.com/ s/^deb/# deb/' "$source_list"
    fi
    if [[ ! -e /etc/default/dropbox-repo ]]; then
        echo "# Dropbox is installed from the official package or tarball; keep the stale apt repo disabled." |
            sudo tee /etc/default/dropbox-repo >/dev/null
    fi
}

disable_stale_dropbox_repo() {
    local source_list="/etc/apt/sources.list.d/dropbox.list"
    if [[ -f "$source_list" ]] && grep -qE '^[[:space:]]*deb[[:space:]].*linux\.dropbox\.com' "$source_list"; then
        disable_dropbox_repo
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
        disable_stale_dropbox_repo || return 1
        sudo apt update || return 1
        sudo apt install -y "${deps[@]}" || return 1
    fi

    tmpdir="$(mktemp -d)"
    TEMP_PATHS+=("$tmpdir")

    info "Downloading the current Dropbox CLI"
    curl -fL --progress-bar -o "$tmpdir/dropbox.deb" \
        "https://linux.dropbox.com/packages/ubuntu/$pkg" || return 1
    dpkg-deb -x "$tmpdir/dropbox.deb" "$tmpdir/extract" || return 1

    # The packaged script uses /usr/bin/env python3, which can pick up a
    # conda/venv Python that does not have the system gi bindings.
    sed '1s|^#!/usr/bin/env python3|#!/usr/bin/python3|' \
        "$tmpdir/extract/usr/bin/dropbox" |
        sudo tee /usr/local/bin/dropbox >/dev/null || return 1
    sudo chmod 0755 /usr/local/bin/dropbox || return 1

    if [[ -f "$tmpdir/extract/usr/share/applications/dropbox.desktop" ]]; then
        # The Dropbox CLI hardcodes this path when creating its autostart entry.
        sudo rm -f /usr/local/share/applications/dropbox.desktop
        sudo install -Dm0644 "$tmpdir/extract/usr/share/applications/dropbox.desktop" \
            /usr/share/applications/dropbox.desktop || return 1
    fi
    for icon in "$tmpdir"/extract/usr/share/icons/hicolor/*/apps/dropbox.png; do
        [[ -f "$icon" ]] || continue
        size="$(basename "$(dirname "$(dirname "$icon")")")"
        sudo install -Dm0644 "$icon" "/usr/local/share/icons/hicolor/$size/apps/dropbox.png" || return 1
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        sudo gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor 2>/dev/null || true
    fi

    rm -rf "$tmpdir"
}

install_dropbox_tarball() {
    local pkg="$1" tmpdir was_running=0

    tmpdir="$(mktemp -d)"
    TEMP_PATHS+=("$tmpdir")
    info "Downloading the latest Dropbox daemon"
    curl -fL --progress-bar -o "$tmpdir/dropbox.tar.gz" \
        "https://www.dropbox.com/download?plat=lnx.x86_64" || return 1
    tar xzf "$tmpdir/dropbox.tar.gz" -C "$tmpdir" || return 1

    if pgrep -f "^$HOME/\.dropbox-dist/.*/dropbox$" >/dev/null 2>&1; then
        was_running=1
        info "Stopping the running Dropbox daemon"
        pkill -f "^$HOME/\.dropbox-dist/.*/dropbox$" 2>/dev/null || true
        sleep 1
    fi

    # Replace the daemon tree so old version directories do not accumulate.
    rm -rf "$HOME/.dropbox-dist" || return 1
    mkdir -p "$HOME/.dropbox-dist" || return 1
    cp -a "$tmpdir/.dropbox-dist/." "$HOME/.dropbox-dist/" || return 1
    rm -rf "$tmpdir"

    install_dropbox_cli "$pkg" || return 1

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
    if [[ "$ARCH" != amd64 ]]; then
        echo "Dropbox's Linux client is x86_64-only (detected $ARCH)." >&2
        return 1
    fi

    disable_dropbox_repo || return 1

    local pkg
    if ! pkg="$(latest_dropbox_deb)"; then
        echo "Could not fetch or find the latest Dropbox package." >&2
        return 1
    fi
    if [[ -z "$pkg" ]]; then
        echo "Could not find the latest Dropbox package." >&2
        return 1
    fi

    if dropbox_deb_compatible; then
        install_deb "https://linux.dropbox.com/packages/ubuntu/$pkg" || return 1
        info "Dropbox installed. Run 'dropbox start -i' if it is not already running."
    else
        info "The current Dropbox .deb needs GTK 4.8+; using Dropbox's official tarball instead"
        install_dropbox_tarball "$pkg" || return 1
    fi
}

install_obsidian() {
    info "Installing Obsidian"
    if [[ "$ARCH" != amd64 ]]; then
        echo "Obsidian's .deb is amd64-only (detected $ARCH). Use the AppImage from GitHub instead." >&2
        return 1
    fi

    local url
    if ! url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
        | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+_amd64\.deb"' \
        | sed -E 's/.*"(https:[^"]+)".*/\1/' \
        | sed -n '1p')"; then
        echo "Could not fetch the latest Obsidian release." >&2
        return 1
    fi
    if [[ -z "$url" ]]; then
        echo "Could not find the latest Obsidian release." >&2
        return 1
    fi
    install_deb "$url" || return 1
}

install_opencode() {
    info "Installing opencode"
    curl -fsSL https://opencode.ai/v2/install | bash
}

install_codex() {
    info "Installing Codex CLI"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
}

install_cursor() {
    info "Installing Cursor CLI"
    curl -fsS https://cursor.com/install | bash
}

install_claude() {
    info "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
}

install_uv() {
    local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
    export PATH="$bin_dir:$PATH"

    if command -v uv >/dev/null 2>&1; then
        if ((APPS_ONLY)); then
            info "uv is already installed ($(uv --version 2>/dev/null || echo 'unknown version'))"
        fi
        return 0
    fi

    info "Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh || return 1
    if ! command -v uv >/dev/null 2>&1; then
        echo "uv was installed but is not on PATH. Add $bin_dir to PATH." >&2
        return 1
    fi
    info "Installed $(uv --version)"
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

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        return 1
    fi
}

find_ssh_key() {
    local key
    for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ecdsa"; do
        if [[ -f "$key" ]]; then
            printf '%s\n' "$key"
            return 0
        fi
    done
    return 1
}

generate_ssh_key() {
    local comment
    comment="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
    comment="${comment:-$(whoami)@$(hostname)}"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    info "Generating an ed25519 SSH key at $HOME/.ssh/id_ed25519"
    if ! ssh-keygen -t ed25519 -C "$comment" -f "$HOME/.ssh/id_ed25519" -N ""; then
        echo "warning: could not generate an SSH key." >&2
        return 1
    fi
    SSH_KEYFILE="$HOME/.ssh/id_ed25519"
}

github_ssh_ok() {
    local key="${1:-}" output
    local ssh_args=(
        -o BatchMode=yes
        -o ConnectTimeout=5
        -o StrictHostKeyChecking=accept-new
    )
    if [[ -n "$key" ]]; then
        ssh_args=(-i "$key" -o IdentitiesOnly=yes "${ssh_args[@]}")
    fi

    # GitHub closes the connection with status 1 even when authentication works.
    output="$(ssh "${ssh_args[@]}" -T git@github.com 2>&1)" || true
    grep -qi "successfully authenticated" <<<"$output"
}

show_ssh_key() {
    local key="$1"
    [[ -r "${key}.pub" ]] || return 0

    echo
    echo "Add this public key to GitHub: https://github.com/settings/ssh/new"
    echo "----------------------------------------------------------------------"
    cat "${key}.pub"
    echo "----------------------------------------------------------------------"
}

setup_ssh_access() {
    if ((REPO_URL_EXPLICIT)) && [[ "$REPO_URL" != git@* && "$REPO_URL" != ssh://* ]]; then
        info "Skipping SSH setup because REPO_URL already uses HTTPS"
        return 0
    fi

    if [[ "$SSH_KEY_SETUP" == no ]]; then
        info "Skipping SSH key setup and GitHub SSH check"
        return 0
    fi

    SSH_KEYFILE="$(find_ssh_key || true)"
    local generated=0

    # This also picks up keys loaded in ssh-agent or configured in ~/.ssh/config.
    if github_ssh_ok ""; then
        SSH_AUTH_OK=1
        info "GitHub SSH authentication succeeded"
        return 0
    fi

    if [[ -z "$SSH_KEYFILE" ]]; then
        case "$SSH_KEY_SETUP" in
            yes)
                generate_ssh_key || return 0
                generated=1
                ;;
            *)
                if [[ ! -t 0 ]]; then
                    info "No SSH key found; SSH will be unavailable"
                    return 0
                fi
                local reply
                read -rp "No GitHub SSH key found. Generate an ed25519 key without a passphrase? [Y/n] " reply
                case "$reply" in
                    [nN]*) info "Skipping SSH key setup"; return 0 ;;
                esac
                generate_ssh_key || return 0
                generated=1
                ;;
        esac
    fi

    if ((generated)); then
        info "The new SSH key is not on GitHub yet"
    else
        info "GitHub does not accept $SSH_KEYFILE yet"
    fi
    show_ssh_key "$SSH_KEYFILE"
    if [[ -t 0 ]]; then
        local reply
        read -rp "Add the key at https://github.com/settings/ssh/new, then press Enter to check again (or type s to skip): " reply
        if [[ "$reply" != [sS] ]] && github_ssh_ok "$SSH_KEYFILE"; then
            SSH_AUTH_OK=1
            info "GitHub SSH authentication succeeded."
        elif [[ "$reply" != [sS] ]]; then
            echo "warning: GitHub still does not accept the key; continuing over HTTPS." >&2
        fi
    fi
}

configure_repo_url() {
    if ((REPO_URL_EXPLICIT)); then
        info "Using repository URL from REPO_URL: $REPO_URL"
    elif [[ "$SSH_AUTH_OK" == 1 ]]; then
        REPO_URL="$SSH_REPO_URL"
        info "Cloning over SSH"
    else
        REPO_URL="$HTTPS_REPO_URL"
        info "Cloning over HTTPS"
    fi

    GIT_REPO_CONFIG=()
    if [[ "$REPO_URL" == https://* ]]; then
        GIT_REPO_CONFIG=(-c "url.https://github.com/.insteadOf=git@github.com:")
    fi
}

switch_origin_to_ssh() {
    if ((REPO_URL_EXPLICIT)); then
        return 0
    fi
    if [[ "$SSH_KEY_SETUP" == no || ! -d "$INSTALL_DIR/.git" ]]; then
        return 0
    fi

    local origin
    origin="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$origin" == https://* ]] || return 0

    if github_ssh_ok ""; then
        git -C "$INSTALL_DIR" remote set-url origin "$SSH_REPO_URL"
        info "Switched $INSTALL_DIR origin to SSH"
    fi
}

preflight_apps() {
    require_command curl || return 1

    local needs_apt=0 app
    for app in "${SELECTED[@]}"; do
        case "$app" in
            discord | dropbox | obsidian) needs_apt=1 ;;
        esac
    done

    if ((needs_apt)); then
        require_command sudo || return 1
        require_command apt-get || return 1
        disable_stale_dropbox_repo
        sudo apt update
    fi
}

check_repo_access() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        return 0
    fi

    if ! git "${GIT_REPO_CONFIG[@]}" ls-remote "$REPO_URL" HEAD >/dev/null 2>&1; then
        echo "Could not access $REPO_URL." >&2
        echo "Check your SSH key, or run with --no-ssh-key to clone over HTTPS." >&2
        return 1
    fi
}

setup_base() {
    info "Installing for Ubuntu $UBUNTU_VERSION"
    info "Installing basic dependencies"
    disable_stale_dropbox_repo
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
        wget
        openssh-client
        xclip
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

    info "Checking GitHub access"
    setup_ssh_access
    configure_repo_url

    info "Checking repository access"
    check_repo_access

    install_uv

    info "Cloning the config"
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "$INSTALL_DIR already exists, updating it"
        git -C "$INSTALL_DIR" pull --ff-only ||
            echo "warning: could not fast-forward $INSTALL_DIR, leaving it as is"
        git -C "$INSTALL_DIR" "${GIT_REPO_CONFIG[@]}" submodule update --init --recursive
    else
        if [[ -e "$INSTALL_DIR" ]]; then
            mv "$INSTALL_DIR" "$INSTALL_DIR.bak.$(date +%s)"
        fi
        git "${GIT_REPO_CONFIG[@]}" clone --recursive "$REPO_URL" "$INSTALL_DIR"
    fi
    switch_origin_to_ssh

    info "Setting symbolic links"
    if [[ -e "$HOME/.vimrc" && ! -L "$HOME/.vimrc" ]]; then
        mv "$HOME/.vimrc" "$HOME/.vimrc.bak.$(date +%s)"
    fi
    ln -sfn "$INSTALL_DIR/vimrc" "$HOME/.vimrc"
    if [[ -e "$HOME/.byobu" && ! -L "$HOME/.byobu" ]]; then
        mv "$HOME/.byobu" "$HOME/.byobu.bak.$(date +%s)"
    fi
    ln -sfn "$INSTALL_DIR/byobu" "$HOME/.byobu"

    local aliases_line
    aliases_line="$(printf 'source %q' "$INSTALL_DIR/aliases")"
    if ! grep -qF "$aliases_line" "$HOME/.bashrc" 2>/dev/null; then
        info "Adding aliases to ~/.bashrc"
        printf '%s\n' "$aliases_line" >>"$HOME/.bashrc"
    fi

    if [[ ! -d "$HOME/miniforge3" ]]; then
        local arch="x86_64"
        if [[ "$(uname -m)" == "aarch64" ]]; then
            arch="aarch64"
        fi

        local installer="$HOME/Miniforge3-Linux-${arch}.sh"
        TEMP_PATHS+=("$installer")
        info "Downloading miniforge for conda and mamba"
        curl -fL -o "$installer" \
            "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${arch}.sh"
        sh "$installer" -b
        rm -f "$installer"
    fi

    # Setup git properly
    git config --global core.editor "vim"
    if [[ -z "$(git config --global user.name)" ]]; then
        if [[ -n "${GIT_NAME:-}" ]]; then
            git config --global user.name "$GIT_NAME"
        elif [[ -t 0 ]]; then
            local git_name
            read -rp "Enter your name for git: " git_name
            git config --global user.name "$git_name"
        else
            echo "warning: git user.name is not set. Run: git config --global user.name 'Your Name'" >&2
        fi
    fi
    if [[ -z "$(git config --global user.email)" ]]; then
        if [[ -n "${GIT_EMAIL:-}" ]]; then
            git config --global user.email "$GIT_EMAIL"
        elif [[ -t 0 ]]; then
            local git_email
            read -rp "Enter your email for git: " git_email
            git config --global user.email "$git_email"
        else
            echo "warning: git user.email is not set. Run: git config --global user.email 'you@example.com'" >&2
        fi
    fi
    git config --global pull.rebase false
    git config --global push.autoSetupRemote true

    export PATH="$HOME/.local/bin:$HOME/miniforge3/bin:$PATH"

    if [[ -x "$HOME/miniforge3/bin/mamba" ]]; then
        "$HOME/miniforge3/bin/mamba" init
    fi
}

SELECTED=()
INSTALL_ALL=0
APPS_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        20 | 22 | 24 | 26) UBUNTU_VERSION="$1" ;;
        --ssh-key) SSH_KEY_SETUP=yes ;;
        --no-ssh-key) SSH_KEY_SETUP=no ;;
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

if ((APPS_ONLY)); then
    preflight_apps
fi

if ((APPS_ONLY == 0)); then
    if [[ -d "$INSTALL_DIR/.git" ]] && ((${#SELECTED[@]})); then
        info "Config already exists; running setup too (use --apps-only to skip it)"
    fi
    setup_base
fi

failed_apps=()
for app in "${SELECTED[@]}"; do
    # The base setup already installs uv; do not run it twice.
    if [[ "$app" == "uv" ]] && ((APPS_ONLY == 0)); then
        continue
    fi
    if ! "${APP_INSTALL[$app]}"; then
        failed_apps+=("$app")
    fi
done

if ((${#failed_apps[@]})); then
    echo "Failed to install: ${failed_apps[*]}" >&2
    exit 1
fi

if ((${#SELECTED[@]})); then
    info "Done. Installed: ${SELECTED[*]}"
else
    info "Done."
fi

if ((APPS_ONLY == 0)); then
    info "Restart your shell (or run 'source ~/.bashrc') to pick up PATH and shell changes."
fi
