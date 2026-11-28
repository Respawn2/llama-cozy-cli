#!/usr/bin/env bash
# llama-cozy installer — v0.3
# Usage:
#   ./install.sh                          install from a local checkout
#   curl -fsSL <url>/install.sh | bash    install from GitHub (downloads binary)
#   ./install.sh --uninstall              remove binary, completions, aliases
#   ./install.sh --uninstall --purge      also remove config and state
#   ./install.sh --migrate                import settings from v0.1
#   ./install.sh --prefix DIR             install binary to DIR (default: ~/.local)
#   ./install.sh --no-completions
#   ./install.sh --no-aliases
#   ./install.sh --yes                    non-interactive
#
# NEW flags for remote install:
#   --repo USER/REPO      GitHub repo (default: igor/llama-cozy)
#   --tag TAG             git tag / release (default: v<VERSION>)
#   --sha256 HASH         verify downloaded binary against this hash
#   --force               re-download even if a local copy exists
#
# License: MIT

set -euo pipefail

PROG="llama-cozy"
VERSION="0.3.0"

# ---------------------------------------------------------------- paths
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
BIN_PATH="$BIN_DIR/$PROG"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

CONFIG_DIR="$XDG_CONFIG_HOME/$PROG"
STATE_DIR="$XDG_STATE_HOME/$PROG"

BASH_COMP_DIR="$XDG_DATA_HOME/bash-completion/completions"
ZSH_COMP_DIR="${ZSH_COMP_DIR:-$HOME/.zfunc}"
FISH_COMP_DIR="$XDG_CONFIG_HOME/fish/completions"

# NEW: remote install defaults
REPO="${LLAMA_COZY_REPO:-igor/llama-cozy}"
TAG="${LLAMA_COZY_TAG:-v$VERSION}"
SHA256=""

# ---------------------------------------------------------------- flags
DO_UNINSTALL=0
DO_PURGE=0
DO_MIGRATE=0
DO_COMPLETIONS=1
DO_ALIASES=1
ASSUME_YES=0
FORCE=0

usage() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case $1 in
        --uninstall)       DO_UNINSTALL=1; shift ;;
        --purge)           DO_PURGE=1; shift ;;
        --migrate)         DO_MIGRATE=1; shift ;;
        --prefix)          PREFIX=${2:?"--prefix needs a value"}; BIN_DIR="$PREFIX/bin"; BIN_PATH="$BIN_DIR/$PROG"; shift 2 ;;
        --no-completions)  DO_COMPLETIONS=0; shift ;;
        --no-aliases)      DO_ALIASES=0; shift ;;
        --yes|-y)          ASSUME_YES=1; shift ;;
        # NEW
        --repo)            REPO=${2:?"--repo needs a value"}; shift 2 ;;
        --tag)             TAG=${2:?"--tag needs a value"}; shift 2 ;;
        --sha256)          SHA256=${2:?"--sha256 needs a value"}; shift 2 ;;
        --force)           FORCE=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# ---------------------------------------------------------------- helpers
info() { printf '%s\n' "$*" >&2; }
ok()   { printf '✅ %s\n' "$*" >&2; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }

