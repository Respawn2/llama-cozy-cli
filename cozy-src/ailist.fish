function ailist --description "List all available local .gguf models"
    echo "📂 Available local models in cache tree:"
    # Search all .gguf files recursively, filtering out secondary multimodal mmproj modules
    command find $LLAMA_MODELS_DIR -type f -name "*.gguf" ! -name "mmproj*" 2>/dev/null | while read -l file
        set -l name (basename "$file")
        set -l size (ls -lh "$file" | awk '{print $5}')
        echo "• $name ($size)"
    end
end
