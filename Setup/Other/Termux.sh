#!/bin/bash

# Определяем директорию, где лежит САМ этот скрипт (то есть папку Other)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

source "$SCRIPT_DIR/menu.sh"

# Функция паузы
pause() {
    echo
    read -p "Press Enter to continue..." dummy
}

# Проверка локальных файлов внутри папки Other/
check_files() {
    local missing=0
    echo -e "${CYAN}Scanning 'Other/' directory for assets...${RESET}"
    
    if [[ ! -f "$SCRIPT_DIR/colors.properties" ]]; then
        echo -e "${YELLOW}[!] Warning: 'colors.properties' not found in $SCRIPT_DIR${RESET}"
        missing=1
    fi
    if [[ ! -f "$SCRIPT_DIR/font.ttf" ]]; then
        echo -e "${YELLOW}[!] Warning: 'font.ttf' not found in $SCRIPT_DIR${RESET}"
        missing=1
    fi
    if [[ ! -d "$SCRIPT_DIR/fastfetch" ]]; then
        echo -e "${YELLOW}[!] Warning: 'fastfetch/' directory not found in $SCRIPT_DIR${RESET}"
        missing=1
    fi
    if [[ ! -f "$SCRIPT_DIR/.zshrc" ]]; then
        echo -e "${YELLOW}[!] Warning: Custom '.zshrc' configuration not found in $SCRIPT_DIR${RESET}"
        missing=1
    fi
    
    if [[ $missing -eq 0 ]]; then
        echo -e "${GREEN}[✓] All configuration assets found inside 'Other/'!${RESET}"
    fi
    echo
    sleep 1.2
}

# ==============================================================================
# ADVANCED SETUP (дерево пакетов)
# ==============================================================================
ADV_CAT_LABELS=(
    "${GREEN}${BOLD}[1]${RESET} Install base packages"
    "${GREEN}${BOLD}[2]${RESET} Install Mesa components ${DIM}(Recommended)${RESET}"
    "${GREEN}${BOLD}[3]${RESET} Install Vulkan components"
    "${GREEN}${BOLD}[4]${RESET} Install Extra Graphics drivers"
    "${GREEN}${BOLD}[5]${RESET} Install Glibc environment ${DIM}(apt install glibc)${RESET}"
    "${GREEN}${BOLD}[6]${RESET} Install Mesa-Glibc stack ${DIM}(apt install mesa-glibc)${RESET}"
)
ADV_CAT_PKGS_0=(x11-repo root-repo tur-repo glibc-repo clang python ruby git curl wget fastfetch neovim termux-x11-nightly)
ADV_CAT_PKGS_1=(mesa mesa-dev mesa-opencl-icd-rusticl mesa-vulkan-icd-freedreno mesa-vulkan-icd-swrast virglrenderer)
ADV_CAT_PKGS_2=(clvk shaderc swiftshader vulkan-extension-layer vulkan-headers vulkan-tools vulkan-volk vulkan-utility-libraries vulkan-validation-layers)
ADV_CAT_PKGS_3=(glfw angle-android glslang libepoxy libftgl2 opengl clinfo clpeak ocl-icd opencl-headers opencl-vendor-driver)
ADV_CAT_PKGS_4=(glibc)
ADV_CAT_PKGS_5=(mesa-glibc)

declare -A ADV_PKG_SEL
declare -A ADV_CAT_SEL

adv_cat_count() {
    local -n p="ADV_CAT_PKGS_$1"
    printf '%s' "${#p[@]}"
}

adv_pkg_name() {
    local -n p="ADV_CAT_PKGS_$1"
    ADV_PKG_NAME="${p[$2]}"
}

adv_set_all() {
    local c=$1 val=$2 i
    local -n p="ADV_CAT_PKGS_$c"
    for i in "${!p[@]}"; do
        ADV_PKG_SEL["$c:$i"]=$val
    done
}

adv_cat_any() {
    local c=$1 i
    local -n p="ADV_CAT_PKGS_$c"
    for i in "${!p[@]}"; do
        [[ ${ADV_PKG_SEL["$c:$i"]} == 1 ]] && return 0
    done
    return 1
}

