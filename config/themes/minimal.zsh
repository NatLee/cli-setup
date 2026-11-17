# "minimal" theme for fast-syntax-highlighting — managed by cli-setup
# Almost monochrome: only errors, strings and paths get a hint of colour.
#   252 text · 245 grey · 110 blue · 180 tan · 167 red

() {
  local k
  local -A s=(
    default                                none
    unknown-token                          fg=167
    commandseparator                       fg=245
    redirection                            fg=245
    comment                                fg=242,italic

    command                                fg=252
    builtin                                fg=252
    function                               fg=252
    alias                                  fg=252
    suffix-alias                           fg=252
    precommand                             fg=252,underline
    hashed-command                         fg=252
    reserved-word                          fg=250
    subcommand                             fg=250
    global-alias                           fg=250
    single-sq-bracket                      fg=250
    double-sq-bracket                      fg=250
    double-paren                           fg=250

    path                                   fg=110
    path-to-dir                            fg=110
    path_pathseparator                     fg=110
    globbing                               fg=250
    globbing-ext                           fg=250
    history-expansion                      fg=250

    single-hyphen-option                   fg=245
    double-hyphen-option                   fg=245
    optarg-string                          fg=180
    optarg-number                          fg=250

    single-quoted-argument                 fg=180
    double-quoted-argument                 fg=180
    dollar-quoted-argument                 fg=180
    back-quoted-argument                   fg=250
    back-dollar-quoted-argument            fg=245
    back-or-dollar-double-quoted-argument  fg=245

    variable                               fg=250
    assign                                 none
    assign-array-bracket                   fg=245

    paired-bracket                         fg=252,underline
    bracket-level-1                        fg=110
    bracket-level-2                        fg=250
    bracket-level-3                        fg=245

    here-string-tri                        fg=245
    here-string-text                       fg=180
    here-string-var                        fg=245
    exec-descriptor                        fg=250

    correct-subtle                         fg=240
    incorrect-subtle                       fg=167
    subtle-separator                       fg=240
    subtle-bg                              none

    case-input                             fg=252
    case-parentheses                       fg=250
    case-condition                         fg=180

    mathvar                                fg=250
    mathnum                                fg=250
    matherr                                fg=167
    for-loop-variable                      fg=250
    for-loop-number                        fg=250
    for-loop-operator                      fg=250
    for-loop-separator                     fg=245
  )
  typeset -gA FAST_HIGHLIGHT_STYLES
  for k in ${(k)s}; do
    FAST_HIGHLIGHT_STYLES[$k]=$s[$k]
    [[ -n $FAST_THEME_NAME ]] && FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}$k]=$s[$k]
  done
}
