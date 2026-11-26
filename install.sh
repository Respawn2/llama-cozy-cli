#!/bin/bash

echo "🐐 Llama-Cozy-CLI Installer: Начинаем уничтожение Ollama..."
echo "--------------------------------------------------"

# Проверяем, установлен ли llama-cli глобально
if ! command -v llama-cli &> /dev/null; then
    echo "⚠️  Ошибка: 'llama-cli' не найден в системе."
    echo "Пожалуйста, установите llama.cpp перед использованием этого скрипта."
    exit 1
fi

# Определяем текущий шелл пользователя
USER_SHELL=$(basename "$SHELL")
echo "🔍 Определён шелл: $USER_SHELL"

# Запрашиваем путь к папке с моделями
DEFAULT_DIR="$HOME/.cache/lm-studio/models"
read -p "📂 Укажите путь к папке с .gguf моделями [$DEFAULT_DIR]: " USER_DIR
USER_DIR=${USER_DIR:-$DEFAULT_DIR}

# Проверяем существование директории (просто предупреждение)
if [ ! -d "$USER_DIR" ]; then
    echo "⚠️  Предупреждение: Папка $USER_DIR сейчас не существует. Убедитесь, что создадите её позже."
fi

# --- УСТАНОВКА ДЛЯ FISH SHELL ---
if [ "$USER_SHELL" == "fish" ]; then
    FISH_FUNC_DIR="$HOME/.config/fish/functions"
    FISH_CONFIG="$HOME/.config/fish/config.fish"

    # Создаем папку функций, если её нет
    mkdir -p "$FISH_FUNC_DIR"
    mkdir -p "$(dirname "$FISH_CONFIG")"

    # Копируем изолированные файлы функций из репозитория в автозагрузку Fish
    if [ -f "cozy-src/ai.fish" ] && [ -f "cozy-src/ailist.fish" ]; then
        cp cozy-src/ai.fish "$FISH_FUNC_DIR/ai.fish"
        cp cozy-src/ailist.fish "$FISH_FUNC_DIR/ailist.fish"
        echo "📂 Модульные функции скопированы в $FISH_FUNC_DIR"
    else
        echo "⚠️  Ошибка: Папка 'cozy-src' с файлами функций не найдена в текущей директории!"
        exit 1
    fi

    # Прописываем путь к моделям в config.fish, если его там ещё нет
    if ! grep -q "LLAMA_MODELS_DIR" "$FISH_CONFIG" 2>/dev/null; then
        echo -e "\n# === Added by llama-cozy-cli ===" >> "$FISH_CONFIG"
        echo "set -gx LLAMA_MODELS_DIR \"$USER_DIR\"" >> "$FISH_CONFIG"
        echo "✅ Переменная LLAMA_MODELS_DIR добавлена в config.fish"
    fi
    echo "🎉 Установка для Fish успешно завершена!"

# --- УСТАНОВКА ДЛЯ BASH ИЛИ ZSH ---
elif [ "$USER_SHELL" == "bash" ] || [ "$USER_SHELL" == "zsh" ]; then
    if [ "$USER_SHELL" == "bash" ]; then
        RC_FILE="$HOME/.bashrc"
    else
        RC_FILE="$HOME/.zshrc"
    fi

    COZY_ENV_FILE="$HOME/.llama-cozy-env"

    # Генерируем изолированный POSIX-совместимый файл функций
    cat << 'EOF' > "$COZY_ENV_FILE"
# === Llama.cpp Cozy CLI Env ===
export LLAMA_MODELS_DIR="REPLACE_PATH"

ai() {
    if [ -z "$1" ]; then
        echo "❌ Ошибка: Укажи часть имени модели (например: ai bonsai)"
        return 1
    fi

    local model_path=$(command find "$LLAMA_MODELS_DIR" -type f -name "*$1*.gguf" 2>/dev/null | head -n 1)

    if [ -z "$model_path" ]; then
        echo "❌ Модель со словом '$1' не найдена в $LLAMA_MODELS_DIR"
        return 1
    fi

    local model_name=$(basename "$model_path")
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
}

ailist() {
    echo "📂 Доступные локальные модели в кэше:"
    command find "$LLAMA_MODELS_DIR" -type f -name "*.gguf" 2>/dev/null | while read -r file; do
        local name=$(basename "$file")
        local size=$(ls -lh "$file" | awk '{print $5}')
        echo "• $name ($size)"
    done
}
EOF

    # Подставляем реальный путь пользователя вместо плейсхолдера через sed
    sed -i "s|REPLACE_PATH|$USER_DIR|g" "$COZY_ENV_FILE"
    echo "📂 Изолированное окружение создано в $COZY_ENV_FILE"

    # Безопасно подключаем созданный файл в .bashrc / .zshrc
    if ! grep -q "llama-cozy-env" "$RC_FILE" 2>/dev/null; then
        echo -e "\n# === Added by llama-cozy-cli ===\n[ -f $COZY_ENV_FILE ] && . $COZY_ENV_FILE" >> "$RC_FILE"
        echo "✅ Строка подключения (source) добавлена в $RC_FILE"
    fi
    echo "🎉 Установка для шелла $USER_SHELL успешно завершена!"
fi

echo "--------------------------------------------------"
echo "💻 Установка завершена! Перезапустите терминал или обновите конфиг, чтобы начать."
