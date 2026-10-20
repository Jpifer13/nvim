#!/usr/bin/env bash
# Pack this config, its plugins, its LSP servers and its treesitter parsers onto a
# thumbdrive, so a machine that cannot reach github.com/Jpifer13 can install the lot.
#
#   scripts/export-to-usb.sh /Volumes/MY_DRIVE
#
# Everything ships as tar archives rather than loose files on purpose: exFAT and FAT32
# (what most thumbdrives are) store neither the executable bit nor symlinks, so a plain
# copy arrives with every Mason binary unexecutable. tar carries both through intact.
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

# Plugins, LSP servers/debug adapters, and the compiled treesitter parsers. Everything
# else under the share dir is local state (chat history, harpoon marks, quest progress)
# that belongs to this machine, so it stays here.
SHARE_PARTS=(lazy mason site)

usage() {
    cat >&2 <<EOF
usage: $(basename "$0") DESTINATION [--no-compress]

  DESTINATION    where to write the bundle (a mounted drive, or any directory)
  --no-compress  skip gzip: much faster, roughly twice the size

Writes DESTINATION/nvim-export-<timestamp>/ containing the archives, an install.sh to
run on the other machine, a MANIFEST.txt, and a README.md.
EOF
    exit 2
}

[[ $# -ge 1 ]] || usage
DEST_ROOT="$1"
shift
COMPRESS=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-compress) COMPRESS=0 ;;
        -h | --help) usage ;;
        *) echo "unknown argument: $1" >&2 && usage ;;
    esac
    shift
done

[[ -d "$CONFIG_DIR" ]] || { echo "no config at $CONFIG_DIR" >&2; exit 1; }
[[ -d "$DEST_ROOT" ]] || { echo "destination $DEST_ROOT is not a directory (is the drive mounted?)" >&2; exit 1; }

for part in "${SHARE_PARTS[@]}"; do
    [[ -d "$SHARE_DIR/$part" ]] || echo "warning: $SHARE_DIR/$part is missing; it will not be in the bundle" >&2
done

STAMP="$(date +%Y%m%d-%H%M)"
OUT="$DEST_ROOT/nvim-export-$STAMP"
mkdir -p "$OUT"

if [[ $COMPRESS -eq 1 ]]; then
    TAR_FLAGS=(-czf)
    EXT="tar.gz"
else
    TAR_FLAGS=(-cf)
    EXT="tar"
fi

echo "==> packing config"
tar "${TAR_FLAGS[@]}" "$OUT/nvim-config.$EXT" \
    --exclude '.DS_Store' \
    -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"

echo "==> packing plugins, LSP servers and parsers (this is the big one)"
present=()
for part in "${SHARE_PARTS[@]}"; do
    [[ -d "$SHARE_DIR/$part" ]] && present+=("$part")
done
tar "${TAR_FLAGS[@]}" "$OUT/nvim-share.$EXT" --exclude '.DS_Store' -C "$SHARE_DIR" "${present[@]}"

# What the other machine is compared against, and what a human needs to read.
{
    echo "exported:     $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "from:         $(hostname -s)"
    echo "platform:     $(uname -ms)"
    echo "neovim:       $(nvim --version | head -1)"
    echo "config commit: $(git -C "$CONFIG_DIR" rev-parse --short HEAD 2>/dev/null || echo 'not a git repo')"
    echo "archives:     nvim-config.$EXT nvim-share.$EXT"
    echo "share parts:  ${present[*]}"
    echo
    echo "tools this config expects on the target machine:"
    for tool in git nvim node go mvn python3 rg fd aws; do
        printf '  %-8s %s\n' "$tool" "$(command -v "$tool" || echo 'MISSING here too')"
    done
    echo
    echo "hardcoded paths in this config (see README):"
    printf '  black  %s\n' "$HOME/.pyenv/versions/3.13.3/bin/black"
    printf '  jdk21  %s\n' "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
} >"$OUT/MANIFEST.txt"

cp "$(dirname "$0")/usb-install.sh" "$OUT/install.sh"
cp "$(dirname "$0")/usb-README.md" "$OUT/README.md"
chmod +x "$OUT/install.sh"
sed -i '' "s/@EXT@/$EXT/g" "$OUT/install.sh"

echo
echo "==> done: $OUT"
du -sh "$OUT"/* | sed 's/^/    /'
echo
echo "On the other Mac: open the drive, then run ./install.sh"
