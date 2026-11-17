# "soft" theme for fast-syntax-highlighting — managed by zsh-setup
# Muted 256-colour pastels that match the Starship prompt. No background blocks, no bold.
#   149 green · 110 blue · 116 teal · 176 pink · 180 tan · 215 orange · 167 red · 24x greys

() {
  local k
  local -A s=(
    default                                none
    unknown-token                          fg=167
    commandseparator                       fg=245
    redirection                            fg=245
    comment                                fg=242,italic

    command                                fg=149
    builtin                                fg=149
    function                               fg=149
    alias                                  fg=149
    suffix-alias                           fg=149
    precommand                             fg=149,underline
    hashed-command                         fg=149
    reserved-word                          fg=176
    subcommand                             fg=176
    global-alias                           fg=176
    single-sq-bracket                      fg=176
    double-sq-bracket                      fg=176
    double-paren                           fg=176

    path                                   fg=110
    path-to-dir                            fg=110
    path_pathseparator                     fg=110
    globbing                               fg=215
    globbing-ext                           fg=215
    history-expansion                      fg=215

    single-hyphen-option                   fg=116
    double-hyphen-option                   fg=116
    optarg-string                          fg=180
    optarg-number                          fg=215

    single-quoted-argument                 fg=180
    double-quoted-argument                 fg=180
    dollar-quoted-argument                 fg=180
    back-quoted-argument                   fg=176
    back-dollar-quoted-argument            fg=116
    back-or-dollar-double-quoted-argument  fg=116

    variable                               fg=146
    assign                                 none
    assign-array-bracket                   fg=245

    paired-bracket                         fg=231,bg=238
    bracket-level-1                        fg=110
    bracket-level-2                        fg=176
    bracket-level-3                        fg=116

    here-string-tri                        fg=245
    here-string-text                       fg=180
    here-string-var                        fg=116
    exec-descriptor                        fg=215

    correct-subtle                         fg=240
    incorrect-subtle                       fg=167
    subtle-separator                       fg=240
    subtle-bg                              none

    case-input                             fg=149
    case-parentheses                       fg=176
    case-condition                         fg=180

    mathvar                                fg=146
    mathnum                                fg=215
    matherr                                fg=167
    for-loop-variable                      fg=146
    for-loop-number                        fg=215
    for-loop-operator                      fg=176
    for-loop-separator                     fg=245
  )
  typeset -gA FAST_HIGHLIGHT_STYLES
  for k in ${(k)s}; do
    FAST_HIGHLIGHT_STYLES[$k]=$s[$k]
    [[ -n $FAST_THEME_NAME ]] && FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}$k]=$s[$k]
  done
}
