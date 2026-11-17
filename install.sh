#!/usr/bin/env bash
#
# mac-zsh-setup — Homebrew + zsh 外掛 + Starship + Hack Nerd Font，一行搞定。
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/mac-zsh-setup/main/install.sh)"
#
# 直接執行會出現互動選單；也可以用參數指定（搭配 -y 完全不詢問）：
#   -y, --yes                 不顯示選單，使用預設值（或上次安裝時的選擇）
#   --plugins=a,b,c           選用外掛：fzf-tab, history-substring-search, you-should-use,
#                             zoxide, fzf, eza, aliases（none = 都不要；all = 全部）
#   --suggest-color=VALUE     自動建議文字顏色：dim | medium | bright | 0-255
#   --theme=NAME              語法高亮主題：soft | minimal | default
#   --time=on|off             Prompt 右側顯示時間
#   --ip=on|off               Prompt 右側顯示本機 IP
#   --conda=MODE              conda 載入方式：fast | lazy | full | off
#   --terminal-app=on|off     設定 Terminal.app：Home/End 鍵 + Hack Nerd Font Mono 字型
#   --no-font                 不安裝 Hack Nerd Font
#   --skip-brew               不使用 Homebrew（需已安裝 git 與 starship）
#   -h, --help                顯示說明
#
# bash 3.2 compatible (macOS /bin/bash).
set -euo pipefail

REPO_URL="https://github.com/NatLee/mac-zsh-setup.git"
ZSH_DIR="$HOME/.zsh"
PLUGIN_DIR="$ZSH_DIR/plugins"
OPTIONS_FILE="$ZSH_DIR/options.zsh"
STARSHIP_TOML="$HOME/.config/starship.toml"
ZSH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
BACKUP_DIR="$HOME/.mac-zsh-setup-backup/$(date +%Y%m%d-%H%M%S)"

CORE_PLUGINS="autosuggestions syntax-highlighting completions"
OPTIONAL="fzf-tab history-substring-search you-should-use zoxide fzf eza aliases"

# ---------- defaults (overridden by a previous install, then by flags / menu) ----------
SEL="fzf-tab history-substring-search zoxide fzf aliases"
DEFAULT_SEL="$SEL"
SUGGEST_COLOR=244
THEME=soft
CONDA_MODE=fast
PROMPT_TIME=1
PROMPT_IP=1
INSTALL_FONT=1
TERMINAL_APP=1
SKIP_BREW=0
ASSUME_YES=0

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
usage() { sed -n '3,21p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; }

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
brew_dep() {
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
    you-should-use)           echo "打了完整指令時，提醒你有對應的 alias" ;;
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

# Back up a file/symlink/dir before replacing it (only if it differs from the new one).
backup() {
  local target="$1" new="${2:-}"
  [[ -e "$target" || -L "$target" ]] || return 0
  if [[ -n "$new" && -f "$target" && ! -L "$target" ]] && cmp -s "$target" "$new"; then
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  cp -RP "$target" "$BACKUP_DIR/$(basename "$target")"
  warn "已備份 $target → $BACKUP_DIR/"
}

load_brew_env() {
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
}

find_conda() {
  local r
  for r in "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" \
           /opt/homebrew/Caskroom/miniconda/base /opt/homebrew/Caskroom/miniforge/base; do
    [[ -x "$r/bin/conda" ]] && { echo "$r"; return 0; }
  done
  return 1
}

# ---------- 0. sanity ----------
[[ "$(uname -s)" == "Darwin" ]] || die "這個腳本只支援 macOS。"
[[ $EUID -ne 0 ]] || die "請用一般使用者執行，不要用 root / sudo。"

# ---------- 1. previous choices ----------
if [[ -r "$OPTIONS_FILE" ]]; then
  # shellcheck disable=SC1090
  MZS_PLUGINS=(); source "$OPTIONS_FILE" 2>/dev/null || true
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
  TERMINAL_APP="${MZS_TERMINAL_APP:-$TERMINAL_APP}"
fi

# ---------- 2. flags ----------
for arg in "$@"; do
  case "$arg" in
    -y|--yes)          ASSUME_YES=1 ;;
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
    --terminal-app=on)  TERMINAL_APP=1 ;;  --terminal-app=off) TERMINAL_APP=0 ;;
    --no-font)   INSTALL_FONT=0 ;;
    --skip-brew) SKIP_BREW=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "未知的參數：${arg}（用 --help 查看說明）" ;;
  esac
done

printf '\n%s%s mac-zsh-setup %s %sHomebrew · zsh 外掛 · Starship · Hack Nerd Font%s\n' \
  "$C_BOLD" "$C_BLUE" "$C_RESET" "$C_DIM" "$C_RESET"

