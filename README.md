<p align="center">
  <img src="assets/cover.png" alt="mac-zsh-setup" width="100%">
</p>

<p align="center">
  一行指令，把 macOS 終端機設定成 <b>zsh + Starship</b> 的樣子，啟動只要約 <b>40 ms</b>。<br>
  Homebrew · zsh-autosuggestions · fast-syntax-highlighting · zsh-completions · Starship · Hack Nerd Font
</p>

---

## 🚀 一行安裝

打開「終端機」，貼上：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/mac-zsh-setup/main/install.sh)"
```

執行後會先出現選單，可以挑選要裝的外掛和外觀，直接按 Enter 就是推薦設定：

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
  14 設定 Terminal.app  開  Home/End 鍵送給 shell、字型換成 Hack Nerd Font Mono

  ★ 推薦  輸入編號切換（可一次多個，例如 1 8 9），直接 Enter 開始安裝，q 離開
  >
```

裝好之後：

1. **完全結束 Terminal.app（⌘Q）再重新打開**：Home/End 鍵和 Nerd Font 字型會自動設定好
   （用 iTerm2 或 VS Code 的話，字型請手動設定，見 [設定字型](#-設定字型)）
2. 或在目前的視窗執行 `exec zsh`，先套用 zsh 的設定

> 如果還沒裝 Homebrew，安裝過程會要求輸入一次 macOS 登入密碼。
> 之後想改選項，再執行一次同一行指令就好，選單會記住你上次的選擇。

## 🧩 外掛

### 一定會裝

| 外掛 | 用途 |
| --- | --- |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | 依照歷史紀錄和補完結果，用灰字提示接下來可能要打的指令，按 `→` 就能採用 |
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | 輸入指令時即時上色，打錯的指令會變紅 |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | 額外的 Tab 補完定義 |

### 選用（★ 為預設開啟）

| 外掛 / 工具 | 用途 | 怎麼用 |
| --- | --- | --- |
| ★ [fzf-tab](https://github.com/Aloxaf/fzf-tab) | 把 Tab 補完選單換成可以模糊搜尋的 fzf | `cd <Tab>`、`git checkout <Tab>`，接著直接打字篩選 |
| ★ [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | 依照已經打的內容搜尋歷史 | 打 `docker` 再按 `↑`，只會翻出包含 docker 的指令 |
| ★ [zoxide](https://github.com/ajeetdsouza/zoxide) | 記住你常去的目錄，用關鍵字就能跳過去 | `z proj`、`z api`；`zi` 開啟互動選單 |
| ★ [fzf](https://github.com/junegunn/fzf) 快捷鍵 | 模糊搜尋歷史、檔案和目錄 | `Ctrl-R` 搜歷史 · `Ctrl-T` 插入檔案路徑 · `Alt-C` 跳目錄 |
| [zsh-you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use) | 打了完整指令時，提醒你其實有 alias 可以用 | 例如打 `git status` 時，提示你可以用 `gst` |
| [eza](https://github.com/eza-community/eza) | 更好看的 `ls`，有顏色、圖示和 git 狀態 | `ls` · `l` · `ll` · `la` · `lt`（樹狀顯示） |
| ★ 常用 alias | 一組常用的縮寫，見下方 [常用 alias](#-常用-alias) | `ll`、`..`、`gst`、`ports` |

## ⌨️ 常用 alias

所有 alias 都定義在 `~/.zsh/aliases.zsh`。git 的縮寫和 Oh My Zsh 用一樣的名稱，從 Oh My Zsh 換過來不用重新記；如果開啟了 eza，`l` / `ll` / `la` 會自動換成 eza 版本。

| 分類 | alias |
| --- | --- |
| 目錄 | `..` → `cd ..` · `...` → `cd ../..` · `....` · `-` → `cd -` |
| 列出檔案 | `l` → `ls -lh` · `ll` → `ls -lah` · `la` → `ls -A` |
| 常用預設 | `mkdir` → `mkdir -p` · `grep` → 有顏色 · `df` / `du` → 容易閱讀的單位 · `h` → 最近 20 筆歷史 |
| git | `g` · `gst` status · `gss` 簡短 status · `ga` / `gaa` add · `gc` commit · `gcmsg` commit -m · `gd` / `gds` diff · `gco` checkout · `gsw` switch · `gb` branch · `gl` pull · `gp` push · `glog` 圖形化 log · `gsta` / `gstp` stash |
| macOS | `o` 用 Finder 打開目前目錄 · `reload` 重新啟動 shell · `path` 逐行列出 PATH · `localip` 本機 IP · `ports` 查看哪個程式在監聽哪個 port · `flushdns` 清除 DNS 快取 |

想新增或覆蓋 alias，寫在 `~/.zsh/.zshrc.local` 就好，它比 `aliases.zsh` 晚載入。

## ⌨️ Home / End 鍵

Terminal.app 預設把 **Home / End** 拿去捲動視窗內容，按鍵根本不會送進 shell；zsh 也沒有綁定這些鍵。這個專案兩邊都會處理：

- **zsh**：綁定各家終端機會送出的 Home / End / Delete 按鍵序列，以及 Ctrl / Option + ←/→ 一次跳一個單字
- **Terminal.app**（選單第 14 項）：把預設描述檔的 Home / End 改成送給 shell，同時把字型換成 Hack Nerd Font Mono，大小維持不變。修改前會先把原本的 Terminal 設定備份到 `~/.mac-zsh-setup-backup/`

Terminal.app 要**完全結束（⌘Q）再重新打開**才會生效。想捲動視窗內容時，可以用 `Shift + Home / End`。

## 🎨 外觀

```
╭─ natlee  macOS  MacBook  ~/projects/app  main !1  base 3.12 ············ 10:42:07
╰─❯ git sta░tus░
```

- **Prompt 分段**：使用者 → 作業系統 → 主機名稱 → 目錄 → Git 分支／狀態 → Conda 環境／Python 版本；右側顯示時間和 IP，兩者都可以在選單裡關掉
- **自動建議文字**：灰色，有暗 `240`、中 `244`、亮 `248` 三種，也可以用參數指定任意 0–255 的顏色
- **語法高亮主題**：
  | 主題 | 風格 |
  | --- | --- |
  | `soft`（預設） | 柔和的粉彩色，和 Starship 的配色一致；沒有背景色塊，也不加粗 |
  | `minimal` | 幾乎是單色，只有路徑、字串和錯誤會帶一點顏色 |
  | `default` | fast-syntax-highlighting 原本的高對比配色 |

## ⚡ 啟動速度

| | 啟動時間 |
| --- | --- |
| 一般的 `conda init` + 外掛 | ~280 ms |
| **mac-zsh-setup** | **~40 ms** |

變快的原因：

- **快取初始化腳本**：`brew shellenv`、`starship init`、`fzf --zsh`、`zoxide init`、`conda hook` 的輸出會存在 `~/.cache/zsh/`，對應的程式更新後才重新產生
- **Conda fast 模式**：不另外啟動 Python 就直接啟用 base 環境，結果和官方 `conda activate` 完全相同；如果 base 有 activate.d 腳本或環境變數，會自動改走官方流程
- **`compinit` 每天只完整檢查一次**，其他時候直接讀快取（`-C`），而且會先編譯成 `.zwc`
- **zsh-autosuggestions** 開啟 `USE_ASYNC` 和 `MANUAL_REBIND`，不會在每次顯示 prompt 前重新綁定 widget
- **略過 fast-syntax-highlighting 第一次啟動時的網路下載**

手動安裝或更新了工具後，如果行為怪怪的，執行 `zsh-cache-clear` 再重開終端機即可。

Conda 有四種載入方式：

| 模式 | 說明 |
| --- | --- |
| `fast`（預設） | 快取 hook，並直接啟用 base |
| `lazy` | 第一次打 `conda` 時才載入，最快，但開新終端機時 base 不會自動啟用 |
| `full` | 官方 `conda init` 的行為 |
| `off` | 完全不載入 conda |

## 🔤 設定字型

提示字元裡的圖示（󰊢、󰌠、󰀵…）需要 Nerd Font 才能正常顯示。

- **Terminal.app**：設定 → 描述檔 → 文字 → 字體 → 改成 `Hack Nerd Font Mono`
- **iTerm2**：Settings → Profiles → Text → Font → 改成 `Hack Nerd Font Mono`
- **VS Code**：在 `settings.json` 加上
  ```json
  "terminal.integrated.fontFamily": "Hack Nerd Font Mono"
  ```

## 🧰 參數

不想看選單時，可以直接用參數指定，加上 `-y` 就完全不會詢問：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/mac-zsh-setup/main/install.sh)" -- \
  -y --plugins=fzf-tab,zoxide,fzf --theme=minimal --suggest-color=dim --ip=off
```

| 參數 | 說明 |
| --- | --- |
| `-y`, `--yes` | 不顯示選單，使用預設值（或上次安裝時的選擇） |
| `--plugins=a,b,c` | 選用外掛：`fzf-tab` `history-substring-search` `you-should-use` `zoxide` `fzf` `eza` `aliases`；`none` 表示都不要，`all` 表示全部 |
| `--suggest-color=` | `dim` / `medium` / `bright`，或 `0`–`255` |
| `--theme=` | `soft` / `minimal` / `default` |
| `--time=on\|off` | Prompt 是否顯示時間 |
| `--ip=on\|off` | Prompt 是否顯示 IP |
| `--conda=` | `fast` / `lazy` / `full` / `off` |
| `--terminal-app=on\|off` | 是否設定 Terminal.app（Home/End 鍵 + 字型） |
| `--no-font` | 不安裝 Hack Nerd Font |
| `--skip-brew` | 不使用 Homebrew（需要已經有 `git` 和 `starship`） |

也可以 clone 下來再執行：

```bash
git clone https://github.com/NatLee/mac-zsh-setup.git && cd mac-zsh-setup && ./install.sh
```

## 📁 安裝了哪些檔案

```
~/.zsh/
├── .zshrc            ← zsh 設定（本 repo 的 config/zshrc）
├── options.zsh       ← 你在選單裡的選擇
├── aliases.zsh       ← 常用 alias
├── .zshrc.local      ← (選用) 你自己的設定，不會被覆蓋
├── themes/           ← 語法高亮主題（soft / minimal）
└── plugins/          ← zsh 外掛
~/.zshrc              → symlink 指向 ~/.zsh/.zshrc
~/.config/starship.toml
~/.cache/zsh/         ← 初始化快取，可以隨時刪除
```

原本就有的設定檔，如果內容和新的不一樣，會先備份到 `~/.mac-zsh-setup-backup/<時間>/`，再寫入新的。

## ⚙️ 自訂

| 想改什麼 | 改哪裡 |
| --- | --- |
| 外掛、顏色、主題、conda 模式 | 重新執行安裝指令 |
| Prompt 的顏色、分段、格式 | `~/.config/starship.toml`，參考 [Starship 文件](https://starship.rs/config/) |
| 在 base 環境時隱藏 conda 那一格 | `starship.toml` 的 `[conda]` 改成 `ignore_base = true` |
| 自己的 alias、環境變數 | 寫在 `~/.zsh/.zshrc.local` |

> 重新執行安裝時會覆蓋 `starship.toml`，覆蓋前會先備份；如果你手動改過，記得從備份中把修改搬回來。

## ↩️ 還原

```bash
ls ~/.mac-zsh-setup-backup/                         # 找到要還原的時間點
cp ~/.mac-zsh-setup-backup/<時間>/.zshrc ~/.zshrc
cp ~/.mac-zsh-setup-backup/<時間>/starship.toml ~/.config/starship.toml
defaults import com.apple.Terminal ~/.mac-zsh-setup-backup/<時間>/com.apple.Terminal.plist   # 還原 Terminal.app 設定
```

如果要整個移除：

```bash
rm -rf ~/.zsh/plugins ~/.zsh/themes ~/.zsh/options.zsh ~/.zsh/aliases.zsh ~/.zshrc ~/.config/starship.toml ~/.cache/zsh
brew uninstall starship fzf zoxide eza
brew uninstall --cask font-hack-nerd-font
```

## 📄 License

[MIT](LICENSE)
