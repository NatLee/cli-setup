# Common aliases — managed by cli-setup (fish)
# Same names as the zsh version; git aliases match Oh My Zsh, so muscle memory carries over.
# Written as functions: that is what fish's `alias` creates anyway, minus the startup cost.
# Add your own in ~/.config/fish/config.fish (loaded after this file, so it can override anything here).

# ---------- navigation ----------
function ..
    cd ..
end
function ...
    cd ../..
end
function ....
    cd ../../..
end
abbr -a -g -- - 'cd -'

# ---------- listing (replaced by eza versions when eza is enabled) ----------
function l --wraps ls
    ls -lh $argv
end
function ll --wraps ls
    ls -lah $argv
end
function la --wraps ls
    ls -A $argv
end

# ---------- safer / friendlier defaults ----------
function mkdir --wraps mkdir
    command mkdir -p $argv
end
function grep --wraps grep
    command grep --color=auto $argv
end
function df --wraps df
    command df -h $argv
end
function du --wraps du
    command du -h $argv
end
function h
    history -n 20
end

# ---------- git ----------
function g --wraps git
    git $argv
end
function gst --wraps 'git status'
    git status $argv
end
function gss --wraps 'git status'
    git status -sb $argv
end
function ga --wraps 'git add'
    git add $argv
end
function gaa --wraps 'git add'
    git add --all $argv
end
function gc --wraps 'git commit'
    git commit -v $argv
end
function gcmsg --wraps 'git commit'
    git commit -m $argv
end
function gd --wraps 'git diff'
    git diff $argv
end
function gds --wraps 'git diff'
    git diff --staged $argv
end
function gco --wraps 'git checkout'
    git checkout $argv
end
function gsw --wraps 'git switch'
    git switch $argv
end
function gb --wraps 'git branch'
    git branch $argv
end
function gl --wraps 'git pull'
    git pull $argv
end
function gp --wraps 'git push'
    git push $argv
end
function glog --wraps 'git log'
    git log --oneline --decorate --graph -20 $argv
end
function gsta --wraps 'git stash'
    git stash push $argv
end
function gstp --wraps 'git stash'
    git stash pop $argv
end

# ---------- system helpers ----------
# (no `path` here: fish has a `path` builtin that its own functions rely on — use `printf '%s\n' $PATH`)
function reload
    exec fish
end

function __mzs_is_wsl
    test -r /proc/version; or return 1
    read -l v </proc/version
    string match -qi '*microsoft*' -- $v
end

function o --description 'open the current directory in the file manager'
    if test (uname) = Darwin
        open .
    else if __mzs_is_wsl
        explorer.exe .
    else if command -sq xdg-open
        xdg-open . >/dev/null 2>&1
    end
end

function localip
    if test (uname) = Darwin
        ipconfig getifaddr en0
    else if command -sq ip
        ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i+1); exit }}'
    else
        hostname -I 2>/dev/null | awk '{print $1}'
    end
end

function ports --description 'who is listening on which port'
    if test (uname) = Darwin
        lsof -iTCP -sTCP:LISTEN -n -P $argv
    else
        ss -tlnp $argv
    end
end

function flushdns
    if test (uname) = Darwin
        sudo dscacheutil -flushcache; and sudo killall -HUP mDNSResponder
    else if command -sq resolvectl
        sudo resolvectl flush-caches
    end
end
