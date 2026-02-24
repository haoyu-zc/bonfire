# =============================================================================
# ~/.zshrc — Interactive shell configuration
# Platform-aware: works on Pop!_OS / Ubuntu and macOS
# =============================================================================

# =============================================================================
# Homebrew init (must come early to set PATH)
# =============================================================================
if [[ -x /opt/homebrew/bin/brew ]]; then
    # macOS Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    # macOS Intel
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    # Linux (system-wide Linuxbrew)
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    # Linux (user Linuxbrew)
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# =============================================================================
# mise — dev tool version manager
# =============================================================================
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi

# =============================================================================
# PATH additions
# =============================================================================
# Local binaries
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# bonfire repo utilities
export BONFIRE_DIR="$HOME/_workspace/projects/bonfire"
[[ -d "$BONFIRE_DIR/bin" ]] && export PATH="$BONFIRE_DIR/bin:$PATH"

# =============================================================================
# History
# =============================================================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate commands
setopt HIST_REDUCE_BLANKS     # Strip extra blanks from history
setopt HIST_VERIFY            # Confirm history expansion before executing
setopt SHARE_HISTORY          # Share history across all open sessions
setopt INC_APPEND_HISTORY     # Append immediately, not on exit
setopt EXTENDED_HISTORY       # Save timestamp + duration

# =============================================================================
# Zsh options
# =============================================================================
setopt AUTO_CD               # Type directory name to cd into it
setopt CORRECT               # Suggest corrections for mistyped commands
setopt NO_CASE_GLOB          # Case-insensitive globbing
setopt GLOB_DOTS             # Include hidden files in globbing
setopt EXTENDED_GLOB         # Extended glob patterns
setopt INTERACTIVE_COMMENTS  # Allow # comments in interactive shell

# =============================================================================
# Completion
# =============================================================================
autoload -Uz compinit
# Only regenerate .zcompdump once per day
if [[ -n "$HOME/.zcompdump"(N-mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' menu select                   # Arrow-key navigable menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # Case-insensitive completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'

# =============================================================================
# Key bindings
# =============================================================================
bindkey -e  # Emacs key bindings (Ctrl+A, Ctrl+E, Ctrl+R, etc.)
bindkey '^[[A' history-search-backward  # Up arrow: history search
bindkey '^[[B' history-search-forward   # Down arrow: history search

# =============================================================================
# Zsh plugins
# =============================================================================
# zsh-autosuggestions — check both apt and brew paths
_load_plugin() {
    local -a paths=("$@")
    for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then
            source "$p"
            return 0
        fi
    done
    return 1
}

_load_plugin \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    "$(brew --prefix 2>/dev/null)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#888888"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# zsh-syntax-highlighting (must be sourced LAST among plugins)
_load_plugin \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    "$(brew --prefix 2>/dev/null)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# =============================================================================
# fzf — fuzzy finder
# =============================================================================
if command -v fzf &>/dev/null; then
    # fzf shell integration (key bindings + completion)
    if [[ -f "$HOME/.config/fzf/fzf.zsh" ]]; then
        source "$HOME/.config/fzf/fzf.zsh"
    else
        # Try common install paths
        for fzf_init in \
            "$(brew --prefix 2>/dev/null)/opt/fzf/shell/completion.zsh" \
            "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.zsh" \
            /usr/share/doc/fzf/examples/completion.zsh \
            /usr/share/doc/fzf/examples/key-bindings.zsh; do
            [[ -f "$fzf_init" ]] && source "$fzf_init"
        done
    fi

    # fzf via mise puts it in PATH — activate key bindings
    if command -v fzf &>/dev/null && [[ -z "$FZF_DEFAULT_COMMAND" ]]; then
        eval "$(fzf --zsh 2>/dev/null)" || true
    fi

    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
fi

# =============================================================================
# zoxide — smarter cd
# =============================================================================
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# =============================================================================
# Aliases
# =============================================================================

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd $HOME"

# ls → eza (or fallback to ls)
if command -v eza &>/dev/null; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -l --icons --group-directories-first --git"
    alias la="eza -la --icons --group-directories-first --git"
    alias lt="eza --tree --icons --level=2"
    alias lta="eza --tree --icons --level=3 -a --git-ignore"
else
    alias ls="ls --color=auto"
    alias ll="ls -lh"
    alias la="ls -lha"
fi

# cat → bat
if command -v bat &>/dev/null; then
    alias cat="bat"
    alias catp="bat --plain"  # plain (no decorations)
fi

# Git
alias g="git"
alias gs="git status -sb"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit"
alias gcm="git commit -m"
alias gca="git commit --amend"
alias gco="git checkout"
alias gbr="git branch"
alias gpl="git pull --rebase"
alias gps="git push"
alias glg="git log --oneline --graph --decorate --all"
alias lg="lazygit"

# Podman (rootless, drop-in Docker replacement)
alias d="podman"
alias dc="podman-compose"
alias dps="podman ps"
alias dpsa="podman ps -a"
alias di="podman images"
alias dex="podman exec -it"

# Utilities
alias grep="grep --color=auto"
alias diff="diff --color=auto"
alias ip="ip --color=auto"
alias mk="make"
alias python="python3"
alias pip="pip3"
alias reload="source ~/.zshrc"
alias path='echo -e ${PATH//:/\\n}'

# Clipboard helpers (cross-platform)
if command -v wl-copy &>/dev/null; then
    alias pbcopy="wl-copy"
    alias pbpaste="wl-paste"
elif command -v xclip &>/dev/null; then
    alias pbcopy="xclip -selection clipboard"
    alias pbpaste="xclip -selection clipboard -o"
fi

# =============================================================================
# Functions
# =============================================================================

# mkcd: make directory and cd into it
mkcd() { mkdir -p "$@" && cd "$_" || return; }

# extract: universal archive extractor
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.tar.zst) tar --zstd -xf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.7z)      7z x "$1" ;;
            *.zst)     zstd -d "$1" ;;
            *)         echo "extract: '$1' - unknown archive type" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# y: yazi file manager with directory change on exit
# (requires yazi to be installed)
y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
        cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
}

# =============================================================================
# Environment
# =============================================================================
export EDITOR="code --wait"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-R --quit-if-one-screen"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# bat: configure theme
export BAT_THEME="Dracula"

# ripgrep: default config
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

# =============================================================================
# Starship prompt (must be last)
# =============================================================================
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# Let starship handle conda env display
export CONDA_CHANGEPS1=false

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/haoyu/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/haoyu/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/home/haoyu/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/home/haoyu/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba shell init' !!
export MAMBA_EXE='/home/haoyu/miniforge3/bin/mamba';
export MAMBA_ROOT_PREFIX='/home/haoyu/miniforge3';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<
