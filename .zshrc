#!/usr/bin/env zsh

# ============================================================================
# Environment Variables (Set early for consistency)
# ============================================================================

# Use xterm-ghostty locally (enables Ghostty-specific capabilities)
# Remote machines get xterm-256color via SSH SetEnv (see ~/.ssh/config)
if [[ -z "$SSH_CONNECTION" ]] && infocmp xterm-ghostty &>/dev/null; then
    export TERM="xterm-ghostty"
else
    export TERM="xterm-256color"
fi
export EDITOR='nvim'
export LANG=en_US.UTF-8

# ============================================================================
# PATH Configuration (Consolidated and deduplicated)
# ============================================================================

# Keep $path unique: repeated prepends (nested shells, tmux, re-source)
# collapse to a single entry instead of accumulating duplicates
typeset -U path PATH

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

# NOTE: brew shellenv runs once in ~/.zprofile (login shells); subshells
# inherit the exported vars, and the explicit prepend above guarantees the
# brew paths for any non-login edge case — no need to eval it again here.

# Bob Neovim (MUST be last to have highest priority)
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# Compilation flags for macOS
export LDFLAGS="-L/opt/homebrew/lib"
export CPPFLAGS="-I/opt/homebrew/include"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"

# Homebrew settings
export HOMEBREW_NO_ANALYTICS=1

# ============================================================================
# Oh-My-Zsh Path and Settings (for Zinit OMZ:: snippets)
# ============================================================================

export ZSH=$HOME/.oh-my-zsh
HIST_STAMPS="yyyy-mm-dd"

# NOTE: tmux autostart is intentionally absent — sessions are managed via
# sesh (Ctrl-a T / the "s" command); the old ZSH_TMUX_AUTOSTART vars were
# dead config because their only consumer (OMZ tmux plugin) is never loaded.

# NOTE: We do NOT source oh-my-zsh.sh here.
# All OMZ libs and plugins are loaded via Zinit for better control and no conflicts.

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
# Note: functions.zsh must come before termsupport.zsh (provides omz_urlencode)
zinit snippet OMZ::lib/functions.zsh
zinit snippet OMZ::lib/clipboard.zsh
zinit snippet OMZ::lib/directories.zsh
zinit snippet OMZ::lib/history.zsh
zinit snippet OMZ::lib/misc.zsh
zinit snippet OMZ::lib/termsupport.zsh
zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/key-bindings.zsh

# Fix directories.zsh conflict with zoxide (1-9 aliases should use builtin cd)
alias -- -='builtin cd -'
for i in {1..9}; do alias $i="builtin cd -$i"; done

# Strengthen history deduplication (beyond OMZ defaults)
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# Initialize completion system (required by OMZ plugins that use compdef)
autoload -Uz compinit
compinit -C

# OMZ Plugins (via Zinit for better control)
zinit snippet OMZP::git
# macos plugin loaded directly from OMZ (has multiple files that Zinit svn doesn't handle well)
source "$ZSH/plugins/macos/macos.plugin.zsh"
zinit snippet OMZP::brew
zinit snippet OMZP::common-aliases
zinit snippet OMZP::colored-man-pages
zinit snippet OMZP::web-search
zinit snippet OMZP::dotenv
zinit snippet OMZP::rake
zinit snippet OMZP::rbenv
zinit snippet OMZP::ruby
zinit snippet OMZP::sudo

# eza aliases plugin - configure params before loading
export _EZA_PARAMS=(
    '--git' '--icons=always' '--group' '--group-directories-first'
    '--time-style=long-iso' '--color-scale=all' '--color=always'
)
zinit light z-shell/zsh-eza

# ============================================================================
# Deferred Plugins (Load after prompt for faster startup)
# ============================================================================

# Canonical zinit turbo trio: syntax highlighting, completions,
# autosuggestions. COMPINIT_OPTS=-C makes the deferred zicompinit skip the
# compaudit security scan (already done implicitly by the early
# 'compinit -C' above) — compinit previously ran twice, once with the
# full audit, on every shell start.
zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
    blockf \
    zsh-users/zsh-completions \
    atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# Additional useful plugins
zinit wait lucid for \
    MichaelAquilina/zsh-you-should-use \
    fdellwing/zsh-bat \
    OMZP::copypath \
    OMZP::copyfile \
    OMZP::jsontools \
    OMZP::encode64

# ============================================================================
# Binary Programs via Zinit (Load in background)
# ============================================================================

# Development tools
zinit wait"1" lucid for \
    from'gh-r' sbin'* -> jq' \
    @jqlang/jq

# Tmux and related tools (only if not already installed)
if ! command -v tmux &> /dev/null; then
    zinit wait"2" lucid for \
        configure'--disable-utf8proc' make sbin'tmux' \
        @tmux/tmux
