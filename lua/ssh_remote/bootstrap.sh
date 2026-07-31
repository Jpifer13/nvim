#!/usr/bin/env bash
# =============================================================================
# nvim remote bootstrap
# Checks for required dependencies, prompts to install any that are missing,
# then clones / updates the nvim config from the public repo.
# =============================================================================

NVIM_CONFIG_REPO="https://github.com/Jpifer13/nvim"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
LAZY_PATH="$HOME/.local/share/nvim/lazy/lazy.nvim"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "${RED}✗${NC}  $*"; }
info() { echo -e "   $*"; }

echo ""
echo -e "${BOLD}┌──────────────────────────────────────┐${NC}"
echo -e "${BOLD}│         nvim remote setup             │${NC}"
echo -e "${BOLD}└──────────────────────────────────────┘${NC}"
echo ""

# =============================================================================
# Package manager detection
# =============================================================================
detect_pkg_manager() {
  if   command -v apt-get &>/dev/null; then echo "apt"
  elif command -v dnf     &>/dev/null; then echo "dnf"
  elif command -v yum     &>/dev/null; then echo "yum"
  elif command -v pacman  &>/dev/null; then echo "pacman"
  elif command -v brew    &>/dev/null; then echo "brew"
  else echo "unknown"
  fi
}

PKG_MANAGER=$(detect_pkg_manager)

install_package() {
  local pkg="$1"
  case "$PKG_MANAGER" in
    apt)    sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf     install -y "$pkg" ;;
    yum)    sudo yum     install -y "$pkg" ;;
    pacman) sudo pacman  -S --noconfirm "$pkg" ;;
    brew)         brew   install    "$pkg" ;;
    *)
      err "Unknown package manager — install ${pkg} manually and re-run."
      return 1
      ;;
  esac
}

# =============================================================================
# Neovim gets a special installer so we always get a recent version.
# Most distro package managers ship a very old neovim.
# =============================================================================
install_neovim() {
  if [ "$PKG_MANAGER" = "brew" ]; then
    brew install neovim
    return
  fi

  # GitHub release tarball (Linux x86_64 / arm64)
  local arch
  arch=$(uname -m)
  local url

  if [ "$arch" = "x86_64" ]; then
    url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
  elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
  else
    warn "Unsupported arch '${arch}' for automatic install — trying package manager..."
    install_package neovim
    return
  fi

  if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    err "Neither curl nor wget is available — cannot download neovim."
    info "Install curl or wget and try again."
    return 1
  fi

  local tmp
  tmp=$(mktemp -d)
  info "Downloading neovim from GitHub releases..."

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  else
    wget -q "$url" -O "$tmp/nvim.tar.gz"
  fi

  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  # Install to /usr/local so it is on PATH for all users
  local extracted_dir
  extracted_dir=$(find "$tmp" -maxdepth 1 -type d -name 'nvim-*' | head -1)
  sudo install -Dm755 "$extracted_dir/bin/nvim" /usr/local/bin/nvim
  sudo cp -r "$extracted_dir/lib"   /usr/local/ 2>/dev/null || true
  sudo cp -r "$extracted_dir/share" /usr/local/ 2>/dev/null || true

  rm -rf "$tmp"
}

# =============================================================================
# Node.js installer — package name varies by distro (nodejs vs node),
# and distro versions are often ancient, so use the official binary.
# =============================================================================
install_node() {
  if [ "$PKG_MANAGER" = "brew" ]; then
    brew install node
    return
  fi

  local arch
  arch=$(uname -m)
  local node_arch

  if [ "$arch" = "x86_64" ]; then
    node_arch="x64"
  elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    node_arch="arm64"
  else
    warn "Unsupported arch '${arch}' — trying package manager..."
    install_package nodejs
    return
  fi

  if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    err "Neither curl nor wget is available — cannot download node."
    return 1
  fi

  local tmp
  tmp=$(mktemp -d)

  # Resolve the actual latest v22.x filename instead of hardcoding a version
  local index_url="https://nodejs.org/dist/latest-v22.x/"
  local filename=""
  info "Resolving latest Node.js v22.x..."

  if command -v curl &>/dev/null; then
    filename=$(curl -fsSL "$index_url" | grep -oP "node-v[0-9.]+-linux-${node_arch}\\.tar\\.xz" | head -1)
  else
    filename=$(wget -qO- "$index_url" | grep -oP "node-v[0-9.]+-linux-${node_arch}\\.tar\\.xz" | head -1)
  fi

  if [ -z "$filename" ]; then
    err "Could not resolve Node.js download URL"
    rm -rf "$tmp"
    return 1
  fi

  local url="${index_url}${filename}"
  info "Downloading ${filename}..."

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$tmp/node.tar.xz"
  else
    wget -q "$url" -O "$tmp/node.tar.xz"
  fi

  tar -xJf "$tmp/node.tar.xz" -C "$tmp"

  local extracted_dir
  extracted_dir=$(find "$tmp" -maxdepth 1 -type d -name 'node-*' | head -1)
  sudo cp -r "$extracted_dir/bin/"*     /usr/local/bin/
  sudo cp -r "$extracted_dir/lib/"*     /usr/local/lib/ 2>/dev/null || true
  sudo cp -r "$extracted_dir/include/"* /usr/local/include/ 2>/dev/null || true
  sudo cp -r "$extracted_dir/share/"*   /usr/local/share/ 2>/dev/null || true

  rm -rf "$tmp"
  hash -r 2>/dev/null
}

