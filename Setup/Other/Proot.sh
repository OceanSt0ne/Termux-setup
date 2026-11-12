#!/bin/bash

# Находим директорию папки Other
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================================================================
# ЦВЕТА И СТИЛИ ДЛЯ ИНТЕРФЕЙСА (ANSI-коды)
# ==============================================================================
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
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

# Функция проверки proot-distro в самом Termux
check_proot_distro() {
    echo "Checking for proot-distro..."
    if dpkg -s proot-distro &> /dev/null; then
        echo -e "${GREEN}[✓] proot-distro is already installed.${RESET}"
    else
        echo -e "${YELLOW}[!] proot-distro is missing. Deploying package...${RESET}"
        apt update && apt install -y proot-distro
        if [ $? -ne 0 ]; then
            echo -e "${RED}[X] Error: Failed to install proot-distro.${RESET}"
            return 1
        fi
    fi
    return 0
}

# ==============================================================================
# PROOT SETUP (дерево пакетов)
# ==============================================================================
PROOT_DISTRO="archlinuxarm"
PROOT_CAT_LABELS=()

declare -A PROOT_PKG_SEL
declare -A PROOT_CAT_SEL

proot_cat_count() {
    local -n p="PROOT_CAT_PKGS_$1"
    printf '%s' "${#p[@]}"
}

proot_pkg_name() {
    local -n p="PROOT_CAT_PKGS_$1"
    PROOT_PKG_NAME="${p[$2]}"
}

proot_set_all() {
    local c=$1 val=$2 i
    local -n p="PROOT_CAT_PKGS_$c"
    for i in "${!p[@]}"; do
        PROOT_PKG_SEL["$c:$i"]=$val
    done
}

proot_cat_any() {
    local c=$1 i
    local -n p="PROOT_CAT_PKGS_$c"
    for i in "${!p[@]}"; do
        [[ ${PROOT_PKG_SEL["$c:$i"]} == 1 ]] && return 0
    done
    return 1
}

proot_cat_all() {
    local c=$1 i
    local -n p="PROOT_CAT_PKGS_$c"
    for i in "${!p[@]}"; do
        [[ ${PROOT_PKG_SEL["$c:$i"]} == 1 ]] || return 1
    done
    return 0
}

proot_init_selection() {
    local c
    for c in "${!PROOT_CAT_LABELS[@]}"; do
        PROOT_CAT_SEL[$c]=0
        proot_set_all "$c" 1
    done
}

proot_cat_mark() {
    local c=$1
    if [[ ${PROOT_CAT_SEL[$c]} == 1 ]]; then
        if proot_cat_all "$c"; then
            printf '%b[x]%b' "$GREEN" "$RESET"
        else
            printf '%b[-]%b' "$YELLOW" "$RESET"
        fi
    else
        printf '[ ]'
    fi
}

proot_preview_line() {
    local c=$1 i=$2 conn=$3 mark
    if [[ ${PROOT_PKG_SEL["$c:$i"]} == 1 ]]; then
        mark="${GREEN}[x]${RESET}"
    else
        mark="[ ]"
    fi
    proot_pkg_name "$c" "$i"
    printf '     %b %b %b\n' "$conn" "$mark" "$PROOT_PKG_NAME"
}

proot_print_preview() {
    local c=$1 count=$2 i conn
    if (( count > 5 )); then
        for (( i = 0; i < 4; i++ )); do
            proot_preview_line "$c" "$i" "├─"
        done
        printf '     %b└─ ... (%d more, → to edit)%b\n' "$DIM" "$(( count - 4 ))" "$RESET"
    else
        for (( i = 0; i < count; i++ )); do
            conn="├─"
            (( i == count - 1 )) && conn="└─"
            proot_preview_line "$c" "$i" "$conn"
        done
    fi
}

proot_chosen() {
    local c=$1 i
    local -n p="PROOT_CAT_PKGS_$c"
    local -a chosen=()
    for i in "${!p[@]}"; do
        [[ ${PROOT_PKG_SEL["$c:$i"]} == 1 ]] && chosen+=("${p[$i]}")
    done
    PROOT_CHOSEN="${chosen[*]}"
}

