# cli-setup -- PowerShell profile for Windows
# https://github.com/NatLee/cli-setup
#
# Loaded by a small block in your $PROFILE. Everything here lives locally in ~\.config\cli-setup,
# so it keeps working when Documents is redirected to a synced / network folder.
#   options.ps1 : choices made at install time (re-run install.ps1 to change them)
#   local.ps1   : your own tweaks -- never overwritten
# NOTE: keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).

$ZsDir   = Join-Path $HOME '.config\cli-setup'
$ZsCache = Join-Path $env:LOCALAPPDATA 'cli-setup\cache'
if (-not (Test-Path $ZsCache)) { New-Item -ItemType Directory -Force -Path $ZsCache | Out-Null }

# ---------- defaults (overridden by options.ps1) ----------
$ZS = @{
  Plugins      = @('fzf-tab', 'history-substring-search', 'zoxide', 'fzf', 'aliases')
  SuggestColor = 244
  Theme        = 'soft'
  Conda        = 'defer'      # defer | fast | lazy | full | off
  CondaRoot    = ''           # empty = auto-detect
  CondaTimeout = 30
  EditMode     = 'Emacs'      # Emacs (same keys as the zsh setup) | Windows
}
$__opt = Join-Path $ZsDir 'options.ps1'
if (Test-Path $__opt) { . $__opt }

function Test-ZsPlugin([string]$Name) { $ZS.Plugins -contains $Name }

# Interactive = a real console with no -Command / -File: skip prompt and key-binding work for scripts.
$__args = @([Environment]::GetCommandLineArgs() | Select-Object -Skip 1)
$global:ZsInteractive = ($Host.Name -eq 'ConsoleHost') -and
  -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
  @($__args | Where-Object { $_ -notmatch '^-(NoLogo|NoExit|Login|l|Interactive|i|NoProfileLoadTime)$' }).Count -eq 0
if ($env:CLI_SETUP_INTERACTIVE -eq '1') { $global:ZsInteractive = $true }   # used by the installer to time the profile

# Path of a cached init script, regenerated only when the tool's executable changes.
# Dot-source the result at top level:  . (Get-ZsCached starship $exe { starship init powershell --print-full-init })
function Get-ZsCached([string]$Name, [string]$Exe, [scriptblock]$Generate) {
  $file = Join-Path $ZsCache "$Name.ps1"
  $stale = -not (Test-Path $file)
  if (-not $stale) { $stale = (Get-Item $file).LastWriteTimeUtc -lt (Get-Item $Exe).LastWriteTimeUtc }
  if ($stale) { (& $Generate | Out-String) | Set-Content -Path $file -Encoding UTF8 }
  $file
}
function Get-ZsExe([string]$Name, [string[]]$Extra = @()) {
  $c = Get-Command $Name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
  if ($c) { return $c.Source }
  foreach ($p in $Extra) { if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return $p } }
}

# ================================
# PSReadLine: suggestions, colours, keys (interactive only)
# ================================
$__e = [char]27
function ConvertTo-ZsColor([int]$n) { "$__e[38;5;${n}m" }