fi

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
    # Exclude cache and dependency directories for faster directory navigation
    export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix \
        --exclude .git \
        --exclude node_modules \
        --exclude .npm \
        --exclude .cache \
        --exclude .hawtjni \
        --exclude '__pycache__' \
        --exclude '.cargo/registry' \
        --exclude 'Library/Caches' \
        --exclude '.gradle'"

    # Load Catppuccin Mocha theme
    if [ -f "$HOME/.config/fzf/catppuccin-mocha.sh" ]; then
        source "$HOME/.config/fzf/catppuccin-mocha.sh"
        # Remove background colors for transparency (remove bg:#1E1E2E)
        export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS//bg:#1E1E2E,/}"
    fi

    # Additional FZF options (non-color) - ensure proper spacing
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} \
--highlight-line \
--info=inline-right \
--ansi \
--layout=reverse \
--border=rounded"

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

    # FZF-git integration (Ctrl-G key bindings) — zinit-managed so
    # 'zinit update' keeps it fresh (was a manual clone in $HOME)
    zinit ice wait lucid pick"fzf-git.sh"
    zinit light junegunn/fzf-git.sh
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

# Sesh + Carapace completions — deferred via zinit's null plugin. Both only
# register compdefs and together cost ~30-50ms of subprocess spawns; the
# turbo queue runs them after the prompt is already up, and declaration
# order guarantees zicompinit (in the trio block above) has run first.
export CARAPACE_BRIDGES='zsh,fish,bash'  # Bridge completions from other shells
zinit ice wait"1" lucid nocd id-as"deferred-completions" as"null" \
    atload'command -v sesh &>/dev/null && eval "$(sesh completion zsh)"; command -v carapace &>/dev/null && source <(carapace _carapace)'
zinit light zdharma-continuum/null

# Zoxide - init moved to end of file (before starship) to satisfy zoxide doctor

# pay-respects (command correction; Rust successor to the unmaintained
# thefuck, which dragged in a whole python@3.13 dependency chain).
# Lazy-loaded: init cost is only paid on first use.
if command -v pay-respects &> /dev/null; then
    fk() {
        unfunction fk 2>/dev/null
        eval "$(pay-respects zsh --alias fk)"
        # The init defines fk as an ALIAS, which can't take effect inside
        # this already-parsed function — invoke its target directly.
        __pr_main suggest
    }
fi

# Atuin (enhanced shell history with syntax highlighting)
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# Mise (polyglot dev tool version manager)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# ============================================================================
# Aliases
# ============================================================================

# Universal archive extraction via ouch (replaces the OMZ extract plugin;
# note: multi-file archives are extracted into a subdirectory)
alias extract='ouch decompress'
alias x='ouch decompress'

# Modern replacements (managed by z-shell/zsh-eza plugin)
# Plugin provides: ls, l, ll, llm, la, lx, tree
# With custom params: --git, --icons=always, --group, --group-directories-first,
#                     --time-style=long-iso, --color-scale=all, --color=always

# Custom eza aliases (override plugin or add new ones)
alias lt='eza -l --grid --header --icons=always --color=always'  # Grid view (override plugin's tree lt)

# Tool replacements
alias cat='bat'
alias vim='nvim'
alias vi='nvim'
alias ps='procs'

# History with syntax highlighting (requires atuin + bat)
alias h='atuin history list -f "{time}\t{command}" | bat -l bash --style=plain --paging=never'
alias hh='atuin history list --cmd-only | bat -l bash --style=plain'

# Shortcuts
alias c='clear'
# Use zoxide for cd (skip in Claude Code to avoid interference)
if [[ -z "$CLAUDECODE" ]]; then
    alias cd='z'
fi
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

# Claude Code launcher. The session NAME is set by the SessionStart hook
# (~/.local/bin/claude-name-session), which names every launch method
# (shell, claudecode.nvim, ClaudeDeck, SSH). This wrapper only decorates
# tmux: it renames the window so a live Claude pane is identifiable, then
# restores auto-rename when claude exits. Portable (no macOS-only commands).
# Subcommands (agents, mcp, config, ...) and print mode pass through plainly.
claude() {
    local arg sub=0
    case "$1" in
        agents|mcp|config|setup-token|update|doctor|install|migrate-installer)
            sub=1 ;;
    esac
    for arg in "$@"; do
        case "$arg" in
            -p|--print) sub=1 ;;
        esac
    done

    if (( sub )) || [[ -z "$TMUX" ]]; then
        command claude "$@"
        return
    fi

    # Window label = <project>[/<branch>] from the git repo root. The yadm-
    # managed $HOME is not a plain git repo, so fall back to yadm's branch
    # there; short hostname prefix over SSH.
    local root label branch prev prev_name ret
    root="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -n "$root" ]]; then
        label="${root:t}"
        branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"
    elif [[ "$PWD" == "$HOME" ]]; then
        label="home"
        branch="$(yadm rev-parse --abbrev-ref HEAD 2>/dev/null)"
    else
        label="${PWD:t}"
        branch=""
    fi
    case "$branch" in
        "" | main | master | trunk) ;;
        *) label="$label/$branch" ;;
    esac
    [[ -n "$SSH_CONNECTION" ]] && label="${HOST%%.*}:$label"

    prev="$(tmux display-message -p '#{automatic-rename}' 2>/dev/null)"
    prev_name="$(tmux display-message -p '#{window_name}' 2>/dev/null)"
    tmux set-window-option automatic-rename off >/dev/null 2>&1
    tmux rename-window "🤖 $label" >/dev/null 2>&1
    command claude "$@"
    ret=$?
    # Restore on exit: if the window had a manual name (automatic-rename was
    # off), put that name back; otherwise re-enable tmux's auto-renaming.
    if [[ "$prev" == "0" ]]; then
        tmux rename-window "$prev_name" >/dev/null 2>&1
    else
        tmux set-window-option automatic-rename on >/dev/null 2>&1
    fi
    return $ret
}