# =============================================================================
# Claude Code installer — requires npm
# =============================================================================
install_claude_code() {
  # Refresh PATH in case node was just installed in this session
  hash -r 2>/dev/null
  local npm_bin=""
  if command -v npm &>/dev/null; then
    npm_bin="npm"
  else
    for p in /usr/local/bin/npm /usr/bin/npm; do
      if [ -x "$p" ]; then npm_bin="$p"; break; fi
    done
  fi
  if [ -z "$npm_bin" ]; then
    err "npm is required to install Claude Code."
    return 1
  fi
  # Use sudo so the binary lands in /usr/local/bin (on Neovim's PATH)
  sudo "$npm_bin" install -g @anthropic-ai/claude-code
}

# =============================================================================
# Dependency check + optional install
# Usage: check_dep <display-name> <binary-name> [install-function]
# Returns 0 if available after check, 1 otherwise.
# =============================================================================
check_dep() {
  local name="$1"
  local bin="$2"
  local installer="${3:-}"

  if command -v "$bin" &>/dev/null; then
    ok "$name ($(command -v "$bin"))"
    return 0
  fi

  # Check common install locations not always on PATH in SSH sessions
  local search_dirs="/usr/local/bin /usr/bin /snap/bin $HOME/.nvm/current/bin $HOME/.local/bin $HOME/.fnm/aliases/default/bin"
  for dir in $search_dirs; do
    if [ -x "$dir/$bin" ]; then
      ok "$name ($dir/$bin — adding to PATH)"
      export PATH="$dir:$PATH"
      hash -r 2>/dev/null
      return 0
    fi
  done
  # nvm: check version directories if no 'current' symlink
  if [ -d "$HOME/.nvm/versions/node" ]; then
    local nvm_node
    nvm_node=$(find "$HOME/.nvm/versions/node" -maxdepth 2 -name "$bin" -path "*/bin/$bin" 2>/dev/null | sort -V | tail -1)
    if [ -n "$nvm_node" ] && [ -x "$nvm_node" ]; then
      local nvm_bin_dir
      nvm_bin_dir=$(dirname "$nvm_node")
      ok "$name ($nvm_node — adding to PATH)"
      export PATH="$nvm_bin_dir:$PATH"
      hash -r 2>/dev/null
      return 0
    fi
  fi

  warn "$name is not installed"
  printf "   Install %s? [y/N] " "$name"
  read -r answer
  echo ""

  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if [ -n "$installer" ]; then
      $installer
    else
      install_package "$name"
    fi

    hash -r 2>/dev/null
    if command -v "$bin" &>/dev/null; then
      ok "$name installed"
      return 0
    fi
    # Check common locations in case PATH wasn't updated
    for dir in $search_dirs; do
      if [ -x "$dir/$bin" ]; then
        ok "$name installed ($dir/$bin — adding to PATH)"
        export PATH="$dir:$PATH"
        hash -r 2>/dev/null
        return 0
      fi
    done
    err "$name install failed — you may need to install it manually."
    return 1
  else
    info "Skipping $name"
    return 1
  fi
}

# =============================================================================
# Dependency checks
# =============================================================================
echo -e "${BOLD}Checking dependencies...${NC}"
echo ""

hash -r 2>/dev/null

GIT_OK=0
NVIM_OK=0

check_dep "git"         "git"    ""                    && GIT_OK=1
check_dep "neovim"      "nvim"   "install_neovim"       && NVIM_OK=1
check_dep "node"        "node"   "install_node"          && NODE_OK=1
if [ "${NODE_OK:-0}" -eq 1 ]; then
  check_dep "claude-code" "claude" "install_claude_code"
else
  warn "Skipping claude-code (requires node/npm)"
fi

echo ""

# git is required — we cannot clone the config without it
if [ "$GIT_OK" -eq 0 ]; then
  err "git is required to install the nvim config. Exiting."
  exit 1
fi

# =============================================================================
# Clone / update nvim config
# =============================================================================
echo -e "${BOLD}Setting up nvim config...${NC}"
echo ""

if [ -d "$NVIM_CONFIG_DIR/.git" ]; then
  info "Updating existing config..."
  git -C "$NVIM_CONFIG_DIR" pull --ff-only
  ok "Config up to date"
else
  # Back up any pre-existing non-git config directory
  if [ -d "$NVIM_CONFIG_DIR" ] && [ "$(ls -A "$NVIM_CONFIG_DIR" 2>/dev/null)" ]; then
    local_backup="${NVIM_CONFIG_DIR}.bak.$(date +%s)"
    warn "Existing config found — backing up to ${local_backup}"
    mv "$NVIM_CONFIG_DIR" "$local_backup"
  fi
  info "Cloning nvim config..."
  git clone "$NVIM_CONFIG_REPO" "$NVIM_CONFIG_DIR"
  ok "Config cloned"
fi

# =============================================================================
# lazy.nvim bootstrap (required for first nvim launch)
# =============================================================================
echo ""
if [ ! -d "$LAZY_PATH" ]; then
  info "Installing lazy.nvim..."
  git clone --filter=blob:none \
    https://github.com/folke/lazy.nvim.git \
    --branch=stable \
    "$LAZY_PATH"
  ok "lazy.nvim installed"
else
  ok "lazy.nvim already present"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${BOLD}──────────────────────────────────────────${NC}"
if [ "$NVIM_OK" -eq 1 ] || command -v nvim &>/dev/null; then
  ok "All done!  Run ${BOLD}nvim${NC} to start — plugins install automatically on first launch."
else
  warn "Config is installed but neovim is not available."
  info "Install neovim, then run 'nvim'."
fi
echo ""
