<p align="center">
  <img src="assets/cover.png" alt="zsh-setup" width="100%">
</p>

<p align="center">
  一行指令，把終端機設定成 <b>zsh + Starship</b> 的樣子，啟動只要約 <b>20–40 ms</b>。<br>
  支援 <b>macOS · Linux · WSL · Windows（PowerShell）</b>
</p>

---

## 🚀 一行安裝

**macOS / Linux / WSL**（在終端機貼上）：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/zsh-setup/main/install.sh)"
```

**Windows**（在 PowerShell 貼上）：

```powershell
irm https://raw.githubusercontent.com/NatLee/zsh-setup/main/install.ps1 | iex
```

執行後會先出現選單，可以挑選要裝的外掛和外觀，直接按 Enter 就是推薦設定。之後想改選項，再執行一次同一行指令就好，選單會記住你上次的選擇。

```
  外掛 / 工具
   1 [x] ★ fzf-tab                    Tab 補完改成 fzf 模糊搜尋選單
   2 [x] ★ history-substring-search   ↑/↓ 依目前已輸入的內容搜尋歷史
   3 [ ]   you-should-use             打了完整指令時，提醒你有對應的 alias
   4 [x] ★ zoxide                     z <關鍵字> 直接跳到常去的目錄
   5 [x] ★ fzf                        Ctrl-R 搜歷史 · Ctrl-T 找檔案 · Alt-C 跳目錄
   6 [ ]   eza                        ls / l / ll / la / lt 換成彩色 + 圖示的 eza
   7 [x] ★ aliases                    常用 alias：ll = ls -lah、..、gst / gco 等 git 縮寫

  外觀
   8 建議文字顏色    中 (244)     預覽：git status --short
   9 語法高亮主題    soft         預覽：git commit -m "fix" ~/src
  10 Prompt 時間     開
  11 Prompt IP       開

  其他
  12 Conda 載入方式  fast         快取 hook，瞬間啟用 base（推薦）
  13 安裝 Hack Nerd Font  開
  14 設定 Terminal.app  開  Home/End 鍵送給 shell、字型換成 Hack Nerd Font Mono   ← 只有 macOS

  ★ 推薦  輸入編號切換（可一次多個，例如 1 8 9），直接 Enter 開始安裝，q 離開
  >