# ---------- 3. interactive menu ----------
CONDA_ROOT="$(find_conda || true)"

show_menu() {
  local i=1 p mark star
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
  if [[ $SKIP_BREW -eq 1 ]]; then
    printf '  %s%2d 安裝 Hack Nerd Font （--skip-brew，略過）%s\n' "$C_DIM" 13 "$C_RESET"
  else
    printf '  %2d 安裝 Hack Nerd Font  %s\n' 13 "$(onoff "$INSTALL_FONT")"
  fi
  printf '  %2d 設定 Terminal.app  %s  %sHome/End 鍵送給 shell、字型換成 Hack Nerd Font Mono%s\n' \
    14 "$(onoff "$TERMINAL_APP")" "$C_DIM" "$C_RESET"
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
        [1-7]) toggle "${opt_arr[$((n-1))]}" ;;
        8)  case "$SUGGEST_COLOR" in 240) SUGGEST_COLOR=244 ;; 244) SUGGEST_COLOR=248 ;; *) SUGGEST_COLOR=240 ;; esac ;;
        9)  case "$THEME" in soft) THEME=minimal ;; minimal) THEME=default ;; *) THEME=soft ;; esac ;;
        10) PROMPT_TIME=$((1-PROMPT_TIME)) ;;
        11) PROMPT_IP=$((1-PROMPT_IP)) ;;
        12) [[ -n "$CONDA_ROOT" ]] && case "$CONDA_MODE" in fast) CONDA_MODE=lazy ;; lazy) CONDA_MODE=full ;; full) CONDA_MODE=off ;; *) CONDA_MODE=fast ;; esac ;;
        13) [[ $SKIP_BREW -eq 0 ]] && INSTALL_FONT=$((1-INSTALL_FONT)) ;;
        14) TERMINAL_APP=$((1-TERMINAL_APP)) ;;
        *)  warn "沒有這個選項：$n" ;;
      esac
    done
    printf '\033[2m  ────────────────────────────────────────────%s\n' "$C_RESET"
  done
fi

# normalise selection order
_sel=""; for p in $OPTIONAL; do has "$p" && _sel="$_sel $p"; done; SEL="${_sel# }"

# ---------- 4. Homebrew & packages ----------
if [[ $SKIP_BREW -eq 0 ]]; then
  step "Homebrew"
  load_brew_env
  if ! command -v brew >/dev/null 2>&1; then
    warn "沒有找到 Homebrew，開始安裝（可能會要求輸入密碼）"
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew_env
    command -v brew >/dev/null 2>&1 || die "Homebrew 安裝失敗。"
  fi
  ok "brew $(brew --version | head -1 | awk '{print $2}')"

  pkgs="starship"; command -v git >/dev/null 2>&1 || pkgs="git $pkgs"
  for p in $SEL; do
    d="$(brew_dep "$p")"
    [[ -n "$d" ]] && case " $pkgs " in *" $d "*) ;; *) pkgs="$pkgs $d" ;; esac
  done
  step "套件：$pkgs"
  missing=""
  for pkg in $pkgs; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then ok "${pkg}（已安裝）"; else missing="$missing $pkg"; fi
  done
  if [[ -n "$missing" ]]; then
    # shellcheck disable=SC2086
    HOMEBREW_NO_AUTO_UPDATE=1 brew install $missing && ok "已安裝：$missing"
  fi

  if [[ $INSTALL_FONT -eq 1 ]]; then
    step "字型：Hack Nerd Font（含 Hack Nerd Font Mono）"
    if brew list --cask font-hack-nerd-font >/dev/null 2>&1; then
      ok "font-hack-nerd-font（已安裝）"
    else
      HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask font-hack-nerd-font && ok "font-hack-nerd-font"
    fi
  fi
fi

command -v git >/dev/null 2>&1      || die "需要 git。"
command -v starship >/dev/null 2>&1 || die "需要 starship。"
for p in $SEL; do
  d="$(brew_dep "$p")"
  [[ -z "$d" ]] || command -v "$d" >/dev/null 2>&1 || warn "$p 需要 ${d}，但找不到這個指令，啟動時會自動略過"
done

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

# ---------- 7. configs ----------
step "寫入設定"
mkdir -p "$ZSH_DIR/themes" "$(dirname "$STARSHIP_TOML")" "$ZSH_CACHE"

backup "$ZSH_DIR/.zshrc" "$SRC_DIR/config/zshrc"
cp "$SRC_DIR/config/zshrc" "$ZSH_DIR/.zshrc"
ok "$ZSH_DIR/.zshrc"