proot_load_profile() {
    PROOT_DISTRO="$1"

    case "$PROOT_DISTRO" in
        debian)
            PROOT_CAT_LABELS=(
                "${GREEN}${BOLD}[1]${RESET} Install Debian base system"
                "${GREEN}${BOLD}[2]${RESET} Install kernel & firmware"
                "${GREEN}${BOLD}[3]${RESET} Install GPU / Mesa stack"
                "${GREEN}${BOLD}[4]${RESET} Install Dev Tools"
                "${GREEN}${BOLD}[5]${RESET} Install Utilities"
            )
            PROOT_CAT_PKGS_0=(nano sudo fastfetch wget curl git ca-certificates)
            PROOT_CAT_PKGS_1=(linux-image-arm64 linux-headers-arm64 firmware-linux)
            PROOT_CAT_PKGS_2=(mesa-vulkan-drivers mesa-utils libgl1-mesa-dri vulkan-tools)
            PROOT_CAT_PKGS_3=(build-essential clang python3 python3-pip rustc cargo golang)
            PROOT_CAT_PKGS_4=(htop unzip zip dbus)
            ;;
        void)
            PROOT_CAT_LABELS=(
                "${GREEN}${BOLD}[1]${RESET} Install Void base system"
                "${GREEN}${BOLD}[2]${RESET} Install kernel & firmware"
                "${GREEN}${BOLD}[3]${RESET} Install GPU / Mesa stack"
                "${GREEN}${BOLD}[4]${RESET} Install Dev Tools"
                "${GREEN}${BOLD}[5]${RESET} Install Utilities"
            )
            PROOT_CAT_PKGS_0=(nano sudo fastfetch wget curl git)
            PROOT_CAT_PKGS_1=(linux7.3 linux7.3-headers linux-firmware)
            PROOT_CAT_PKGS_2=(mesa mesa-dri vulkan-loader vulkan-tools)
            PROOT_CAT_PKGS_3=(base-devel clang python3 python3-pip rust cargo go)
            PROOT_CAT_PKGS_4=(htop unzip zip dbus)
            ;;
        archlinux)
            PROOT_CAT_LABELS=(
                "${GREEN}${BOLD}[1]${RESET} Install Arch Linux base system"
                "${GREEN}${BOLD}[2]${RESET} Install Linux Kernel ${DIM}(Headers & Firmware)${RESET}"
                "${GREEN}${BOLD}[3]${RESET} Install GPU Hardware Accel ${DIM}(Mesa)${RESET}"
                "${GREEN}${BOLD}[4]${RESET} Install Dev Tools"
                "${GREEN}${BOLD}[5]${RESET} Install YAY ${DIM}(AUR Helper)${RESET}"
            )
            PROOT_CAT_PKGS_0=(nano sudo fastfetch wget curl git)
            PROOT_CAT_PKGS_1=(linux linux-firmware linux-headers dbus)
            PROOT_CAT_PKGS_2=(mesa mesa-demos unzip vulkan-icd-loader vulkan-headers wget)
            PROOT_CAT_PKGS_3=(wget curl git rust clang python go base-devel)
            PROOT_CAT_PKGS_4=(git base-devel)
            ;;
        archlinuxarm)
            PROOT_CAT_LABELS=(
                "${GREEN}${BOLD}[1]${RESET} Install Arch Linux ARM base system"
                "${GREEN}${BOLD}[2]${RESET} Install Linux Kernel ${DIM}(Headers & Firmware)${RESET}"
                "${GREEN}${BOLD}[3]${RESET} Install GPU Hardware Accel ${DIM}(Mesa Turnip)${RESET}"
                "${GREEN}${BOLD}[4]${RESET} Install Dev Tools"
                "${GREEN}${BOLD}[5]${RESET} Install YAY ${DIM}(AUR Helper)${RESET}"
            )
            PROOT_CAT_PKGS_0=(nano sudo fastfetch wget curl git)
            PROOT_CAT_PKGS_1=(linux linux-firmware linux-headers dbus)
            PROOT_CAT_PKGS_2=(mesa mesa-demos unzip vulkan-icd-loader vulkan-headers wget)
            PROOT_CAT_PKGS_3=(wget curl git rust clang python go base-devel)
            PROOT_CAT_PKGS_4=(git base-devel)
            ;;
    esac
}