```

## 🖥️ 支援的平台

| 平台 | 安裝方式 | 已實際測試 |
| --- | --- | --- |
| macOS（Apple Silicon / Intel） | Homebrew | macOS 27 |
| Ubuntu / Debian | apt | Ubuntu 22.04、24.04，Debian 12 |
| Fedora | dnf | Fedora 42 |
| Arch Linux | pacman | Arch（rolling） |
| openSUSE | zypper | Tumbleweed |
| WSL | 同 Linux | — |
| Windows 10 / 11 | winget（或 Scoop）+ PowerShell Gallery | PowerShell 7 的設定邏輯（在 Linux 上的 pwsh 測試）；Windows 本機尚未實測 |

Linux 上如果套件管理器沒有某個工具，或版本太舊（例如 Ubuntu 22.04 的 fzf 不支援 `fzf --zsh`），會自動改從官方來源安裝到 `~/.local/bin`，不會動到系統。

> Windows 沒有原生的 zsh，所以用 PowerShell 做出一樣的體驗：同一份 Starship 設定、同樣的配色、同樣的 alias。想在 Windows 用真正的 zsh，請在 **WSL** 裡執行上面的 Linux 指令。

## 🧩 功能

| 功能 | macOS / Linux（zsh） | Windows（PowerShell） |
| --- | --- | --- |
| 灰字自動建議 | [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | PSReadLine 歷史預測（InlineView） |
| 語法高亮 | [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) + soft / minimal 主題 | PSReadLine 配色，同樣的 soft / minimal 主題 |
| 補完 | [zsh-completions](https://github.com/zsh-users/zsh-completions) | PowerShell 內建 |
| ★ Tab 模糊選單 | [fzf-tab](https://github.com/Aloxaf/fzf-tab) | [PSFzf](https://github.com/kelleyma49/PSFzf) |
| ★ ↑/↓ 依輸入搜尋歷史 | [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | PSReadLine HistorySearchBackward |
| ★ Ctrl-R / Ctrl-T / Alt-C | [fzf](https://github.com/junegunn/fzf) | fzf + PSFzf |
| ★ `z` 智慧跳目錄 | [zoxide](https://github.com/ajeetdsouza/zoxide) | zoxide |
| `ls` 彩色 + 圖示 | [eza](https://github.com/eza-community/eza) | eza |
| ★ 常用 alias | `aliases.zsh` | `aliases.ps1`（名稱相同） |
| 提醒你有 alias 可用 | [zsh-you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use) | — |
| Prompt | [Starship](https://starship.rs)（同一份 `starship.toml`） | Starship |
| 字型 | [Hack Nerd Font](https://www.nerdfonts.com) | Hack Nerd Font（裝在目前使用者，不需要系統管理員） |
| 終端機自動設定 | Terminal.app：Home/End + 字型 | Windows Terminal：字型 |

★ 為預設開啟。

## ⌨️ 常用 alias

git 的縮寫和 Oh My Zsh 用一樣的名稱，從 Oh My Zsh 換過來不用重新記；如果開啟了 eza，`l` / `ll` / `la` 會自動換成 eza 版本。

| 分類 | alias |
| --- | --- |
| 目錄 | `..` → `cd ..` · `...` → `cd ../..` · `....` · `-` → `cd -`（zsh） |
| 列出檔案 | `l` → `ls -lh` · `ll` → `ls -lah` · `la` → `ls -A` |
| 常用預設 | `mkdir` → `mkdir -p` · `grep` 有顏色 · `df` / `du` 易讀單位 · `h` 最近 20 筆歷史 |
| git | `g` · `gst` status · `gss` 簡短 status · `ga` / `gaa` add · `gc` commit · `gcmsg` commit -m · `gd` / `gds` diff · `gco` checkout · `gsw` switch · `gb` branch · `gl` pull · `gp` push · `glog` 圖形化 log · `gsta` / `gstp` stash |
| 系統 | `o` 用檔案總管打開目前目錄 · `path` 逐行列出 PATH · `localip` 本機 IP · `ports` 哪個程式在監聽哪個 port · `flushdns` 清除 DNS 快取 · `reload` 重啟 shell（zsh） |
| Windows 額外 | `which` · `touch` |

Windows 版會移除 PowerShell 內建、名稱衝突的 `gc`（Get-Content）、`gp`、`gl` alias。

## ⌨️ Home / End 鍵

- **zsh**：綁定各家終端機送出的 Home / End / Delete 按鍵序列，以及 Ctrl / Option + ←/→ 一次跳一個單字。
- **macOS Terminal.app**：預設把 Home / End 拿去捲動視窗，按鍵根本不會送進 shell。選單第 14 項會把預設描述檔的 Home / End 改成送給 shell，順便把字型換成 Hack Nerd Font Mono（大小不變），改之前會先備份原本的 Terminal 設定。要**完全結束 Terminal.app（⌘Q）再重新打開**才會生效；想捲動視窗內容時改用 `Shift + Home / End`。
- **Windows Terminal / PowerShell**：Home / End 原本就能用。

## 🎨 外觀

```
╭─ natlee  macOS  MacBook  ~/projects/app  main !1  base 3.12 ············ 10:42:07
╰─❯ git sta░tus░
```

- **Prompt 分段**：使用者 → 作業系統 → 主機名稱 → 目錄 → Git 分支／狀態 → Conda 環境／Python 版本；右側顯示時間和 IP，都可以在選單關掉
- **自動建議文字**：灰色，暗 `240`、中 `244`、亮 `248`，也可以用參數指定 0–255
- **語法高亮主題**：

  | 主題 | 風格 |
  | --- | --- |
  | `soft`（預設） | 柔和的粉彩色，和 Starship 配色一致；沒有背景色塊，也不加粗 |
  | `minimal` | 幾乎是單色，只有路徑、字串和錯誤會帶一點顏色 |
  | `default` | 外掛原本的高對比配色 |

## ⚡ 啟動速度

| | 啟動時間 |
| --- | --- |
| 一般的 `conda init` + 外掛（macOS） | ~280 ms |
| **zsh-setup（macOS）** | **~40 ms** |
| **zsh-setup（Linux）** | **~20 ms** |
| **zsh-setup（PowerShell 設定檔，快取後）** | **~20 ms**（不含 PowerShell 本身的啟動時間） |

變快的原因：

- **快取初始化腳本**：`brew shellenv`、`starship init`、`fzf --zsh`、`zoxide init`、conda hook 的輸出存在快取資料夾，對應的程式更新後才重新產生
- **Conda fast 模式**（zsh）：不另外啟動 Python 就直接啟用 base 環境，結果和官方 `conda activate` 完全相同；base 有 activate.d 腳本或環境變數時，自動改走官方流程
- **`compinit` 每天只完整檢查一次**，其他時候直接讀快取並編譯成 `.zwc`；Debian / Ubuntu 會設定 `skip_global_compinit=1`，避免系統再跑一次
- **zsh-autosuggestions** 開啟 `USE_ASYNC` 和 `MANUAL_REBIND`

手動安裝或更新了工具後，如果行為怪怪的，執行 `zsh-cache-clear` 再重開終端機即可（zsh 和 PowerShell 都有）。

| Conda 模式 | 說明 |
| --- | --- |
| `fast`（預設） | 快取 hook 並直接啟用 base |
| `lazy` | 第一次打 `conda` 時才載入，最快，但開新終端機時 base 不會自動啟用 |
| `full` | 官方 `conda init` 的行為 |
| `off` | 不載入 conda |

## 🔤 字型

提示字元裡的圖示（󰊢、󰌠、󰀵…）需要 Nerd Font 才能正常顯示。字型要裝在**你打字的那台電腦**上：透過 SSH 連到伺服器時，裝在本機；用 WSL 時，裝在 Windows 端（執行 `install.ps1`）。所以在沒有桌面環境的 Linux 和 WSL 上，選單預設不安裝字型。

| 終端機 | 設定方式 |
| --- | --- |
| Terminal.app | 選單第 14 項自動設定，或：設定 → 描述檔 → 文字 → 字體 |
| iTerm2 | Settings → Profiles → Text → Font |
| Windows Terminal | `install.ps1` 自動設定，或：設定 → 預設值 → 外觀 → 字體 |
| GNOME Terminal / Konsole | 偏好設定 → 描述檔 → 自訂字型 |
| VS Code | `"terminal.integrated.fontFamily": "Hack Nerd Font Mono"` |

## 🧰 參數

不想看選單時可以直接用參數，加上 `-y` / `-Yes` 就完全不會詢問。

**install.sh**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/zsh-setup/main/install.sh)" -- \
  -y --plugins=fzf-tab,zoxide,fzf,aliases --theme=minimal --suggest-color=dim --ip=off
```

