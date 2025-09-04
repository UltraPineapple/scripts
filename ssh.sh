#!/bin/bash

# Цвета для красивого вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Функция для проверки, запущен ли скрипт от имени root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Ошибка: Этот скрипт необходимо запускать с правами root (используйте sudo).${NC}"
        exit 1
    fi
}

# Функция для вывода информации о подключении
show_connection_info() {
    echo -e "\n${YELLOW}--- Информация для подключения ---${NC}"
    
    # Ищем порт SSH в конфигурационном файле
    PORT=$(grep -i '^port' /etc/ssh/sshd_config | awk '{print $2}')
    # Если порт не указан, по умолчанию используется 22
    if [ -z "$PORT" ]; then
        PORT="22"
    fi

    # Получаем все IP-адреса, кроме локального (127.0.0.1)
    IP_ADDRESSES=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1")

    # --- НОВАЯ ЧАСТЬ ---
    # Определяем имя пользователя для примера команды
    # Если скрипт запущен через sudo, берем имя оригинального пользователя из $SUDO_USER
    # Иначе, берем текущего пользователя (вероятно, root)
    if [ -n "$SUDO_USER" ]; then
        USERNAME_TO_CONNECT=$SUDO_USER
    else
        USERNAME_TO_CONNECT=$USER
    fi
    # --- КОНЕЦ НОВОЙ ЧАСТИ ---

    if [ -z "$IP_ADDRESSES" ]; then
        echo -e "${RED}Не удалось определить IP-адрес сервера.${NC}"
    else
        echo -e "IP адреса сервера:"
        for IP in $IP_ADDRESSES; do
            echo -e "  ${GREEN}$IP${NC}"
        done
        echo -e "Порт SSH: ${GREEN}$PORT${NC}"
        echo -e "\nПример команды для подключения от имени пользователя ${YELLOW}${USERNAME_TO_CONNECT}${NC}:"
        # --- ИЗМЕНЕНА СТРОКА НИЖЕ ---
        echo -e "  ${GREEN}ssh ${USERNAME_TO_CONNECT}@$(echo "$IP_ADDRESSES" | head -n 1) -p $PORT${NC}"
    fi
    echo -e "${YELLOW}----------------------------------${NC}"
}

# Функция установки и запуска SSH
install_and_start_ssh() {
    check_root
    
    echo "Обновление списка пакетов..."
    apt-get update > /dev/null 2>&1
    
    echo "Установка OpenSSH сервера..."
    if apt-get install -y openssh-server; then
        echo -e "${GREEN}OpenSSH сервер успешно установлен.${NC}"
    else
        echo -e "${RED}Произошла ошибка при установке OpenSSH сервера.${NC}"
        exit 1
    fi

    # Спрашиваем про автозагрузку
    read -p "Включить автозагрузку SSH сервера при старте системы? (Y/n): " enable_choice
    # Если ответ пустой или 'y'/'Y'/'д'/'Д', включаем
    if [[ -z "$enable_choice" || "$enable_choice" =~ ^[YyДд]$ ]]; then
        systemctl enable ssh
        echo -e "${GREEN}Автозагрузка SSH включена.${NC}"
    else
        systemctl disable ssh
        echo -e "${YELLOW}Автозагрузка SSH отключена.${NC}"
    fi

    echo "Запуск службы SSH..."
    systemctl start ssh
    
    # Проверяем статус после запуска
    if systemctl is-active --quiet ssh; then
        echo -e "${GREEN}SSH сервер успешно запущен!${NC}"
        show_connection_info
    else
        echo -e "${RED}Не удалось запустить SSH сервер. Проверьте логи командой 'journalctl -u ssh'${NC}"
    fi
}

# Функция для вывода статуса
show_status() {
    # Проверяем, установлена ли служба
    if ! command -v sshd &> /dev/null; then
        echo -e "${RED}SSH сервер не установлен. Выберите пункт 1 для установки.${NC}"
        return
    fi

    echo -e "${YELLOW}--- Статус SSH сервера ---${NC}"
    if systemctl is-active --quiet ssh; then
        echo -e "Статус: ${GREEN}Активен (запущен)${NC}"
        # Выводим детальный статус от systemd
        systemctl status ssh | grep "Active:"
        show_connection_info
    else
        echo -e "Статус: ${RED}Неактивен (остановлен)${NC}"
        systemctl status ssh | grep "Active:"
    fi
    echo -e "${YELLOW}--------------------------${NC}"
}


# Главное меню
while true; do
    clear
    echo "================================="
    echo "    Менеджер SSH сервера"
    echo "================================="
    echo "1 - Установка и запуск SSH сервера"
    echo "2 - Статус и адрес подключения"
    echo "0 - Выход"
    echo "---------------------------------"
    read -p "Выберите опцию: " choice

    case $choice in
        1)
            install_and_start_ssh
            ;;
        2)
            show_status
            ;;
        0)
            echo "Выход."
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор. Пожалуйста, попробуйте снова.${NC}"
            ;;
    esac
    
    # Пауза перед возвращением в меню
    echo ""
    read -p "Нажмите Enter для продолжения..."
done