confirm() {
    [ "$ASSUME_YES" = 1 ] && return 0
    local ans
    read -r -p "$1 [y/N] " ans || return 1
    [[ $ans == [yY]* ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

detect_shell() {
    local s
    s=$(basename "${SHELL:-}")
    case $s in
        fish|bash|zsh) printf '%s' "$s" ;;
        *) printf 'bash' ;;
    esac
}

# NEW: find the source binary — local checkout first, then download.
# Works for both `./install.sh` and `curl … | bash`.
find_source() {
    # $0 is "bash" under `curl | bash`, so BASH_SOURCE is the reliable one
    local self_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    fi

    # 1) local checkout next to the installer
    if [ -n "$self_dir" ] && [ -f "$self_dir/$PROG" ]; then
        printf '%s' "$self_dir/$PROG"
        return 0
    fi
    if [ -n "$self_dir" ] && [ -f "$self_dir/$PROG.sh" ]; then
        # tolerate the old name
        printf '%s' "$self_dir/$PROG.sh"
        return 0
    fi

    # 2) remote: download to a temp file
    have curl || die "curl is required for remote install"
    local url="https://raw.githubusercontent.com/$REPO/$TAG/$PROG"
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/$PROG.XXXXXX")
    info "⬇️  $url"
    curl -fsSL "$url" -o "$tmp" || { rm -f "$tmp"; die "Download failed: $url"; }

    if [ -n "$SHA256" ]; then
        local got
        got=$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')
        [ "$got" = "$SHA256" ] || { rm -f "$tmp"; die "sha256 mismatch: got $got, want $SHA256"; }
        ok "sha256 verified"
    fi

    printf '%s' "$tmp"
}

# ---------------------------------------------------------------- migrate (v0.1 → v0.3)
migrate_v01() {
    info "🔎 Looking for v0.1 leftovers…"
    local found=0
    local old_models="" old_prompt=""

    local fish_cfg="$XDG_CONFIG_HOME/fish/config.fish"
    if [ -f "$fish_cfg" ] && grep -q 'Added by llama-cozy-cli' "$fish_cfg" 2>/dev/null; then
        found=1
        old_models=$(grep -E 'set -gx LLAMA_MODELS_DIR' "$fish_cfg" | head -n1 | sed -E 's/.*LLAMA_MODELS_DIR "?([^"]*)"?/\1/')
        old_prompt=$(grep -E 'set -gx LLAMA_PROMPT' "$fish_cfg" | head -n1 | sed -E 's/.*LLAMA_PROMPT "?([^"]*)"?/\1/')
        info "  • fish config block in $fish_cfg"
    fi

    local envf="$HOME/.llama-cozy-env"
    if [ -f "$envf" ]; then
        found=1
        old_models=${old_models:-$(grep -E '^export LLAMA_MODELS_DIR=' "$envf" | head -n1 | cut -d= -f2- | tr -d '"')}
        old_prompt=${old_prompt:-$(grep -E '^export LLAMA_PROMPT=' "$envf" | head -n1 | cut -d= -f2- | tr -d '"')}
        info "  • env file $envf"
    fi

    if [ "$found" = 0 ]; then
        info "  · nothing to migrate"
        return 0
    fi

    mkdir -p "$CONFIG_DIR"
    local cfg="$CONFIG_DIR/config"
    touch "$cfg"

    if [ -n "$old_models" ] && ! grep -q '^MODELS_DIR=' "$cfg"; then
        printf 'MODELS_DIR=%s\n' "$old_models" >> "$cfg"
        ok "MODELS_DIR = $old_models"
    fi
    if [ -n "$old_prompt" ] && ! grep -q '^SYSTEM_PROMPT=' "$cfg"; then
        printf 'SYSTEM_PROMPT=%s\n' "${old_prompt//$'\n'/ }" >> "$cfg"
        ok "SYSTEM_PROMPT migrated"
    fi

    if confirm "Remove v0.1 leftovers (fish functions, env file, rc hooks)?"; then
        rm -f "$XDG_CONFIG_HOME/fish/functions/ai.fish" \
              "$XDG_CONFIG_HOME/fish/functions/ailist.fish" \
              "$envf"
        if [ -f "$fish_cfg" ]; then
            awk '
                /# === Added by llama-cozy-cli ===/ { skip=1; next }
                skip && /set -gx LLAMA_PROMPT/ { skip=0; next }
                !skip { print }
            ' "$fish_cfg" > "$fish_cfg.tmp" && mv "$fish_cfg.tmp" "$fish_cfg"
        fi
        for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
            [ -f "$rc" ] || continue
            sed -i.bak '/# === Added by llama-cozy-cli ===/,/llama-cozy-env/d' "$rc" 2>/dev/null || true
        done
        ok "v0.1 leftovers removed"
    else
        info "  · kept v0.1 leftovers (run ./install.sh --migrate again later)"
    fi
}

# ---------------------------------------------------------------- install
install_binary() {
    local src
    src=$(find_source)
    [ -f "$src" ] || die "No source binary found"

    mkdir -p "$BIN_DIR"

    # if src is a temp download, move it; if it's the checkout, copy it
    case "$src" in
        "${TMPDIR:-/tmp}"/*)
            install -m 0755 "$src" "$BIN_PATH"
            rm -f "$src"
            ;;
        *)
            install -m 0755 "$src" "$BIN_PATH"
            ;;
    esac
    ok "Installed $BIN_PATH"
}

install_completions() {
    mkdir -p "$BASH_COMP_DIR"
    if "$BIN_PATH" completions bash > "$BASH_COMP_DIR/$PROG" 2>/dev/null; then
        ok "bash completion → $BASH_COMP_DIR/$PROG"
    else
        warn "bash completion not generated (old binary?)"
    fi

    mkdir -p "$ZSH_COMP_DIR"
    if "$BIN_PATH" completions zsh > "$ZSH_COMP_DIR/_$PROG" 2>/dev/null; then
        ok "zsh completion → $ZSH_COMP_DIR/_$PROG"
        if ! grep -q "$ZSH_COMP_DIR" "$HOME/.zshrc" 2>/dev/null; then
            info "  · add to ~/.zshrc:  fpath+=($ZSH_COMP_DIR)"
        fi
    fi

    mkdir -p "$FISH_COMP_DIR"
    if "$BIN_PATH" completions fish > "$FISH_COMP_DIR/$PROG.fish" 2>/dev/null; then
        ok "fish completion → $FISH_COMP_DIR/$PROG.fish"
    fi
}

install_aliases() {
    local shell f; shell=$(detect_shell)
    info "🔗 Adding aliases for $shell (ai, ailist)…"

    case $shell in
        fish)
            f="$XDG_CONFIG_HOME/fish/conf.d/$PROG.fish"
            mkdir -p "$(dirname "$f")"
            cat > "$f" <<EOF
# Added by llama-cozy installer
alias ai '$PROG'
alias ailist '$PROG list'
EOF
            ok "aliases → $f"
            ;;
        bash)
            f="$XDG_CONFIG_HOME/$PROG/aliases.bash"
            mkdir -p "$(dirname "$f")"
            cat > "$f" <<EOF
# Added by llama-cozy installer
alias ai='$PROG'
alias ailist='$PROG list'
EOF
            if ! grep -q "$PROG/aliases.bash" "$HOME/.bashrc" 2>/dev/null; then
                printf '\n# Added by llama-cozy installer\n[ -f %q ] && . %q\n' "$f" "$f" >> "$HOME/.bashrc"
            fi
            ok "aliases → $f (hooked into ~/.bashrc)"
            ;;
        zsh)
            f="$XDG_CONFIG_HOME/$PROG/aliases.zsh"
            mkdir -p "$(dirname "$f")"
            cat > "$f" <<EOF
# Added by llama-cozy installer
alias ai='$PROG'
alias ailist='$PROG list'
EOF
            if ! grep -q "$PROG/aliases.zsh" "$HOME/.zshrc" 2>/dev/null; then
                printf '\n# Added by llama-cozy installer\n[ -f %q ] && . %q\n' "$f" "$f" >> "$HOME/.zshrc"
            fi
            ok "aliases → $f (hooked into ~/.zshrc)"
            ;;
    esac
}

check_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) ok "$BIN_DIR is in PATH" ;;
        *)
            warn "$BIN_DIR is NOT in PATH"
            info "  add to your shell rc:"
            info "    fish:  fish_add_path $BIN_DIR"
            info "    bash:  export PATH=\"$BIN_DIR:\$PATH\""
            info "    zsh:   export PATH=\"$BIN_DIR:\$PATH\""
            ;;
    esac
}

do_install() {
    info "🦙 llama-cozy installer v$VERSION"
    info "   prefix: $PREFIX"
    [ -n "$REPO" ] && info "   repo:   $REPO@$TAG"
    info ""

    if ! have llama-cli; then
        warn "llama-cli not found in PATH."
        info "  llama-cozy will still install, but 'run' will fail until you"
        info "  install llama.cpp or set BIN_DIR:"
        info "    llama-cozy config set BIN_DIR /path/to/llama.cpp/build/bin"
        confirm "Continue anyway?" || die "Aborted"
    fi

    install_binary
    check_path

    [ "$DO_COMPLETIONS" = 1 ] && install_completions
    [ "$DO_ALIASES" = 1 ]     && install_aliases

    info ""
    ok "Done. Try:  $PROG doctor"
    info "   then:     $PROG list"
}

# ---------------------------------------------------------------- uninstall
do_uninstall() {
    info "🧹 Uninstalling $PROG…"

    rm -f "$BIN_PATH" && ok "removed $BIN_PATH" || true
    rm -f "$BASH_COMP_DIR/$PROG"
    rm -f "$ZSH_COMP_DIR/_$PROG"
    rm -f "$FISH_COMP_DIR/$PROG.fish"

    rm -f "$XDG_CONFIG_HOME/fish/conf.d/$PROG.fish"
    rm -f "$XDG_CONFIG_HOME/$PROG/aliases.bash"
    rm -f "$XDG_CONFIG_HOME/$PROG/aliases.zsh"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        sed -i.bak "/llama-cozy installer/d" "$rc" 2>/dev/null || true
    done

    if [ "$DO_PURGE" = 1 ]; then
        rm -rf "$CONFIG_DIR" "$STATE_DIR"
        ok "purged config and state"
    else
        info "  · kept $CONFIG_DIR (use --purge to remove)"
        info "  · kept $STATE_DIR"
    fi
    ok "Uninstalled."
}

# ---------------------------------------------------------------- main
if [ "$DO_UNINSTALL" = 1 ]; then
    do_uninstall
    exit 0
fi

if [ "$DO_MIGRATE" = 1 ]; then
    migrate_v01
    exit 0
fi

do_install
