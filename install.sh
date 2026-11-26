#!/bin/bash

# --- Global Configurations ---
COZY_ENV_FILE="$HOME/.llama-cozy-env"

# --- Uninstall Logic ---
if [ "$1" == "--uninstall" ]; then
    echo "🐐 Llama-Cozy-CLI: Starting uninstallation process..."
    echo "--------------------------------------------------"

    USER_SHELL=$(basename "$SHELL")

    if [ "$USER_SHELL" == "fish" ]; then
        FISH_FUNC_DIR="$HOME/.config/fish/functions"
        FISH_CONFIG="$HOME/.config/fish/config.fish"

        rm -f "$FISH_FUNC_DIR/ai.fish" "$FISH_FUNC_DIR/ailist.fish"
        [ -f "$FISH_CONFIG" ] && sed -i '/# === Added by llama-cozy-cli ===/,/set -gx LLAMA_MODELS_DIR/d' "$FISH_CONFIG"
        echo "✅ Removed Fish functions and configuration lines."

    elif [ "$USER_SHELL" == "bash" ] || [ "$USER_SHELL" == "zsh" ]; then
        [ "$USER_SHELL" == "bash" ] && RC_FILE="$HOME/.bashrc" || RC_FILE="$HOME/.zshrc"

        rm -f "$COZY_ENV_FILE"
        [ -f "$RC_FILE" ] && sed -i '/# === Added by llama-cozy-cli ===/,/llama-cozy-env/d' "$RC_FILE"
        echo "✅ Removed environment files and hooks from $RC_FILE"
    fi

    echo "--------------------------------------------------"
    echo "🎉 Uninstallation complete. Ollama is safe... for now."
    exit 0
fi

# --- Installation Logic ---
echo "🦙 Welcome to Llama.cpp Cozy CLI Installer!"
echo "--------------------------------------------------"

if ! command -v llama-cli &> /dev/null; then
    echo "❌ Error: 'llama-cli' is not installed globally in your system."
    echo "Please install llama.cpp before running this installer."
    exit 1
fi

USER_SHELL=$(basename "$SHELL")
echo "🔍 Detected shell: $USER_SHELL"

DEFAULT_DIR="$HOME/.lm-studio/models"
read -p "📂 Specify the path to your .gguf models folder [$DEFAULT_DIR]: " USER_DIR
USER_DIR=${USER_DIR:-$DEFAULT_DIR}

if [ ! -d "$USER_DIR" ]; then
    echo "⚠️  Warning: Target directory $USER_DIR does not exist yet."
fi

# --- Fish Installation ---
if [ "$USER_SHELL" == "fish" ]; then
    FISH_FUNC_DIR="$HOME/.config/fish/functions"
    FISH_CONFIG="$HOME/.config/fish/config.fish"

    mkdir -p "$FISH_FUNC_DIR"
    mkdir -p "$(dirname "$FISH_CONFIG")"

    if [ -f "cozy-src/ai.fish" ] && [ -f "cozy-src/ailist.fish" ]; then
        cp cozy-src/ai.fish "$FISH_FUNC_DIR/ai.fish"
        cp cozy-src/ailist.fish "$FISH_FUNC_DIR/ailist.fish"
        echo "📂 Modular functions copied to $FISH_FUNC_DIR"
    else
        echo "❌ Error: 'cozy-src' folder not found in the current directory!"
        exit 1
    fi

    # Smart duplication protection via sed: remove old blocks if they exist
    if grep -q "LLAMA_MODELS_DIR" "$FISH_CONFIG" 2>/dev/null; then
        sed -i '/# === Added by llama-cozy-cli ===/,/set -gx LLAMA_MODELS_DIR/d' "$FISH_CONFIG"
    fi

    # Append fresh configuration block
    echo -e "\n# === Added by llama-cozy-cli ===\nset -gx LLAMA_MODELS_DIR \"$USER_DIR\"" >> "$FISH_CONFIG"
    echo "✅ Configuration block updated safely in $FISH_CONFIG"
    echo "🎉 Installation for Fish completed successfully!"

# --- Bash / Zsh Installation ---
elif [ "$USER_SHELL" == "bash" ] || [ "$USER_SHELL" == "zsh" ]; then
    [ "$USER_SHELL" == "bash" ] && RC_FILE="$HOME/.bashrc" || RC_FILE="$HOME/.zshrc"

    cat << 'EOF' > "$COZY_ENV_FILE"
# === Llama.cpp Cozy CLI Env ===
export LLAMA_MODELS_DIR="REPLACE_PATH"

ai() {
    if [ -z "$1" ]; then
        echo "❌ Error: Please specify a model name pattern (e.g., ai bonsai)"
        return 1
    fi

    local model_path=$(command find "$LLAMA_MODELS_DIR" -type f -name "*$1*.gguf" 2>/dev/null | head -n 1)

    if [ -z "$model_path" ]; then
        echo "❌ Error: Model pattern '$1' not found in $LLAMA_MODELS_DIR"
        return 1
    fi

    local model_name=$(basename "$model_path")
    echo "🚀 Found model: $model_name"
    echo "🔥 Initializing GPU acceleration (Nvidia CUDA)..."

    command llama-cli \
        -m "$model_path" \
        -ngl 99 \
        --flash-attn \
        -c 4096 \
        --color \
        -i \
        -r "User:" \
        -p "System: You are a helpful assistant. Please reply in Russian by default.\nUser: Hello!\nAI: Привет!\n"
}

ailist() {
    echo "📂 Available local models in cache:"
    command find "$LLAMA_MODELS_DIR" -type f -name "*.gguf" 2>/dev/null | while read -r file; do
        local name=$(basename "$file")
        local size=$(ls -lh "$file" | awk '{print $5}')
        echo "• $name ($size)"
    done
}
EOF

    sed -i "s|REPLACE_PATH|$USER_DIR|g" "$COZY_ENV_FILE"
    echo "📂 Environment script updated at $COZY_ENV_FILE"

    if ! grep -q "llama-cozy-env" "$RC_FILE" 2>/dev/null; then
        echo -e "\n# === Added by llama-cozy-cli ===\n[ -f $COZY_ENV_FILE ] && . $COZY_ENV_FILE" >> "$RC_FILE"
        echo "✅ Connection hook injected into $RC_FILE"
    fi
    echo "🎉 Installation for $USER_SHELL completed successfully!"
fi

echo "--------------------------------------------------"
echo "💻 Done! Please restart your terminal or source your configuration to apply changes."
