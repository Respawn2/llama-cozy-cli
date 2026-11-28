#!/usr/bin/env bash
# llama-cozy-cli installer — any Linux distro, any shell.
#
#   ./install.sh                    interactive install into ~/.local
#   ./install.sh --yes              non-interactive, sensible defaults
#   ./install.sh --prefix /usr/local   system-wide (uses sudo when needed)
#   ./install.sh --uninstall [--purge]

set -u

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="$HOME/.local"
MODELS_DIR=""
PROMPT=""
YES=0
ACTION=install
PURGE=0
SUDO=""

BEGIN="# >>> llama-cozy-cli >>>"
END="# <<< llama-cozy-cli <<<"

say()  { printf '%s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case $1 in
        --prefix)      PREFIX=${2:?"--prefix needs a path"}; shift 2 ;;
        --models-dir)  MODELS_DIR=${2:?"--models-dir needs a path"}; shift 2 ;;
        --prompt)      PROMPT=${2:?"--prompt needs text"}; shift 2 ;;
        -y|--yes)      YES=1; shift ;;
        --uninstall)   ACTION=uninstall; shift ;;
        --purge)       PURGE=1; shift ;;
        -h|--help)     usage; exit 0 ;;
        *)             die "Unknown option: $1 (see --help)" ;;
    esac
done

