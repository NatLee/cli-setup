<p align="center">
  <img src="assets/cover.png" alt="mac-zsh-setup" width="100%">
</p>

<p align="center">
  一行指令，把 macOS 終端機設定成 <b>zsh + Starship</b> 的樣子。<br>
  Homebrew · zsh-autosuggestions · zsh-completions · fast-syntax-highlighting · Starship · Hack Nerd Font
</p>

---

## 🚀 一行安裝

打開「終端機」，貼上：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/mac-zsh-setup/main/install.sh)"
```

裝好之後：

1. 把終端機字型改成 **Hack Nerd Font Mono**（見下方 [設定字型](#-設定字型)）
2. 重開終端機，或執行 `exec zsh`

> 如果還沒裝 Homebrew，安裝過程會要求輸入一次 macOS 登入密碼。

## 📦 會安裝哪些東西

| 項目 | 說明 |
| --- | --- |
| [Homebrew](https://brew.sh) | macOS 套件管理工具，已經裝過就略過 |
| [Starship](https://starship.rs) | 跨 shell 的提示字元（prompt） |
| [Hack Nerd Font](https://www.nerdfonts.com) | 用 `brew install --cask font-hack-nerd-font` 安裝，內含 **Hack Nerd Font Mono** |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | 依照歷史紀錄和補完結果，用灰字提示接下來可能要打的指令，按 `→` 就能採用 |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | 額外的 Tab 補完定義 |
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | 輸入指令時即時語法上色 |

會寫入或建立的檔案：

```
~/.zsh/
├── .zshrc               ← zsh 設定（本 repo 的 config/zshrc）
├── .zshrc.local         ← (選用) 你自己的設定，不會被覆蓋
├── .zsh_history
└── plugins/
    ├── fast-syntax-highlighting/
    ├── zsh-autosuggestions/
    └── zsh-completions/
~/.zshrc                 → symlink 指向 ~/.zsh/.zshrc
~/.config/starship.toml  ← Starship 設定（本 repo 的 config/starship.toml）
```

原本就有的 `~/.zshrc`、`~/.zsh/.zshrc`、`~/.config/starship.toml`，如果內容和新的不一樣，會先備份到 `~/.mac-zsh-setup-backup/<時間>/`，再寫入新的。

## 🔤 設定字型

提示字元裡的圖示（󰊢、󰌠、󰀵…）需要 Nerd Font 才能正常顯示。

- **Terminal.app**：設定 → 描述檔 → 文字 → 字體 → 改成 `Hack Nerd Font Mono`
- **iTerm2**：Settings → Profiles → Text → Font → 改成 `Hack Nerd Font Mono`
- **VS Code**：在 `settings.json` 加上
  ```json
  "terminal.integrated.fontFamily": "Hack Nerd Font Mono"
  ```

## 🎨 外觀

```
╭─ natlee  macOS  MacBook  ~/projects/app  main !1  base 3.12 ············ 10:42:07
╰─❯ git sta░tus░
```

- **Prompt 分段**：使用者 → 作業系統 → 主機名稱 → 目錄 → Git 分支／狀態 → Conda 環境／Python 版本，右邊顯示時間、本機 IP，指令跑超過 5 秒時再加上執行時間
- **自動建議**：用柔和的灰色（`fg=244`）顯示，不會搶走注意力
- **Conda**：如果有裝 Miniconda、Anaconda 或 Miniforge，會自動載入，並關掉 conda 自己加的 `(base)` 前綴，環境名稱只會在 Starship 那一格出現一次

## ⚙️ 自訂

| 想改什麼 | 改哪裡 |
| --- | --- |
| 自動建議的顏色 | `~/.zsh/.zshrc` 裡的 `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE`（`fg=232` 最暗 … `fg=255` 最亮） |
| Prompt 的顏色、分段、格式 | `~/.config/starship.toml`，參考 [Starship 文件](https://starship.rs/config/) |
| 在 base 環境時隱藏 conda 那一格 | `starship.toml` 的 `[conda]` 改成 `ignore_base = true` |
| 自己的 alias、環境變數 | 寫在 `~/.zsh/.zshrc.local`，重新執行安裝也不會被覆蓋 |

## 🧰 進階用法

先 clone 再執行，或帶參數：

```bash
git clone https://github.com/NatLee/mac-zsh-setup.git
cd mac-zsh-setup
./install.sh              # 完整安裝
./install.sh --no-font    # 不安裝字型
./install.sh --skip-brew  # 不碰 Homebrew（需要已經有 git 和 starship）
```

帶參數的一行版本：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/mac-zsh-setup/main/install.sh)" -- --no-font
```

安裝腳本可以重複執行：已經裝好的東西會略過，外掛會用 `git pull` 更新到最新版。

## ↩️ 還原

```bash
ls ~/.mac-zsh-setup-backup/                         # 找到要還原的時間點
cp ~/.mac-zsh-setup-backup/<時間>/.zshrc ~/.zshrc
cp ~/.mac-zsh-setup-backup/<時間>/starship.toml ~/.config/starship.toml
```

如果要整個移除：

```bash
rm -rf ~/.zsh/plugins ~/.zshrc ~/.config/starship.toml
brew uninstall starship
brew uninstall --cask font-hack-nerd-font
```

## 📄 License

[MIT](LICENSE)
