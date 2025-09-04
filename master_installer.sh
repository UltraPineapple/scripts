#!/bin/bash

# Останавливаем выполнение скрипта, если любая команда завершится с ошибкой
set -e
# Также останавливаем, если команда в конвейере (pipe) завершится с ошибкой
set -o pipefail

# --- Глобальные переменные и цвета ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Проверка прав суперпользователя в самом начале ---
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
       # Проверяем, может ли пользователь использовать sudo
       if ! sudo -v &> /dev/null; then
         echo -e "${RED}ОШИБКА: Этот скрипт требует прав суперпользователя (sudo).${NC}"
         echo -e "${RED}Запустите его с 'sudo ./master_installer.sh' или от имени root.${NC}"
         exit 1
       fi
    fi
}

# =================================================================================
# --- БЛОК ФУНКЦИЙ ДЛЯ VMWARE TOOLS ---
# =================================================================================

# Функция для проверки, установлен ли пакет
is_package_installed() {
    dpkg-query -s "$1" &> /dev/null
}

# Функция для вывода финального сообщения об успехе VMware
show_vmware_success_message() {
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}         Установка/Переустановка VMware Tools успешно завершена!      ${NC}"
    echo -e "${YELLOW}----------------------------------------------------------------------${NC}"
    echo -e "${YELLOW} ВАЖНО: Чтобы изменения вступили в силу, виртуальную машину         ${NC}"
    echo -e "${YELLOW}          необходимо ПЕРЕЗАГРУЗИТЬ.                                   ${NC}"
    echo -e "${YELLOW}                                                                    ${NC}"
    echo -e "${YELLOW} После перезагрузки должны заработать функции, такие как:            ${NC}"
    echo -e "${YELLOW} - Общий буфер обмена (Copy/Paste)                                  ${NC}"
    echo -e "${YELLOW} - Перетаскивание файлов (Drag and Drop)                            ${NC}"
    echo -e "${YELLOW} - Автоматическая подгонка разрешения экрана                        ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
}

# Функция установки VMware Tools
install_vmware_tools() {
    echo -e "\n--- ${YELLOW}Запуск установки open-vm-tools-desktop${NC} ---"
    if is_package_installed "open-vm-tools-desktop"; then
        echo -e "${GREEN}Пакет 'open-vm-tools-desktop' уже установлен.${NC}"
        echo -e "${YELLOW}Если вы хотите переустановить его, выберите соответствующий пункт в меню.${NC}"
        return
    fi
    if is_package_installed "open-vm-tools"; then
        echo -e "${YELLOW}Обнаружен конфликтующий пакет 'open-vm-tools'. Удаляем его...${NC}"
        sudo apt-get update
        sudo apt-get autoremove -y open-vm-tools
        echo -e "${GREEN}Пакет 'open-vm-tools' успешно удален.${NC}"
    fi
    echo -e "\n${YELLOW}Обновляем список пакетов перед установкой...${NC}"
    sudo apt-get update
    echo -e "${YELLOW}Устанавливаем 'open-vm-tools-desktop'...${NC}"
    sudo apt-get install -y open-vm-tools-desktop
    if is_package_installed "open-vm-tools-desktop"; then
        show_vmware_success_message
    else
        echo -e "${RED}ОШИБКА: Не удалось установить пакет 'open-vm-tools-desktop'.${NC}"
        exit 1
    fi
}

# Функция полного удаления VMware Tools
uninstall_vmware_tools() {
    echo -e "\n--- ${YELLOW}Запуск полного удаления VMware Tools${NC} ---"
    if ! is_package_installed "open-vm-tools-desktop" && ! is_package_installed "open-vm-tools"; then
        echo -e "${GREEN}Пакеты VMware Tools не установлены. Пропускаем.${NC}"
        return
    fi
    echo -e "${YELLOW}Полностью удаляем пакеты (purge)...${NC}"
    sudo apt-get purge -y open-vm-tools open-vm-tools-desktop
    sudo apt-get autoremove -y
    echo -e "${GREEN}VMware Tools успешно удалены.${NC}"
}

# Функция переустановки VMware Tools
reinstall_vmware_tools() {
    echo -e "\n--- ${YELLOW}Запуск переустановки open-vm-tools-desktop${NC} ---"
    uninstall_vmware_tools
    echo -e "\n${YELLOW}Устанавливаем 'open-vm-tools-desktop'...${NC}"
    sudo apt-get update
    sudo apt-get install -y open-vm-tools-desktop
    if is_package_installed "open-vm-tools-desktop"; then
        show_vmware_success_message
    else
        echo -e "${RED}ОШИБКА: Не удалось переустановить пакет 'open-vm-tools-desktop'.${NC}"
        exit 1
    fi
}