PREFIX=${PREFIX/#\~/$HOME}
BINDIR="$PREFIX/bin"
CONF_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
BASH_COMP="$PREFIX/share/bash-completion/completions"
ZSH_COMP="$PREFIX/share/zsh/site-functions"
if [ "$PREFIX" = "$HOME/.local" ]; then
    FISH_COMP="$CONF_HOME/fish/completions"
else
    FISH_COMP="$PREFIX/share/fish/vendor_completions.d"
fi

# Use sudo only when the target isn't writable by us.
probe=$PREFIX; while [ ! -d "$probe" ] && [ "$probe" != "/" ]; do probe=$(dirname "$probe"); done
if [ ! -w "$probe" ]; then
    command -v sudo >/dev/null 2>&1 || die "$PREFIX is not writable and sudo is missing"
    SUDO=sudo
fi

ask() {  # ask "question" "default"
    local ans
    if [ $YES = 1 ] || [ ! -t 0 ]; then printf '%s' "$2"; return; fi
    read -r -e -p "$1 [$2]: " ans || true
    printf '%s' "${ans:-$2}"
}

# ---------------------------------------------------------- rc-file blocks
drop_block() {
    [ -f "$1" ] || return 0
    sed -i "/$BEGIN/,/$END/d" "$1"
}
put_block() {  # put_block FILE BODY
    [ -f "$1" ] && [ ! -f "$1.cozy-bak" ] && cp "$1" "$1.cozy-bak"
    mkdir -p "$(dirname "$1")"; touch "$1"
    drop_block "$1"
    printf '\n%s\n%s\n%s\n' "$BEGIN" "$2" "$END" >> "$1"
}
zshrc() { printf '%s' "${ZDOTDIR:-$HOME}/.zshrc"; }

# ---------------------------------------------------------- v0 leftovers
# The first version installed fish functions / a bash env file. They shadow the
# new executable, so they must go. Old settings are reused as defaults.
LEGACY_DIR=""; LEGACY_PROMPT=""
migrate_legacy() {
    local fcfg="$CONF_HOME/fish/config.fish" f envf="$HOME/.llama-cozy-env" rc

    if [ -f "$fcfg" ] && grep -q 'Added by llama-cozy-cli' "$fcfg"; then
        LEGACY_DIR=$(sed -n 's/^set -gx LLAMA_MODELS_DIR "\(.*\)"$/\1/p' "$fcfg" | tail -n1)
        LEGACY_PROMPT=$(sed -n 's/^set -gx LLAMA_PROMPT "\(.*\)"$/\1/p' "$fcfg" | tail -n1)
        [ -f "$fcfg.cozy-bak" ] || cp "$fcfg" "$fcfg.cozy-bak"
        sed -i '/# === Added by llama-cozy-cli ===/,/^set -gx LLAMA_PROMPT/d' "$fcfg"
        say "🧹 removed old block from $fcfg"
    fi
    for f in ai ailist; do
        if [ -f "$CONF_HOME/fish/functions/$f.fish" ] && grep -q 'llama' "$CONF_HOME/fish/functions/$f.fish"; then
            rm -f "$CONF_HOME/fish/functions/$f.fish"; say "🧹 removed old fish function $f.fish"
        fi
    done
    if [ -f "$envf" ]; then
        [ -z "$LEGACY_DIR" ] && LEGACY_DIR=$(sed -n 's/^export LLAMA_MODELS_DIR="\(.*\)"$/\1/p' "$envf" | tail -n1)
        [ -z "$LEGACY_PROMPT" ] && LEGACY_PROMPT=$(sed -n 's/^export LLAMA_PROMPT="\(.*\)"$/\1/p' "$envf" | tail -n1)
        rm -f "$envf"; say "🧹 removed old $envf"
    fi
    for rc in "$HOME/.bashrc" "$(zshrc)"; do
        if [ -f "$rc" ] && grep -q 'llama-cozy-env' "$rc"; then
            [ -f "$rc.cozy-bak" ] || cp "$rc" "$rc.cozy-bak"
            sed -i '/# === Added by llama-cozy-cli ===/,/llama-cozy-env/d' "$rc"
            say "🧹 removed old hook from $rc"
        fi
    done
    [ "$LEGACY_DIR" = "REPLACE_PATH" ] && LEGACY_DIR=""
    [ "$LEGACY_PROMPT" = "REPLACE_PROMPT" ] && LEGACY_PROMPT=""
    return 0
}

# ---------------------------------------------------------- uninstall
do_uninstall() {
    say "🐐 llama-cozy-cli: uninstalling…"
    $SUDO rm -f "$BINDIR/llama-cozy" "$BINDIR/ai" "$BINDIR/ailist" \
                "$BASH_COMP/ai" "$ZSH_COMP/_ai" "$FISH_COMP/ai.fish"
    migrate_legacy
    drop_block "$HOME/.bashrc"
    drop_block "$(zshrc)"
    if command -v fish >/dev/null 2>&1; then
        fish -c "set -l i (contains -i -- '$BINDIR' \$fish_user_paths); and set -e -U fish_user_paths[\$i]" 2>/dev/null
    fi
    if [ $PURGE = 1 ]; then
        rm -rf "$CONF_HOME/llama-cozy" "${XDG_STATE_HOME:-$HOME/.local/state}/llama-cozy"
        say "🧹 settings removed"
    else
        say "ℹ️  settings kept in $CONF_HOME/llama-cozy (use --purge to delete)"
    fi
    say "✅ Done. Your model files were never touched."
}

# ---------------------------------------------------------- install
do_install() {
    say "🦙 llama-cozy-cli installer"
    say "--------------------------------------------------"
    [ -f "$SRC/bin/llama-cozy" ] || die "Run this from the repository folder (bin/llama-cozy not found)."
    [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 4 ]; } \
        || die "bash >= 4.4 is required"

    migrate_legacy

    # llama.cpp present?
    local bindir_llama=""
    if ! command -v llama-cli >/dev/null 2>&1; then
        local c
        for c in "$HOME/llama.cpp/build/bin" "$HOME/.local/llama.cpp/bin" "/opt/llama.cpp/bin" "/usr/local/bin"; do
            [ -x "$c/llama-cli" ] && { bindir_llama=$c; break; }
        done
        if [ -n "$bindir_llama" ]; then say "🔍 found llama.cpp in $bindir_llama (not in PATH)"
        else warn "llama-cli not found. Install llama.cpp (https://github.com/ggml-org/llama.cpp) — you can still install now."; fi
    fi

    # Settings
    local cfg="$CONF_HOME/llama-cozy/config" existing=""
    [ -f "$cfg" ] && existing=$(sed -n 's/^MODELS_DIR=//p' "$cfg" | tail -n1)
    if [ -z "$MODELS_DIR" ]; then
        local def="${existing:-$LEGACY_DIR}" c
        if [ -z "$def" ]; then
            for c in "$HOME/.lmstudio/models" "$HOME/.cache/llama.cpp" "$HOME/models"; do
                [ -d "$c" ] && { def=$c; break; }
            done
        fi
        [ -z "$def" ] && def="${XDG_DATA_HOME:-$HOME/.local/share}/llama-cozy/models"
        MODELS_DIR=$(ask "📂 Folder with your .gguf models" "$def")
    fi
    MODELS_DIR=${MODELS_DIR/#\~/$HOME}
    [ -d "$MODELS_DIR" ] || { mkdir -p "$MODELS_DIR" 2>/dev/null && say "📁 created $MODELS_DIR"; }

    if [ -z "$PROMPT" ] && [ -n "$LEGACY_PROMPT" ]; then PROMPT=$LEGACY_PROMPT; fi

    # Files
    $SUDO install -Dm755 "$SRC/bin/llama-cozy" "$BINDIR/llama-cozy" || die "copy failed"
    $SUDO ln -sf llama-cozy "$BINDIR/ai"
    $SUDO ln -sf llama-cozy "$BINDIR/ailist"
    say "📦 installed ai, ailist, llama-cozy → $BINDIR"

    $SUDO install -Dm644 "$SRC/completions/ai.bash" "$BASH_COMP/ai"
    command -v zsh  >/dev/null 2>&1 && $SUDO install -Dm644 "$SRC/completions/_ai" "$ZSH_COMP/_ai"
    command -v fish >/dev/null 2>&1 && $SUDO install -Dm644 "$SRC/completions/ai.fish" "$FISH_COMP/ai.fish"

    # Config via the tool itself (no shell-specific escaping, ever)
    local tool="$BINDIR/llama-cozy"
    "$tool" config set MODELS_DIR "$MODELS_DIR" >/dev/null
    [ -n "$PROMPT" ] && "$tool" config set SYSTEM_PROMPT "$PROMPT" >/dev/null
    [ -n "$bindir_llama" ] && "$tool" config set BIN_DIR "$bindir_llama" >/dev/null

    # PATH + completion hooks for the user's login shell
    case ":$PATH:" in *":$BINDIR:"*) ;; *)
        case $(basename "${SHELL:-sh}") in
            fish) command -v fish >/dev/null 2>&1 && fish -c "fish_add_path -U '$BINDIR'" 2>/dev/null \
                      && say "🔧 added $BINDIR to fish PATH" ;;
            bash) put_block "$HOME/.bashrc" "export PATH=\"$BINDIR:\$PATH\""; say "🔧 added $BINDIR to PATH in ~/.bashrc" ;;
            zsh)  put_block "$(zshrc)" "export PATH=\"$BINDIR:\$PATH\""; say "🔧 added $BINDIR to PATH in $(zshrc)" ;;
            *)    warn "Add $BINDIR to your PATH manually." ;;
        esac ;;
    esac
    if [ "$(basename "${SHELL:-sh}")" = zsh ] && [ "$PREFIX" = "$HOME/.local" ]; then
        put_block "$(zshrc)" "export PATH=\"$BINDIR:\$PATH\"
fpath=(\"$ZSH_COMP\" \$fpath)   # must come before compinit"
    fi

    local other; other=$(type -P ai 2>/dev/null || true)
    [ -n "$other" ] && [ "$other" != "$BINDIR/ai" ] && warn "another 'ai' exists at $other and may take priority over ours."

    say "--------------------------------------------------"
    say "🎉 Done! Open a new terminal, then try:"
    say "     ai doctor     # check everything"
    say "     ai list       # see your models"
    say "     ai <name>     # chat"
}

if [ $ACTION = uninstall ]; then do_uninstall; else do_install; fi