adv_cat_all() {
    local c=$1 i
    local -n p="ADV_CAT_PKGS_$c"
    for i in "${!p[@]}"; do
        [[ ${ADV_PKG_SEL["$c:$i"]} == 1 ]] || return 1
    done
    return 0
}

adv_init_selection() {
    local c
    for c in "${!ADV_CAT_LABELS[@]}"; do
        ADV_CAT_SEL[$c]=0
        adv_set_all "$c" 1
    done
}

adv_cat_mark() {
    local c=$1
    if [[ ${ADV_CAT_SEL[$c]} == 1 ]]; then
        if adv_cat_all "$c"; then
            printf '%b[x]%b' "$GREEN" "$RESET"
        else
            printf '%b[-]%b' "$YELLOW" "$RESET"
        fi
    else
        printf '[ ]'
    fi
}

adv_preview_line() {
    local c=$1 i=$2 conn=$3 mark
    if [[ ${ADV_PKG_SEL["$c:$i"]} == 1 ]]; then
        mark="${GREEN}[x]${RESET}"
    else
        mark="[ ]"
    fi
    adv_pkg_name "$c" "$i"
    printf '     %b %b %b\n' "$conn" "$mark" "$ADV_PKG_NAME"
}

adv_print_preview() {
    local c=$1 count=$2 i conn
    if (( count > 5 )); then
        for (( i = 0; i < 4; i++ )); do
            adv_preview_line "$c" "$i" "├─"
        done
        printf '     %b└─ ... (%d more, → to edit)%b\n' "$DIM" "$(( count - 4 ))" "$RESET"
    else
        for (( i = 0; i < count; i++ )); do
            conn="├─"
            (( i == count - 1 )) && conn="└─"
            adv_preview_line "$c" "$i" "$conn"
        done
    fi
}

