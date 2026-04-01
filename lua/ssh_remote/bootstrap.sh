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
# Dependency check + optional install
# Usage: check_dep <display-name> <binary-name> [install-function]
# Returns 0 if available after check, 1 otherwise.
# =============================================================================
check_dep() {
  local name="$1"
  local bin="$2"
  local installer="${3:-}"

  if command -v "$bin" &>/dev/null; then
    ok "$name"
    return 0
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

    if command -v "$bin" &>/dev/null; then
      ok "$name installed"
      return 0
    else
      err "$name install failed — you may need to install it manually."
      return 1
    fi
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

GIT_OK=0
NVIM_OK=0

check_dep "git"    "git"  ""             && GIT_OK=1
check_dep "neovim" "nvim" "install_neovim" && NVIM_OK=1

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
