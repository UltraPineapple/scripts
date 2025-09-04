#!/bin/bash

# Останавливаем выполнение скрипта, если любая команда завершится с ошибкой
set -e
# Также останавливаем, если команда в конвейере (pipe) завершится с ошибкой
set -o pipefail

# --- Цвета для вывода ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Вспомогательные функции ---

# Функция для вывода ошибок
error_exit() {
    echo -e "${RED}ОШИБКА: $1${NC}" >&2
    exit 1
}

# Функция проверки, установлен ли Docker
check_if_docker_installed() {
    if command -v docker &> /dev/null; then
        return 0 # 0 означает "успех" (true), Docker установлен
    else
        return 1 # 1 означает "неудача" (false), Docker не установлен
    fi
}

# --- Основные функции ---

# Функция полного удаления Docker
uninstall_docker() {
    echo -e "${YELLOW}Удаление предыдущих версий Docker...${NC}"
    # Используем || true, чтобы скрипт не падал, если пакеты не были установлены
    sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io docker-doc docker-compose podman-docker containerd runc || true
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo apt-get autoremove -y || true
    echo -e "${GREEN}Очистка завершена.${NC}"
}

# Функция установки Docker и Docker Compose с валидацией
install_docker_and_compose() {
    echo -e "${YELLOW}--- Начало установки Docker и Docker Compose ---${NC}"

    # 1. Обновляем индекс пакетов и устанавливаем зависимости
    echo -e "\n${YELLOW}[ШАГ 1/6] Обновление пакетов и установка зависимостей...${NC}"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    echo -e "${GREEN}Зависимости успешно установлены.${NC}"

    # 2. Добавляем официальный GPG-ключ Docker
    echo -e "\n${YELLOW}[ШАГ 2/6] Добавление GPG-ключа Docker...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # ---- ВАЛИДАЦИЯ КЛЮЧА ----
    if [ -f "/etc/apt/keyrings/docker.gpg" ]; then
        echo -e "${GREEN}GPG-ключ Docker успешно добавлен и проверен.${NC}"
    else
        error_exit "Не удалось добавить GPG-ключ Docker. Файл /etc/apt/keyrings/docker.gpg не найден."
    fi

    # 3. Добавляем репозиторий Docker в источники Apt
    echo -e "\n${YELLOW}[ШАГ 3/6] Добавление репозитория Docker...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # ---- ВАЛИДАЦИЯ РЕПОЗИТОРИЯ ----
    if [ -f "/etc/apt/sources.list.d/docker.list" ]; then
        echo -e "${GREEN}Репозиторий Docker успешно добавлен.${NC}"
    else
        error_exit "Не удалось добавить репозиторий Docker. Файл /etc/apt/sources.list.d/docker.list не найден."
    fi

    # 4. Обновляем индекс пакетов с новым репозиторием
    echo -e "\n${YELLOW}[ШАГ 4/6] Повторное обновление индекса пакетов...${NC}"
    sudo apt-get update
    echo -e "${GREEN}Индекс пакетов успешно обновлен.${NC}"

    # 5. Устанавливаем Docker Engine, CLI, Containerd и плагины
    echo -e "\n${YELLOW}[ШАГ 5/6] Установка пакетов Docker...${NC}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # ---- ВАЛИДАЦИЯ УСТАНОВКИ DOCKER ----
    if ! check_if_docker_installed; then
        error_exit "Установка Docker не удалась. Команда 'docker' не найдена после установки."
    fi
    # ---- ВАЛИДАЦИЯ УСТАНОВКИ DOCKER COMPOSE ----
    if ! docker compose version &> /dev/null; then
        error_exit "Установка Docker Compose (plugin) не удалась."
    fi
    echo -e "${GREEN}Docker и Docker Compose (plugin) успешно установлены!${NC}"
    docker --version
    docker compose version

    # 6. Добавляем текущего пользователя в группу docker
    echo -e "\n${YELLOW}[ШАГ 6/6] Добавление пользователя $USER в группу docker...${NC}"
    sudo usermod -aG docker $USER

    # ---- ВАЛИДАЦИЯ ДОБАВЛЕНИЯ В ГРУППУ ----
    if groups $USER | grep -q '\bdocker\b'; then
        echo -e "${GREEN}Пользователь $USER успешно добавлен в группу docker.${NC}"
    else
        # Это не критическая ошибка, поэтому просто выводим предупреждение
        echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ: Не удалось автоматически проверить добавление пользователя в группу. Проверьте вручную после перезагрузки.${NC}"
    fi

    echo -e "\n${GREEN}--- Установка успешно завершена! ---${NC}"
    echo -e "${YELLOW}ВАЖНО: Чтобы использовать docker без sudo, вам нужно ВЫЙТИ ИЗ СИСТЕМЫ И СНОВА ВОЙТИ, или выполнить команду 'newgrp docker'.${NC}"
}

# --- Функция для отображения меню ---
show_menu() {
    echo -e "\n${YELLOW}Меню управления установкой Docker:${NC}"
    echo "1 - Установить Docker и Docker Compose"
    echo "2 - Переустановить Docker и Docker Compose (полное удаление)"
    echo "0 - Выход"
    echo ""
}

# --- Основная логика скрипта с меню ---
main() {
    while true; do
        show_menu
        read -p "Выберите опцию: " choice

        case $choice in
            1)
                if check_if_docker_installed; then
                    echo -e "${GREEN}Docker уже установлен. Пропускаем установку.${NC}"
                    echo -e "Если вы хотите переустановить, выберите опцию '2'."
                    docker --version
                else
                    install_docker_and_compose
                fi
                ;;
            2)
                echo -e "${YELLOW}Запуск полной переустановки Docker...${NC}"
                uninstall_docker
                install_docker_and_compose
                ;;
            0)
                echo "Выход из скрипта."
                exit 0
                ;;
            *)
                echo -e "${RED}Неверная опция. Пожалуйста, попробуйте снова.${NC}"
                ;;
        esac
    done
}

# Запуск основной функции
main