#!/usr/bin/env bash
# Install the exported Neovim config, plugins, LSP servers and parsers on this machine.
# Run it from the folder it sits in (on the thumbdrive). Nothing here needs the network.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT="@EXT@"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
STAMP="$(date +%Y%m%d-%H%M%S)"
SHARE_PARTS=(lazy mason site)

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

[[ -f "$HERE/nvim-config.$EXT" ]] || { echo "nvim-config.$EXT is missing next to this script" >&2; exit 1; }

say "checking this machine"
cat "$HERE/MANIFEST.txt" | sed 's/^/    /'

want_platform="$(awk '/^platform:/ {print $2, $3}' "$HERE/MANIFEST.txt")"
have_platform="$(uname -ms)"
if [[ "$want_platform" != "$have_platform" ]]; then
    warn "bundle built on '$want_platform' but this is '$have_platform'."
    warn "The Mason LSP binaries and the compiled treesitter parsers will NOT run here;"
    warn "after installing, use :Mason to reinstall the servers and :TSEnsure for parsers."
fi

if ! command -v nvim >/dev/null; then
    warn "neovim is not installed here. Install it first (brew install neovim), then re-run."
    exit 1
fi
want_nvim="$(awk '/^neovim:/ {print $3}' "$HERE/MANIFEST.txt")"
have_nvim="$(nvim --version | head -1 | awk '{print $2}')"
if [[ "${want_nvim%.*}" != "${have_nvim%.*}" ]]; then
    warn "bundle built against Neovim $want_nvim, this machine has $have_nvim."
    warn "Treesitter parsers are tied to Neovim's parser ABI; if highlighting misbehaves, run :TSEnsure."
fi

say "backing up anything already here"
backup_root="$HOME/.nvim-backup-$STAMP"
moved=0
if [[ -e "$CONFIG_DIR" ]]; then
    mkdir -p "$backup_root"
    mv "$CONFIG_DIR" "$backup_root/config"
    moved=1
fi
for part in "${SHARE_PARTS[@]}"; do
    if [[ -e "$SHARE_DIR/$part" ]]; then
        mkdir -p "$backup_root/share"
        mv "$SHARE_DIR/$part" "$backup_root/share/$part"
        moved=1
    fi
done
if [[ $moved -eq 1 ]]; then
    echo "    previous setup moved to $backup_root"
else
    echo "    nothing to back up"
fi

say "installing config"
mkdir -p "$(dirname "$CONFIG_DIR")"
tar -xf "$HERE/nvim-config.$EXT" -C "$(dirname "$CONFIG_DIR")"

say "installing plugins, LSP servers and parsers"
mkdir -p "$SHARE_DIR"
[[ -f "$HERE/nvim-share.$EXT" ]] && tar -xf "$HERE/nvim-share.$EXT" -C "$SHARE_DIR"

# The config is a git repo whose origin is a personal account this machine may not reach —
# and an absent-minded `git push` from here would send work edits there. Keep the history,
# drop the remote. README says how to put it back.
if git -C "$CONFIG_DIR" remote get-url origin >/dev/null 2>&1; then
    origin="$(git -C "$CONFIG_DIR" remote get-url origin)"
    git -C "$CONFIG_DIR" remote remove origin
    echo "    removed git remote origin ($origin); history kept"
fi

say "checking what this config expects"
missing=0
check() { # check <command> <what it is for> <how to get it>
    if command -v "$1" >/dev/null; then
        printf '    \033[32mok\033[0m       %-8s %s\n' "$1" "$(command -v "$1")"
    else
        printf '    \033[31mmissing\033[0m  %-8s %s — %s\n' "$1" "$2" "$3"
        missing=1
    fi
}
check git "version control, lazy.nvim" "xcode-select --install"
check node "copilot, ts_ls" "brew install node"
check rg "telescope live grep" "brew install ripgrep"
check fd "telescope file finding" "brew install fd"
check go "Go tooling" "brew install go"
check mvn "Java test runner" "brew install maven"
check python3 "python tooling" "brew install python"
check aws "AWS profile selector, FastAPI debug flow" "brew install awscli"

check_path() { # check_path <path> <what> <how>
    if [[ -e "$1" ]]; then
        printf '    \033[32mok\033[0m       %s\n' "$1"
    else
        printf '    \033[31mmissing\033[0m  %s — %s\n' "$1" "$2"
        missing=1
    fi
}
echo "    paths this config hardcodes:"
check_path "$HOME/.pyenv/versions/3.13.3/bin/black" "format-on-save for Python: pyenv install 3.13.3 && pip install black (or edit lua/plugins/formatting.lua)"
check_path "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" "jdtls and the Maven runner: brew install openjdk@21 (or edit lua/java/{init,jdtls,maven}.lua)"

say "done"
cat <<EOF
    Start Neovim: nvim
    Then check:   :Lazy        all plugins should be installed, nothing pending
                  :Mason       servers present (pyright, lua_ls, gopls, jdtls, …)
                  :checkhealth
    Still needs the network, once, on this machine:
                  :Copilot auth     (GitHub Copilot sign-in)
                  claude            (Claude Code CLI, if you want <leader>a*)
EOF
[[ $missing -eq 1 ]] && echo "
Some tools above are missing. Neovim will still start; the features that use them will not."
exit 0
