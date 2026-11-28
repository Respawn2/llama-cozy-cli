#!/usr/bin/env bash
# Unit tests for llama-cozy wrapper logic. No real llama.cpp required.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/.." && pwd)
BIN="$ROOT/llama-cozy"
FIX="$HERE/fixtures"

pass=0; fail=0
t() { # t "name" expected actual
    local name=$1 want=$2 got=$3
    if [ "$want" = "$got" ]; then
        printf '  ✅ %s\n' "$name"; pass=$((pass+1))
    else
        printf '  ❌ %s\n     want: %s\n     got:  %s\n' "$name" "$want" "$got"; fail=$((fail+1))
    fi
}

contains() { # contains "name" needle haystack
    local name=$1 needle=$2 hay=$3
    case $hay in
        *"$needle"*) printf '  ✅ %s\n' "$name"; pass=$((pass+1)) ;;
        *) printf '  ❌ %s\n     missing: %s\n     in: %s\n' "$name" "$needle" "$hay"; fail=$((fail+1)) ;;
    esac
}

# isolated env
export XDG_CONFIG_HOME="$HERE/.tmp/config"
export XDG_DATA_HOME="$HERE/.tmp/data"
export XDG_STATE_HOME="$HERE/.tmp/state"
rm -rf "$HERE/.tmp"
mkdir -p "$XDG_DATA_HOME/llama-cozy/models/fake" "$XDG_CONFIG_HOME/llama-cozy"

# fake model
: > "$XDG_DATA_HOME/llama-cozy/models/fake/Tiny-Q4_K_M.gguf"

# point BIN_DIR at fixtures
"$BIN" config set BIN_DIR "$FIX" >/dev/null

echo "== run: basic =="
out=$("$BIN" tiny -p "hello" 2>&1)
contains "model path passed" "-m $XDG_DATA_HOME/llama-cozy/models/fake/Tiny-Q4_K_M.gguf" "$out"
contains "ngl default" "-ngl 99" "$out"
contains "ctx default" "-c 4096" "$out"
contains "one-shot flags" "-no-cnv --no-display-prompt" "$out"
contains "prompt" "-p hello" "$out"

echo "== run: --cpu, -c, -- =="
out=$("$BIN" run tiny --cpu -c 2048 -p x -- --flash-attn 2>&1)
contains "--cpu sets ngl 0" "-ngl 0" "$out"
contains "ctx override" "-c 2048" "$out"
contains "raw extra after --" "--flash-attn" "$out"

echo "== run: system prompt (modern llama.cpp) =="
out=$("$BIN" run tiny -s "be terse" 2>&1)
contains "system-prompt flag" "--system-prompt" "$out"
contains "system text" "be terse" "$out"

echo "== serve: defaults =="
out=$("$BIN" serve tiny 2>&1)
contains "server model" "-m $XDG_DATA_HOME/llama-cozy/models/fake/Tiny-Q4_K_M.gguf" "$out"
contains "host default" "--host 127.0.0.1" "$out"
contains "port default" "--port 8080" "$out"
contains "alias" "--alias Tiny-Q4_K_M" "$out"

echo "== serve: --port/--host =="
out=$("$BIN" serve tiny --port 9099 --host 127.0.0.1 2>&1)
contains "port override" "--port 9099" "$out"
contains "host override" "--host 127.0.0.1" "$out"

echo "== bench: passthrough =="
out=$("$BIN" bench tiny -- -p 512 -n 128 2>&1)
contains "bench model" "-m $XDG_DATA_HOME/llama-cozy/models/fake/Tiny-Q4_K_M.gguf" "$out"
contains "bench -p" "-p 512" "$out"
contains "bench -n" "-n 128" "$out"
contains "bench ngl" "-ngl 99" "$out"

echo "== list/show =="
out=$("$BIN" list --names)
contains "list names" "Tiny-Q4_K_M" "$out"
out=$("$BIN" show tiny)
contains "show path" "path:" "$out"
contains "show quant" "quant:   Q4_K_M" "$out"

echo "== unknown subcommand falls through to run =="
out=$("$BIN" tiny -p hi 2>&1)
contains "bare model is run" "-p hi" "$out"

echo "== missing model =="
set +e
out=$("$BIN" nonexistent-model 2>&1); rc=$?
set -e
[ $rc -ne 0 ] && { printf '  ✅ %s\n' "missing model exits nonzero"; pass=$((pass+1)); } \
             || { printf '  ❌ missing model exits nonzero\n'; fail=$((fail+1)); }
contains "error mentions No model" "No model matches" "$out"

echo "== public bind refuses without --api-key =="
set +e
out=$(printf '' | "$BIN" serve tiny --host 0.0.0.0 2>&1); rc=$?
set -e
[ $rc -ne 0 ] && { printf '  ✅ %s\n' "public bind refuses (non-tty)"; pass=$((pass+1)); } \
             || { printf '  ❌ public bind refuses (non-tty)\n'; fail=$((fail+1)); }
contains "suggests api-key" "--api-key" "$out"

echo
printf 'passed: %d, failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]