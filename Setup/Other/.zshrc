# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

zstyle ':omz:update' mode auto

ENABLE_CORRECTION="true"

plugins=(
	git
	fzf
	zsh-syntax-highlighting
	zsh-autosuggestions
	)

source $ZSH/oh-my-zsh.sh

export ARCHFLAGS="-arch $(uname -m)"

alias ls=lsd
alias arch="proot-distro login archlinuxarm --shared-tmp"