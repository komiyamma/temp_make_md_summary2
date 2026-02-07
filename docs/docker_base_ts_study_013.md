# 第13章：Windowsでハマりがちな点（改行/パス/権限）🪤😵

この章は「マウント（bind mount）を使った開発」で**事故りやすい3大トラップ**を、わざと再現して💥 → 直して🛠️ → 予防する✅ ところまでやります😄✨
（Todo APIを育てる流れのまま行くよ〜🌱）

---

## 1) この章でできるようになること🎯

* 「なんか動かない…」の原因が **改行 / パス / 権限** のどれか、すぐ当てられる🔍
* 典型エラーを見た瞬間に「次に確認する1手」が出せる🧠⚡
* **Windows↔WSL2↔Docker** の“ファイルの居場所”が混乱しなくなる🗺️

---

## 2) まず地図！Windows開発は「ファイルの居場所」で勝負🗺️🪟🐧🐳

WindowsでDocker開発すると、ファイルの置き場所が2系統あります👇

* 🪟 **Windows側**（例：`C:\Users\...`）
* 🐧 **WSL側（Linuxファイルシステム）**（例：`/home/<user>/...`）

ここ、**性能と互換性に直結**します⚡
Docker公式のWSLベストプラクティスは、**bind mountするコードはLinux側（WSLのファイルシステム）に置くのを推奨**しています。さらに、ホットリロード等に必要な **inotify（ファイル変更通知）が安定する**点も明言されています。([Docker Documentation][1])
VS CodeのDev Containers側のガイドも、同様に「WSL2のファイルシステムに置くと性能と権限互換が良い」方向で説明しています。([Visual Studio Code][2])
（Docker DesktopがWSL2バックエンドで動く前提の話も公式にあります。([Docker Documentation][3])）

**結論（この章の推奨）📌**
✅ Todo API の作業フォルダは **WSLの`/home/...`配下**に置くのが一番ラク＆事故りにくいです😄([Docker Documentation][1])

---

## 3) 罠① 改行（CRLF）🧨「動くはずのシェルが動かない」

### よくある症状😵

* `env: bash\r: No such file or directory`
* `Syntax error: unexpected ...`
* `npm`スクリプトがLinuxでだけ壊れる

**原因あるある**
Windowsで編集したファイルが **CRLF** になってて、Linux側で「`\r`混入」として爆発💥

---

### 3-1) まず10秒で判定する方法⏱️

* VS Code右下に `CRLF / LF` 表示あるよね👀（そこで即確認！）

---

### 3-2) 再現ハンズオン（わざと壊す→直す）🧪💥🛠️

#### ✅ ① CRLFのシェルを作って、コンテナで実行

```bash
## WSLの作業フォルダで（例: ~/todo-api）
mkdir -p scripts
printf '#!/usr/bin/env bash\r\necho "hello"\r\n' > scripts/hello.sh
chmod +x scripts/hello.sh

## コンテナで実行（bind mount）
docker run --rm -v "$PWD:/app" -w /app ubuntu:24.04 ./scripts/hello.sh
```

💥 たぶん `bash\r` 系で死にます😇

#### ✅ ② 直す（最短：LFへ変換）

```bash
## 1) dos2unix があるなら
dos2unix scripts/hello.sh

## 2) 無いなら sed でもOK
sed -i 's/\r$//' scripts/hello.sh
```

もう一回実行して通れば勝ち🏆✨

---

### 3-3) 予防策（ガチで効くやつ）🛡️✨

#### ✅ A) `.gitattributes` で「このリポジトリはLF主義」に固定する（最強）🥇

Gitは `text` / `eol` 属性で、リポジトリ内の改行正規化を制御できます。([Git][4])
VS CodeのDev Containers Tipsにも、LF固定の例（`text=auto eol=lf` など）が載っています。([Visual Studio Code][5])

例（Todo API向けの現実ライン👇）

```gitattributes
## だいたい全部テキストは正規化（Gitがテキストと判断したもの）
* text=auto

## Linuxで動く系はLF固定（Docker/WSLで事故りやすい）
*.sh text eol=lf
*.ts text eol=lf
*.js text eol=lf
*.json text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.env text eol=lf

## Windows専用はCRLFでもOK（必要なら）
*.bat text eol=crlf
*.cmd text eol=crlf
```