# ==============================================================================
# PROOT DISTRO HELPERS
# ==============================================================================
proot_is_installed() {
    local name="$1"
    local base="$PREFIX/var/lib/proot-distro"

    [[ -d "$base/containers/$name" || -d "$base/installed-rootfs/$name" ]]
}

proot_distro_image() {
    case "$1" in
        debian) PROOT_DISTRO_IMAGE="debian:stable" ;;
        void) PROOT_DISTRO_IMAGE="ghcr.io/void-linux/void-musl:latest" ;;
        archlinux) PROOT_DISTRO_IMAGE="archlinux/archlinux:latest" ;;
        archlinuxarm) PROOT_DISTRO_IMAGE="danhunsaker/archlinuxarm:latest" ;;
        *) PROOT_DISTRO_IMAGE="" ;;
    esac
}

proot_install_distro() {
    local name="$1"

    proot_distro_image "$name"
    if [[ -z "$PROOT_DISTRO_IMAGE" ]]; then
        echo -e "${RED}[X] Unknown distribution: $name${RESET}"
        return 1
    fi

    if proot_is_installed "$name"; then
        echo -e "${GREEN}[✓] $name is already installed.${RESET}"
        return 0
    fi

    echo -e "${CYAN}Installing $name (${PROOT_DISTRO_IMAGE})...${RESET}"
    proot-distro install -n "$name" "$PROOT_DISTRO_IMAGE"
}

proot_pm_install() {
    local pkgs="$1"
    [[ -z "$pkgs" ]] && return 0

    case "$PROOT_DISTRO" in
        debian)
            proot-distro login "$PROOT_DISTRO" --shared-tmp -- env PKGS="$pkgs" bash -c '
                apt-get update
                apt-get install -y $PKGS
            '
            ;;
        void)
            proot-distro login "$PROOT_DISTRO" --shared-tmp -- env PKGS="$pkgs" bash -c '
                xbps-install -Sy $PKGS
            '
            ;;
        archlinux|archlinuxarm)
            proot-distro login "$PROOT_DISTRO" --shared-tmp -- env PKGS="$pkgs" bash -c '
                pacman -Syu --noconfirm
                pacman -S --noconfirm $PKGS
            '
            ;;
    esac
}

proot_install_arch_user() {
    local pkgs="$1"
    local username userpass

    read -p "Enter username to create: " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}Username cannot be empty.${RESET}"
        return 1
    fi

    read -s -p "Enter password for $username (default 'qwerty'): " userpass
    echo
    [[ -z "$userpass" ]] && userpass="qwerty"

    proot-distro login "$PROOT_DISTRO" --shared-tmp -- env USERNAME="$username" USERPASS="$userpass" PKGS="$pkgs" DISTRO="$PROOT_DISTRO" bash -c '
        sed -i "s/^DownloadUser = alpm/# DownloadUser = alpm/" /etc/pacman.conf 2>/dev/null || true
        sed -i "s/#DisableSandboxFilesystem/DisableSandboxFilesystem/" /etc/pacman.conf 2>/dev/null || true
        sed -i "s/#DisableSandboxSyscalls/DisableSandboxSyscalls/" /etc/pacman.conf 2>/dev/null || true

        pacman -Syu --noconfirm
        if [ -n "$PKGS" ]; then
            pacman -S --noconfirm $PKGS
        fi

        useradd -m -G wheel "$USERNAME" 2>/dev/null || true
        echo "$USERNAME:$USERPASS" | chpasswd
        echo "$USERNAME ALL=(ALL:ALL) ALL" >> /etc/sudoers

        clear
        echo -e "\e[32m\e[1mArch Linux setup complete! User $USERNAME configured.\e[0m"
        echo "To enter: proot-distro login $DISTRO -> su - $USERNAME"
    '
}