adv_run_category() {
    local c=$1 i p
    local -n pkgs="ADV_CAT_PKGS_$c"
    local -a chosen=()

    for i in "${!pkgs[@]}"; do
        [[ ${ADV_PKG_SEL["$c:$i"]} == 1 ]] && chosen+=("${pkgs[$i]}")
    done
    (( ${#chosen[@]} == 0 )) && return 0

    echo -e "\n${CYAN}Installing:${RESET} ${chosen[*]}"

    if (( c == 0 )); then
        apt update && apt upgrade -y
        local -a repos=() rest=()
        for p in "${chosen[@]}"; do
            case "$p" in
                *-repo) repos+=("$p") ;;
                *) rest+=("$p") ;;
            esac
        done
        if (( ${#repos[@]} > 0 )); then
            apt install -y "${repos[@]}" && apt update
        fi
        if (( ${#rest[@]} > 0 )); then
            apt install -y "${rest[@]}"
        fi
    else
        apt install -y "${chosen[@]}"
    fi
    echo -e "${GREEN}[✓] Category $((c + 1)) complete.${RESET}"
}

# ==============================================================================
# ПОДМЕНЮ 2: ADVANCED SETUP (Драйверы и компоненты)
# ==============================================================================
advanced_setup_menu() {
    local mode="cats"
    local cat_cur=0 pkg_cur=0
    local cat_count=${#ADV_CAT_LABELS[@]}
    local count i key rest apply ran

    adv_init_selection

    while true; do
        apply=0
        clear
        ui_header "ADVANCED SETUP"

        if [[ $mode == "cats" ]]; then
            for (( i = 0; i < cat_count; i++ )); do
                count=$(adv_cat_count "$i")
                if (( i == cat_cur )); then
                    printf ' %b❯%b %b %b\n' "${GREEN}${BOLD}" "${RESET}" "$(adv_cat_mark "$i")" "${ADV_CAT_LABELS[$i]}"
                    adv_print_preview "$i" "$count"
                else
                    printf '   %b %b\n' "$(adv_cat_mark "$i")" "${ADV_CAT_LABELS[$i]}"
                fi
            done
            printf '\n %b↑/↓ move · Space toggle · → packages · Enter apply · Esc back%b\n' "$DIM" "$RESET"
        else
            count=$(adv_cat_count "$cat_cur")
            printf ' %b%s%b  %b(%d packages)%b\n\n' "$BOLD" "${ADV_CAT_LABELS[$cat_cur]}" "$RESET" \
                "$DIM" "$count" "$RESET"
            for (( i = 0; i < count; i++ )); do
                local mark conn
                if [[ ${ADV_PKG_SEL["$cat_cur:$i"]} == 1 ]]; then
                    mark="${GREEN}[x]${RESET}"
                else
                    mark="[ ]"
                fi
                conn="├─"
                (( i == count - 1 )) && conn="└─"
                adv_pkg_name "$cat_cur" "$i"
                if (( i == pkg_cur )); then
                    printf ' %b❯%b %b %b %b\n' "${GREEN}${BOLD}" "${RESET}" "$conn" "$mark" "$ADV_PKG_NAME"
                else
                    printf '   %b %b %b\n' "$conn" "$mark" "$ADV_PKG_NAME"
                fi
            done
            printf '\n %b↑/↓ move · Space toggle · ← back · Enter apply%b\n' "$DIM" "$RESET"
        fi

        IFS= read -rsn1 key

        if [[ -z "$key" ]]; then
            apply=1
        elif [[ $mode == "cats" ]]; then
            case "$key" in
                " ")
                    if [[ ${ADV_CAT_SEL[$cat_cur]} == 1 ]]; then
                        ADV_CAT_SEL[$cat_cur]=0
                    else
                        ADV_CAT_SEL[$cat_cur]=1
                        adv_set_all "$cat_cur" 1
                    fi
                    ;;
                $'\x1b')
                    IFS= read -rsn2 -t 0.05 rest
                    case "$rest" in
                        '[A'|'OA') (( cat_cur-- )) ;;
                        '[B'|'OB') (( cat_cur++ )) ;;
                        '[C'|'OC')
                            ADV_CAT_SEL[$cat_cur]=1
                            adv_cat_any "$cat_cur" || adv_set_all "$cat_cur" 1
                            if (( $(adv_cat_count "$cat_cur") > 0 )); then
                                mode="pkgs"
                                pkg_cur=0
                            fi
                            ;;
                        '') return ;;
                    esac
                    ;;
                k|K) (( cat_cur-- )) ;;
                j|J) (( cat_cur++ )) ;;
            esac
            (( cat_cur < 0 )) && cat_cur=$(( cat_count - 1 ))
            (( cat_cur >= cat_count )) && cat_cur=0
        else
            count=$(adv_cat_count "$cat_cur")
            case "$key" in
                " ")
                    if [[ ${ADV_PKG_SEL["$cat_cur:$pkg_cur"]} == 1 ]]; then
                        ADV_PKG_SEL["$cat_cur:$pkg_cur"]=0
                    else
                        ADV_PKG_SEL["$cat_cur:$pkg_cur"]=1
                    fi
                    if adv_cat_any "$cat_cur"; then
                        ADV_CAT_SEL[$cat_cur]=1
                    else
                        ADV_CAT_SEL[$cat_cur]=0
                    fi
                    ;;
                $'\x1b')
                    IFS= read -rsn2 -t 0.05 rest
                    case "$rest" in
                        '[A'|'OA') (( pkg_cur-- )) ;;
                        '[B'|'OB') (( pkg_cur++ )) ;;
                        '[D'|'OD') mode="cats" ;;
                        '') mode="cats" ;;
                    esac
                    ;;
                k|K) (( pkg_cur-- )) ;;
                j|J) (( pkg_cur++ )) ;;
                h|H) mode="cats" ;;
            esac
            if [[ $mode == "pkgs" ]]; then
                (( pkg_cur < 0 )) && pkg_cur=$(( count - 1 ))
                (( pkg_cur >= count )) && pkg_cur=0
            fi
        fi

        if (( apply )); then
            clear
            ran=0
            for (( i = 0; i < cat_count; i++ )); do
                if [[ ${ADV_CAT_SEL[$i]} == 1 ]] && adv_cat_any "$i"; then
                    adv_run_category "$i"
                    ran=1
                fi
            done
            if (( ran == 0 )); then
                echo -e "${YELLOW}[!] No packages selected.${RESET}"
            fi
            pause
            mode="cats"
        fi
    done
}