> 「全部LFでいいじゃん！」でOKなら、`.bat/.cmd`行すら無くてもいけます😄

#### ✅ B) Git設定（おすすめは “input”）🧠

`core.autocrlf` は環境次第で地雷にもなるので、**「WindowsでもcommitはLF寄せ」**にしたいなら `input` がわかりやすいです。([Visual Studio Code][5])

```bash
git config --global core.autocrlf input
```

#### ✅ C) VS Codeの新規ファイルをLFに寄せる📝

VS Codeは `files.eol` で新規ファイルのEOLを指定できます。([Visual Studio Code][6])
（既存ファイルは別途「EOL変換」する必要ありだよ）

---

## 4) 罠② パス（Windows/WSL/Compose）🧭「マウントしたのに空っぽ」

### よくある症状😵

* マウントしたはずなのに、コンテナ内が空📭
* `invalid volume specification` とか怒られる💢
* スペース入りパスで死ぬ🫠

---

### 4-1) まず基本ルール（`-v` の形）📌

`-v` / `--volume` は **`host-path:container-path[:opts]`** のコロン区切りです。([Docker Documentation][7])
→ Windowsは **ドライブレターにもコロンがある**から、ここで混乱しがち😵‍💫

---

### 4-2) 「どこでdockerコマンド打ってる？」が超重要⚠️

#### 🪟 PowerShell / cmd で打つとき（Windowsパス世界）

* `C:\...` を使う
* スペースがあるなら必ず引用符

例：

```powershell
docker run --rm -v "C:\Users\you\work\todo-api:/app" -w /app node:22 bash -lc "ls -la"
```

#### 🐧 WSL で打つとき（Linuxパス世界）

* `/home/you/...` を使う（←推奨）
* `/mnt/c/...` は「動くけどハマりやすい」寄り

例：

```bash
docker run --rm -v "$PWD:/app" -w /app node:22 bash -lc "ls -la"
```

---

### 4-3) “/mnt/c” を避けたい理由（体感で効く）🚀

Docker公式は、**Windows側の`/mnt/c`由来をbind mountすると遅くなりやすい**、さらに **inotifyが期待通り来ないことがある**ので、Linux側ファイルシステムを推奨しています。([Docker Documentation][1])
→ ホットリロード（ts-node-dev / nodemon 等）が「効いたり効かなかったり」になりがち😇

---

## 5) 罠③ 権限（Permission denied / EACCES）🔒「読めない・書けない・実行できない」

### 5-1) 典型症状セット😵‍💫

* `Permission denied`
* `EACCES: permission denied, mkdir ...`
* シェルが `chmod +x` したのに実行できない🏃‍♂️❌
* コンテナが作ったファイルが **root所有**になって、編集が変になる👻

---

### 5-2) “最強の回避” はこれ（まずこれで勝てる）🥇

✅ **コードはWSLのLinux領域（`/home/...`）に置く**
これだけで「実行ビット」「所有権」「監視イベント」系が一気に落ち着きます。([Docker Documentation][1])

---

### 5-3) それでも出る「npm系EACCES」の現場対策📦🛠️

#### ✅ A) 依存（node_modules）を bind mount しない（地味に効く）🎯

やりがち：`./:/app` をマウントすると、ホストの状態に引っ張られて壊れやすい💥
→ **node_modulesは“名前付きvolume”に逃がす**のが鉄板です😄

例（Composeの考え方）：

```yaml
services:
  api:
    image: node:22
    working_dir: /app
    volumes:
      - ./:/app
      - node_modules:/app/node_modules
    command: bash -lc "npm ci && npm run dev"
volumes:
  node_modules:
```

（この構成だと、ホストの`node_modules`問題が薄くなります🙂）

#### ✅ B) コンテナを「非rootユーザー」で動かす（開発でも安全寄り）🧑‍💻

Node公式イメージには `node` ユーザー（uid 1000）が用意されていて、`-u node` で実行できます。([GitHub][8])

例：

```bash
docker run --rm -u node -v "$PWD:/app" -w /app node:22 bash -lc "npm ci"
```

---

### 5-4) WSL側のマウント権限（/mnt/c）をいじるなら注意⚠️

