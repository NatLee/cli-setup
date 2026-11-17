<#
  cli-setup for Windows — PowerShell 版本（Starship + Hack Nerd Font + PSReadLine + fzf + zoxide）

  一行安裝（PowerShell）：
    irm https://raw.githubusercontent.com/NatLee/cli-setup/main/install.ps1 | iex

  帶參數：
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/NatLee/cli-setup/main/install.ps1))) -Yes -Theme minimal

  參數（都可省略，省略時出現互動選單）：
    -Yes                     不顯示選單，使用預設值（或上次安裝時的選擇）
    -Plugins a,b,c           fzf-tab, history-substring-search, zoxide, fzf, eza, aliases（none / all）
    -SuggestColor VALUE      自動建議文字顏色：dim | medium | bright | 0-255
    -Theme NAME              語法高亮主題：soft | minimal | default
    -Time on|off             Prompt 右側顯示時間
    -Ip on|off               Prompt 右側顯示本機 IP
    -Conda MODE              conda 載入方式：defer | fast | lazy | full | off
    -EditMode Emacs|Windows  PSReadLine 編輯模式（Emacs = 和 zsh 一樣的按鍵）
    -Font on|off             安裝 Hack Nerd Font（裝在目前使用者，不需要系統管理員）
    -WindowsTerminal on|off  把 Windows Terminal 的預設字型改成 Hack Nerd Font Mono
    -WindowsPowerShell on|off  Windows PowerShell 5.1 也套用（有 PowerShell 7 時預設 off）
    -ReplaceProfile          把原本的 PowerShell 設定檔移到旁邊的備份資料夾，由 cli-setup 接管
    -SkipPackages            不安裝任何套件 / 模組