# ==============================================================================
# ДЕЙСТВИЯ: COSMETIC SETUP
# ==============================================================================
cos_zsh() {
    echo -e "\n${CYAN}Setting up Zsh environment...${RESET}"
    apt install -y zsh lsd fzf
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    echo -e "${CYAN}Cloning themes and plugins...${RESET}"
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    echo -e "${GREEN}[✓] Zsh environment ready.${RESET}"
}

cos_fish() {
    local fish_config="$HOME/.config/fish/config.fish"

    echo -e "\n${CYAN}Installing Fish shell...${RESET}"
    apt install -y fish

    mkdir -p "$HOME/.config/fish"
    touch "$fish_config"
    grep -vE '^[[:space:]]*set[[:space:]].*fish_greeting' "$fish_config" > "$fish_config.tmp" || true
    mv "$fish_config.tmp" "$fish_config"
    echo 'set -g fish_greeting ""' >> "$fish_config"

    echo -e "${GREEN}[✓] Fish shell installed (greeting disabled).${RESET}"
    echo -e "${DIM}Set it as default with: chsh -s $PREFIX/bin/fish${RESET}"
}

apply_welcome_rxfetch() {
    echo -e "\n${CYAN}Configuring rxfetch welcome screen...${RESET}"

    apt install -y rxfetch

    mkdir -p ~/.termux
    ln -sf $PREFIX/etc/motd.sh ~/.termux/motd.sh

    echo "#!/data/data/com.termux/files/usr/bin/bash" > ~/.termux/motd.sh
    echo "rxfetch" >> ~/.termux/motd.sh
    chmod +x ~/.termux/motd.sh

    echo -e "${GREEN}[✓] rxfetch welcome screen enabled.${RESET}"
}

apply_welcome_fastfetch() {
    echo -e "\n${CYAN}Configuring fastfetch welcome screen...${RESET}"

    apt install -y fastfetch

    if [[ -d "$SCRIPT_DIR/fastfetch" ]]; then
        mkdir -p ~/.config
        rm -rf ~/.config/fastfetch
        cp -r "$SCRIPT_DIR/fastfetch" ~/.config/
    fi

    mkdir -p ~/.termux
    ln -sf $PREFIX/etc/motd.sh ~/.termux/motd.sh

    echo "#!/data/data/com.termux/files/usr/bin/bash" > ~/.termux/motd.sh
    echo "fastfetch" >> ~/.termux/motd.sh
    chmod +x ~/.termux/motd.sh

    echo -e "${GREEN}[✓] fastfetch welcome screen enabled.${RESET}"
}

configure_motd() {
    menu_select "WELCOME SCREEN" \
        "fastfetch ${DIM}(Custom config + logos)${RESET}" \
        "rxfetch ${DIM}(Lightweight)${RESET}"
    case $MENU_RESULT in
        0) apply_welcome_fastfetch ;;
        1) apply_welcome_rxfetch ;;
    esac
}

cos_motd() {
    configure_motd
}

cos_colors() {
    echo -e "\n${CYAN}Applying Colors...${RESET}"
    if [[ -f "$SCRIPT_DIR/colors.properties" ]]; then
        mkdir -p ~/.termux
        cp "$SCRIPT_DIR/colors.properties" ~/.termux/
        termux-reload-settings
        echo -e "${GREEN}[✓] Color scheme applied.${RESET}"
    else
        echo -e "${RED}[X] Error: colors.properties not found in $SCRIPT_DIR${RESET}"
    fi
}