WSLは `wsl.conf` で自動マウント設定（`automount`）を調整できます。([Microsoft Learn][9])
ただし、ここを雑に変えると別のアプリに副作用が出ることがあります（特に `fmask` など）。
→ **基本は「/mnt/c を開発の主戦場にしない」**が安全です😄([Docker Documentation][1])

---

## 6) 早見表：症状 → 原因 → まず見る場所 → 最短で直す📋✨

* 🧨 `bash\r` / `^M` が出る
  → 原因：CRLF
  → まず：VS Code右下 `CRLF/LF`
  → 直す：LFへ変換 + `.gitattributes` で固定 ([Visual Studio Code][5])

* 📭 マウントしたのに空っぽ
  → 原因：パス解釈違い（PowerShell/WSL混在）
  → まず：どのターミナルで実行したか
  → 直す：WSLならLinuxパス、PowerShellならWindowsパス。`-v host:container`形式を再確認 ([Docker Documentation][7])

* 🔒 `EACCES` / `Permission denied`
  → 原因：所有権/実行ビット/マウント先がWindows側
  → まず：プロジェクトが`/home/...`か`/mnt/c/...`か
  → 直す：WSL側に置く + node_modulesをvolume化 + 必要なら `-u node` ([Docker Documentation][1])

* 🏃‍♂️ ホットリロードが効かない/不安定
  → 原因：inotifyが来ない系（Windows側由来のbind mount）
  → まず：コード場所がWindows側か
  → 直す：WSLのLinuxファイルシステムへ移動 ([Docker Documentation][1])

---

## 7) Todo APIに適用！この章の“おすすめ完成形”🧩🏁

### ✅ ① 作業フォルダはWSL側に置く

例：

```bash
## WSL
mkdir -p ~/work
cd ~/work
## ここに todo-api を置く（git clone もここで）
```

### ✅ ② `.gitattributes` でLF固定（シェル・TS・YAML）

（さっきの例でOK👌）([Git][4])

### ✅ ③ Composeは「コードはbind」「node_modulesはvolume」

（さっきの例がそのまま使える😄）

---

## 8) AI活用テンプレ🤖✨（コピペで即戦力）

* 🧨 改行事故っぽい時
  「このエラーはCRLF/LFの問題の可能性ある？根拠と、最短の確認手順を3つ出して」

* 📭 マウントが空っぽ
  「この`docker run -v ...`がWindows/WSLどっちのパスとして解釈されてる？正しい書き方を2パターン（PowerShell / WSL）で」

* 🔒 EACCES
  「このEACCESを、(1)権限 (2)所有者 (3)node_modules置き場 の観点で切り分けるチェックリストを作って」

---

## 9) 合格チェック✅🎓（ここまでできたら第13章クリア！）

* [ ] `bash\r` を自分で再現して、LFに直せた😄
* [ ] `-v` のホストパスを「PowerShell/WSL」で書き分けできた🧭
* [ ] `EACCES` が出た時に、`/home` へ移す・node_modulesをvolume化する判断ができた📦
* [ ] ホットリロードが不安定な時に、inotify/置き場所を疑える👀 ([Docker Documentation][1])

---

次の第14章は、ここで出てきた「bind mount と volume、結局どっち？」を**判断できるようにする回**だよ〜⚖️😆

[1]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[2]: https://code.visualstudio.com/remote/advancedcontainers/improve-performance?utm_source=chatgpt.com "Improve disk performance"
[3]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
[4]: https://git-scm.com/docs/gitattributes?utm_source=chatgpt.com "Git - gitattributes Documentation"
[5]: https://code.visualstudio.com/docs/devcontainers/tips-and-tricks?utm_source=chatgpt.com "Dev Containers Tips and Tricks"
[6]: https://code.visualstudio.com/updates/v1_40?utm_source=chatgpt.com "October 2019 (version 1.40)"
[7]: https://docs.docker.com/engine/storage/bind-mounts/?utm_source=chatgpt.com "Bind mounts"
[8]: https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md?utm_source=chatgpt.com "docker-node/docs/BestPractices.md at main"
[9]: https://learn.microsoft.com/en-us/windows/wsl/wsl-config?utm_source=chatgpt.com "Advanced settings configuration in WSL"