proot_install_turnip() {
    proot-distro login archlinuxarm --shared-tmp -- bash -c '
        cd /tmp
        wget -q --show-progress https://github.com/MatrixhKa/mesa-turnip/releases/download/24.1.0/mesa-turnip-kgsl-24.1.0-devel.zip

        rm -rf turnip
        unzip mesa-turnip-kgsl-24.1.0-devel.zip -d turnip/
        cd turnip/

        mkdir -p /usr/share/vulkan/icd.d/
        mv libvulkan_freedreno.so /usr/lib/
        mv freedreno_icd.aarch64.json /usr/share/vulkan/icd.d/

        cd /tmp
        rm -rf turnip mesa-turnip-kgsl-24.1.0-devel.zip
        echo -e "\e[32m\e[1mMesa Turnip hardware stack deployed!\e[0m"
    '
}

proot_install_yay() {
    local pkgs="$1"

    echo -e "\n${CYAN}Installing YAY (AUR Helper) directly via PRoot optimized builder...${RESET}"
    proot-distro login "$PROOT_DISTRO" --shared-tmp -- env PKGS="$pkgs" bash -c '
        if [ -n "$PKGS" ]; then
            pacman -S --noconfirm --needed $PKGS
        fi

        rm -rf /root/yay-bin

        cd /root
        echo "Cloning YAY repository..."
        git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin

        echo "Compiling YAY package..."

        export FORCE_UNSAFE_CONFIGURE=1
        makepkg -s --noconfirm --asroot 2>/dev/null || makepkg -s --noconfirm --allow-root 2>/dev/null || touch .failed_flags

        if [ -f .failed_flags ]; then
            rm .failed_flags
            useradd -m builder 2>/dev/null
            chown -R builder:builder /root/yay-bin
            su - builder -c "cd /root/yay-bin && makepkg -s --noconfirm"
        fi

        echo "Installing compiled package..."
        PACKAGE_FILE=$(ls /root/yay-bin/yay-bin-*.pkg.tar.* 2>/dev/null | head -n 1)

        if [[ -n "$PACKAGE_FILE" && -f "$PACKAGE_FILE" ]]; then
            pacman -U --noconfirm "$PACKAGE_FILE"
            echo -e "\e[32m\e[1m[✓] YAY AUR Helper successfully deployed!\e[0m"
        else
            echo -e "\e[31m\e[1m[X] Error: Package compilation failed.\e[0m"
        fi

        rm -rf /root/yay-bin
        userdel -r builder 2>/dev/null
    '
}

proot_run_step() {
    local c=$1
    proot_chosen "$c"
    local pkgs="$PROOT_CHOSEN"

    if (( c == 0 )); then
        proot_install_distro "$PROOT_DISTRO" || return 1
        if [[ "$PROOT_DISTRO" == archlinux* ]]; then
            proot_install_arch_user "$pkgs"
        else
            proot_pm_install "$pkgs"
        fi
        return
    fi

    if ! proot_is_installed "$PROOT_DISTRO"; then
        echo -e "${RED}[X] $PROOT_DISTRO is not installed. Run step [1] first.${RESET}"
        return 1
    fi

    if [[ "$PROOT_DISTRO" == archlinux* && $c -eq 4 ]]; then
        proot_install_yay "$pkgs"
        return
    fi

    proot_pm_install "$pkgs"

    if [[ "$PROOT_DISTRO" == "archlinuxarm" && $c -eq 2 ]]; then
        proot_install_turnip
    fi
}

# ==============================================================================
# ВЫБОР ДИСТРИБУТИВА
# ==============================================================================
select_proot_distro() {
    local -a labels=()
    local d n=1

    for d in debian void archlinux archlinuxarm; do
        if proot_is_installed "$d"; then
            labels+=("${GREEN}${BOLD}[$n]${RESET} $d ${DIM}(installed)${RESET}")
        else
            labels+=("${GREEN}${BOLD}[$n]${RESET} $d")
        fi
        (( n++ ))
    done
    labels+=("${RED}${BOLD}[0]${RESET} Back to Main Menu")

    menu_select "PROOT DISTRIBUTION" "${labels[@]}"

    case $MENU_RESULT in
        0) PROOT_DISTRO="debian" ;;
        1) PROOT_DISTRO="void" ;;
        2) PROOT_DISTRO="archlinux" ;;
        3) PROOT_DISTRO="archlinuxarm" ;;
        *) return 1 ;;
    esac

    proot_load_profile "$PROOT_DISTRO"
    return 0
}

