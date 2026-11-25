#!/usr/bin/env bash
#
# cli-setup — zsh / fish + Starship + Hack Nerd Font，一行搞定（macOS / Linux / WSL）。
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/cli-setup/main/install.sh)"
#
# 直接執行會出現互動選單；也可以用參數指定（搭配 -y 完全不詢問）：
#   -y, --yes                 不顯示選單，使用預設值（或上次安裝時的選擇）
#   --shell=NAME              要設定的 shell：zsh | fish | both（預設：目前的登入 shell 是 fish 就選 fish，否則 zsh）
#   --plugins=a,b,c           選用外掛：fzf-tab, history-substring-search, you-should-use,
#                             zoxide, fzf, eza, aliases（none = 都不要；all = 全部）
#   --suggest-color=VALUE     自動建議文字顏色：dim | medium | bright | 0-255
#   --theme=NAME              語法高亮主題：soft | minimal | default
#   --time=on|off             Prompt 右側顯示時間
#   --ip=on|off               Prompt 右側顯示本機 IP
#   --conda=MODE              conda 載入方式：fast | lazy | full | off
#   --font=on|off             安裝 Hack Nerd Font（--no-font = --font=off）
#   --terminal-app=on|off     [macOS] 設定 Terminal.app：Home/End 鍵 + Hack Nerd Font Mono 字型
#   --skip-packages           不安裝任何套件（需已有 zsh / fish、git、starship；舊名 --skip-brew）
#   -h, --help                顯示說明
#
# Windows 請改用 PowerShell 版本：
#   irm https://raw.githubusercontent.com/NatLee/cli-setup/main/install.ps1 | iex
#
# bash 3.2 compatible (macOS /bin/bash).
set -euo pipefail

REPO_URL="https://github.com/NatLee/cli-setup.git"
ZSH_DIR="$HOME/.zsh"
PLUGIN_DIR="$ZSH_DIR/plugins"
OPTIONS_FILE="$ZSH_DIR/options.zsh"
STARSHIP_TOML="$HOME/.config/starship.toml"
ZSH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
FISH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
FISH_SUPPORT="$FISH_DIR/cli-setup"
FISH_OPTIONS="$FISH_SUPPORT/options.fish"
FISH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cli-setup/fish"
LOCAL_BIN="$HOME/.local/bin"
BACKUP_DIR="$HOME/.cli-setup-backup/$(date +%Y%m%d-%H%M%S)"

CORE_PLUGINS="autosuggestions syntax-highlighting completions"
OPTIONAL="fzf-tab history-substring-search you-should-use zoxide fzf eza aliases"

# ---------- platform ----------
OS="$(uname -s)"
ARCH="$(uname -m)"
IS_MAC=0; IS_LINUX=0; IS_WSL=0
case "$OS" in
  Darwin) IS_MAC=1 ;;
  Linux)  IS_LINUX=1; grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1 ;;
esac

# ---------- defaults (overridden by a previous install, then by flags / menu) ----------
SEL="fzf-tab history-substring-search zoxide fzf aliases"
DEFAULT_SEL="$SEL"
SHELLS=zsh
case "${SHELL:-}" in */fish) SHELLS=fish ;; esac
SUGGEST_COLOR=244
THEME=soft
CONDA_MODE=fast
PROMPT_TIME=1
PROMPT_IP=1
INSTALL_FONT=1
TERMINAL_APP=$IS_MAC
SKIP_PKGS=0
ASSUME_YES=0
# Linux without a desktop (servers, containers, WSL): the font belongs on the machine you type on.
if [[ $IS_LINUX -eq 1 ]] && { [[ $IS_WSL -eq 1 ]] || [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; }; then
  INSTALL_FONT=0
fi

# ---------- helpers ----------
if [[ -t 1 ]]; then
  C_BLUE=$'\033[38;5;110m'; C_GREEN=$'\033[38;5;149m'; C_YELLOW=$'\033[38;5;221m'
  C_RED=$'\033[38;5;167m'; C_DIM=$'\033[38;5;244m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi
c256() { printf '\033[38;5;%sm' "$1"; }
step() { printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%s✖ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }
usage() { sed -n '3,23p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; }
have() { command -v "$1" >/dev/null 2>&1; }

use_shell() { case " $SHELLS " in *" $1 "*) return 0 ;; esac; return 1; }
set_shells() {   # <zsh|fish|both|zsh,fish|...>  — non-zero if nothing valid was given
  local v out=""
  case " $(echo "$1" | tr ',+' '  ') " in *" both "*|*" all "*) SHELLS="zsh fish"; return 0 ;; esac
  for v in zsh fish; do
    case " $(echo "$1" | tr ',+' '  ') " in *" $v "*) out="$out $v" ;; esac
  done
  [[ -n "$out" ]] || return 1
  SHELLS="${out# }"
}
shells_label() { echo "${SHELLS// / + }"; }
c256_hex() {   # xterm 256-colour index → RRGGBB (fish takes hex colours)
  local n=$((10#$1)) v
  local lv=(0 95 135 175 215 255)
  local base=(000000 800000 008000 808000 000080 800080 008080 c0c0c0 808080 ff0000 00ff00 ffff00 0000ff ff00ff 00ffff ffffff)
  if (( n < 16 )); then echo "${base[$n]}"
  elif (( n < 232 )); then n=$((n - 16)); printf '%02x%02x%02x\n' "${lv[$((n / 36))]}" "${lv[$(((n / 6) % 6))]}" "${lv[$((n % 6))]}"
  else v=$((8 + (n - 232) * 10)); printf '%02x%02x%02x\n' "$v" "$v" "$v"; fi
}

has()      { case " $SEL " in *" $1 "*) return 0 ;; esac; return 1; }
toggle() {
  local p out=""
  if has "$1"; then
    for p in $SEL; do [[ "$p" == "$1" ]] || out="$out $p"; done
    SEL="$out"
  else
    SEL="$SEL $1"
  fi
}
is_optional() { case " $OPTIONAL " in *" $1 "*) return 0 ;; esac; return 1; }
onoff()    { [[ "$1" == 1 ]] && echo "開" || echo "關"; }