#>
[CmdletBinding()]
param(
  [switch]$Yes,
  [string]$Plugins,
  [string]$SuggestColor,
  [ValidateSet('soft', 'minimal', 'default')][string]$Theme,
  [ValidateSet('on', 'off')][string]$Time,
  [ValidateSet('on', 'off')][string]$Ip,
  [ValidateSet('defer', 'fast', 'lazy', 'full', 'off')][string]$Conda,
  [ValidateSet('Emacs', 'Windows')][string]$EditMode,
  [ValidateSet('on', 'off')][string]$Font,
  [ValidateSet('on', 'off')][string]$WindowsTerminal,
  [ValidateSet('on', 'off')][string]$WindowsPowerShell,
  [switch]$ReplaceProfile,
  [switch]$SkipPackages
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar in 5.1

function Invoke-ZsSetup {
  # ---------- constants ----------
  $RepoZip      = 'https://github.com/NatLee/cli-setup/archive/refs/heads/main.zip'
  $FontZip      = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip'
  $ZsDir        = Join-Path $HOME '.config\cli-setup'
  $StarshipToml = Join-Path $HOME '.config\starship.toml'
  $ZsCache      = Join-Path $env:LOCALAPPDATA 'cli-setup\cache'
  $BackupDir    = Join-Path $HOME ('.cli-setup-backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  $Optional     = @('fzf-tab', 'history-substring-search', 'zoxide', 'fzf', 'eza', 'aliases')
  $DefaultSel   = @('fzf-tab', 'history-substring-search', 'zoxide', 'fzf', 'aliases')
  $Recommended  = $DefaultSel
  $Describe = @{
    'fzf-tab'                  = 'Tab 補完改成 fzf 模糊搜尋選單（PSFzf）'
    'history-substring-search' = '↑/↓ 依目前已輸入的內容搜尋歷史'
    'zoxide'                   = 'z <關鍵字> 直接跳到常去的目錄'
    'fzf'                      = 'Ctrl-R 搜歷史 · Ctrl-T 找檔案 · Alt-C 跳目錄'
    'eza'                      = 'ls / l / ll / la / lt 換成彩色 + 圖示的 eza'
    'aliases'                  = '常用 alias：ll、..、gst / gco 等 git 縮寫、which、touch'
  }
  $WingetIds = @{ starship = 'Starship.Starship'; fzf = 'junegunn.fzf'; zoxide = 'ajeetdsouza.zoxide'; eza = 'eza-community.eza' }

  # ---------- helpers ----------
  $e = [char]27
  function Step($m) { Write-Host ''; Write-Host '==> ' -ForegroundColor Cyan -NoNewline; Write-Host $m }
  function Ok($m)   { Write-Host '  ✔ ' -ForegroundColor Green -NoNewline; Write-Host $m }
  function Warn($m) { Write-Host '  ! ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
  function Fail($m) { Write-Host "✖ $m" -ForegroundColor Red; throw $m }
  function OnOff($b) { if ($b) { '開' } else { '關' } }
  function C256($n) { "$e[38;5;${n}m" }
  function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
  function Update-SessionPath {
    $env:Path = ([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User') |
      Where-Object { $_ }) -join ';'
  }
  function Read-Text([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { return [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3) }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { return [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2) }
    try { (New-Object Text.UTF8Encoding $false, $true).GetString($bytes) }      # strict UTF-8
    catch { [Text.Encoding]::Default.GetString($bytes) }                         # legacy ANSI file
  }
  function Write-Text([string]$path, [string]$text, [bool]$bom = $true) {
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $bom))
  }
  function Backup-Item($path, $newContent) {
    if (-not (Test-Path $path)) { return }
    if ($null -ne $newContent -and (Read-Text $path) -eq $newContent) { return }
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    Copy-Item $path -Destination $BackupDir -Force
    Warn "已備份 $path → $BackupDir"
  }
  function Font-Installed {
    (Test-Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\HackNerdFontMono-Regular.ttf") -or
    (Test-Path "$env:WINDIR\Fonts\HackNerdFontMono-Regular.ttf")
  }
  function Find-Conda {
    $roots = @()
    if ($env:CONDA_EXE) { $roots += Split-Path (Split-Path $env:CONDA_EXE) }
    foreach ($parent in $env:USERPROFILE, $env:LOCALAPPDATA, $env:ProgramData, $env:ProgramFiles) {
      if ($parent) { foreach ($n in 'miniconda3', 'anaconda3', 'miniforge3', 'mambaforge') { $roots += Join-Path $parent $n } }
    }
    $roots | Where-Object { $_ -and (Test-Path (Join-Path $_ 'Scripts\conda.exe')) } | Select-Object -First 1
  }
  function Get-ProfilePath([string]$exe, [string]$which) {
    if (-not $exe -or -not (Test-Path $exe)) { return }
    $r = & $exe -NoLogo -NoProfile -NonInteractive -Command "`$PROFILE.$which" 2>$null | Select-Object -Last 1
    if ($r) { $r.Trim() }
  }
  # Effective policy for an edition, ignoring the Process scope this installer may have been started with.
  function Get-EffectivePolicy([string]$exe, [bool]$core) {
    $list = & $exe -NoLogo -NoProfile -NonInteractive -Command 'Get-ExecutionPolicy -List | ForEach-Object { "{0}={1}" -f $_.Scope, $_.ExecutionPolicy }' 2>$null
    $map = @{}; foreach ($l in $list) { $k, $v = $l -split '=', 2; $map[$k] = $v }
    foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
      if ($map[$scope] -and $map[$scope] -ne 'Undefined') { return @{ Policy = $map[$scope]; Scope = $scope } }
    }
    @{ Policy = $(if ($core) { 'RemoteSigned' } else { 'Restricted' }); Scope = 'Default' }
  }
  function Set-TomlDisabled([string]$text, [string]$section, [bool]$disabled) {
    $out = New-Object System.Collections.Generic.List[string]
    $in = $false
    foreach ($line in ($text -split "`r?`n")) {
      if ($line -match '^\[') { $in = ($line.Trim() -eq "[$section]") }
      if ($in -and $line -match '^disabled\s*=') { $line = "disabled = $($disabled.ToString().ToLower())" }
      $out.Add($line)
    }
    $out -join "`n"
  }

  # ---------- 0. sanity ----------
  if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Fail '這是 Windows 版本。macOS / Linux / WSL 請改用 install.sh（見 README）。'
  }
  try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
  $ps5 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

  # ---------- 1. defaults + previous choices ----------
  $ZS = @{
    Plugins = $DefaultSel; SuggestColor = 244; Theme = 'soft'; Conda = 'defer'; EditMode = 'Emacs'
    PromptTime = $true; PromptIp = $true; Font = $true; WindowsTerminal = $true; WindowsPowerShell = $null; Offered = $null
  }
  $optFile = Join-Path $ZsDir 'options.ps1'
  if (Test-Path $optFile) {
    . $optFile
    $offered = if ($ZS.Offered) { $ZS.Offered } else { $Optional }
    foreach ($p in $DefaultSel) { if ($offered -notcontains $p -and $ZS.Plugins -notcontains $p) { $ZS.Plugins += $p } }
  }
  $sel = [System.Collections.Generic.List[string]]::new()
  foreach ($p in $ZS.Plugins) { if ($Optional -contains $p) { $sel.Add($p) } }

  # ---------- 2. parameters ----------
  if ($Plugins) {
    $sel.Clear()
    switch ($Plugins) {
      'none' { }
      'all'  { $Optional | ForEach-Object { $sel.Add($_) } }
      default {
        foreach ($p in ($Plugins -split '[,\s]+' | Where-Object { $_ })) {
          if ($Optional -notcontains $p) { Fail "未知的外掛：$p（可用：$($Optional -join ', ')）" }
          $sel.Add($p)
        }
      }
    }
  }
  if ($SuggestColor) {
    switch ($SuggestColor) {
      'dim' { $ZS.SuggestColor = 240 } 'medium' { $ZS.SuggestColor = 244 } 'bright' { $ZS.SuggestColor = 248 }
      default {
        if ($SuggestColor -notmatch '^\d+$' -or [int]$SuggestColor -gt 255) { Fail '-SuggestColor 要是 dim/medium/bright 或 0-255' }
        $ZS.SuggestColor = [int]$SuggestColor
      }
    }
  }
  if ($Theme)           { $ZS.Theme = $Theme }
  if ($Conda)           { $ZS.Conda = $Conda }
  if ($Time)            { $ZS.PromptTime = ($Time -eq 'on') }
  if ($Ip)              { $ZS.PromptIp = ($Ip -eq 'on') }
  if ($Font)            { $ZS.Font = ($Font -eq 'on') }
  if ($WindowsTerminal) { $ZS.WindowsTerminal = ($WindowsTerminal -eq 'on') }
  if ($EditMode)        { $ZS.EditMode = $EditMode }
  if ($WindowsPowerShell) { $ZS.WindowsPowerShell = ($WindowsPowerShell -eq 'on') }
  if ($null -eq $ZS.WindowsPowerShell) { $ZS.WindowsPowerShell = -not $pwsh }   # 5.1 only when there is no PowerShell 7
  if (-not $pwsh) { $ZS.WindowsPowerShell = $true }

  $edition = "PowerShell $($PSVersionTable.PSVersion)"
  Write-Host ''
  Write-Host ' cli-setup ' -ForegroundColor Cyan -NoNewline
  Write-Host " Starship · Hack Nerd Font · PSReadLine — Windows / $edition" -ForegroundColor DarkGray

  # ---------- 3. interactive menu ----------
  $condaRoot = Find-Conda
  $interactive = (-not $Yes) -and [Environment]::UserInteractive -and ($Host.Name -eq 'ConsoleHost')
  if ($interactive) {
    while ($true) {
      Write-Host ''; Write-Host '  外掛 / 工具'
      for ($i = 0; $i -lt $Optional.Count; $i++) {
        $p = $Optional[$i]
        $mark = if ($sel.Contains($p)) { '[x]' } else { '[ ]' }
        $star = if ($Recommended -contains $p) { '★' } else { ' ' }
        Write-Host ('  {0,2} ' -f ($i + 1)) -NoNewline
        Write-Host $mark -ForegroundColor $(if ($sel.Contains($p)) { 'Green' } else { 'DarkGray' }) -NoNewline
        Write-Host " $star " -ForegroundColor Yellow -NoNewline
        Write-Host ('{0,-26} ' -f $p) -NoNewline
        Write-Host $Describe[$p] -ForegroundColor DarkGray
      }
      $label = switch ($ZS.SuggestColor) { 240 { '暗 (240)' } 244 { '中 (244)' } 248 { '亮 (248)' } default { "自訂 ($($ZS.SuggestColor))" } }
      $r = "$e[0m"
      $preview = switch ($ZS.Theme) {
        'soft'    { "$(C256 149)git $(C256 116)commit -m $(C256 180)'fix' $(C256 146)`$path$r" }
        'minimal' { "$(C256 252)git $(C256 245)commit -m $(C256 180)'fix' $(C256 250)`$path$r" }
        default   { "$e[93mgit $e[90mcommit -m $e[36m'fix' $e[92m`$path$r" }
      }
      Write-Host ''; Write-Host '  外觀'
      Write-Host ("   7 建議文字顏色    {0,-12} 預覽：{1}git sta{2}{3}tus --short{2}" -f $label, (C256 252), $r, (C256 $ZS.SuggestColor))
      Write-Host ("   8 語法高亮主題    {0,-12} 預覽：{1}" -f $ZS.Theme, $preview)
      Write-Host ("   9 Prompt 時間     {0}" -f (OnOff $ZS.PromptTime))
      Write-Host ("  10 Prompt IP       {0}" -f (OnOff $ZS.PromptIp))
      Write-Host ''; Write-Host '  其他'
      if ($condaRoot) {
        $cdesc = switch ($ZS.Conda) {
          'defer' { '背景啟用 base，提示字元立刻出現（推薦）' } 'fast' { '立刻啟用 base（啟動會等 conda）' }
          'lazy' { '第一次打 conda 才載入，base 不會自動啟用' } 'full' { '官方 conda init 行為（最慢）' } 'off' { '不載入 conda' } }
        Write-Host ("  11 Conda 載入方式  {0,-12} " -f $ZS.Conda) -NoNewline; Write-Host $cdesc -ForegroundColor DarkGray
      } else {
        Write-Host '  11 Conda 載入方式  （沒有偵測到 conda）' -ForegroundColor DarkGray
      }
      Write-Host ("  12 安裝 Hack Nerd Font      {0}" -f (OnOff $ZS.Font))
      Write-Host ("  13 設定 Windows Terminal    {0}  " -f (OnOff $ZS.WindowsTerminal)) -NoNewline
      Write-Host '預設字型換成 Hack Nerd Font Mono' -ForegroundColor DarkGray
      Write-Host ("  14 編輯模式               {0,-8} " -f $ZS.EditMode) -NoNewline
      Write-Host $(if ($ZS.EditMode -eq 'Emacs') { 'Ctrl-A / Ctrl-E 等，和 zsh 一樣' } else { 'Windows 傳統按鍵' }) -ForegroundColor DarkGray
      if ($pwsh) {
        Write-Host ("  15 Windows PowerShell 5.1   {0}  " -f (OnOff $ZS.WindowsPowerShell)) -NoNewline
        Write-Host '也套用到舊版 powershell.exe（會調整執行原則）' -ForegroundColor DarkGray
      }
      Write-Host ''
      Write-Host '  ★ 推薦' -ForegroundColor Yellow -NoNewline
      Write-Host '  輸入編號切換（可一次多個，例如 1 7 8），直接 Enter 開始安裝，q 離開'
      $answer = Read-Host '  >'
      if ($null -eq $answer -or $answer.Trim() -eq '') { break }
      foreach ($n in ($answer -split '\s+' | Where-Object { $_ })) {
        switch -Regex ($n) {
          '^[qQ]$' { Write-Host '  已取消。'; return }
          '^[1-6]$' { $p = $Optional[[int]$n - 1]; if ($sel.Contains($p)) { [void]$sel.Remove($p) } else { $sel.Add($p) } }
          '^7$'  { $ZS.SuggestColor = switch ($ZS.SuggestColor) { 240 { 244 } 244 { 248 } default { 240 } } }
          '^8$'  { $ZS.Theme = switch ($ZS.Theme) { 'soft' { 'minimal' } 'minimal' { 'default' } default { 'soft' } } }
          '^9$'  { $ZS.PromptTime = -not $ZS.PromptTime }
          '^10$' { $ZS.PromptIp = -not $ZS.PromptIp }
          '^11$' { if ($condaRoot) { $ZS.Conda = switch ($ZS.Conda) { 'defer' { 'fast' } 'fast' { 'lazy' } 'lazy' { 'full' } 'full' { 'off' } default { 'defer' } } } }
          '^12$' { $ZS.Font = -not $ZS.Font }
          '^13$' { $ZS.WindowsTerminal = -not $ZS.WindowsTerminal }
          '^14$' { $ZS.EditMode = if ($ZS.EditMode -eq 'Emacs') { 'Windows' } else { 'Emacs' } }
          '^15$' { if ($pwsh) { $ZS.WindowsPowerShell = -not $ZS.WindowsPowerShell } }
          default { Warn "沒有這個選項：$n" }
        }
      }
      Write-Host '  ────────────────────────────────────────────' -ForegroundColor DarkGray
    }
  }
  $sel = @($Optional | Where-Object { $sel.Contains($_) })   # stable order

  $targets = @()
  if ($pwsh) { $targets += [pscustomobject]@{ Name = 'PowerShell 7'; Exe = $pwsh.Source; Core = $true; Folder = 'PowerShell' } }
  if ($ZS.WindowsPowerShell -and (Test-Path $ps5)) { $targets += [pscustomobject]@{ Name = 'Windows PowerShell 5.1'; Exe = $ps5; Core = $false; Folder = 'WindowsPowerShell' } }

  # ---------- 4. packages ----------
  $tools = @('starship')
  if ($sel -contains 'fzf' -or $sel -contains 'fzf-tab') { $tools += 'fzf' }
  if ($sel -contains 'zoxide') { $tools += 'zoxide' }
  if ($sel -contains 'eza') { $tools += 'eza' }

  if (-not $SkipPackages) {
    Step "工具：$($tools -join ' ')"
    $useWinget = Have 'winget'
    $useScoop = (-not $useWinget) -and (Have 'scoop')
    if (-not $useWinget -and -not $useScoop) {
      Warn '找不到 winget 或 Scoop。請先從 Microsoft Store 安裝「應用程式安裝程式」（App Installer），或安裝 Scoop。'
    }
    foreach ($t in $tools) {
      if (Have $t) { Ok "$t（已安裝）"; continue }
      try {
        if ($useWinget) {
          winget install --id $WingetIds[$t] --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
        } elseif ($useScoop) {
          scoop install $t | Out-Null
        }
      } catch { }
      Update-SessionPath
      if (Have $t) { Ok "$t（安裝完成）" } else { Warn "$t 安裝失敗，相關功能啟動時會自動略過" }
    }

    # PowerShell modules, for each edition cli-setup is applied to
    $modules = @('PSReadLine')
    if ($tools -contains 'fzf') { $modules += 'PSFzf' }
    Step "PowerShell 模組：$($modules -join ' ')"
    $installCmd = @'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if ($PSVersionTable.PSVersion.Major -lt 6) {
  if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
  }
}
$need = @{ PSReadLine = [version]'2.2.6'; PSFzf = [version]'2.0.0' }
foreach ($m in $args) {
  $have = Get-Module -ListAvailable -Name $m | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $have -or $have.Version -lt $need[$m]) {
    Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -Repository PSGallery
  }
}
'@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("& { $installCmd } $($modules -join ' ')"))
    foreach ($t in $targets) {
      & $t.Exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) { Ok "$($t.Name)：$($modules -join ', ')" } else { Warn "$($t.Name)：模組安裝失敗（之後可重跑）" }
    }

    # Font (per user, no admin needed)
    if ($ZS.Font) {
      Step '字型：Hack Nerd Font（含 Hack Nerd Font Mono）'
      if (Font-Installed) { Ok 'Hack Nerd Font Mono（已存在）' }
      else {
        try {
          $tmp = Join-Path ([IO.Path]::GetTempPath()) ("cli-setup-font-" + [guid]::NewGuid())
          New-Item -ItemType Directory -Path $tmp | Out-Null
          Invoke-WebRequest -Uri $FontZip -OutFile "$tmp\Hack.zip" -UseBasicParsing
          Expand-Archive -Path "$tmp\Hack.zip" -DestinationPath $tmp -Force
          $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
          New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
          $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
          if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
          foreach ($f in Get-ChildItem $tmp -Filter 'HackNerdFont*.ttf') {
            $dest = Join-Path $fontDir $f.Name
            Copy-Item $f.FullName $dest -Force
            New-ItemProperty -Path $reg -Name "$($f.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
          }
          Remove-Item $tmp -Recurse -Force
          Ok "已安裝到 $fontDir"
        } catch { Warn "字型安裝失敗：$($_.Exception.Message)" }
      }
    }
  }

  # ---------- 5. config source ----------
  Step '設定檔來源'
  $src = $null
  if ($PSCommandPath) {
    $here = Split-Path -Parent $PSCommandPath
    if (Test-Path (Join-Path $here 'config\windows\profile.ps1')) { $src = $here }
  }
  if (-not $src) {
    $tmpRepo = Join-Path ([IO.Path]::GetTempPath()) ("cli-setup-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmpRepo | Out-Null
    Invoke-WebRequest -Uri $RepoZip -OutFile "$tmpRepo\repo.zip" -UseBasicParsing
    Expand-Archive -Path "$tmpRepo\repo.zip" -DestinationPath $tmpRepo -Force
    $src = (Get-ChildItem $tmpRepo -Directory | Select-Object -First 1).FullName
  }
  Ok $src

  # ---------- 6. configs ----------
  Step '寫入設定'
  New-Item -ItemType Directory -Force -Path $ZsDir, (Split-Path $StarshipToml), $ZsCache | Out-Null

  foreach ($f in 'profile.ps1', 'aliases.ps1', 'conda-defer.ps1') {
    $new = Read-Text (Join-Path $src "config\windows\$f")
    Backup-Item (Join-Path $ZsDir $f) $new
    Write-Text (Join-Path $ZsDir $f) $new
  }
  Ok "$ZsDir\profile.ps1"
  if ($sel -contains 'aliases') { Ok "常用 alias：$ZsDir\aliases.ps1" }

  $toml = Read-Text (Join-Path $src 'config\starship.toml')
  $toml = Set-TomlDisabled $toml 'time' (-not $ZS.PromptTime)
  $toml = Set-TomlDisabled $toml 'localip' (-not $ZS.PromptIp)
  Backup-Item $StarshipToml $toml
  Write-Text $StarshipToml $toml $false
  Ok "$StarshipToml（時間：$(OnOff $ZS.PromptTime)，IP：$(OnOff $ZS.PromptIp)）"

  $q = { param($a) ($a | ForEach-Object { "'$_'" }) -join ', ' }
  $opts = @"
# Generated by cli-setup -- re-run install.ps1 to change these.
`$ZS.Plugins         = @($(& $q $sel))
`$ZS.SuggestColor    = $($ZS.SuggestColor)
`$ZS.Theme           = '$($ZS.Theme)'
`$ZS.Conda           = '$($ZS.Conda)'
`$ZS.EditMode        = '$($ZS.EditMode)'
`$ZS.WindowsPowerShell = `$$($ZS.WindowsPowerShell.ToString().ToLower())
`$ZS.PromptTime      = `$$($ZS.PromptTime.ToString().ToLower())
`$ZS.PromptIp        = `$$($ZS.PromptIp.ToString().ToLower())
`$ZS.Font            = `$$($ZS.Font.ToString().ToLower())
`$ZS.WindowsTerminal = `$$($ZS.WindowsTerminal.ToString().ToLower())
`$ZS.Offered         = @($(& $q $Optional))
"@
  Write-Text $optFile $opts
  Ok $optFile

  if ($condaRoot -and $ZS.Conda -ne 'off') {
    & (Join-Path $condaRoot 'Scripts\conda.exe') config --set changeps1 False 2>&1 | Out-Null
    Ok "conda：changeps1 = False（載入方式：$($ZS.Conda)）"
  }

  # ---------- 7. hook into $PROFILE ----------
  Step 'PowerShell 設定檔'
  $docs = [Environment]::GetFolderPath('MyDocuments')
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  # The block is tiny on purpose: Documents may be synced to other PCs, where it just prints a hint.
  $hook = @'
# >>> cli-setup >>>
$__zs = Join-Path $HOME '.config\cli-setup\profile.ps1'
if (Test-Path $__zs) { . $__zs }
elseif ($Host.Name -eq 'ConsoleHost') { Write-Host 'cli-setup is not installed on this PC: irm https://raw.githubusercontent.com/NatLee/cli-setup/main/install.ps1 | iex' -ForegroundColor DarkGray }
Remove-Variable __zs -ErrorAction SilentlyContinue
# <<< cli-setup <<<
'@
  foreach ($t in $targets) {
    # Ask the edition itself (handles OneDrive / Synology / other redirected Documents)
    $prof = Get-ProfilePath $t.Exe 'CurrentUserAllHosts'
    if (-not $prof) { $prof = Join-Path (Join-Path $docs $t.Folder) 'profile.ps1' }
    $dir = Split-Path $prof
    $hostProf = Get-ProfilePath $t.Exe 'CurrentUserCurrentHost'
    if (-not $hostProf) { $hostProf = Join-Path $dir 'Microsoft.PowerShell_profile.ps1' }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    if ($ReplaceProfile) {
      # Keep the old files next to the profile (so a synced folder doesn't lose them), then start clean.
      $old = @($prof, $hostProf) | Where-Object { (Test-Path $_) -and ((Read-Text $_) -notmatch '^\s*# >>> cli-setup >>>[\s\S]*# <<< cli-setup <<<\s*$') }
      if ($old) {
        $keep = Join-Path $dir "backup-before-cli-setup-$stamp"
        New-Item -ItemType Directory -Force -Path $keep | Out-Null
        foreach ($o in $old) { Move-Item $o $keep -Force }
        Warn "$($t.Name)：原本的設定檔已移到 $keep"
      }
    }
    $cur = if (Test-Path $prof) { Read-Text $prof } else { '' }
    if ($cur -notmatch '>>> cli-setup >>>') {
      Backup-Item $prof $null
      Write-Text $prof (($cur.TrimEnd() + "`r`n`r`n" + $hook).TrimStart() + "`r`n")
    }
    Ok "$($t.Name)：$prof"
    foreach ($other in $hostProf, $prof) {
      if ((Test-Path $other) -and ((Read-Text $other) -match '(?m)^[^#]*(starship init|oh-my-posh|Set-PSReadLineOption|conda.*hook)')) {
        Warn "$other 裡已經有 starship / PSReadLine / conda 的設定，可能會蓋掉 cli-setup（可用 -ReplaceProfile 讓 cli-setup 接管）"
      }
    }

    # execution policy: profiles can't load under Restricted / AllSigned
    $pol = Get-EffectivePolicy $t.Exe $t.Core
    if ($pol.Policy -in 'Restricted', 'AllSigned') {
      if ($pol.Scope -in 'MachinePolicy', 'UserPolicy') { Warn "$($t.Name)：執行原則由群組原則設為 $($pol.Policy)，設定檔不會載入" }
      else {
        try {
          & $t.Exe -NoLogo -NoProfile -NonInteractive -Command 'Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force' 2>&1 | Out-Null
          Ok "$($t.Name)：執行原則 $($pol.Policy) → RemoteSigned（目前使用者）"
        } catch { Warn "$($t.Name)：無法調整執行原則：$($_.Exception.Message)" }
      }
    }
  }

  # PowerShell 7's update notification is noisy (and crashes on some localized consoles)
  if ($pwsh -and -not [Environment]::GetEnvironmentVariable('POWERSHELL_UPDATECHECK', 'User')) {
    [Environment]::SetEnvironmentVariable('POWERSHELL_UPDATECHECK', 'Off', 'User')
    Ok 'POWERSHELL_UPDATECHECK = Off（目前使用者）'
  }

  # Local launcher: works even when the synced Documents folder (and so $PROFILE) is unavailable
  $launcherDir = Join-Path $env:LOCALAPPDATA 'cli-setup'
  New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
  $shellExe = if ($pwsh) { 'pwsh.exe' } else { 'powershell.exe' }
  $launcher = "@echo off`r`nchcp 65001 >nul`r`n$shellExe -NoLogo -NoProfile -NoExit -Command "". '%USERPROFILE%\.config\cli-setup\profile.ps1'""`r`n"
  Write-Text (Join-Path $launcherDir 'Start-PowerShell-Local.cmd') $launcher $false
  Ok "備援啟動器：$launcherDir\Start-PowerShell-Local.cmd"

  # ---------- 8. Windows Terminal ----------
  $wtDone = $false
  if ($ZS.WindowsTerminal) {
    Step 'Windows Terminal'
    $wtFiles = @(
      "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
      "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
      "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json",
      "$HOME\scoop\persist\windows-terminal\settings\settings.json"
    ) | Where-Object { Test-Path $_ }
    if (-not $wtFiles) { Warn '沒有找到 Windows Terminal 的設定檔（先開過一次 Windows Terminal 再重跑），略過' }
    foreach ($wt in $wtFiles) {
      try {
        $raw = Read-Text $wt
        $clean = ($raw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"   # drop // comment lines (5.1 parser)
        $json = $clean | ConvertFrom-Json
        if ($json.profiles -is [array]) { Warn "$wt 使用舊格式，請手動把字型改成 Hack Nerd Font Mono"; continue }
        if (-not $json.profiles.PSObject.Properties['defaults']) {
          $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
        }
        $d = $json.profiles.defaults
        if ($d.PSObject.Properties['font'] -and $d.font.PSObject.Properties['face'] -and $d.font.face -eq 'Hack Nerd Font Mono') {
          Ok "${wt}：預設字型已經是 Hack Nerd Font Mono"; $wtDone = $true; continue
        }
        if (-not $d.PSObject.Properties['font']) { $d | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) }
        if ($d.font.PSObject.Properties['face']) { $d.font.face = 'Hack Nerd Font Mono' }
        else { $d.font | Add-Member -NotePropertyName face -NotePropertyValue 'Hack Nerd Font Mono' }
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item $wt (Join-Path $BackupDir ((Split-Path (Split-Path (Split-Path $wt)) -Leaf) + '-settings.json')) -Force
        Write-Text $wt ($json | ConvertTo-Json -Depth 64) $false
        Ok "$wt：預設字型 → Hack Nerd Font Mono（原檔已備份到 $BackupDir）"
        $wtDone = $true
      } catch { Warn "無法修改 ${wt}：$($_.Exception.Message)" }
    }
  }

  # ---------- 9. warm cache & measure ----------
  Get-ChildItem $ZsCache -Filter '*.ps1' -ErrorAction SilentlyContinue | Remove-Item -Force
  Step '建立快取並測量啟動時間'
  $shell = $targets[0].Exe
  # PSReadLine is already loaded by the console before profiles run, so don't count it
  $measure = "Import-Module PSReadLine -ErrorAction SilentlyContinue; `$env:CLI_SETUP_INTERACTIVE = '1'; `$sw = [Diagnostics.Stopwatch]::StartNew(); . '$ZsDir\profile.ps1' *> `$null; `$sw.ElapsedMilliseconds"
  $times = foreach ($i in 1..4) { & $shell -NoLogo -NoProfile -NonInteractive -Command $measure 2>$null | Select-Object -Last 1 }
  $best = ($times | Select-Object -Skip 1 | ForEach-Object { [int]$_ } | Measure-Object -Minimum).Minimum
  Ok ("設定檔載入時間：約 {0} ms（{1}，不含 PowerShell 本身的啟動）" -f $best, $targets[0].Name)

  # ---------- done ----------
  Write-Host ''
  Write-Host '✔ 完成！' -ForegroundColor Green
  Write-Host ''
  Write-Host "  已啟用：$((@('autosuggestions', 'syntax-highlighting') + $sel) -join ' ')"
  Write-Host ''
  Write-Host '  接下來：'
  if ($wtDone) { Write-Host '    1. 關閉所有 Windows Terminal 視窗再重新打開' }
  else { Write-Host '    1. 把終端機字型改成 Hack Nerd Font Mono（Windows Terminal → 設定 → 預設值 → 外觀 → 字體）' }
  Write-Host '       VS Code："terminal.integrated.fontFamily": "Hack Nerd Font Mono"' -ForegroundColor DarkGray
  if (-not $pwsh) { Write-Host '    2. 建議安裝 PowerShell 7（winget install Microsoft.PowerShell），啟動更快、功能更完整' }
  Write-Host "    同步資料夾暫時讀不到時：Win+R 輸入 %LOCALAPPDATA%\cli-setup\Start-PowerShell-Local.cmd" -ForegroundColor DarkGray
  Write-Host '    之後想改選項，重新執行安裝指令即可（會記住這次的選擇）'
  if (Test-Path $BackupDir) { Write-Host "  舊檔案已備份到 $BackupDir" -ForegroundColor DarkGray }
  Write-Host ''
}

Invoke-ZsSetup