cos_font() {
    echo -e "\n${CYAN}Applying Font...${RESET}"
    if [[ -f "$SCRIPT_DIR/font.ttf" ]]; then
        mkdir -p ~/.termux
        cp "$SCRIPT_DIR/font.ttf" ~/.termux/
        termux-reload-settings
        echo -e "${GREEN}[✓] Font file applied successfully.${RESET}"
    else
        echo -e "${RED}[X] Error: font.ttf not found in $SCRIPT_DIR${RESET}"
    fi
}

cos_fastfetch() {
    echo -e "\n${CYAN}Configuring Fastfetch...${RESET}"
    if [[ -d "$SCRIPT_DIR/fastfetch" ]]; then
        mkdir -p ~/.config
        rm -rf ~/.config/fastfetch
        cp -r "$SCRIPT_DIR/fastfetch" ~/.config/
        echo -e "${GREEN}[✓] Custom Fastfetch setup applied (including scripts and logos).${RESET}"
    else
        echo -e "${RED}[X] Error: fastfetch/ folder missing in $SCRIPT_DIR${RESET}"
    fi
}

cos_zshrc() {
    echo -e "\n${CYAN}Applying Custom .zshrc Config...${RESET}"
    if [[ -f "$SCRIPT_DIR/.zshrc" ]]; then
        if [[ -f "$HOME/.zshrc" ]]; then
            mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
            echo -e "${DIM}Existing .zshrc moved to .zshrc.bak${RESET}"
        fi
        cp "$SCRIPT_DIR/.zshrc" "$HOME/"
        echo -e "${GREEN}[✓] Custom .zshrc configuration applied successfully.${RESET}"
    else
        echo -e "${RED}[X] Error: .zshrc missing in $SCRIPT_DIR${RESET}"
    fi
}

run_cosmetic_step() {
    case $1 in
        0) cos_zsh ;;
        1) cos_fish ;;
        2) cos_motd ;;
        3) cos_colors ;;
        4) cos_font ;;
        5) cos_fastfetch ;;
        6) cos_zshrc ;;
    esac
}