# Меню для VMware Tools
vmware_tools_menu() {
    while true; do
        clear
        echo -e "${GREEN}--- Меню: Настройка VMware Tools на Ubuntu Desktop ---${NC}"
        echo "--------------------------------------------------------"
        if is_package_installed "open-vm-tools-desktop"; then
            echo -e "Статус: ${GREEN}open-vm-tools-desktop УСТАНОВЛЕН${NC}"
        else
            echo -e "Статус: ${YELLOW}open-vm-tools-desktop НЕ УСТАНОВЛЕН${NC}"
        fi
        echo "--------------------------------------------------------"
        echo "1 - Установить open-vm-tools-desktop"
        echo "2 - Переустановить open-vm-tools-desktop"
        echo -e "3 - ${RED}Удалить${NC} open-vm-tools-desktop"
        echo "0 - Назад в главное меню"
        echo "--------------------------------------------------------"
        read -p "Ваш выбор: " choice

        case $choice in
            1) install_vmware_tools; read -p $'\nНажмите Enter для возврата в меню...' ;;
            2) reinstall_vmware_tools; read -p $'\nНажмите Enter для возврата в меню...' ;;
            3) uninstall_vmware_tools; read -p $'\nНажмите Enter для возврата в меню...' ;;
            0) return ;;
            *) echo -e "\n${RED}Неверный выбор.${NC}"; read -p "Нажмите Enter для продолжения..." ;;
        esac
    done
}


# =================================================================================
# --- БЛОК ФУНКЦИЙ ДЛЯ DOCKER ---
# =================================================================================

# Функция для вывода ошибок
error_exit() {
    echo -e "${RED}ОШИБКА: $1${NC}" >&2
    exit 1
}

# Функция проверки, установлен ли Docker
check_if_docker_installed() {
    if command -v docker &> /dev/null; then return 0; else return 1; fi
}

# Функция полного удаления Docker
uninstall_docker() {
    if ! check_if_docker_installed; then
        echo -e "${GREEN}Docker не установлен. Пропускаем.${NC}"
        return
    fi
    echo -e "\n--- ${YELLOW}Запуск полного удаления Docker${NC} ---"
    echo -e "${YELLOW}Удаление всех версий Docker...${NC}"
    sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io docker-doc docker-compose podman-docker containerd runc || true
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    echo -e "${YELLOW}Удаление связанных каталогов...${NC}"
    sudo rm -rf /var/lib/docker /var/lib/containerd
    sudo apt-get autoremove -y || true
    echo -e "${GREEN}Полная очистка Docker завершена.${NC}"
}

# Функция установки Docker
install_docker_and_compose() {
    echo -e "\n--- ${YELLOW}Начало установки Docker и Docker Compose ---${NC}"
    echo -e "\n${YELLOW}[1/6] Обновление пакетов и установка зависимостей...${NC}"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    echo -e "\n${YELLOW}[2/6] Добавление GPG-ключа Docker...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    if [ ! -f "/etc/apt/keyrings/docker.gpg" ]; then error_exit "Не удалось добавить GPG-ключ Docker."; fi
    echo -e "\n${YELLOW}[3/6] Добавление репозитория Docker...${NC}"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    if [ ! -f "/etc/apt/sources.list.d/docker.list" ]; then error_exit "Не удалось добавить репозиторий Docker."; fi
    echo -e "\n${YELLOW}[4/6] Повторное обновление индекса пакетов...${NC}"
    sudo apt-get update
    echo -e "\n${YELLOW}[5/6] Установка пакетов Docker...${NC}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if ! check_if_docker_installed; then error_exit "Установка Docker не удалась."; fi
    if ! docker compose version &> /dev/null; then error_exit "Установка Docker Compose (plugin) не удалась."; fi
    echo -e "${GREEN}Docker и Docker Compose (plugin) успешно установлены!${NC}"
    docker --version && docker compose version
    echo -e "\n${YELLOW}[6/6] Добавление пользователя $USER в группу docker...${NC}"
    sudo usermod -aG docker ${SUDO_USER:-$USER}
    echo -e "\n${GREEN}--- Установка Docker успешно завершена! ---${NC}"
    echo -e "${YELLOW}ВАЖНО: Чтобы использовать docker без sudo, вам нужно ВЫЙТИ ИЗ СИСТЕМЫ И СНОВА ВОЙТИ.${NC}"
}