if [[ "$(readlink "$HOME/.zshrc" 2>/dev/null)" != "$ZSH_DIR/.zshrc" ]]; then
  backup "$HOME/.zshrc"
  rm -f "$HOME/.zshrc"
  ln -s "$ZSH_DIR/.zshrc" "$HOME/.zshrc"
fi
ok "~/.zshrc → $ZSH_DIR/.zshrc"

cp "$SRC_DIR"/config/themes/*.zsh "$ZSH_DIR/themes/"
ok "語法高亮主題：$THEME"

cp "$SRC_DIR/config/aliases.zsh" "$ZSH_DIR/aliases.zsh"
if has aliases; then ok "常用 alias：$ZSH_DIR/aliases.zsh"; fi

tmp_toml="$(mktemp)"
cp "$SRC_DIR/config/starship.toml" "$tmp_toml"
[[ $PROMPT_TIME -eq 1 ]] && set_starship_disabled "$tmp_toml" time false    || set_starship_disabled "$tmp_toml" time true
[[ $PROMPT_IP   -eq 1 ]] && set_starship_disabled "$tmp_toml" localip false || set_starship_disabled "$tmp_toml" localip true
backup "$STARSHIP_TOML" "$tmp_toml"
cp "$tmp_toml" "$STARSHIP_TOML"; rm -f "$tmp_toml"
ok "${STARSHIP_TOML}（時間：$(onoff "$PROMPT_TIME")，IP：$(onoff "$PROMPT_IP")）"

cat > "$OPTIONS_FILE" <<EOF
# Generated by mac-zsh-setup — re-run install.sh to change these.
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

if [[ -n "$CONDA_ROOT" && "$CONDA_MODE" != off ]]; then
  "$CONDA_ROOT/bin/conda" config --set changeps1 False >/dev/null 2>&1 && ok "conda：changeps1 = False（載入方式：${CONDA_MODE}）"
fi

# ---------- Terminal.app profile ----------
TERMINAL_DONE=0
if [[ $TERMINAL_APP -eq 1 ]]; then
  step "Terminal.app"
  if defaults read com.apple.Terminal "Window Settings" >/dev/null 2>&1; then
    font="-"
    ls "$HOME/Library/Fonts"/HackNerdFontMono-Regular.* /Library/Fonts/HackNerdFontMono-Regular.* >/dev/null 2>&1 && font="HackNFM-Regular"
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
rm -f "$ZSH_CACHE"/*.zsh "$ZSH_CACHE"/zcompdump*

# ---------- 8. default shell ----------
ZSH_BIN="$(command -v zsh)"
if [[ "${SHELL:-}" != */zsh ]]; then
  step "預設 shell"
  if chsh -s "$ZSH_BIN"; then ok "預設 shell 已改成 $ZSH_BIN"; else warn "請手動執行：chsh -s $ZSH_BIN"; fi
fi

# ---------- 9. warm cache & measure ----------
step "建立快取並測量啟動時間"
zsh -i -c exit >/dev/null 2>&1 || true
start_ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }
best=999999
for _ in 1 2 3; do
  t0=$(start_ms); zsh -i -c exit >/dev/null 2>&1 || true; t1=$(start_ms)
  (( t1 - t0 < best )) && best=$((t1 - t0))
done
ok "zsh 啟動時間：約 ${best} ms"

# ---------- done ----------
printf '\n%s✔ 完成！%s\n\n' "$C_GREEN" "$C_RESET"
printf '  已啟用外掛：%s\n\n' "$CORE_PLUGINS${SEL:+ $SEL}"
echo "  接下來："
if [[ $TERMINAL_DONE -eq 1 ]]; then
  printf '    1. %s完全結束 Terminal.app（⌘Q）再重新打開%s，Home/End 和字型才會生效\n' "$C_YELLOW" "$C_RESET"
  printf '       %s用 iTerm2 / VS Code 的話，字型請手動改成 Hack Nerd Font Mono%s\n' "$C_DIM" "$C_RESET"
else
  cat <<EOF
    1. 把終端機字型改成 ${C_YELLOW}Hack Nerd Font Mono${C_RESET}
       ${C_DIM}Terminal.app → 設定 → 描述檔 → 文字 → 字體
       iTerm2       → Settings → Profiles → Text → Font
       VS Code      → "terminal.integrated.fontFamily": "Hack Nerd Font Mono"${C_RESET}
    2. 重開終端機，或執行：${C_YELLOW}exec zsh${C_RESET}
EOF
fi
echo "    之後想改選項，重新執行安裝指令即可（會記住這次的選擇）"
if [[ -d "$BACKUP_DIR" ]]; then printf '\n  %s舊檔案已備份到 %s%s\n' "$C_DIM" "$BACKUP_DIR" "$C_RESET"; fi
echo
