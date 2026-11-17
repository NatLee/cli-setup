# zsh-setup -- common aliases for PowerShell (Windows)
# Same names as the zsh version; git aliases match Oh My Zsh. Keep this file ASCII-only.
# Add your own in local.ps1 (loaded later, so it can override anything here).

# Built-in aliases that clash with the git shortcuts below (gc = Get-Content, gp = Get-ItemProperty, gl = Get-Location)
foreach ($__n in 'gc', 'gp', 'gl') {
  if (Test-Path "Alias:$__n") { Remove-Item "Alias:$__n" -Force -ErrorAction SilentlyContinue }
}
Remove-Variable __n -ErrorAction SilentlyContinue

# ---------- navigation ----------
function ..   { Set-Location .. }
function ...  { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# ---------- listing (replaced by eza versions when eza is enabled) ----------
function l  { Get-ChildItem @args }
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Name @args }
function h  { Get-History -Count 20 }

# ---------- unix-style helpers ----------
function which([string]$Name) { (Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
function touch([string]$Path) {
  if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $Path | Out-Null }
}

# ---------- git ----------
function g     { git @args }
function gst   { git status @args }
function gss   { git status -sb @args }
function ga    { git add @args }
function gaa   { git add --all @args }
function gc    { git commit -v @args }
function gcmsg { git commit -m @args }
function gd    { git diff @args }
function gds   { git diff --staged @args }
function gco   { git checkout @args }
function gsw   { git switch @args }
function gb    { git branch @args }
function gl    { git pull @args }
function gp    { git push @args }
function glog  { git log --oneline --decorate --graph -20 @args }
function gsta  { git stash push @args }
function gstp  { git stash pop @args }

# ---------- system helpers ----------
function o        { Invoke-Item . }                                # open current dir in Explorer
function path     { $env:PATH -split [IO.Path]::PathSeparator | Where-Object { $_ } }
function localip  {
  (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.InterfaceAlias -notmatch 'vEthernet|Loopback' } |
    Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress
}
function ports {                                                     # who is listening on which port
  Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Sort-Object LocalPort |
    Select-Object LocalAddress, LocalPort, OwningProcess,
      @{ n = 'Process'; e = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } }
}
function flushdns { Clear-DnsClientCache; 'DNS cache cleared' }