# ==============================================================================
# ПОДМЕНЮ 3: COSMETIC SETUP (Кастомизация внешнего вида)
# ==============================================================================
cosmetic_setup_menu() {
    local -a items=(
        "${GREEN}${BOLD}[1]${RESET} Install Zsh ${DIM}(Oh-My-Zsh + p10k)${RESET}"
        "${GREEN}${BOLD}[2]${RESET} Install Fish shell"
        "${GREEN}${BOLD}[3]${RESET} Configure welcome screen ${DIM}(Fastfetch / rxfetch)${RESET}"
        "${GREEN}${BOLD}[4]${RESET} Apply custom Colors"
        "${GREEN}${BOLD}[5]${RESET} Apply custom Font"
        "${GREEN}${BOLD}[6]${RESET} Apply custom Fastfetch config"
        "${GREEN}${BOLD}[7]${RESET} Copy custom .zshrc config"
    )
    local idx

    while true; do
        if ! menu_multiselect "COSMETIC SETUP" "${items[@]}"; then
            return
        fi
        (( ${#MENU_SELECTED[@]} == 0 )) && return

        clear
        for idx in "${MENU_SELECTED[@]}"; do
            run_cosmetic_step "$idx"
        done
        pause
    done
}

set_default_shell() {
    local shell="$1"
    local path="$PREFIX/bin/$shell"

    if [[ ! -x "$path" ]]; then
        echo -e "${RED}[X] $shell not found at $path${RESET}"
        return 1
    fi

    if "$PREFIX/bin/chsh" -s "$shell" >/dev/null 2>&1; then
        echo -e "${GREEN}[✓] Default shell set to $shell.${RESET}"
        echo -e "${DIM}Restart Termux to apply the new shell.${RESET}"
        return 0
    fi

    echo -e "${YELLOW}[!] Could not set default shell automatically.${RESET}"
    echo -e "${DIM}Run manually: chsh -s $shell${RESET}"
    return 1
}

# ==============================================================================
# ONE-TAP FULL INSTALL
# ==============================================================================
one_tap_install() {
    local default_shell welcome

    menu_select "DEFAULT SHELL" \
        "bash ${DIM}(Default Termux shell)${RESET}" \
        "fish ${DIM}(Friendly Interactive Shell)${RESET}" \
        "zsh ${DIM}(Zsh + Oh-My-Zsh)${RESET}"
    case $MENU_RESULT in
        0) default_shell="bash" ;;
        1) default_shell="fish" ;;
        2) default_shell="zsh" ;;
        *) default_shell="bash" ;;
    esac

    menu_select "WELCOME SCREEN" \
        "fastfetch ${DIM}(Custom config + logos)${RESET}" \
        "rxfetch ${DIM}(Lightweight)${RESET}"
    case $MENU_RESULT in
        0) welcome="fastfetch" ;;
        1) welcome="rxfetch" ;;
        *) welcome="fastfetch" ;;
    esac

    echo -e "\n${YELLOW}${BOLD}Starting Scripted One-Tap Automated Process...${RESET}"
    echo -e "${CYAN}Selected default shell:${RESET} ${BOLD}${default_shell}${RESET}"
    echo -e "${CYAN}Selected welcome screen:${RESET} ${BOLD}${welcome}${RESET}"

    apt update && apt upgrade -y
    apt install -y x11-repo root-repo tur-repo glibc-repo && apt update
    apt install -y clang python ruby git curl wget fastfetch neovim termux-x11-nightly

    apt install -y mesa mesa-dev mesa-opencl-icd-rusticl mesa-vulkan-icd-freedreno mesa-vulkan-icd-swrast virglrenderer
    apt install -y clvk shaderc swiftshader vulkan-extension-layer vulkan-headers vulkan-tools vulkan-volk vulkan-utility-libraries vulkan-validation-layers
    apt install -y glfw angle-android glslang libepoxy libftgl2 opengl clinfo clpeak ocl-icd opencl-headers opencl-vendor-driver

    apt install -y zsh lsd fzf
    if [[ "$default_shell" == "fish" ]]; then
        cos_fish
    fi
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

    if [[ -f "$SCRIPT_DIR/.zshrc" ]]; then
        cp "$SCRIPT_DIR/.zshrc" "$HOME/"
        echo -e "${GREEN}[✓] Custom .zshrc deployed in full install.${RESET}"
    fi

    case "$welcome" in
        fastfetch) apply_welcome_fastfetch ;;
        rxfetch) apply_welcome_rxfetch ;;
    esac

    if [[ -f "$SCRIPT_DIR/colors.properties" ]]; then
        cp "$SCRIPT_DIR/colors.properties" ~/.termux/
    fi
    if [[ -f "$SCRIPT_DIR/font.ttf" ]]; then
        cp "$SCRIPT_DIR/font.ttf" ~/.termux/
    fi

    set_default_shell "$default_shell"
    termux-reload-settings

    echo -e "\n${GREEN}${BOLD}One-tap installation completely finished!${RESET}"
    exit
}

# ==============================================================================
# ГЛАВНЫЙ ЦИКЛ ПРОГРАММЫ (ОСНОВНОЕ МЕНЮ)
# ==============================================================================

# Запускаем проверку один раз при старте Termux.sh
clear
check_files

while true; do
    menu_select "TERMUX ADVANCED SETUP" \
        "${YELLOW}${BOLD}[1]${RESET} One-tap Full Install ${DIM}(Scripted Automated Process)${RESET}" \
        "${GREEN}${BOLD}[2]${RESET} Advanced Setup ${DIM}(Base, Mesa, Vulkan, Extra, Glibc)${RESET}" \
        "${GREEN}${BOLD}[3]${RESET} Cosmetic Setup ${DIM}(Zsh, Fish, Welcome Screen, Colors, Fonts)${RESET}" \
        "${RED}${BOLD}[0]${RESET} Exit"

    case $MENU_RESULT in
        0)
            one_tap_install
            ;;
        1)
            advanced_setup_menu
            ;;
        2)
            cosmetic_setup_menu
            ;;
        3)
            clear
            echo -e "${GREEN}Session terminated. Goodbye!${RESET}"
            exit 0
            ;;
    esac
done
