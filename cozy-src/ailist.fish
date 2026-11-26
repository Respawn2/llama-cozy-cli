function ailist --description "Список всех локальных .gguf моделей"
    echo "📂 Доступные локальные модели в кэше:"
    command find $LLAMA_MODELS_DIR -type f -name "*.gguf" 2>/dev/null | while read -l file
        set -l name (basename "$file")
        set -l size (ls -lh "$file" | awk '{print $5}')
        echo "• $name ($size)"
    end
end