if ($global:ZsInteractive) {
  if (-not (Get-Module PSReadLine)) { Import-Module PSReadLine -ErrorAction SilentlyContinue }
}
if ($global:ZsInteractive -and (Get-Module PSReadLine)) {
  $psrl = (Get-Module PSReadLine).Version
  Set-PSReadLineOption -EditMode $ZS.EditMode -BellStyle None -HistoryNoDuplicates -MaximumHistoryCount 50000

  # zsh-autosuggestions equivalent: grey inline suggestion from history, accept with Right arrow / End
  if ($psrl -ge [version]'2.1.0' -and $Host.UI.SupportsVirtualTerminal) {
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
  # Home / End / Ctrl+arrows behave the same in Emacs and Windows mode
  Set-PSReadLineKeyHandler -Key Home -Function BeginningOfLine
  Set-PSReadLineKeyHandler -Key End  -Function EndOfLine
  Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
  Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
}

# ================================
# fzf (Ctrl-R history, Ctrl-T files, Alt-C cd) and fzf-tab (Tab menu) via PSFzf
# ================================
# PSFzf takes ~200 ms to import, so it is loaded on the first key press instead of at startup.
if ($global:ZsInteractive -and ((Test-ZsPlugin 'fzf') -or (Test-ZsPlugin 'fzf-tab')) -and (Get-Module PSReadLine) -and (Get-ZsExe fzf)) {
  $env:FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border --color=bg+:236,hl:110,hl+:110,pointer:149,marker:176,prompt:110,info:244'
  function global:Invoke-ZsFzf([string]$Handler, [scriptblock]$Fallback) {
    if (-not (Get-Module PSFzf)) { Import-Module PSFzf -Global -ErrorAction SilentlyContinue }
    if (Get-Command $Handler -ErrorAction Ignore) { & $Handler } elseif ($Fallback) { & $Fallback }
  }
  if (Test-ZsPlugin 'fzf') {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -BriefDescription 'fzf history' -ScriptBlock {
      Invoke-ZsFzf Invoke-FzfPsReadlineHandlerHistory { [Microsoft.PowerShell.PSConsoleReadLine]::ReverseSearchHistory() } }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'fzf files' -ScriptBlock { Invoke-ZsFzf Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Chord 'Alt+c'  -BriefDescription 'fzf cd'    -ScriptBlock { Invoke-ZsFzf Invoke-FzfPsReadlineHandlerSetLocation }
  }
  if (Test-ZsPlugin 'fzf-tab') {
    Set-PSReadLineKeyHandler -Key Tab -BriefDescription 'fzf tab completion' -ScriptBlock {
      Invoke-ZsFzf Invoke-FzfTabCompletion { [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete() } }
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
# Conda -- Starship already shows the env, so conda's own "(base)" prefix stays off.
#   defer : load the Conda module, activate base in the background (PowerShell 7, interactive)
#   fast  : load the Conda module, activate base right away
#   lazy  : load conda on the first `conda` call (base not active at start)
#   full  : official `conda init` hook
#   off   : don't load conda
# Scripts and `pwsh -Command` always get base activated synchronously (unless lazy/off).
# ================================
function Find-ZsCondaRoot {
  $ok = { param($c) $c -and (Test-Path -LiteralPath (Join-Path $c 'Scripts\conda.exe') -PathType Leaf) -and
                     (Test-Path -LiteralPath (Join-Path $c 'shell\condabin\Conda.psm1') -PathType Leaf) }
  # cheap checks first: setting, current env, usual install folders
  $candidates = @()
  if ($ZS.CondaRoot) { $candidates += [Environment]::ExpandEnvironmentVariables($ZS.CondaRoot) }
  if ($env:_CONDA_ROOT) { $candidates += $env:_CONDA_ROOT }
  if ($env:CONDA_EXE) { $candidates += Split-Path (Split-Path $env:CONDA_EXE) }
  foreach ($parent in $env:USERPROFILE, $env:LOCALAPPDATA, $env:ProgramData, $env:ProgramFiles) {
    if ($parent) { foreach ($n in 'miniconda3', 'anaconda3', 'miniforge3', 'mambaforge') { $candidates += Join-Path $parent $n } }
  }
  foreach ($c in $candidates) { if (& $ok $c) { return [IO.Path]::GetFullPath($c) } }
  # last resort: scan PATH (~50 ms)
  foreach ($x in Get-Command conda.exe -CommandType Application -All -ErrorAction Ignore) {
    $c = Split-Path (Split-Path $x.Source); if (& $ok $c) { return [IO.Path]::GetFullPath($c) }
  }
}
function Import-ZsConda([string]$Root) {
  # Same as the official hook, minus spawning conda.exe just to print it.
  $env:CONDA_EXE = Join-Path $Root 'Scripts\conda.exe'
  $env:_CONDA_EXE = $env:CONDA_EXE
  $env:_CONDA_ROOT = $Root
  $env:_CE_M = $null; $env:_CE_CONDA = $null
  $m = Join-Path $Root 'shell\condabin\Conda.psm1'
  if (-not (Get-Module Conda | Where-Object Path -eq $m)) {
    Import-Module $m -ArgumentList @{ ChangePs1 = $false } -Global -ErrorAction Stop
  }
}

$env:CONDA_CHANGEPS1 = 'false'
if ($ZS.Conda -ne 'off') {
  $global:ZsCondaRoot = Find-ZsCondaRoot
  if ($global:ZsCondaRoot) {
    try {
      switch ($ZS.Conda) {
        'lazy' {
          function global:conda {
            Remove-Item Function:\conda -ErrorAction SilentlyContinue
            Import-ZsConda $global:ZsCondaRoot
            Invoke-Conda @args
          }
        }
        'full' {
          (& (Join-Path $global:ZsCondaRoot 'Scripts\conda.exe') 'shell.powershell' 'hook') | Out-String | Where-Object { $_ } | Invoke-Expression
        }
        default {
          Import-ZsConda $global:ZsCondaRoot
          if (-not $env:CONDA_PREFIX -and -not $env:VIRTUAL_ENV) {
            $__defer = Join-Path $ZsDir 'conda-defer.ps1'
            if ($ZS.Conda -eq 'defer' -and $global:ZsInteractive -and $PSVersionTable.PSVersion.Major -ge 7 -and (Test-Path $__defer)) {
              . $__defer -TimeoutSeconds $ZS.CondaTimeout
            } else {
              Conda\Invoke-Conda activate base
            }
          }
        }
      }
    } catch { Write-Warning "cli-setup: conda was skipped: $_" }
    # python3 -> python, unless a real python3.exe exists (the WindowsApps one just opens the Microsoft Store)
    $__p3 = Get-Command python3 -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $__p3 -or $__p3.Source -like '*\WindowsApps\*') { Set-Alias python3 python -Scope Global }
  }
}

# ================================
# Prompt (Starship, cached init) and zoxide (must come last) -- interactive only
# ================================
if ($global:ZsInteractive) {
  $env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship.toml'
  $__starship = Get-ZsExe starship @("$env:ProgramFiles\starship\bin\starship.exe", "$env:LOCALAPPDATA\starship\bin\starship.exe",
                                      "$env:USERPROFILE\.cargo\bin\starship.exe", "$env:USERPROFILE\scoop\shims\starship.exe")
  if ($__starship) {
    try { . (Get-ZsCached 'starship' $__starship { & $__starship init powershell --print-full-init }) }
    catch { Write-Warning "cli-setup: Starship was skipped: $_" }
  }

  $__zoxide = Get-ZsExe zoxide
  if ((Test-ZsPlugin 'zoxide') -and $__zoxide) {
    . (Get-ZsCached 'zoxide' $__zoxide { & $__zoxide init powershell })     # z <dir> | zi = interactive
  }
}

# ================================
# Local overrides (not managed by this repo)
# ================================
$__local = Join-Path $ZsDir 'local.ps1'
if (Test-Path $__local) { . $__local }

function zsh-cache-clear { Remove-Item (Join-Path $ZsCache '*') -Force; 'cache cleared -- restart PowerShell' }

Remove-Variable __opt, __args, __a, __defer, __p3, __starship, __zoxide, __local, palettes, colors, psrl -ErrorAction SilentlyContinue