# Zellij shortcuts
alias zj='zellij'
alias zja='zellij attach'
alias zjl='zellij list-sessions'
alias zjk='zellij kill-session'
alias zjd='zellij delete-session'

# Git extras (in addition to OMZ git plugin)
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate --all'

# Battery monitoring
alias battery='battery-status'

# Daily maintenance shortcuts
alias mr='~/daily-maintenance-control.sh run'      # maintenance run
alias ms='~/daily-maintenance-control.sh status'   # maintenance status
alias ml='~/daily-maintenance-control.sh logs'     # maintenance logs

# ============================================================================
# Modern CLI Tools Aliases
# ============================================================================

# System monitoring
alias top='btop'
alias htop='btop'

# Disk analysis
alias du='dust'
alias df='duf'

# Text processing (keep sed for compatibility, add replace for convenience)
alias replace='sd'

# Network tools
alias dog='doggo'  # Keep dog naming convention

# HTTP client
if command -v xh &> /dev/null; then
    alias http='xh'
    alias https='xh https'
fi

# Development tools
if command -v hyperfine &> /dev/null; then
    alias bench='hyperfine'
fi
if command -v tokei &> /dev/null; then
    alias count='tokei'
fi
if command -v hexyl &> /dev/null; then
    alias hex='hexyl'
fi

# Documentation
alias help='tldr'
alias cheat='tldr'

# Markdown rendering
if command -v glow &> /dev/null; then
    alias md='glow'
fi

# Search and replace TUI
if command -v serpl &> /dev/null; then
    alias sr='serpl'
fi

# File management (yazi with cd-on-exit wrapper)
if command -v yazi &> /dev/null; then
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
    }
fi

# FZF-powered git helpers
alias gb='git branch --sort=-committerdate | fzf --preview "git log --oneline -10 {1}" | xargs git checkout'
alias gcof='git log --oneline --all --color=always | fzf --ansi --preview "git show --stat --color=always {1}" | cut -d" " -f1 | xargs git checkout'

# Ripgrep + FZF for interactive code search (Enter opens in nvim)
rgf() {
    rg --color=always --line-number --no-heading "$@" |
    fzf --ansi --delimiter : \
        --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
        --preview-window '+{2}-5' \
        --bind 'enter:become(nvim {1} +{2})'
}

# Quick utilities (inspired by nickjj/dotfiles)
alias sz='source ~/.zshrc'
alias myip='curl -s https://checkip.amazonaws.com | pbcopy && pbpaste'

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

# Exclude patterns for recursive glob - affects cd **<Tab>
# This prevents slow cache directories from appearing in completion
zstyle ':completion:*:cd:*' ignored-patterns '(*/.git|*/.npm|*/node_modules|*/.cache|*/__pycache__|*/.hawtjni|*/Library/Caches|*/.gradle)'

# ============================================================================
# Environment Specific Settings
# ============================================================================

# Bat theme
export BAT_THEME="Catppuccin Mocha"

# ============================================================================
# Prompt (Starship) - Load before zoxide so zoxide doctor check passes
# ============================================================================

eval "$(starship init zsh)"

# ============================================================================
# Remote Work Helpers
# ============================================================================

# Detect SSH session
if [[ -n "$SSH_CONNECTION" ]]; then
    export SSH_SESSION=1

    # OSC52 clipboard helper for remote sessions
    # Usage: echo "text" | clip   OR   clip "some text"
    clip() {
        local input
        if [[ -p /dev/stdin ]]; then
            input=$(cat)
        else
            input="$*"
        fi
        local encoded=$(printf '%s' "$input" | base64 | tr -d '\n')
        printf '\033]52;c;%s\a' "$encoded"
    }

    # On remote, alias pbcopy to use OSC52
    alias pbcopy='clip'
fi

# Quick SSH + tmux attach-or-create
# Usage: ssht hostname [session-name]
# Example: ssht dev-server → connects and attaches to "main" session
ssht() {
    local host="$1"
    local session="${2:-main}"
    ssh -t "$host" "tmux new-session -A -s $session"
}

# ============================================================================
# Local/Private Configuration
# ============================================================================

# Source local environment if exists
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# Source private/work specific configs if exists
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ============================================================================
# Zoxide (better cd) - Load LAST to satisfy zoxide doctor check
# ============================================================================

if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi
