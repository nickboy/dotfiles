#!/usr/bin/env zsh

# ============================================================================
# Environment Variables (Set early for consistency)
# ============================================================================

export TERM="xterm-256color"
export EDITOR='nvim'
export LANG=en_US.UTF-8

# ============================================================================
# PATH Configuration (Consolidated and deduplicated)
# ============================================================================

# Homebrew (Apple Silicon)
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# User binaries
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# System paths
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# Language specific
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="/Library/TeX/texbin:$PATH"

# Initialize Homebrew environment (this also sets PATH, MANPATH, INFOPATH)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Bob Neovim (MUST be absolutely last after brew shellenv to have highest priority)
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# Compilation flags for macOS
export LDFLAGS="-L/opt/homebrew/lib"
export CPPFLAGS="-I/opt/homebrew/include"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"

# Homebrew settings
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_RUBY3=true

# ============================================================================
# History Configuration (Set early for better history handling)
# ============================================================================

HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# ============================================================================
# Oh-My-Zsh Configuration (Framework only, plugins via Zinit)
# ============================================================================

export ZSH=$HOME/.oh-my-zsh
ZSH_THEME=""  # Empty because we use Starship
plugins=(macos)    # Load macos plugin through OMZ to avoid submodule issues

# Tmux settings (before loading OMZ)
ZSH_TMUX_AUTOSTART='true'

# Load Oh-My-Zsh framework
source $ZSH/oh-my-zsh.sh

# ============================================================================
# Zinit Plugin Manager
# ============================================================================

# Install Zinit if not present
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ============================================================================
# Zinit Annexes
# ============================================================================

zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# ============================================================================
# Essential Plugins (Load immediately)
# ============================================================================

# OMZ Libraries (load first as other plugins may depend on them)
zinit snippet OMZ::lib/clipboard.zsh
zinit snippet OMZ::lib/termsupport.zsh
zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/key-bindings.zsh

# OMZ Plugins (via Zinit for better control)
zinit snippet OMZP::git
# macos plugin is loaded via OMZ plugins array to avoid submodule issues
zinit snippet OMZP::brew
zinit snippet OMZP::dotenv
zinit snippet OMZP::rake
zinit snippet OMZP::rbenv
zinit snippet OMZP::ruby

# Fast syntax highlighting (load early for immediate effect)
zinit light zdharma-continuum/fast-syntax-highlighting

# History search
zinit load zdharma-continuum/history-search-multi-word

# ============================================================================
# Deferred Plugins (Load after prompt for faster startup)
# ============================================================================

# Autosuggestions and completions
zinit wait lucid for \
    atinit"zicompinit; zicdreplay" \
    zsh-users/zsh-completions \
    atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
    blockf \
    zsh-users/zsh-completions

# Additional useful plugins
zinit wait lucid for \
    MichaelAquilina/zsh-you-should-use \
    fdellwing/zsh-bat

# ============================================================================
# Binary Programs via Zinit (Load in background)
# ============================================================================

# Development tools
zinit wait"1" lucid for \
    from'gh-r' sbin'* -> jq' \
    @jqlang/jq \
    from'gh-r' sbin'fzf' \
    junegunn/fzf

# Tmux and related tools (only if not already installed)
if ! command -v tmux &> /dev/null; then
    zinit wait"2" lucid for \
        configure'--disable-utf8proc' make sbin'tmux' \
        @tmux/tmux
fi

# ============================================================================
# Prompt (Starship)
# ============================================================================

eval "$(starship init zsh)"

# ============================================================================
# Shell Integrations
# ============================================================================

# FZF Configuration
if command -v fzf &> /dev/null; then
    # Load FZF key-bindings and completion
    eval "$(fzf --zsh)"

    # Use fd for better performance
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

    # FZF Theme (TokyoNight Night - from BAT theme)
    export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
      --highlight-line \
      --info=inline-right \
      --ansi \
      --layout=reverse \
      --border=none \
      --color=bg+:#282833 \
      --color=bg:#1a1b26 \
      --color=border:#7aa2f7 \
      --color=fg:#c0caf5 \
      --color=gutter:#1a1b26 \
      --color=header:#ff9e64 \
      --color=hl+:#7dcfff \
      --color=hl:#7aa2f7 \
      --color=info:#565f89 \
      --color=marker:#f7768e \
      --color=pointer:#f7768e \
      --color=prompt:#7dcfff \
      --color=query:#c0caf5:regular \
      --color=scrollbar:#565f89 \
      --color=separator:#ff9e64 \
      --color=spinner:#f7768e"

    # Preview settings
    show_file_or_dir_preview="if [ -d {} ]; then eza --tree --icons=always --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
    export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
    export FZF_ALT_C_OPTS="--preview 'eza --tree --icons=always --color=always {} | head -200'"

    # FZF completion functions
    _fzf_compgen_path() {
        fd --hidden --exclude .git . "$1"
    }

    _fzf_compgen_dir() {
        fd --type=d --hidden --exclude .git . "$1"
    }

    _fzf_comprun() {
        local command=$1
        shift

        case "$command" in
            cd)           fzf --preview 'eza --tree --icons=always --color=always {} | head -200' "$@" ;;
            export|unset) fzf --preview "eval 'echo \${}'" "$@" ;;
            ssh)          fzf --preview 'dig {}' "$@" ;;
            *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
        esac
    }

    # FZF-git integration
    [[ -f ~/fzf-git.sh/fzf-git.sh ]] && source ~/fzf-git.sh/fzf-git.sh