# Меню для Docker
docker_menu() {
    while true; do
        clear
        echo -e "${GREEN}--- Меню: Управление Docker ---${NC}"
        echo "-----------------------------------"
        if check_if_docker_installed; then
            echo -e "Статус: ${GREEN}Docker УСТАНОВЛЕН${NC}"
            docker --version
        else
            echo -e "Статус: ${YELLOW}Docker НЕ УСТАНОВЛЕН${NC}"
        fi
        echo "-----------------------------------"
        echo "1 - Установить Docker и Docker Compose"
        echo "2 - Переустановить (полное удаление и установка)"
        echo -e "3 - ${RED}Полностью удалить${NC} Docker"
        echo "0 - Назад в главное меню"
        echo "-----------------------------------"
        read -p "Выберите опцию: " choice

        case $choice in
            1)
                if check_if_docker_installed; then
                    echo -e "${GREEN}Docker уже установлен.${NC} Выберите '2' для переустановки."
                else
                    install_docker_and_compose
                fi
                read -p $'\nНажмите Enter для возврата в меню...'
                ;;
            2)
                uninstall_docker
                install_docker_and_compose
                read -p $'\nНажмите Enter для возврата в меню...'
                ;;
            3)
                uninstall_docker
                read -p $'\nНажмите Enter для возврата в меню...'
                ;;
            0) return ;;
            *) echo -e "\n${RED}Неверная опция.${NC}"; read -p "Нажмите Enter для продолжения..." ;;
        esac
    done
}


# =================================================================================
# --- БЛОК ФУНКЦИЙ ДЛЯ SSH ---
# =================================================================================
# Функция проверки, установлен ли SSH сервер
is_ssh_installed() {
    command -v sshd &> /dev/null
}

# Функция для вывода информации о подключении
show_ssh_connection_info() {
    echo -e "\n${YELLOW}--- Информация для подключения ---${NC}"
    PORT=$(grep -i '^port' /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    IP_ADDRESSES=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1")
    USERNAME_TO_CONNECT=${SUDO_USER:-$USER}
    
    if [ -z "$IP_ADDRESSES" ]; then
        echo -e "${RED}Не удалось определить IP-адрес сервера.${NC}"
    else
        echo -e "IP адреса сервера:"
        for IP in $IP_ADDRESSES; do echo -e "  ${GREEN}$IP${NC}"; done
        echo -e "Порт SSH: ${GREEN}$PORT${NC}"
        echo -e "\nПример команды для подключения от имени ${YELLOW}${USERNAME_TO_CONNECT}${NC}:"
        echo -e "  ${GREEN}ssh ${USERNAME_TO_CONNECT}@$(echo "$IP_ADDRESSES" | head -n 1) -p $PORT${NC}"
    fi
    echo -e "${YELLOW}----------------------------------${NC}"
}

# Функция установки и запуска SSH (с автоматизацией для полной установки)
install_and_start_ssh() {
    echo -e "\n--- ${YELLOW}Установка OpenSSH сервера${NC} ---"
    echo "Обновление списка пакетов..."
    sudo apt-get update > /dev/null 2>&1
    echo "Установка openssh-server..."
    if sudo apt-get install -y openssh-server; then
        echo -e "${GREEN}OpenSSH сервер успешно установлен.${NC}"
    else
        echo -e "${RED}Произошла ошибка при установке OpenSSH сервера.${NC}"; exit 1
    fi

    # Если функция вызвана с аргументом "auto", не задаем вопросов
    if [[ "$1" == "auto" ]]; then
        enable_choice="y"
    else
        read -p "Включить автозагрузку SSH сервера при старте системы? (Y/n): " enable_choice
    fi

    if [[ -z "$enable_choice" || "$enable_choice" =~ ^[YyДд]$ ]]; then
        sudo systemctl enable ssh
        echo -e "${GREEN}Автозагрузка SSH включена.${NC}"
    else
        sudo systemctl disable ssh
        echo -e "${YELLOW}Автозагрузка SSH отключена.${NC}"
    fi

    echo "Запуск службы SSH..."
    sudo systemctl start ssh
    
    if systemctl is-active --quiet ssh; then
        echo -e "${GREEN}SSH сервер успешно запущен!${NC}"
        show_ssh_connection_info
    else
        echo -e "${RED}Не удалось запустить SSH сервер.${NC}"
    fi
}

# Функция полного удаления SSH сервера
uninstall_ssh() {
    if ! is_ssh_installed; then
        echo -e "${GREEN}SSH сервер не установлен. Пропускаем.${NC}"
        return
    fi
    echo -e "\n--- ${YELLOW}Полное удаление OpenSSH сервера${NC} ---"
    echo "Остановка и отключение службы ssh..."
    sudo systemctl stop ssh || true
    sudo systemctl disable ssh || true
    echo "Полное удаление пакета openssh-server..."
    sudo apt-get purge -y openssh-server
    sudo apt-get autoremove -y
    echo -e "${GREEN}OpenSSH сервер успешно удален.${NC}"
}

# Функция для вывода статуса SSH
show_ssh_status() {
    if ! is_ssh_installed; then
        echo -e "${RED}SSH сервер не установлен. Выберите пункт 1 для установки.${NC}"; return
    fi
    echo -e "${YELLOW}--- Статус SSH сервера ---${NC}"
    if systemctl is-active --quiet ssh; then
        echo -e "Статус: ${GREEN}Активен (запущен)${NC}"
        systemctl status ssh | grep "Active:"
        show_ssh_connection_info
    else
        echo -e "Статус: ${RED}Неактивен (остановлен)${NC}"
        systemctl status ssh | grep "Active:"
    fi
    echo -e "${YELLOW}--------------------------${NC}"
}

# Меню для SSH
ssh_server_menu() {
    while true; do
        clear
        echo -e "${GREEN}--- Меню: Менеджер SSH сервера ---${NC}"
        echo "================================="
        echo "1 - Установка и запуск SSH сервера"
        echo "2 - Переустановка SSH сервера"
        echo "3 - Статус и адрес подключения"
        echo -e "4 - ${RED}Удалить${NC} SSH сервер"
        echo "0 - Назад в главное меню"
        echo "---------------------------------"
        read -p "Выберите опцию: " choice

        case $choice in
            1) install_and_start_ssh ;;
            2) uninstall_ssh; install_and_start_ssh ;;
            3) show_ssh_status ;;
            4) uninstall_ssh ;;
            0) return ;;
            *) echo -e "${RED}Неверный выбор.${NC}" ;;
        esac
        echo ""; read -p "Нажмите Enter для продолжения..."
    done
}


