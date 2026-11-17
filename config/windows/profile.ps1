# zsh-setup -- PowerShell profile for Windows
# https://github.com/NatLee/zsh-setup
#
# Loaded from your $PROFILE. Options chosen at install time live in options.ps1 next to this file
# (re-run install.ps1 to change them). Personal tweaks go in local.ps1 -- it is never overwritten.
# NOTE: keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).

$ZsDir   = Join-Path $HOME '.config\zsh-setup'
$ZsCache = Join-Path $env:LOCALAPPDATA 'zsh-setup\cache'
if (-not (Test-Path $ZsCache)) { New-Item -ItemType Directory -Force -Path $ZsCache | Out-Null }

# ---------- defaults (overridden by options.ps1) ----------
$ZS = @{
  Plugins      = @('fzf-tab', 'history-substring-search', 'zoxide', 'fzf', 'aliases')
  SuggestColor = 244
  Theme        = 'soft'
  Conda        = 'fast'
}
$__opt = Join-Path $ZsDir 'options.ps1'
if (Test-Path $__opt) { . $__opt }

function Test-ZsPlugin([string]$Name) { $ZS.Plugins -contains $Name }

# Path of a cached init script, regenerated only when the tool's executable changes.
# Dot-source the result at top level:  . (Get-ZsCached starship $exe { starship init powershell --print-full-init })
function Get-ZsCached([string]$Name, [string]$Exe, [scriptblock]$Generate) {
  $file = Join-Path $ZsCache "$Name.ps1"
  $stale = -not (Test-Path $file)
  if (-not $stale) { $stale = (Get-Item $file).LastWriteTimeUtc -lt (Get-Item $Exe).LastWriteTimeUtc }
  if ($stale) { (& $Generate | Out-String) | Set-Content -Path $file -Encoding UTF8 }
  $file
}
function Get-ZsExe([string]$Name) {
  $c = Get-Command $Name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
  if ($c) { $c.Source }
}

# ================================
# PSReadLine: suggestions, colours, keys
# ================================
$__e = [char]27
function ConvertTo-ZsColor([int]$n) { "$__e[38;5;${n}m" }

if (Get-Module -ListAvailable -Name PSReadLine | Where-Object { $_.Version -ge [version]'2.1.0' }) {
  Import-Module PSReadLine -MinimumVersion 2.1.0 -ErrorAction SilentlyContinue
}
if (Get-Module PSReadLine) {
  $psrl = (Get-Module PSReadLine).Version
  Set-PSReadLineOption -BellStyle None -HistoryNoDuplicates -MaximumHistoryCount 50000

  # zsh-autosuggestions equivalent: grey inline suggestion from history, accept with Right arrow / End
  if ($psrl -ge [version]'2.1.0') {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
    Set-PSReadLineOption -Colors @{ InlinePrediction = (ConvertTo-ZsColor $ZS.SuggestColor) }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord        # accept next word
    Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function AcceptSuggestion
  }

  # Syntax colours -- same palettes as the zsh themes
  $palettes = @{
    soft    = @{ Command = 149; Parameter = 116; String = 180; Operator = 245; Variable = 146; Number = 215
                 Type = 110; Member = 110; Keyword = 176; Comment = 242; Error = 167; Default = 252 }
    minimal = @{ Command = 252; Parameter = 245; String = 180; Operator = 245; Variable = 250; Number = 250
                 Type = 110; Member = 250; Keyword = 250; Comment = 242; Error = 167; Default = 252 }
  }
  if ($palettes.ContainsKey($ZS.Theme)) {
    $colors = @{}
    foreach ($k in $palettes[$ZS.Theme].Keys) { $colors[$k] = ConvertTo-ZsColor $palettes[$ZS.Theme][$k] }
    Set-PSReadLineOption -Colors $colors
  }

  # history-substring-search equivalent: Up/Down search history by what's already typed
  if (Test-ZsPlugin 'history-substring-search') {
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  }

  # zsh-like Tab: show a menu of all candidates (replaced by fzf below when fzf-tab is on)
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
  # Ctrl/Alt + arrows jump words, like the zsh setup
  Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
  Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
}

