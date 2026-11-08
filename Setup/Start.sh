#!/bin/bash

# Автоматически определяем директорию, где лежит этот скрипт
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Сразу выдаем права на исполнение всем скриптам в папке проекта
chmod +x "$ROOT_DIR"/*.sh 2>/dev/null || true
chmod +x "$ROOT_DIR"/Other/*.sh 2>/dev/null || true

if [[ -f "$ROOT_DIR/Other/menu.sh" ]]; then
    source "$ROOT_DIR/Other/menu.sh"
else
    echo -e "\e[31m[X] Error: 'Other/menu.sh' not found!\e[0m"
    exit 1
fi

# ==============================================================================
# ЦВЕТА И СТИЛИ ДЛЯ ИНТЕРФЕЙСА (ANSI-коды)
# ==============================================================================
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

# Цвета текста
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"

# Быстрое обновление при первом запуске
echo -e "${CYAN}Checking for system updates...${RESET}"
apt update && apt upgrade -y

# Функция паузы
pause() {
    echo
    read -p "Press Enter to continue..." dummy
}

# ==============================================================================
# ГЛАВНЫЙ ЦИКЛ СУПЕРВИЗОРА
# ==============================================================================
while true; do
    menu_select "MAIN MENU" \
        "${GREEN}${BOLD}[1]${RESET} Termux Setup ${DIM}(Drivers, Packages, Themes)${RESET}" \
        "${GREEN}${BOLD}[2]${RESET} Proot-distro ${DIM}(Arch Linux ARM Environment)${RESET}" \
        "${GREEN}${BOLD}[3]${RESET} Info & Credits" \
        "${RED}${BOLD}[0]${RESET} Exit"

    case $MENU_RESULT in
        0)
            clear
            if [[ -f "$ROOT_DIR/Other/Termux.sh" ]]; then
                bash "$ROOT_DIR/Other/Termux.sh"
                exit 0
            else
                echo -e "${RED}[X] Error: 'Other/Termux.sh' not found!${RESET}"
                pause
            fi
            ;;
        1)
            clear
            if [[ -f "$ROOT_DIR/Other/Proot.sh" ]]; then
                bash "$ROOT_DIR/Other/Proot.sh"
            else
                echo -e "${RED}[X] Error: 'Other/Proot.sh' not found!${RESET}"
                pause
            fi
            ;;
        2)
            clear
            ui_header "SCRIPT INFO"
            echo -e " ${YELLOW}Developer:${RESET}  OStone"
            echo -e " ${YELLOW}AI Assistant:${RESET} Gemini AI (Code structure, logic fixes & styling)"
            echo -e " ${YELLOW}Purpose:${RESET}    Automated setup for Termux and PRoot environments"
            echo -e " ${YELLOW}Tested on:${RESET}  Termux v0.119.0-beta3"
            echo
            echo -e " ${RED}${BOLD}[!] DISCLAIMER:${RESET}"
            echo -e " ${DIM}This script may contain bugs or layout mistakes.${RESET}"
            echo -e " ${DIM}Use it at your own risk. The author carries no${RESET}"
            echo -e " ${DIM}responsibility for broken environments or data loss.${RESET}"
            pause
            ;;
        3)
            clear
            echo -e "${GREEN}Goodbye! See you soon.${RESET}"
            exit 0
            ;;
    esac
done