# ==============================================================================
# ПОДМЕНЮ PROOT SETUP
# ==============================================================================
proot_setup_menu() {
    local mode="cats"
    local cat_cur=0 pkg_cur=0
    local cat_count=${#PROOT_CAT_LABELS[@]}
    local count i key rest apply ran

    proot_init_selection

    while true; do
        apply=0
        clear
        ui_header "PROOT: $PROOT_DISTRO"

        if [[ $mode == "cats" ]]; then
            for (( i = 0; i < cat_count; i++ )); do
                count=$(proot_cat_count "$i")
                if (( i == cat_cur )); then
                    printf ' %b❯%b %b %b\n' "${GREEN}${BOLD}" "${RESET}" "$(proot_cat_mark "$i")" "${PROOT_CAT_LABELS[$i]}"
                    proot_print_preview "$i" "$count"
                else
                    printf '   %b %b\n' "$(proot_cat_mark "$i")" "${PROOT_CAT_LABELS[$i]}"
                fi
            done
            printf '\n %b↑/↓ move · Space toggle · → packages · Enter apply · Esc back%b\n' "$DIM" "$RESET"
        else
            count=$(proot_cat_count "$cat_cur")
            printf ' %b%s%b  %b(%d packages)%b\n\n' "$BOLD" "${PROOT_CAT_LABELS[$cat_cur]}" "$RESET" \
                "$DIM" "$count" "$RESET"
            for (( i = 0; i < count; i++ )); do
                local mark conn
                if [[ ${PROOT_PKG_SEL["$cat_cur:$i"]} == 1 ]]; then
                    mark="${GREEN}[x]${RESET}"
                else
                    mark="[ ]"
                fi
                conn="├─"
                (( i == count - 1 )) && conn="└─"
                proot_pkg_name "$cat_cur" "$i"
                if (( i == pkg_cur )); then
                    printf ' %b❯%b %b %b %b\n' "${GREEN}${BOLD}" "${RESET}" "$conn" "$mark" "$PROOT_PKG_NAME"
                else
                    printf '   %b %b %b\n' "$conn" "$mark" "$PROOT_PKG_NAME"
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
                    if [[ ${PROOT_CAT_SEL[$cat_cur]} == 1 ]]; then
                        PROOT_CAT_SEL[$cat_cur]=0
                    else
                        PROOT_CAT_SEL[$cat_cur]=1
                        proot_set_all "$cat_cur" 1
                    fi
                    ;;
                $'\x1b')
                    IFS= read -rsn2 -t 0.05 rest
                    case "$rest" in
                        '[A'|'OA') (( cat_cur-- )) ;;
                        '[B'|'OB') (( cat_cur++ )) ;;
                        '[C'|'OC')
                            PROOT_CAT_SEL[$cat_cur]=1
                            if (( $(proot_cat_count "$cat_cur") > 0 )); then
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
            count=$(proot_cat_count "$cat_cur")
            case "$key" in
                " ")
                    if [[ ${PROOT_PKG_SEL["$cat_cur:$pkg_cur"]} == 1 ]]; then
                        PROOT_PKG_SEL["$cat_cur:$pkg_cur"]=0
                    else
                        PROOT_PKG_SEL["$cat_cur:$pkg_cur"]=1
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
                if [[ ${PROOT_CAT_SEL[$i]} == 1 ]]; then
                    proot_run_step "$i"
                    ran=1
                fi
            done
            if (( ran == 0 )); then
                echo -e "${YELLOW}[!] No steps selected.${RESET}"
            fi
            pause
            mode="cats"
        fi
    done
}

# ==============================================================================
# ГЛАВНЫЙ ЦИКЛ ОБРАБОТКИ
# ==============================================================================
while true; do
    if ! select_proot_distro; then
        break
    fi
    proot_setup_menu
done