# ================================
# fzf (Ctrl-R history, Ctrl-T files, Alt-C cd) and fzf-tab (Tab menu) via PSFzf
# ================================
if ((Test-ZsPlugin 'fzf') -or (Test-ZsPlugin 'fzf-tab')) {
  if ((Get-ZsExe fzf) -and (Get-Module -ListAvailable -Name PSFzf) -and (Get-Module PSReadLine)) {
    $env:FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border --color=bg+:236,hl:110,hl+:110,pointer:149,marker:176,prompt:110,info:244'
    Import-Module PSFzf -ErrorAction SilentlyContinue
    if (Get-Module PSFzf) {
      if (Test-ZsPlugin 'fzf') {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        Set-PSReadLineKeyHandler -Chord 'Alt+c' -ScriptBlock { Invoke-FuzzySetLocation }
      }
      if (Test-ZsPlugin 'fzf-tab') {
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
      }
    }
  }
}

# ================================
# Aliases
# ================================
if (Test-ZsPlugin 'aliases') {
  $__a = Join-Path $ZsDir 'aliases.ps1'
  if (Test-Path $__a) { . $__a }
}
if ((Test-ZsPlugin 'eza') -and (Get-ZsExe eza)) {
  Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
  function ls { eza --icons=auto --group-directories-first @args }
  function l  { eza -l  --icons=auto --group-directories-first --git --time-style=relative @args }
  function ll { eza -la --icons=auto --group-directories-first --git --time-style=relative @args }
  function la { eza -a  --icons=auto --group-directories-first @args }
  function lt { eza --tree --level=2 --icons=auto @args }
}

# ================================
# Conda -- Starship already shows the env, so hide conda's own "(base)" prefix.
#   fast: cached hook (default) | lazy: load on first `conda` call | full: official | off
# ================================
$env:CONDA_CHANGEPS1 = 'false'
if ($ZS.Conda -ne 'off') {
  $__roots = @("$HOME\miniconda3", "$HOME\anaconda3", "$HOME\miniforge3", "$HOME\mambaforge",
               "$env:LOCALAPPDATA\miniconda3", "$env:LOCALAPPDATA\anaconda3",
               "$env:ProgramData\miniconda3", "$env:ProgramData\anaconda3")
  $__condaExe = $__roots | ForEach-Object { Join-Path $_ 'Scripts\conda.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($__condaExe) {
    $global:ZsCondaExe = $__condaExe
    switch ($ZS.Conda) {
      'lazy' {
        function global:conda {
          Remove-Item Function:\conda -ErrorAction SilentlyContinue
          (& $global:ZsCondaExe 'shell.powershell' 'hook') | Out-String | Where-Object { $_ } | Invoke-Expression
          conda @args
        }
      }
      'full' {
        (& $__condaExe 'shell.powershell' 'hook') | Out-String | Where-Object { $_ } | Invoke-Expression
      }
      default {
        . (Get-ZsCached 'conda-hook' $__condaExe { & $global:ZsCondaExe 'shell.powershell' 'hook' })
      }
    }
  }
}

# ================================
# Prompt (Starship, cached init) and zoxide (must come last)
# ================================
$env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship.toml'
$__starship = Get-ZsExe starship
if ($__starship) { . (Get-ZsCached 'starship' $__starship { starship init powershell --print-full-init }) }

$__zoxide = Get-ZsExe zoxide
if ((Test-ZsPlugin 'zoxide') -and $__zoxide) {
  . (Get-ZsCached 'zoxide' $__zoxide { zoxide init powershell })     # z <dir> . zi = interactive
}

# ================================
# Local overrides (not managed by this repo)
# ================================
$__local = Join-Path $ZsDir 'local.ps1'
if (Test-Path $__local) { . $__local }

function zsh-cache-clear { Remove-Item (Join-Path $ZsCache '*') -Force; 'cache cleared -- restart PowerShell' }

Remove-Variable __opt, __a, __roots, __condaExe, __starship, __zoxide, __local, palettes, colors, psrl -ErrorAction SilentlyContinue
