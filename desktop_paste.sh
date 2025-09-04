#!/bin/bash

# Останавливаем выполнение скрипта, если любая команда завершится с ошибкой
set -e

# --- Цвета для красивого вывода ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Функции ---

# Функция для проверки, установлен ли пакет
# Возвращает 0 (успех), если пакет установлен, и 1 (неудача) в противном случае.
is_package_installed() {
    # dpkg-query -s возвращает статус пакета. Перенаправляем вывод, чтобы не засорять консоль.
    dpkg-query -s "$1" &> /dev/null
}

# Функция для вывода финального сообщения об успехе
show_success_message() {
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}         Операция успешно завершена!                                  ${NC}"
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

# Функция установки
install_tools() {
    echo -e "\n--- ${YELLOW}Запуск установки open-vm-tools-desktop${NC} ---"
    
    # ВАЛИДАЦИЯ: Проверяем, не установлен ли пакет уже
    if is_package_installed "open-vm-tools-desktop"; then
        echo -e "${GREEN}Пакет 'open-vm-tools-desktop' уже установлен.${NC}"
        echo -e "${YELLOW}Если вы хотите переустановить его, выберите соответствующий пункт в меню.${NC}"
        return
    fi
    
    # ВАЛИДАЦИЯ: Проверяем и удаляем базовую версию, если она есть
    if is_package_installed "open-vm-tools"; then
        echo -e "${YELLOW}Обнаружен конфликтующий пакет 'open-vm-tools'. Удаляем его...${NC}"
        sudo apt-get update
        sudo apt-get autoremove -y open-vm-tools
        echo -e "${GREEN}Пакет 'open-vm-tools' успешно удален.${NC}"
    else
        echo -e "${GREEN}Конфликтующий пакет 'open-vm-tools' не найден. Продолжаем...${NC}"
    fi

    echo -e "\n${YELLOW}Обновляем список пакетов перед установкой...${NC}"
    sudo apt-get update

    echo -e "${YELLOW}Устанавливаем 'open-vm-tools-desktop'...${NC}"
    sudo apt-get install -y open-vm-tools-desktop

    # Финальная валидация
    if is_package_installed "open-vm-tools-desktop"; then
        show_success_message
    else
        echo -e "${RED}ОШИБКА: Не удалось установить пакет 'open-vm-tools-desktop'. Проверьте вывод выше.${NC}"
        exit 1
    fi
}

# Функция переустановки
reinstall_tools() {
    echo -e "\n--- ${YELLOW}Запуск переустановки open-vm-tools-desktop${NC} ---"
    
    echo -e "${YELLOW}Обновляем список пакетов...${NC}"
    sudo apt-get update
    
    echo -e "${YELLOW}Полностью удаляем предыдущие версии (purge)...${NC}"
    # Команда не вызовет ошибки, если один из пакетов не установлен
    sudo apt-get purge -y open-vm-tools open-vm-tools-desktop
    sudo apt-get autoremove -y # Очищаем оставшиеся зависимости
    
    echo -e "${GREEN}Старые версии успешно удалены.${NC}"
    
    echo -e "\n${YELLOW}Устанавливаем 'open-vm-tools-desktop'...${NC}"
    sudo apt-get install -y open-vm-tools-desktop
    
    # Финальная валидация
    if is_package_installed "open-vm-tools-desktop"; then
        show_success_message
    else
        echo -e "${RED}ОШИБКА: Не удалось переустановить пакет 'open-vm-tools-desktop'. Проверьте вывод выше.${NC}"
        exit 1
    fi
}


# Функция для отображения меню
print_menu() {
    clear
    echo -e "${GREEN}--- Скрипт для настройки VMware Tools на Ubuntu Desktop ---${NC}"
    echo "--------------------------------------------------------"
    
    # Проверяем статус и выводим его в меню
    if is_package_installed "open-vm-tools-desktop"; then
        echo -e "Статус: ${GREEN}open-vm-tools-desktop УСТАНОВЛЕН${NC}"
    else
        echo -e "Статус: ${YELLOW}open-vm-tools-desktop НЕ УСТАНОВЛЕН${NC}"
    fi
    
    echo "--------------------------------------------------------"
    echo "Выберите действие:"
    echo "1 - Установить open-vm-tools-desktop (если не установлен)"
    echo "2 - Переустановить open-vm-tools-desktop (полное удаление и установка)"
    echo "0 - Выход"
    echo "--------------------------------------------------------"
}


# --- Основной цикл скрипта ---

# ВАЛИДАЦИЯ: Проверяем права суперпользователя в самом начале
if [[ $EUID -ne 0 ]]; then
   # Проверяем, может ли пользователь использовать sudo
   if ! sudo -v &> /dev/null; then
     echo -e "${RED}ОШИБКА: Этот скрипт требует прав суперпользователя (sudo). Запустите его с 'sudo ./script.sh' или от имени root.${NC}"
     exit 1
   fi
fi


while true; do
    print_menu
    read -p "Ваш выбор: " choice

    case $choice in
        1)
            install_tools
            read -p $'\nНажмите Enter для возврата в меню...'
            ;;
        2)
            reinstall_tools
            read -p $'\nНажмите Enter для возврата в меню...'
            ;;
        0)
            echo -e "${GREEN}Работа скрипта завершена. Выход.${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Неверный выбор. Пожалуйста, введите 1, 2 или 0.${NC}"
            read -p "Нажмите Enter для продолжения..."
            ;;
    esac
done