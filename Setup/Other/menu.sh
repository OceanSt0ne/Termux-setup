#!/bin/bash

ui_header() {
    local title="$1"
    local inner=40
    local pad=$(( inner - ${#title} ))
    (( pad < 0 )) && pad=0
    local left=$(( pad / 2 ))
    local right=$(( pad - left ))
    local line
    printf -v line '%*s' "$inner" ''
    line="${line// /─}"
    printf '%b┌%s┐%b\n' "${CYAN}${BOLD}" "$line" "${RESET}"
    printf '%b│%*s%s%*s│%b\n' "${CYAN}${BOLD}" "$left" '' "$title" "$right" '' "${RESET}"
    printf '%b└%s┘%b\n' "${CYAN}${BOLD}" "$line" "${RESET}"
    printf '\n'
}

menu_select() {
    local title="$1"
    shift
    local -a items=("$@")
    local count=${#items[@]}
    local cur=0 key rest i
    MENU_RESULT=-1
    (( count == 0 )) && return 1

    printf '\e[?25l'
    while true; do
        clear
        ui_header "$title"
        for (( i = 0; i < count; i++ )); do
            if (( i == cur )); then
                printf ' %b❯%b %b\n' "${GREEN}${BOLD}" "${RESET}" "${items[i]}"
            else
                printf '   %b\n' "${items[i]}"
            fi
        done
        printf '\n %b↑/↓ — move, Enter — select%b\n' "${DIM}" "${RESET}"

        IFS= read -rsn1 key
        case "$key" in
            "")
                break
                ;;
            $'\x1b')
                IFS= read -rsn2 -t 0.05 rest
                case "$rest" in
                    '[A'|'OA') (( cur-- )) ;;
                    '[B'|'OB') (( cur++ )) ;;
                esac
                ;;
            k|K) (( cur-- )) ;;
            j|J) (( cur++ )) ;;
        esac
        (( cur < 0 )) && cur=$(( count - 1 ))
        (( cur >= count )) && cur=0
    done
    printf '\e[?25h'
    MENU_RESULT=$cur
    return 0
}

menu_multiselect() {
    local title="$1"
    shift
    local -a items=("$@")
    local count=${#items[@]}
    local cur=0 key rest i mark pointer
    local -a checked
    for (( i = 0; i < count; i++ )); do checked[i]=0; done
    MENU_SELECTED=()
    (( count == 0 )) && return 1

    printf '\e[?25l'
    while true; do
        clear
        ui_header "$title"
        for (( i = 0; i < count; i++ )); do
            if (( checked[i] )); then
                mark="${GREEN}[x]${RESET}"
            else
                mark="[ ]"
            fi
            if (( i == cur )); then
                pointer="${GREEN}${BOLD}❯${RESET}"
            else
                pointer=" "
            fi
            printf ' %b %b %b\n' "$pointer" "$mark" "${items[i]}"
        done
        printf '\n %bSpace — toggle, Enter — apply, Esc — back%b\n' "${DIM}" "${RESET}"

        IFS= read -rsn1 key
        case "$key" in
            "")
                MENU_SELECTED=()
                for (( i = 0; i < count; i++ )); do
                    (( checked[i] )) && MENU_SELECTED+=("$i")
                done
                printf '\e[?25h'
                return 0
                ;;
            " ")
                checked[cur]=$(( 1 - checked[cur] ))
                ;;
            $'\x1b')
                IFS= read -rsn2 -t 0.05 rest
                case "$rest" in
                    '[A'|'OA') (( cur-- )) ;;
                    '[B'|'OB') (( cur++ )) ;;
                    '')
                        printf '\e[?25h'
                        MENU_SELECTED=()
                        return 1
                        ;;
                esac
                ;;
            k|K) (( cur-- )) ;;
            j|J) (( cur++ )) ;;
            a|A)
                for (( i = 0; i < count; i++ )); do checked[i]=1; done
                ;;
            n|N)
                for (( i = 0; i < count; i++ )); do checked[i]=0; done
                ;;
        esac
        (( cur < 0 )) && cur=$(( count - 1 ))
        (( cur >= count )) && cur=0
    done
}

trap 'printf "\e[?25h"' EXIT
