function ai --description "Cozy CLI launcher for llama.cpp models"
    if test (count $argv) -eq 0
        echo "❌ Error: Please specify a model name pattern (e.g., ai bonsai)"
        return 1
    end

    set -l search_term $argv

    # Recursive deep search for .gguf files, explicitly excluding mmproj files
    set -l model_path (command find $LLAMA_MODELS_DIR -type f -name "*$search_term*.gguf" ! -name "mmproj*" 2>/dev/null | head -n 1)

    if test -z "$model_path"
        echo "❌ Error: Model pattern '$search_term' not found in $LLAMA_MODELS_DIR"
        return 1
    end

    set -l model_name (basename "$model_path")
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
        -p "System: $LLAMA_PROMPT\nUser: Hello!\nAI: Hello!\n"
end