| 參數 | 說明 |
| --- | --- |
| `-y`, `--yes` | 不顯示選單，使用預設值（或上次安裝時的選擇） |
| `--plugins=a,b,c` | `fzf-tab` `history-substring-search` `you-should-use` `zoxide` `fzf` `eza` `aliases`；`none` / `all` |
| `--suggest-color=` | `dim` / `medium` / `bright`，或 `0`–`255` |
| `--theme=` | `soft` / `minimal` / `default` |
| `--time=on\|off` · `--ip=on\|off` | Prompt 是否顯示時間 / IP |
| `--conda=` | `fast` / `lazy` / `full` / `off` |
| `--font=on\|off` | 是否安裝 Hack Nerd Font（`--no-font` 同 `--font=off`） |
| `--terminal-app=on\|off` | macOS：是否設定 Terminal.app |
| `--skip-packages` | 不安裝任何套件（需要已經有 `zsh`、`git`、`starship`） |

**install.ps1**

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/NatLee/zsh-setup/main/install.ps1))) -Yes -Theme minimal -Ip off
```

| 參數 | 說明 |
| --- | --- |
| `-Yes` | 不顯示選單 |
| `-Plugins a,b,c` | `fzf-tab` `history-substring-search` `zoxide` `fzf` `eza` `aliases`；`none` / `all` |
| `-SuggestColor` · `-Theme` · `-Conda` | 同上 |
| `-Time on\|off` · `-Ip on\|off` · `-Font on\|off` | 同上 |
| `-WindowsTerminal on\|off` | 是否把 Windows Terminal 的預設字型改成 Hack Nerd Font Mono |
| `-SkipPackages` | 不安裝任何工具 / 模組 |

也可以 clone 下來再執行：`./install.sh`，或在 PowerShell 7 執行 `pwsh -File install.ps1`。

## 📁 安裝了哪些檔案

**macOS / Linux**

```
~/.zsh/
├── .zshrc            ← zsh 設定（config/zshrc）
├── options.zsh       ← 你在選單裡的選擇
├── aliases.zsh       ← 常用 alias
├── .zshrc.local      ← (選用) 你自己的設定，不會被覆蓋
├── .zsh_history      ← 第一次安裝時會複製原本的 ~/.zsh_history
├── themes/           ← 語法高亮主題
└── plugins/          ← zsh 外掛
~/.zshrc              → symlink 指向 ~/.zsh/.zshrc
~/.config/starship.toml
~/.cache/zsh/         ← 初始化快取，可以隨時刪除
~/.local/bin/         ← (Linux) 從官方來源安裝的工具
```

**Windows**

```
~\.config\zsh-setup\
├── profile.ps1       ← PowerShell 設定（config/windows/profile.ps1）
├── options.ps1       ← 你在選單裡的選擇
├── aliases.ps1       ← 常用 alias
└── local.ps1         ← (選用) 你自己的設定，不會被覆蓋
~\.config\starship.toml
Documents\PowerShell\profile.ps1         ← 加上一段載入上面 profile.ps1 的程式碼（PowerShell 7）
Documents\WindowsPowerShell\profile.ps1  ← 同上（Windows PowerShell 5.1）
%LOCALAPPDATA%\zsh-setup\cache\          ← 初始化快取
```

原本就有的設定檔，如果內容和新的不一樣，會先備份到 `~/.zsh-setup-backup/<時間>/`，再寫入新的。

## ⚙️ 自訂

| 想改什麼 | 改哪裡 |
| --- | --- |
| 外掛、顏色、主題、conda 模式 | 重新執行安裝指令 |
| Prompt 的顏色、分段、格式 | `~/.config/starship.toml`，參考 [Starship 文件](https://starship.rs/config/) |
| 在 base 環境時隱藏 conda 那一格 | `starship.toml` 的 `[conda]` 改成 `ignore_base = true` |
| 自己的 alias、環境變數 | zsh：`~/.zsh/.zshrc.local`；PowerShell：`~\.config\zsh-setup\local.ps1` |

> 重新執行安裝時會覆蓋 `starship.toml`，覆蓋前會先備份；如果你手動改過，記得從備份中把修改搬回來。

## ↩️ 還原

```bash
ls ~/.zsh-setup-backup/                                   # 找到要還原的時間點
cp ~/.zsh-setup-backup/<時間>/.zshrc ~/.zshrc
cp ~/.zsh-setup-backup/<時間>/starship.toml ~/.config/starship.toml
defaults import com.apple.Terminal ~/.zsh-setup-backup/<時間>/com.apple.Terminal.plist   # macOS：還原 Terminal.app
```

Windows：從 `~\.zsh-setup-backup\<時間>\` 把檔案複製回去，並刪除 `Documents\PowerShell\profile.ps1` 裡 `# >>> zsh-setup >>>` 到 `# <<< zsh-setup <<<` 那一段。

## 📄 License

[MIT](LICENSE)
