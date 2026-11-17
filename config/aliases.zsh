# Common aliases — managed by mac-zsh-setup
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

# ---------- macOS helpers ----------
alias o='open .'                                              # open current dir in Finder
alias reload='exec zsh'                                       # restart the shell
alias path='print -l $path'                                   # one PATH entry per line
alias localip='ipconfig getifaddr en0'
alias ports='lsof -iTCP -sTCP:LISTEN -n -P'                   # who is listening on which port
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