# =================================================================================
# --- ФУНКЦИИ ПОЛНОЙ УСТАНОВКИ/УДАЛЕНИЯ И ГЛАВНОЕ МЕНЮ ---
# =================================================================================

# Функция для полной последовательной установки (для "чистой" системы)
full_install() {
    clear
    echo -e "${GREEN}##################################################${NC}"
    echo -e "${GREEN}#      Запуск полной автоматической установки      #${NC}"
    echo -e "${GREEN}##################################################${NC}"

    # --- ЭТАП 1: DOCKER ---
    echo -e "\n${YELLOW}--- ЭТАП 1 из 3: Установка Docker ---${NC}"
    if check_if_docker_installed; then
        echo -e "${GREEN}Docker уже установлен. Пропускаем.${NC}"
    else
        install_docker_and_compose
    fi

    # --- ЭТАП 2: SSH ---
    echo -e "\n${YELLOW}--- ЭТАП 2 из 3: Установка SSH Сервера ---${NC}"
    if is_ssh_installed; then
        echo -e "${GREEN}SSH Сервер уже установлен. Пропускаем.${NC}"
    else
        install_and_start_ssh "auto"
    fi

    # --- ЭТАП 3: VMWARE TOOLS ---
    echo -e "\n${YELLOW}--- ЭТАП 3 из 3: Установка VMware Tools ---${NC}"
    if is_package_installed "open-vm-tools-desktop"; then
        echo -e "${GREEN}VMware Tools уже установлен. Пропускаем.${NC}"
    else
        # Используем функцию переустановки, чтобы гарантированно получить чистую последнюю версию
        reinstall_vmware_tools
    fi

    # --- Финальное сообщение ---
    echo -e "\n${GREEN}======================================================================${NC}"
    echo -e "${GREEN}          ПОЛНАЯ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                        ${NC}"
    echo -e "${YELLOW}----------------------------------------------------------------------${NC}"
    echo -e "${YELLOW} ВАЖНО: Для полного применения всех изменений необходимо:            ${NC}"
    echo -e "${YELLOW}   1. ВЫЙТИ ИЗ СИСТЕМЫ И ВОЙТИ СНОВА (для прав Docker).            ${NC}"
    echo -e "${YELLOW}   2. ПЕРЕЗАГРУЗИТЬ ВИРТУАЛЬНУЮ МАШИНУ (для VMware Tools).           ${NC}"
    echo -e "${YELLOW}                                                                    ${NC}"
    echo -e "${YELLOW} Рекомендуется просто перезагрузить компьютер.                       ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
}