fi

# Load fzf-tab AFTER fzf is initialized
zinit light Aloxaf/fzf-tab

# Configure fzf-tab
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-pad 4
# Inherit FZF theme and add specific flags for fzf-tab
zstyle ':fzf-tab:*' fzf-flags --height=50% --border=rounded

# Configure preview for different completion types
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --icons=always --color=always $realpath | head -200'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --icons=always --color=always $realpath | head -200'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza --tree --icons=always --color=always $realpath | head -200'
zstyle ':fzf-tab:complete:*:*' fzf-preview '[[ -d $realpath ]] && eza --tree --icons=always --color=always $realpath | head -200 || [[ -f $realpath ]] && bat --style=numbers --color=always --theme=tokyonight_night --line-range :500 $realpath || echo $desc'

# Group colors and descriptions
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'

# Sesh completion
if command -v sesh &> /dev/null; then
    eval "$(sesh completion zsh)"
fi

# Carapace - universal command completions
if command -v carapace &> /dev/null; then
    export CARAPACE_BRIDGES='zsh,fish,bash'  # Bridge completions from other shells
    source <(carapace _carapace)
fi

# Zoxide (better cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# GitHub Copilot CLI
if command -v gh &> /dev/null && gh copilot --help &>/dev/null; then
    eval "$(gh copilot alias -- zsh)"
fi

# The fuck (command correction)
if command -v thefuck &> /dev/null; then
    eval $(thefuck --alias fk)
fi

# ============================================================================
# Aliases
# ============================================================================

# Modern replacements
alias ls='eza --icons=always --color=always'
alias ll='eza -la --icons=always --color=always'
alias tree='eza --tree --icons=always --color=always'
alias cat='bat'
alias vim='nvim'
alias vi='nvim'
alias ps='procs'

# Shortcuts
alias c='clear'
alias cd='z'  # Use zoxide for cd
alias python='python3'
alias pip='pip3'

# Sesh smart session manager function
s() {
    if [ $# -eq 0 ]; then
        # No arguments: show interactive picker (without icons to avoid parsing issues)
        local selected=$(sesh list | fzf \
                --height 50% \
                --border rounded \
                --border-label ' sesh sessions ' \
                --prompt '⚡ ' \
                --header 'Tips: Start typing to filter | Enter to connect | Esc to cancel' \
                --preview 'sesh preview {}' \
            --preview-window right:55%)

        [[ -z "$selected" ]] && return 0
        sesh connect "$selected"
    else
        # Arguments provided: pass directly to sesh
        sesh connect "$@"
    fi
}

# Sesh aliases for quick access
alias sl='sesh list --icons'  # List all sessions with icons
alias sn='sesh connect $(basename $PWD)'  # New session named after current dir
alias sls='sesh list -t --icons'  # List only tmux sessions

# Git extras (in addition to OMZ git plugin)
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'

# Battery monitoring
alias battery='battery-status'
alias batteryv='battery-status -v'  # verbose output

# Daily maintenance shortcuts
alias mr='~/daily-maintenance-control.sh run'      # maintenance run
alias ms='~/daily-maintenance-control.sh status'   # maintenance status
alias ml='~/daily-maintenance-control.sh logs'     # maintenance logs

# ============================================================================
# Shell Options
# ============================================================================

# VI mode
setopt VI

# Better completion
# setopt MENU_COMPLETE  # Comment out - this causes inline completion
setopt AUTO_MENU        # Show completion menu on tab
setopt AUTO_LIST        # List choices on ambiguous completion
setopt COMPLETE_IN_WORD # Complete from cursor position

# ============================================================================
# Environment Specific Settings
# ============================================================================

# Bat theme
export BAT_THEME=tokyonight_night

# ============================================================================
# Local/Private Configuration
# ============================================================================

# Source local environment if exists
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# Source private/work specific configs if exists
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
