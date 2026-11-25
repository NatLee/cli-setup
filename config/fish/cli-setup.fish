# ~/.config/fish/conf.d/cli-setup.fish  —  managed by cli-setup (macOS / Linux / WSL)
# https://github.com/NatLee/cli-setup
#
# Options chosen at install time live in ~/.config/fish/cli-setup/options.fish (re-run install.sh to change them).
# Personal tweaks go in ~/.config/fish/config.fish — fish loads it after this file, and it is never touched.
#
# Autosuggestions, syntax highlighting, completions, ↑/↓ history search, Home / End and word jumps
# are built into fish, so there are no plugins to load here.

if status is-interactive

    set -g __mzs_dir $__fish_config_dir/cli-setup
    set -g __mzs_cache $HOME/.cache/cli-setup/fish
    set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"; and set __mzs_cache $XDG_CACHE_HOME/cli-setup/fish
    test -d $__mzs_cache; or mkdir -p $__mzs_cache

    if test -d $HOME/.local/bin; and not contains -- $HOME/.local/bin $PATH
        set -gx PATH $HOME/.local/bin $PATH
    end

    # ---------- defaults (overridden by options.fish) ----------
    set -g MZS_PLUGINS autosuggestions syntax-highlighting completions
    set -g MZS_SUGGEST_HEX 808080
    set -g MZS_THEME soft
    set -g MZS_CONDA fast
    test -r $__mzs_dir/options.fish; and source $__mzs_dir/options.fish

    function _mzs_has
        contains -- $argv[1] $MZS_PLUGINS
    end

    # Is file <a> newer than file <b>?
    if contains -- path (builtin -n)        # fish >= 3.5 has the `path` builtin: no fork
        function _mzs_newer
            test (path mtime -- $argv[1] 2>/dev/null; or echo 0) -gt (path mtime -- $argv[2] 2>/dev/null; or echo 0)
        end
    else
        function _mzs_newer
            command test $argv[1] -nt $argv[2]
        end
    end

    # Source the output of a slow init command, regenerated only when the binary changes.
    #   _mzs_cached <name> <binary> <command...>
    function _mzs_cached
        set -l f $__mzs_cache/$argv[1].fish
        if not test -s $f; or _mzs_newer $argv[2] $f
            if not $argv[3..-1] >$f 2>/dev/null
                rm -f $f
                return 1
            end
        end
        source $f
    end

    # ================================
    # Homebrew (cached `brew shellenv`)
    # ================================
    if not set -q HOMEBREW_PREFIX
        for __brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
            if test -x $__brew
                _mzs_cached brew-shellenv $__brew $__brew shellenv fish
                break
            end
        end
        set -e __brew
    end

    # ================================
    # Look
    # ================================
    set -q fish_greeting; or set -g fish_greeting              # no welcome banner (unless you set your own)
    set -g fish_color_autosuggestion $MZS_SUGGEST_HEX
    if test "$MZS_THEME" != default; and test -r $__mzs_dir/themes/$MZS_THEME.fish
        source $__mzs_dir/themes/$MZS_THEME.fish
    end

    # ================================
    # CLI tools
    # ================================
    if _mzs_has fzf; and command -sq fzf
        set -gx FZF_DEFAULT_OPTS '--height=40% --layout=reverse --border --color=bg+:236,hl:110,hl+:110,pointer:149,marker:176,prompt:110,info:244'
        # Ctrl-R history · Ctrl-T files · Alt-C cd
        #   `fzf --fish` needs fzf >= 0.48 and fish >= 3.4; older distro packages ship a function instead
        if not string match -qr '^(3\.[4-9]|3\.\d\d|[4-9]|\d\d)' -- $version; or not _mzs_cached fzf (command -s fzf) fzf --fish
            functions -q fzf_key_bindings; and fzf_key_bindings
        end
    end

    # Tab → fzf menu when there is more than one candidate (the fish take on fzf-tab)
    if _mzs_has fzf-tab; and command -sq fzf
        function _mzs_fzf_complete
            set -l token (commandline -ct)
            set -l cands (complete -C (commandline -cp | string collect) 2>/dev/null)
            if test (count $cands) -lt 2
                commandline -f complete        # nothing to choose from: let fish finish the word
                return
            end
            set -l pick (printf '%s\n' $cands | FZF_DEFAULT_OPTS= fzf --height=40% --layout=reverse \
                --delimiter=\t --nth=1 --tabstop=4 --bind=tab:down,btab:up \
                --color=bg+:236,hl:110,hl+:110,pointer:149,marker:176,prompt:110 \
                --query=(string unescape -- $token | string collect))
            if test -n "$pick"
                set -l word (string replace -r '\t.*$' '' -- $pick[1])
                set -l out $word
                if not string match -q '$*' -- $token                     # keep $VAR as it is
                    set out (string escape -n -- $word)
                    string match -q '~*' -- $word; and set out (string replace -r '^\\\\~' '~' -- $out)
                end
                string match -q -r '[/=]$' -- $out; or set out "$out "
                commandline -rt -- $out
            end
            commandline -f repaint
        end
        bind \t _mzs_fzf_complete
        bind -M insert \t _mzs_fzf_complete 2>/dev/null
    end

    _mzs_has aliases; and test -r $__mzs_dir/aliases.fish; and source $__mzs_dir/aliases.fish

    if _mzs_has eza; and command -sq eza
        function ls --wraps eza
            eza --icons=auto --group-directories-first $argv
        end
        function l --wraps eza
            eza -l --icons=auto --group-directories-first --git --time-style=relative $argv
        end
        function ll --wraps eza
            eza -la --icons=auto --group-directories-first --git --time-style=relative $argv
        end
        function la --wraps eza
            eza -a --icons=auto --group-directories-first $argv
        end
        function lt --wraps eza
            eza --tree --level=2 --icons=auto $argv
        end
    end

    # ================================
    # Conda — Starship already shows the env, so hide conda's own "(base)" prefix.
    #   fast : cached hook + instant base activation (default)
    #   lazy : load conda on first `conda` call (fastest, base not active at start)
    #   full : official `conda init` behaviour
    #   off  : don't load conda
    # ================================
    set -gx CONDA_CHANGEPS1 false
    if test "$MZS_CONDA" != off
        for __root in $HOME/miniconda3 $HOME/anaconda3 $HOME/miniforge3 $HOME/mambaforge \
                /opt/homebrew/Caskroom/miniconda/base /opt/homebrew/Caskroom/miniforge/base \
                /opt/conda /opt/miniconda3 /opt/anaconda3
            test -x $__root/bin/conda; or continue
            set __root (builtin realpath $__root)    # resolve symlinks, as conda does
            switch $MZS_CONDA
                case lazy
                    set -g __mzs_conda_root $__root
                    function conda
                        functions -e conda
                        $__mzs_conda_root/bin/conda shell.fish hook 2>/dev/null | source
                        conda $argv
                    end
                case full
                    $__root/bin/conda shell.fish hook 2>/dev/null | source
                case '*'    # fast
                    set -l __hook $__mzs_cache/conda-hook.fish
                    if not test -s $__hook; or _mzs_newer $__root/bin/conda $__hook
                        $__root/bin/conda shell.fish hook 2>/dev/null | string match -v -r '^conda activate' >$__hook
                    end
                    source $__hook
                    # Activate base without spawning Python — unless base needs activation scripts / env vars.
                    if not set -q CONDA_PREFIX; or test -z "$CONDA_PREFIX"
                        set -l __adir $__root/etc/conda/activate.d/*
                        if test (count $__adir) -gt 0; or test -s $__root/conda-meta/state
                            conda activate base
                        else
                            set -gx CONDA_SHLVL 1
                            set -gx CONDA_PREFIX $__root
                            set -gx CONDA_DEFAULT_ENV base
                            set -gx CONDA_PROMPT_MODIFIER ''
                            set -gx PATH $__root/bin $PATH
                        end
                    end
            end
            break
        end
        set -e __root
    end

    # ================================
    # Prompt (Starship, cached init)
    # ================================
    set -gx STARSHIP_CONFIG $HOME/.config/starship.toml
    command -sq starship; and _mzs_cached starship (command -s starship) starship init fish --print-full-init

    # zoxide must be initialised last
    if _mzs_has zoxide; and command -sq zoxide
        _mzs_cached zoxide (command -s zoxide) zoxide init fish    # z <dir> · zi = interactive
    end

    # Clear the cache after changing tools by hand:  fish-cache-clear
    function fish-cache-clear
        set -l files $__mzs_cache/*.fish
        test (count $files) -gt 0; and rm -f $files
        echo "fish cache cleared — restart the shell"
    end

end
