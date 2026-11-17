#!/usr/bin/env bash
#
# mac-zsh-setup — Homebrew + zsh plugins + Starship + Hack Nerd Font, in one go.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/mac-zsh-setup/main/install.sh)"
#
# Options:
#   --skip-brew   don't install Homebrew / brew packages (assumes git & starship exist)
#   --no-font     don't install Hack Nerd Font
#   -h, --help    show this help
#
set -euo pipefail

REPO_URL="https://github.com/NatLee/mac-zsh-setup.git"
ZSH_DIR="$HOME/.zsh"
PLUGIN_DIR="$ZSH_DIR/plugins"
STARSHIP_TOML="$HOME/.config/starship.toml"
BACKUP_DIR="$HOME/.mac-zsh-setup-backup/$(date +%Y%m%d-%H%M%S)"

PLUGINS=(
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
  "zsh-completions|https://github.com/zsh-users/zsh-completions.git"
  "fast-syntax-highlighting|https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
)

SKIP_BREW=0
INSTALL_FONT=1

# ---------- helpers ----------
if [[ -t 1 ]]; then
  C_BLUE=$'\033[38;5;110m'; C_GREEN=$'\033[38;5;149m'; C_YELLOW=$'\033[38;5;221m'
  C_RED=$'\033[38;5;160m'; C_DIM=$'\033[38;5;244m'; C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_RESET=""
fi
step() { printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%s✖ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

usage() { sed -n '3,11p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    --skip-brew) SKIP_BREW=1 ;;
    --no-font)   INSTALL_FONT=0 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

# Back up a file/symlink before replacing it (only if it differs from the new one).
backup() {
  local target="$1" new="${2:-}"
  [[ -e "$target" || -L "$target" ]] || return 0
  if [[ -n "$new" && -f "$target" && ! -L "$target" ]] && cmp -s "$target" "$new"; then
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  cp -RP "$target" "$BACKUP_DIR/$(basename "$target")"
  warn "Backed up $target → $BACKUP_DIR/"
}

load_brew_env() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# ---------- 0. sanity ----------
[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS only."
[[ $EUID -ne 0 ]] || die "Please run as your normal user, not root."

printf '\n%s  mac-zsh-setup%s  %sHomebrew · zsh plugins · Starship · Hack Nerd Font%s\n' \
  "$C_BLUE" "$C_RESET" "$C_DIM" "$C_RESET"

# ---------- 1. Homebrew ----------
if [[ $SKIP_BREW -eq 0 ]]; then
  step "Homebrew"
  load_brew_env
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found — installing (you may be asked for your password)"
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew_env
    command -v brew >/dev/null 2>&1 || die "Homebrew installation failed."
  fi
  ok "brew $(brew --version | head -1 | awk '{print $2}')"

  step "Packages: git, starship"
  for pkg in git starship; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      ok "$pkg (already installed)"
    else
      brew install "$pkg" && ok "$pkg"
    fi
  done

  if [[ $INSTALL_FONT -eq 1 ]]; then
    step "Font: Hack Nerd Font (incl. Hack Nerd Font Mono)"
    if brew list --cask font-hack-nerd-font >/dev/null 2>&1; then
      ok "font-hack-nerd-font (already installed)"
    else
      brew install --cask font-hack-nerd-font && ok "font-hack-nerd-font"
    fi
  fi
fi

command -v git >/dev/null 2>&1      || die "git is required."
command -v starship >/dev/null 2>&1 || die "starship is required."

# ---------- 2. Get config files ----------
step "Config files"
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
ok "Using $SRC_DIR"

# ---------- 3. zsh plugins ----------
step "zsh plugins → $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
for entry in "${PLUGINS[@]}"; do
  name="${entry%%|*}"; url="${entry#*|}"
  dest="$PLUGIN_DIR/$name"
  if [[ -d "$dest/.git" ]]; then
    if git -C "$dest" pull --quiet --ff-only 2>/dev/null; then
      ok "$name (updated)"
    else
      warn "$name exists but could not be updated — leaving as is"
    fi
  else
    [[ -e "$dest" ]] && { backup "$dest"; rm -rf "$dest"; }
    git clone --quiet --depth 1 "$url" "$dest" && ok "$name"
  fi
done

# ---------- 4. Install configs ----------
step "Writing configs"
mkdir -p "$ZSH_DIR" "$(dirname "$STARSHIP_TOML")"

backup "$ZSH_DIR/.zshrc" "$SRC_DIR/config/zshrc"
cp "$SRC_DIR/config/zshrc" "$ZSH_DIR/.zshrc"
ok "$ZSH_DIR/.zshrc"

if [[ "$(readlink "$HOME/.zshrc" 2>/dev/null)" != "$ZSH_DIR/.zshrc" ]]; then
  backup "$HOME/.zshrc"
  rm -f "$HOME/.zshrc"
  ln -s "$ZSH_DIR/.zshrc" "$HOME/.zshrc"
fi
ok "~/.zshrc → $ZSH_DIR/.zshrc"

backup "$STARSHIP_TOML" "$SRC_DIR/config/starship.toml"
cp "$SRC_DIR/config/starship.toml" "$STARSHIP_TOML"
ok "$STARSHIP_TOML"

# Hide conda's own "(base)" prefix permanently too (Starship shows the env instead).
for conda_bin in "$HOME/miniconda3/bin/conda" "$HOME/anaconda3/bin/conda" "$HOME/miniforge3/bin/conda"; do
  if [[ -x "$conda_bin" ]]; then
    "$conda_bin" config --set changeps1 False >/dev/null 2>&1 && ok "conda: changeps1 = False"
    break
  fi
done

# ---------- 5. Default shell ----------
ZSH_BIN="$(command -v zsh)"
if [[ "${SHELL:-}" != */zsh ]]; then
  step "Default shell"
  if chsh -s "$ZSH_BIN"; then ok "Default shell is now $ZSH_BIN"; else warn "Run: chsh -s $ZSH_BIN"; fi
fi

# ---------- done ----------
printf '\n%s✔ All done!%s\n\n' "$C_GREEN" "$C_RESET"
cat <<EOF
  Next steps:
    1. Set your terminal font to ${C_YELLOW}Hack Nerd Font Mono${C_RESET}
       ${C_DIM}Terminal.app → Settings → Profiles → Text → Font
       iTerm2       → Settings → Profiles → Text → Font
       VS Code      → "terminal.integrated.fontFamily": "Hack Nerd Font Mono"${C_RESET}
    2. Restart your terminal, or run: ${C_YELLOW}exec zsh${C_RESET}
EOF
[[ -d "$BACKUP_DIR" ]] && printf '\n  %sOld files were backed up to %s%s\n' "$C_DIM" "$BACKUP_DIR" "$C_RESET"
echo
