function ai --description "Уютный запуск ИИ-модели по части имени"
    if test (count $argv) -eq 0
        echo "❌ Ошибка: Укажи часть имени модели (например: ai bonsai)"
        return 1
    end

    set -l search_term $argv[1]

    # Ищем первый подходящий .gguf файл по ключевому слову
    set -l model_path (command find $LLAMA_MODELS_DIR -type f -name "*$search_term*.gguf" 2>/dev/null | head -n 1)

    if test -z "$model_path"
        echo "❌ Модель со словом '$search_term' не найдена в $LLAMA_MODELS_DIR"
        return 1
    end

    set -l model_name (basename "$model_path")
    echo "🚀 Найдена модель: $model_name"
    echo "🔥 Запуск на полную мощность GPU (Nvidia)..."

    command llama-cli \
        -m "$model_path" \
        -ngl 99 \
        --flash-attn \
        -c 4096 \
        --color \
        -i \
        -r "User:" \
        -p "User: Привет!\nAI: Привет! Я готов к работе. О чём поговорим?\n"
end