plugin_dir() {
  case "$1" in
    autosuggestions)          echo "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git" ;;
    syntax-highlighting)      echo "fast-syntax-highlighting|https://github.com/zdharma-continuum/fast-syntax-highlighting.git" ;;
    completions)              echo "zsh-completions|https://github.com/zsh-users/zsh-completions.git" ;;
    fzf-tab)                  echo "fzf-tab|https://github.com/Aloxaf/fzf-tab.git" ;;
    history-substring-search) echo "zsh-history-substring-search|https://github.com/zsh-users/zsh-history-substring-search.git" ;;
    you-should-use)           echo "zsh-you-should-use|https://github.com/MichaelAquilina/zsh-you-should-use.git" ;;
  esac
}
tool_dep() {
  case "$1" in
    fzf-tab|fzf) echo fzf ;;
    zoxide)      echo zoxide ;;
    eza)         echo eza ;;
  esac
}
describe() {
  case "$1" in
    fzf-tab)                  echo "Tab 補完改成 fzf 模糊搜尋選單" ;;
    history-substring-search) echo "↑/↓ 依目前已輸入的內容搜尋歷史" ;;
    you-should-use)           echo "打了完整指令時，提醒你有對應的 alias（僅 zsh）" ;;
    zoxide)                   echo "z <關鍵字> 直接跳到常去的目錄" ;;
    fzf)                      echo "Ctrl-R 搜歷史 · Ctrl-T 找檔案 · Alt-C 跳目錄" ;;
    eza)                      echo "ls / l / ll / la / lt 換成彩色 + 圖示的 eza" ;;
    aliases)                  echo "常用 alias：ll = ls -lah、..、gst / gco 等 git 縮寫" ;;
  esac
}
suggest_label() {
  case "$SUGGEST_COLOR" in
    240) echo "暗 (240)" ;; 244) echo "中 (244)" ;; 248) echo "亮 (248)" ;; *) echo "自訂 ($SUGGEST_COLOR)" ;;
  esac
}
theme_preview() {   # sample: git commit -m "fix" ~/src
  local r=$'\033[0m'
  case "$1" in
    soft)    printf '%sgit %scommit %s-m %s"fix" %s~/src%s' "$(c256 149)" "$(c256 176)" "$(c256 116)" "$(c256 180)" "$(c256 110)" "$r" ;;
    minimal) printf '%sgit %scommit %s-m %s"fix" %s~/src%s' "$(c256 252)" "$(c256 250)" "$(c256 245)" "$(c256 180)" "$(c256 110)" "$r" ;;
    default) printf '\033[32mgit \033[33mcommit \033[36m-m \033[33m"fix" \033[35;4m~/src%s' "$r" ;;
  esac
}
set_starship_disabled() {   # <file> <section> <true|false>
  local tmp; tmp="$(mktemp)"
  awk -v sec="[$2]" -v val="$3" '
    /^\[/ { insec = ($0 == sec) }
    insec && /^disabled[[:space:]]*=/ { print "disabled = " val; next }
    { print }' "$1" > "$tmp" && mv "$tmp" "$1"
}
now_ms() {
  local t; t="$(date +%s%N 2>/dev/null)"
  if [[ "$t" =~ ^[0-9]+$ ]]; then echo $((t / 1000000)); else perl -MTime::HiRes=time -e 'printf "%d", time*1000'; fi
}

same_file() {   # cmp is missing on minimal Fedora / openSUSE images
  if have cmp; then cmp -s "$1" "$2"; else [[ "$(cat "$1"; echo x)" == "$(cat "$2"; echo x)" ]]; fi
}

# Back up a file/symlink/dir before replacing it (only if it differs from the new one).
backup() {
  local target="$1" new="${2:-}"
  [[ -e "$target" || -L "$target" ]] || return 0
  if [[ -n "$new" && -f "$target" && ! -L "$target" ]] && same_file "$target" "$new"; then
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  cp -RP "$target" "$BACKUP_DIR/$(basename "$target")"
  warn "已備份 $target → $BACKUP_DIR/"
}

find_conda() {
  local r
  for r in "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" "$HOME/mambaforge" \
           /opt/homebrew/Caskroom/miniconda/base /opt/homebrew/Caskroom/miniforge/base \
           /opt/conda /opt/miniconda3 /opt/anaconda3; do
    [[ -x "$r/bin/conda" ]] && { echo "$r"; return 0; }
  done
  return 1
}

font_installed() {
  local f
  for f in "$HOME/Library/Fonts"/HackNerdFontMono-Regular.* /Library/Fonts/HackNerdFontMono-Regular.* \
           "$HOME/.local/share/fonts"/HackNerdFont/HackNerdFontMono-Regular.* \
           "$HOME/.local/share/fonts"/HackNerdFontMono-Regular.* /usr/share/fonts/*/HackNerdFontMono-Regular.*; do
    [[ -e "$f" ]] && return 0
  done
  have fc-list && fc-list 2>/dev/null | grep -qi "Hack Nerd Font Mono" && return 0
  return 1
}

# ---------- Linux package helpers ----------
SUDO=""
PM=""
PM_SYNCED=0
detect_pm() {
  if   have apt-get; then PM=apt
  elif have dnf;     then PM=dnf
  elif have pacman;  then PM=pacman
  elif have zypper;  then PM=zypper
  fi
}
pm_install() {   # quietly try to install one or more packages; non-zero if it failed
  case "$PM" in
    apt)
      if [[ $PM_SYNCED -eq 0 ]]; then $SUDO apt-get update -qq >/dev/null 2>&1 || true; PM_SYNCED=1; fi
      DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq "$@" >/dev/null 2>&1 ;;
    dnf)    $SUDO dnf install -y -q "$@" >/dev/null 2>&1 ;;
    pacman)
      if [[ $PM_SYNCED -eq 0 ]]; then $SUDO pacman -Sy --noconfirm >/dev/null 2>&1 || true; PM_SYNCED=1; fi
      $SUDO pacman -S --noconfirm --needed "$@" >/dev/null 2>&1 ;;
    zypper) $SUDO zypper -n -q install "$@" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}
fzf_ok() { have fzf && fzf --zsh >/dev/null 2>&1; }   # shell integration needs fzf >= 0.48

linux_install_tool() {   # <tool>  — package manager first, official release as fallback
  local t="$1" tmp
  case "$t" in
    starship)
      pm_install starship && have starship && return 0
      curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN" >/dev/null ;;
    fzf)
      fzf_ok && return 0
      pm_install fzf; fzf_ok && return 0
      rm -rf "$HOME/.fzf"
      git clone --quiet --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
      "$HOME/.fzf/install" --bin >/dev/null
      ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"
      hash -r ;;
    zoxide)
      pm_install zoxide && have zoxide && return 0
      curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null 2>&1 ;;
    eza)
      pm_install eza && have eza && return 0
      case "$ARCH" in x86_64|amd64) a=x86_64 ;; aarch64|arm64) a=aarch64 ;; *) return 1 ;; esac
      tmp="$(mktemp -d)"
      curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_${a}-unknown-linux-gnu.tar.gz" | tar -xz -C "$tmp"
      install -m 755 "$tmp/eza" "$LOCAL_BIN/eza"; rm -rf "$tmp" ;;
  esac
}

linux_install_font() {
  local dir="$HOME/.local/share/fonts/HackNerdFont" tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/Hack.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
  mkdir -p "$dir"
  unzip -o -q "$tmp/Hack.zip" 'HackNerdFont*.ttf' -d "$dir"
  rm -rf "$tmp"
  have fc-cache && fc-cache -f "$dir" >/dev/null 2>&1 || true
}

# ---------- 0. sanity ----------
[[ $IS_MAC -eq 1 || $IS_LINUX -eq 1 ]] || die "不支援的系統：${OS}。Windows 請改用 install.ps1（見 README）。"
if [[ $IS_MAC -eq 1 && $EUID -eq 0 ]]; then die "請用一般使用者執行，不要用 root / sudo。"; fi
if [[ $IS_LINUX -eq 1 && $EUID -ne 0 ]] && have sudo; then SUDO="sudo"; fi

# ---------- 1. previous choices ----------
# zsh and fish each keep their own copy; the most recently written one wins.
PREV_OPTIONS=""
[[ -r "$OPTIONS_FILE" ]] && PREV_OPTIONS="$OPTIONS_FILE"
if [[ -r "$FISH_OPTIONS" ]] && { [[ -z "$PREV_OPTIONS" ]] || [[ "$FISH_OPTIONS" -nt "$PREV_OPTIONS" ]]; }; then
  PREV_OPTIONS="$FISH_OPTIONS"
fi
if [[ -n "$PREV_OPTIONS" ]]; then
  MZS_PLUGINS=(); MZS_SHELLS=()
  if [[ "$PREV_OPTIONS" == "$FISH_OPTIONS" ]]; then
    # `set -g NAME a b c` → NAME=(a b c); only plain words get through
    eval "$(sed -n 's/^set -g \(MZS_[A-Z_]*\) \([A-Za-z0-9 _-]*\)$/\1=(\2)/p' "$PREV_OPTIONS")" 2>/dev/null || true
  else
    # shellcheck disable=SC1090
    source "$PREV_OPTIONS" 2>/dev/null || true
  fi
  # installs from before fish support have no MZS_SHELLS: they were zsh
  if [[ ${#MZS_SHELLS[@]} -gt 0 ]]; then set_shells "${MZS_SHELLS[*]}" || SHELLS=zsh; else SHELLS=zsh; fi
  SEL=""
  for p in "${MZS_PLUGINS[@]:-}"; do is_optional "$p" && SEL="$SEL $p"; done
  # options added after the last install start from their default
  offered=" ${MZS_OFFERED[*]:-fzf-tab history-substring-search you-should-use zoxide fzf eza} "
  for p in $DEFAULT_SEL; do
    case "$offered" in *" $p "*) ;; *) has "$p" || SEL="$SEL $p" ;; esac
  done
  SUGGEST_COLOR="${MZS_SUGGEST_COLOR:-$SUGGEST_COLOR}"
  THEME="${MZS_THEME:-$THEME}"
  CONDA_MODE="${MZS_CONDA:-$CONDA_MODE}"
  PROMPT_TIME="${MZS_PROMPT_TIME:-$PROMPT_TIME}"
  PROMPT_IP="${MZS_PROMPT_IP:-$PROMPT_IP}"
  [[ $IS_MAC -eq 1 ]] && TERMINAL_APP="${MZS_TERMINAL_APP:-$TERMINAL_APP}"
fi

# ---------- 2. flags ----------
for arg in "$@"; do
  case "$arg" in
    -y|--yes)          ASSUME_YES=1 ;;
    --shell=*|--shells=*)
      set_shells "${arg#*=}" || die "--shell 只能是 zsh / fish / both" ;;
    --plugins=*)
      v="${arg#*=}"; SEL=""
      case "$v" in
        none) ;;
        all)  SEL="$OPTIONAL" ;;
        *)    for p in $(echo "$v" | tr ',' ' '); do
                is_optional "$p" || die "未知的外掛：${p}（可用：${OPTIONAL}）"; SEL="$SEL $p"
              done ;;
      esac ;;
    --suggest-color=*)
      v="${arg#*=}"
      case "$v" in
        dim) SUGGEST_COLOR=240 ;; medium) SUGGEST_COLOR=244 ;; bright) SUGGEST_COLOR=248 ;;
        *) [[ "$v" =~ ^[0-9]+$ && "$v" -le 255 ]] || die "--suggest-color 要是 dim/medium/bright 或 0-255"; SUGGEST_COLOR="$v" ;;
      esac ;;
    --theme=*)
      THEME="${arg#*=}"
      case "$THEME" in soft|minimal|default) ;; *) die "--theme 只能是 soft / minimal / default" ;; esac ;;
    --conda=*)
      CONDA_MODE="${arg#*=}"
      case "$CONDA_MODE" in fast|lazy|full|off) ;; *) die "--conda 只能是 fast / lazy / full / off" ;; esac ;;
    --time=on)  PROMPT_TIME=1 ;;  --time=off) PROMPT_TIME=0 ;;
    --ip=on)    PROMPT_IP=1 ;;    --ip=off)   PROMPT_IP=0 ;;
    --font=on)  INSTALL_FONT=1 ;; --font=off|--no-font) INSTALL_FONT=0 ;;
    --terminal-app=on)  TERMINAL_APP=$IS_MAC ;;  --terminal-app=off) TERMINAL_APP=0 ;;
    --skip-packages|--skip-brew) SKIP_PKGS=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "未知的參數：${arg}（用 --help 查看說明）" ;;
  esac
done

if [[ $IS_MAC -eq 1 ]]; then PLATFORM="macOS $(sw_vers -productVersion 2>/dev/null)"
else
  PLATFORM="$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}" || echo Linux)"
  [[ $IS_WSL -eq 1 ]] && PLATFORM="$PLATFORM (WSL)"
fi
printf '\n%s%s cli-setup %s %szsh / fish · Starship · Hack Nerd Font — %s%s\n' \
  "$C_BOLD" "$C_BLUE" "$C_RESET" "$C_DIM" "$PLATFORM" "$C_RESET"

# ---------- 3. interactive menu ----------
CONDA_ROOT="$(find_conda || true)"

show_menu() {
  local i=1 p mark star
  printf '\n  %sShell%s\n' "$C_BOLD" "$C_RESET"
  printf '   s 要設定的 shell  %-12s %s按 s 切換：zsh → fish → zsh + fish%s\n' "$(shells_label)" "$C_DIM" "$C_RESET"
  printf '\n  %s外掛 / 工具%s\n' "$C_BOLD" "$C_RESET"
  for p in $OPTIONAL; do
    if has "$p"; then mark="${C_GREEN}[x]${C_RESET}"; else mark="${C_DIM}[ ]${C_RESET}"; fi
    case "$p" in fzf-tab|history-substring-search|zoxide|fzf|aliases) star="${C_YELLOW}★${C_RESET}" ;; *) star=" " ;; esac
    printf '  %2d %s %s %-26s %s%s%s\n' "$i" "$mark" "$star" "$p" "$C_DIM" "$(describe "$p")" "$C_RESET"
    i=$((i+1))
  done
  printf '\n  %s外觀%s\n' "$C_BOLD" "$C_RESET"
  printf '  %2d 建議文字顏色    %-12s 預覽：%sgit sta%s%stus --short%s\n' 8 "$(suggest_label)" "$(c256 252)" "$C_RESET" "$(c256 "$SUGGEST_COLOR")" "$C_RESET"
  printf '  %2d 語法高亮主題    %-12s 預覽：%s\n' 9 "$THEME" "$(theme_preview "$THEME")"
  printf '  %2d Prompt 時間     %s\n' 10 "$(onoff "$PROMPT_TIME")"
  printf '  %2d Prompt IP       %s\n' 11 "$(onoff "$PROMPT_IP")"
  printf '\n  %s其他%s\n' "$C_BOLD" "$C_RESET"
  if [[ -n "$CONDA_ROOT" ]]; then
    local cdesc
    case "$CONDA_MODE" in
      fast) cdesc="快取 hook，瞬間啟用 base（推薦）" ;;
      lazy) cdesc="第一次打 conda 才載入，最快但 base 不會自動啟用" ;;
      full) cdesc="官方 conda init 行為（最慢）" ;;
      off)  cdesc="不載入 conda" ;;
    esac
    printf '  %2d Conda 載入方式  %-12s %s%s%s\n' 12 "$CONDA_MODE" "$C_DIM" "$cdesc" "$C_RESET"
  else
    printf '  %s%2d Conda 載入方式  （沒有偵測到 conda）%s\n' "$C_DIM" 12 "$C_RESET"
  fi
  if [[ $SKIP_PKGS -eq 1 ]]; then
    printf '  %s%2d 安裝 Hack Nerd Font （--skip-packages，略過）%s\n' "$C_DIM" 13 "$C_RESET"
  else
    local fnote=""
    [[ $IS_WSL -eq 1 ]] && fnote="WSL：字型要裝在 Windows 端（執行 install.ps1）"
    [[ $IS_LINUX -eq 1 && $IS_WSL -eq 0 && -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && fnote="沒有桌面環境：字型要裝在你打字的那台電腦"
    printf '  %2d 安裝 Hack Nerd Font  %s  %s%s%s\n' 13 "$(onoff "$INSTALL_FONT")" "$C_DIM" "$fnote" "$C_RESET"
  fi
  if [[ $IS_MAC -eq 1 ]]; then
    printf '  %2d 設定 Terminal.app  %s  %sHome/End 鍵送給 shell、字型換成 Hack Nerd Font Mono%s\n' \
      14 "$(onoff "$TERMINAL_APP")" "$C_DIM" "$C_RESET"
  fi
  printf '\n  %s★ 推薦%s  輸入編號切換（可一次多個，例如 %s1 8 9%s），直接 Enter 開始安裝，q 離開\n' \
    "$C_YELLOW" "$C_RESET" "$C_BOLD" "$C_RESET"
}

if [[ $ASSUME_YES -eq 0 ]] && { : </dev/tty; } 2>/dev/null; then
  opt_arr=($OPTIONAL)
  while true; do
    show_menu
    printf '  > '
    read -r answer </dev/tty || { echo; echo "  已取消。"; exit 0; }
    [[ -z "$answer" ]] && break
    for n in $answer; do
      case "$n" in
        q|Q) echo "  已取消。"; exit 0 ;;
        s|S) case "$SHELLS" in zsh) SHELLS=fish ;; fish) SHELLS="zsh fish" ;; *) SHELLS=zsh ;; esac ;;
        [1-7]) toggle "${opt_arr[$((n-1))]}" ;;
        8)  case "$SUGGEST_COLOR" in 240) SUGGEST_COLOR=244 ;; 244) SUGGEST_COLOR=248 ;; *) SUGGEST_COLOR=240 ;; esac ;;
        9)  case "$THEME" in soft) THEME=minimal ;; minimal) THEME=default ;; *) THEME=soft ;; esac ;;
        10) PROMPT_TIME=$((1-PROMPT_TIME)) ;;
        11) PROMPT_IP=$((1-PROMPT_IP)) ;;
        12) [[ -n "$CONDA_ROOT" ]] && case "$CONDA_MODE" in fast) CONDA_MODE=lazy ;; lazy) CONDA_MODE=full ;; full) CONDA_MODE=off ;; *) CONDA_MODE=fast ;; esac ;;
        13) [[ $SKIP_PKGS -eq 0 ]] && INSTALL_FONT=$((1-INSTALL_FONT)) ;;
        14) [[ $IS_MAC -eq 1 ]] && TERMINAL_APP=$((1-TERMINAL_APP)) ;;
        *)  warn "沒有這個選項：$n" ;;
      esac
    done
    printf '\033[2m  ────────────────────────────────────────────%s\n' "$C_RESET"
  done
fi

# normalise selection order
_sel=""; for p in $OPTIONAL; do has "$p" && _sel="$_sel $p"; done; SEL="${_sel# }"

tools=""
for p in $SEL; do
  d="$(tool_dep "$p")"
  [[ -n "$d" ]] && case " $tools " in *" $d "*) ;; *) tools="$tools $d" ;; esac
done
tools="${tools# }"

mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"

# ---------- 4a. packages: macOS (Homebrew) ----------
load_brew_env() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x "$b" ]] && { eval "$("$b" shellenv)"; return 0; }
  done
  return 0
}

if [[ $SKIP_PKGS -eq 0 && $IS_MAC -eq 1 ]]; then
  step "Homebrew"
  load_brew_env
  if ! have brew; then
    warn "沒有找到 Homebrew，開始安裝（可能會要求輸入密碼）"
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew_env
    have brew || die "Homebrew 安裝失敗。"
  fi
  ok "brew $(brew --version | head -1 | awk '{print $2}')"

  pkgs="starship${tools:+ $tools}"; have git || pkgs="git $pkgs"
  if use_shell fish; then pkgs="fish $pkgs"; fi
  step "套件：$pkgs"
  missing=""
  for pkg in $pkgs; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then ok "${pkg}（已安裝）"
    elif have "$pkg"; then ok "${pkg}（已存在：$(command -v "$pkg")）"
    else missing="$missing $pkg"; fi
  done
  if [[ -n "$missing" ]]; then
    # shellcheck disable=SC2086
    HOMEBREW_NO_AUTO_UPDATE=1 brew install $missing && ok "已安裝：$missing"
  fi

  if [[ $INSTALL_FONT -eq 1 ]]; then
    step "字型：Hack Nerd Font（含 Hack Nerd Font Mono）"
    if brew list --cask font-hack-nerd-font >/dev/null 2>&1; then
      ok "font-hack-nerd-font（已安裝）"
    elif font_installed; then
      ok "Hack Nerd Font Mono（已存在）"
    else
      HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask font-hack-nerd-font && ok "font-hack-nerd-font"
    fi
  fi
fi

# ---------- 4b. packages: Linux ----------
if [[ $SKIP_PKGS -eq 0 && $IS_LINUX -eq 1 ]]; then
  detect_pm
  step "套件管理器：${PM:-（沒有偵測到）}"
  base="$SHELLS git curl"
  manual="請先手動安裝 ${base// /、}，再用 --skip-packages 執行"
  [[ -n "$PM" ]] || die "沒有偵測到 apt / dnf / pacman / zypper。${manual}。"
  if [[ -n "$SUDO" ]]; then
    sudo -v || die "需要 sudo 權限來安裝套件（或${manual#請}）。"
  elif [[ $EUID -ne 0 ]]; then
    die "沒有 sudo，無法安裝套件。${manual}。"
  fi
  base_label="$base"
  [[ $INSTALL_FONT -eq 1 ]] && base="$base unzip fontconfig"
  [[ "$PM" == apt ]] && base="$base ca-certificates"
  need=""
  for pkg in $base; do
    case "$pkg" in
      fontconfig)      have fc-cache || need="$need $pkg" ;;
      ca-certificates) [[ -e /etc/ssl/certs/ca-certificates.crt ]] || need="$need $pkg" ;;
      *)               have "$pkg" || need="$need $pkg" ;;
    esac
  done
  if [[ -n "$need" ]]; then
    # shellcheck disable=SC2086
    pm_install $need || die "安裝基本套件失敗：$need"
  fi
  ok "$base_label"

  step "工具：starship${tools:+ $tools}"
  for t in starship $tools; do
    if [[ "$t" == fzf ]] && fzf_ok; then ok "fzf（已安裝）"; continue; fi
    if [[ "$t" != fzf ]] && have "$t"; then ok "${t}（已安裝）"; continue; fi
    if linux_install_tool "$t" && have "$t"; then ok "${t}（$(command -v "$t")）"
    else warn "$t 安裝失敗，啟動時會自動略過"; fi
  done

  if [[ $INSTALL_FONT -eq 1 ]]; then
    step "字型：Hack Nerd Font（含 Hack Nerd Font Mono）"
    if font_installed; then ok "Hack Nerd Font Mono（已存在）"
    elif linux_install_font; then ok "已安裝到 ~/.local/share/fonts/HackNerdFont"
    else warn "字型下載失敗，可以之後再重跑一次"; fi
  fi
fi

for s in $SHELLS; do have "$s" || die "需要 $s。"; done
if use_shell fish; then
  fish_ver="$(fish --version 2>/dev/null | sed 's/.*version //')"
  case "$fish_ver" in
    [12].*|3.[0-3]|3.[0-3].*)
      warn "fish $fish_ver 比較舊：新版 fzf 的 fish 整合需要 3.4 以上，Ctrl-R / Ctrl-T / Alt-C 可能無法使用（其他功能不受影響）"
      [[ "${PM:-}" == apt ]] && warn "Ubuntu 可以用官方 PPA 升級：sudo add-apt-repository ppa:fish-shell/release-4 && sudo apt install fish" ;;
  esac
fi
have git     || die "需要 git。"
have starship || die "需要 starship。"
for t in $tools; do have "$t" || warn "$t 找不到，相關功能啟動時會自動略過"; done

# ---------- 5. config source ----------
step "設定檔來源"
SRC_DIR=""
script_path="${BASH_SOURCE[0]:-}"
if [[ -n "$script_path" && -f "$script_path" ]]; then
  candidate="$(cd "$(dirname "$script_path")" && pwd)"
  [[ -f "$candidate/config/zshrc" ]] && SRC_DIR="$candidate"
fi
if [[ -z "$SRC_DIR" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --quiet --depth 1 "$REPO_URL" "$TMP_DIR/repo"
  SRC_DIR="$TMP_DIR/repo"
fi
ok "$SRC_DIR"

# ---------- 6. zsh plugins ----------
if use_shell zsh; then
  step "zsh 外掛 → $PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
  for p in $CORE_PLUGINS $SEL; do
    entry="$(plugin_dir "$p")"
    [[ -n "$entry" ]] || continue
    name="${entry%%|*}"; url="${entry#*|}"; dest="$PLUGIN_DIR/$name"
    if [[ -d "$dest/.git" ]]; then
      if git -C "$dest" pull --quiet --ff-only 2>/dev/null; then ok "${name}（已更新）"
      else warn "$name 已存在但無法更新，維持原樣"; fi
    else
      [[ -e "$dest" ]] && { backup "$dest"; rm -rf "$dest"; }
      git clone --quiet --depth 1 "$url" "$dest" && ok "$name"
    fi
  done
fi

# ---------- 7. configs ----------
step "寫入設定"
mkdir -p "$(dirname "$STARSHIP_TOML")"

if use_shell zsh; then
  mkdir -p "$ZSH_DIR/themes" "$ZSH_CACHE"

  backup "$ZSH_DIR/.zshrc" "$SRC_DIR/config/zshrc"
  cp "$SRC_DIR/config/zshrc" "$ZSH_DIR/.zshrc"
  ok "$ZSH_DIR/.zshrc"

  if [[ "$(readlink "$HOME/.zshrc" 2>/dev/null)" != "$ZSH_DIR/.zshrc" ]]; then
    backup "$HOME/.zshrc"
    rm -f "$HOME/.zshrc"
    ln -s "$ZSH_DIR/.zshrc" "$HOME/.zshrc"
  fi
  ok "~/.zshrc → $ZSH_DIR/.zshrc"

  # Debian / Ubuntu run compinit from /etc/zsh/zshrc as well — skip it, ours is cached.
  if [[ -f /etc/zsh/zshrc ]] && grep -q skip_global_compinit /etc/zsh/zshrc 2>/dev/null; then
    if ! grep -q 'skip_global_compinit=1' "$HOME/.zshenv" 2>/dev/null; then
      printf '\n# cli-setup: ~/.zshrc runs a cached compinit\nskip_global_compinit=1\n' >> "$HOME/.zshenv"
      ok "~/.zshenv：skip_global_compinit=1"
    fi
  fi

  # history lives in ~/.zsh/.zsh_history — bring the old ~/.zsh_history along the first time
  if [[ -s "$HOME/.zsh_history" && ! -s "$ZSH_DIR/.zsh_history" ]]; then
    cp -p "$HOME/.zsh_history" "$ZSH_DIR/.zsh_history"
    ok "歷史紀錄：已從 ~/.zsh_history 複製 $(wc -l < "$ZSH_DIR/.zsh_history" | tr -d ' ') 行"
  fi

  cp "$SRC_DIR"/config/themes/*.zsh "$ZSH_DIR/themes/"
  cp "$SRC_DIR/config/aliases.zsh" "$ZSH_DIR/aliases.zsh"
  if has aliases; then ok "常用 alias：$ZSH_DIR/aliases.zsh"; fi
fi

if use_shell fish; then
  # fish loads conf.d/*.fish before config.fish, so the user's own config.fish stays untouched.
  mkdir -p "$FISH_DIR/conf.d" "$FISH_SUPPORT/themes" "$FISH_CACHE"

  backup "$FISH_DIR/conf.d/cli-setup.fish" "$SRC_DIR/config/fish/cli-setup.fish"
  cp "$SRC_DIR/config/fish/cli-setup.fish" "$FISH_DIR/conf.d/cli-setup.fish"
  ok "$FISH_DIR/conf.d/cli-setup.fish"

  cp "$SRC_DIR"/config/fish/themes/*.fish "$FISH_SUPPORT/themes/"
  cp "$SRC_DIR/config/fish/aliases.fish" "$FISH_SUPPORT/aliases.fish"
  if has aliases; then ok "常用 alias：$FISH_SUPPORT/aliases.fish"; fi

  # things cli-setup now does itself — a second copy in config.fish would run twice
  if [[ -f "$FISH_DIR/config.fish" ]]; then
    dup=""
    for pat in 'conda initialize' 'starship init' 'zoxide init' 'fzf --fish'; do
      grep -q -- "$pat" "$FISH_DIR/config.fish" 2>/dev/null && dup="$dup「$pat」"
    done
    [[ -n "$dup" ]] && warn "$FISH_DIR/config.fish 裡還有 ${dup}，cli-setup 已經會處理，建議刪掉以免重複載入"
  fi
fi
ok "語法高亮主題：$THEME"

tmp_toml="$(mktemp)"
cp "$SRC_DIR/config/starship.toml" "$tmp_toml"
[[ $PROMPT_TIME -eq 1 ]] && set_starship_disabled "$tmp_toml" time false    || set_starship_disabled "$tmp_toml" time true
[[ $PROMPT_IP   -eq 1 ]] && set_starship_disabled "$tmp_toml" localip false || set_starship_disabled "$tmp_toml" localip true
backup "$STARSHIP_TOML" "$tmp_toml"
cp "$tmp_toml" "$STARSHIP_TOML"; rm -f "$tmp_toml"
ok "${STARSHIP_TOML}（時間：$(onoff "$PROMPT_TIME")，IP：$(onoff "$PROMPT_IP")）"

if use_shell zsh; then
  cat > "$OPTIONS_FILE" <<EOF
# Generated by cli-setup — re-run install.sh to change these.
MZS_SHELLS=($SHELLS)
MZS_PLUGINS=($CORE_PLUGINS $SEL)
MZS_SUGGEST_COLOR=$SUGGEST_COLOR
MZS_THEME=$THEME
MZS_CONDA=$CONDA_MODE
MZS_PROMPT_TIME=$PROMPT_TIME
MZS_PROMPT_IP=$PROMPT_IP
MZS_TERMINAL_APP=$TERMINAL_APP
MZS_OFFERED=($OPTIONAL)
EOF
  ok "$OPTIONS_FILE"
fi
if use_shell fish; then
  cat > "$FISH_OPTIONS" <<EOF
# Generated by cli-setup — re-run install.sh to change these.
set -g MZS_SHELLS $SHELLS
set -g MZS_PLUGINS $CORE_PLUGINS $SEL
set -g MZS_SUGGEST_COLOR $SUGGEST_COLOR
set -g MZS_SUGGEST_HEX $(c256_hex "$SUGGEST_COLOR")
set -g MZS_THEME $THEME
set -g MZS_CONDA $CONDA_MODE
set -g MZS_PROMPT_TIME $PROMPT_TIME
set -g MZS_PROMPT_IP $PROMPT_IP
set -g MZS_TERMINAL_APP $TERMINAL_APP
set -g MZS_OFFERED $OPTIONAL
EOF
  ok "$FISH_OPTIONS"
fi

if [[ -n "$CONDA_ROOT" && "$CONDA_MODE" != off ]]; then
  "$CONDA_ROOT/bin/conda" config --set changeps1 False >/dev/null 2>&1 && ok "conda：changeps1 = False（載入方式：${CONDA_MODE}）"
fi

# ---------- Terminal.app profile (macOS) ----------
TERMINAL_DONE=0
if [[ $IS_MAC -eq 1 && $TERMINAL_APP -eq 1 ]]; then
  step "Terminal.app"
  if defaults read com.apple.Terminal "Window Settings" >/dev/null 2>&1; then
    font="-"; font_installed && font="HackNFM-Regular"
    mkdir -p "$BACKUP_DIR"
    defaults export com.apple.Terminal "$BACKUP_DIR/com.apple.Terminal.plist"
    if result="$(osascript -l JavaScript "$SRC_DIR/config/terminal-app.js" "$font" 2>&1)"; then
      while IFS= read -r line; do ok "$line"; done <<< "$result"
      [[ "$font" == "-" ]] && warn "找不到 Hack Nerd Font Mono，只設定了 Home/End"
      warn "已備份原本的 Terminal 設定 → $BACKUP_DIR/com.apple.Terminal.plist"
      TERMINAL_DONE=1
    else
      warn "Terminal.app 設定失敗：$result"
    fi
  else
    warn "Terminal.app 還沒有任何設定（先開過一次 Terminal 再重跑），略過"
  fi
fi

# drop cached init scripts so they're regenerated with the new setup
if use_shell zsh;  then rm -f "$ZSH_CACHE"/*.zsh "$ZSH_CACHE"/zcompdump*; fi
if use_shell fish; then rm -f "$FISH_CACHE"/*.fish; fi

# ---------- 8. default shell ----------
# Keep the login shell if it is one we just set up; otherwise switch to the first one chosen.
CUR_SHELL="${SHELL:-}"; CUR_SHELL="${CUR_SHELL##*/}"
NEW_SHELL=""
use_shell "$CUR_SHELL" || NEW_SHELL="${SHELLS%% *}"
SHELL_CHANGED=0
if [[ -n "$NEW_SHELL" ]]; then
  step "預設 shell"
  NEW_BIN="$(command -v "$NEW_SHELL")"
  ME="$(id -un)"
  if [[ $IS_LINUX -eq 1 ]]; then
    grep -qx "$NEW_BIN" /etc/shells 2>/dev/null || echo "$NEW_BIN" | $SUDO tee -a /etc/shells >/dev/null || true
    if $SUDO chsh -s "$NEW_BIN" "$ME" >/dev/null 2>&1 || { have usermod && $SUDO usermod -s "$NEW_BIN" "$ME" >/dev/null 2>&1; }; then
      ok "預設 shell 已改成 $NEW_BIN（重新登入後生效）"; SHELL_CHANGED=1
    else
      warn "請手動執行：chsh -s $NEW_BIN"
    fi
  else
    # Homebrew's fish is not in /etc/shells, and chsh refuses shells that are not listed there
    if ! grep -qx "$NEW_BIN" /etc/shells 2>/dev/null; then
      warn "把 $NEW_BIN 加進 /etc/shells（可能會要求輸入密碼）"
      echo "$NEW_BIN" | sudo tee -a /etc/shells >/dev/null || true
    fi
    if chsh -s "$NEW_BIN"; then ok "預設 shell 已改成 $NEW_BIN"; SHELL_CHANGED=1
    else warn "請手動執行：chsh -s $NEW_BIN"; fi
  fi
fi

# ---------- 9. warm cache & measure ----------
step "建立快取並測量啟動時間"
for s in $SHELLS; do
  "$s" -i -c exit >/dev/null 2>&1 </dev/null || true
  best=999999
  for _ in 1 2 3; do
    t0=$(now_ms); "$s" -i -c exit >/dev/null 2>&1 </dev/null || true; t1=$(now_ms)
    (( t1 - t0 < best )) && best=$((t1 - t0))
  done
  ok "$s 啟動時間：約 ${best} ms"
done

# ---------- done ----------
printf '\n%s✔ 完成！%s\n\n' "$C_GREEN" "$C_RESET"
printf '  Shell：%s\n' "$(shells_label)"
printf '  已啟用外掛：%s\n' "$CORE_PLUGINS${SEL:+ $SEL}"
if use_shell fish; then
  printf '  %sfish：自動建議、語法高亮、補完、↑/↓ 搜尋歷史都是內建功能，不需要另外裝外掛%s\n' "$C_DIM" "$C_RESET"
fi
echo
echo "  接下來："
if [[ $TERMINAL_DONE -eq 1 ]]; then
  printf '    1. %s完全結束 Terminal.app（⌘Q）再重新打開%s，Home/End 和字型才會生效\n' "$C_YELLOW" "$C_RESET"
  printf '       %s用 iTerm2 / VS Code 的話，字型請手動改成 Hack Nerd Font Mono%s\n' "$C_DIM" "$C_RESET"
else
  printf '    1. 把終端機字型改成 %sHack Nerd Font Mono%s\n' "$C_YELLOW" "$C_RESET"
  if [[ $IS_WSL -eq 1 ]]; then
    printf '       %sWSL：字型要裝在 Windows 端 — 在 PowerShell 執行 install.ps1，或手動安裝後在 Windows Terminal 選用%s\n' "$C_DIM" "$C_RESET"
  elif [[ $IS_LINUX -eq 1 ]]; then
    printf '       %sGNOME Terminal / Konsole / VS Code 等：在設定裡把字型改成 Hack Nerd Font Mono\n' "$C_DIM"
    printf '       透過 SSH 連線時，字型要裝在你打字的那台電腦%s\n' "$C_RESET"
  else
    printf '       %sTerminal.app → 設定 → 描述檔 → 文字 → 字體（或用 --terminal-app=on 自動設定）\n' "$C_DIM"
    printf '       iTerm2 → Settings → Profiles → Text → Font · VS Code → terminal.integrated.fontFamily%s\n' "$C_RESET"
  fi
fi
if [[ -z "$NEW_SHELL" ]]; then
  printf '    2. 重開終端機，或執行：%sexec %s%s\n' "$C_YELLOW" "$CUR_SHELL" "$C_RESET"
elif [[ $SHELL_CHANGED -eq 1 ]]; then
  printf '    2. 重新登入（預設 shell 已改成 %s），或現在先執行：%s%s%s\n' "$NEW_SHELL" "$C_YELLOW" "$NEW_SHELL" "$C_RESET"
else
  printf '    2. 執行：%s%s%s（預設 shell 沒有改成功，見上面的訊息）\n' "$C_YELLOW" "$NEW_SHELL" "$C_RESET"
fi
for s in $SHELLS; do
  if [[ "$s" != "$CUR_SHELL" && "$s" != "$NEW_SHELL" ]]; then
    printf '       %s%s 也設定好了：直接執行 %s 就能用；要當成預設 shell：chsh -s %s%s\n' "$C_DIM" "$s" "$s" "$(command -v "$s")" "$C_RESET"
  fi
done
echo "    之後想改選項，重新執行安裝指令即可（會記住這次的選擇）"
if [[ -d "$BACKUP_DIR" ]]; then printf '\n  %s舊檔案已備份到 %s%s\n' "$C_DIM" "$BACKUP_DIR" "$C_RESET"; fi
echo