# Новая функция для полного удаления всех компонентов
full_uninstall() {
    clear
    read -p "$(echo -e ${RED}"ВНИМАНИЕ! Это действие полностью удалит Docker, SSH-сервер и VMware Tools с вашего компьютера. Вы уверены? (y/N): "${NC})" confirm
    if [[ "$confirm" =~ ^[YyДд]$ ]]; then
        echo -e "\n${YELLOW}--- НАЧАТО ПОЛНОЕ УДАЛЕНИЕ КОМПОНЕНТОВ ---${NC}"
        uninstall_docker
        uninstall_ssh
        uninstall_vmware_tools
        echo -e "\n${GREEN}--- ПОЛНОЕ УДАЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО ---${NC}"
    else
        echo -e "\n${GREEN}Удаление отменено.${NC}"
    fi
}

# Новая функция для полной переустановки
full_reinstall() {
    clear
    read -p "$(echo -e ${YELLOW}"ВНИМАНИЕ! Это действие сначала ПОЛНОСТЬЮ УДАЛИТ, а затем заново установит Docker, SSH-сервер и VMware Tools. Продолжить? (y/N): "${NC})" confirm
    if [[ "$confirm" =~ ^[YyДд]$ ]]; then
        echo -e "\n${YELLOW}--- ЭТАП 1: ПОЛНОЕ УДАЛЕНИЕ ---${NC}"
        uninstall_docker
        uninstall_ssh
        uninstall_vmware_tools
        echo -e "\n${YELLOW}--- ЭТАП 2: ПОЛНАЯ УСТАНОВКА ---${NC}"
        # Вызываем установку без проверок, так как мы только что всё удалили
        install_docker_and_compose
        install_and_start_ssh "auto"
        reinstall_vmware_tools # Эта функция уже содержит всё необходимое
        # --- Финальное сообщение ---
        echo -e "\n${GREEN}======================================================================${NC}"
        echo -e "${GREEN}       ПОЛНАЯ ПЕРЕУСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                        ${NC}"
        echo -e "${YELLOW}----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW} ВАЖНО: Для полного применения всех изменений необходимо:            ${NC}"
        echo -e "${YELLOW}   1. ВЫЙТИ ИЗ СИСТЕМЫ И ВОЙТИ СНОВА (для прав Docker).            ${NC}"
        echo -e "${YELLOW}   2. ПЕРЕЗАГРУЗИТЬ ВИРТУАЛЬНУЮ МАШИНУ (для VMware Tools).           ${NC}"
        echo -e "${YELLOW}                                                                    ${NC}"
        echo -e "${YELLOW} Рекомендуется просто перезагрузить компьютер.                       ${NC}"
        echo -e "${GREEN}======================================================================${NC}"
    else
        echo -e "\n${GREEN}Переустановка отменена.${NC}"
    fi
}

# Главная функция (основной цикл)
main() {
    check_sudo
    while true; do
        clear
        echo -e "${GREEN}#############################################${NC}"
        echo -e "${GREEN}#                                           #${NC}"
        echo -e "${GREEN}#        Универсальный установщик для Ubuntu        #${NC}"
        echo -e "${GREEN}#                                           #${NC}"
        echo -e "${GREEN}#############################################${NC}"
        echo ""
        echo -e "${YELLOW}Главное меню:${NC}"
        echo "---------------------------------------------"
        echo "1 - Управление VMware Tools"
        echo "2 - Управление Docker и Docker Compose"
        echo "3 - Управление SSH Сервером"
        echo "---------------------------------------------"
        echo "4 - ПОЛНАЯ УСТАНОВКА (Docker -> SSH -> VMware)"
        echo -e "5 - ${YELLOW}ПОЛНАЯ ПЕРЕУСТАНОВКА (удаление + установка)${NC}"
        echo "---------------------------------------------"
        echo -e "9 - ${RED}ПОЛНОЕ УДАЛЕНИЕ ВСЕХ КОМПОНЕНТОВ${NC}"
        echo "0 - Выход"
        echo "---------------------------------------------"
        read -p "Ваш выбор: " main_choice

        case $main_choice in
            1) vmware_tools_menu ;;
            2) docker_menu ;;
            3) ssh_server_menu ;;
            4) full_install; read -p $'\nНажмите Enter для возврата в главное меню...' ;;
            5) full_reinstall; read -p $'\nНажмите Enter для возврата в главное меню...' ;;
            9) full_uninstall; read -p $'\nНажмите Enter для возврата в главное меню...' ;;
            0) echo -e "${GREEN}Работа завершена. До свидания!${NC}"; exit 0 ;;
            *) echo -e "\n${RED}Неверный выбор. Пожалуйста, попробуйте снова.${NC}"; sleep 2 ;;
        esac
    done
}

# Запуск скрипта
main