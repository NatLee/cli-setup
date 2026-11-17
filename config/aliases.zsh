# Common aliases — managed by zsh-setup
# Git aliases use the same names as Oh My Zsh, so muscle memory carries over.
# Add your own in ~/.zsh/.zshrc.local (loaded after this file, so it can override anything here).

# ---------- navigation ----------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ---------- listing (replaced by eza versions when eza is enabled) ----------
alias l='ls -lh'          # long list
alias ll='ls -lah'        # long list incl. hidden files
alias la='ls -A'          # short list incl. hidden files

# ---------- safer / friendlier defaults ----------
alias mkdir='mkdir -p'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias h='history -20'

# ---------- git ----------
alias g='git'
alias gst='git status'
alias gss='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcmsg='git commit -m'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
alias gl='git pull'
alias gp='git push'
alias glog='git log --oneline --decorate --graph -20'
alias gsta='git stash push'
alias gstp='git stash pop'

# ---------- system helpers ----------
alias reload='exec zsh'                                       # restart the shell
alias path='print -l $path'                                   # one PATH entry per line

if [[ $OSTYPE == darwin* ]]; then
  alias o='open .'                                            # open current dir in Finder
  alias localip='ipconfig getifaddr en0'
  alias ports='lsof -iTCP -sTCP:LISTEN -n -P'                 # who is listening on which port
  alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
else
  alias ls='ls --color=auto'
  if grep -qi microsoft /proc/version 2>/dev/null; then
    alias o='explorer.exe .'                                  # WSL: open in Windows Explorer
  elif (( $+commands[xdg-open] )); then
    alias o='xdg-open . >/dev/null 2>&1'
  fi
  localip() {
    if (( $+commands[ip] )); then
      ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i+1); exit }}'
    else
      hostname -I 2>/dev/null | awk '{print $1}'
    fi
  }
  alias ports='ss -tlnp'                                      # who is listening on which port
  (( $+commands[resolvectl] )) && alias flushdns='sudo resolvectl flush-caches'
fi
