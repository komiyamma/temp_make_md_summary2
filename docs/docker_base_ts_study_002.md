# 第02章：Windowsでの準備（Docker Desktop / WSL2 / VS Code連携）🪟🔧🐳

この章は「最初にコケやすい所を全部つぶす章」です😄✨
ここを越えると、あとは手を動かすだけになります💪🔥

---

## この章のゴール🎯✨

章末でこうなってたら勝ちです🏆

* WindowsでもWSL（Ubuntu）でも `docker` が動く✅
* VS CodeからWSLのフォルダを開いて編集できる✅
* VS Codeの Dev Containers も使える状態になってる✅ ([Visual Studio Code][1])
* 「動かない時に見る場所」と「よくある罠の直し方」が手元にある✅

---

## まず全体像を1枚で理解しよう🗺️✨

イメージはこんな感じです👇

* **Windows**：Docker Desktop のアプリが動く🪟
* **WSL2（Ubuntu）**：Linux環境（開発で使う）🐧
* **Docker Desktop（WSL2 backend）**：DockerエンジンをWSL2上で動かす🐳
* **VS Code**：Windows側のVS Codeから、WSL内のプロジェクトを編集する🧑‍💻

ポイント：Docker DesktopはWSL2を使う設定が基本で、対応環境なら既定でONになってることが多いです✅ ([Docker Documentation][2])

---

## ステップ0：最低ラインだけ確認（ここで詰まりを予防）🧯

### ✅ Windowsの対応条件ざっくり

Docker Desktopの公式要件として、Windows 10/11 の特定ビルドや WSLの最低バージョンなどが明記されています。 ([Docker Documentation][3])
（この章では「要件を満たしている前提」で進めつつ、**満たしてない時の直し方**も後半に用意します😄）

---

## ステップ1：WSL2の状態チェック（PowerShellでOK）🔍

PowerShell（管理者じゃなくてもOK）で👇

```powershell
wsl --version
wsl -l -v
```

見るポイント👀✨

* `wsl --version` が表示される（WSLが新しめ）
* `wsl -l -v` で、使うUbuntuが **VERSION 2** になってる ✅ ([Docker Documentation][2])

### Ubuntuが無い / まだ入れてない場合🐣

まずはWSLのインストール（最近は1コマンドが多い）でOKです👇

```powershell
wsl --install
```

（既に入ってる人は次へGO🏃‍♂️💨）

---

## ステップ2：UbuntuをWSL2にそろえる（VERSION 1 の人はここが重要）⚠️

もし `wsl -l -v` で Ubuntu が VERSION 1 だったら👇

```powershell
wsl --set-version Ubuntu 2
wsl --set-default-version 2
```

これで「今後入れるディストリも基本WSL2」に寄せられます✅ ([Docker Documentation][2])

---

## ステップ3：Docker Desktop 側の“WSL2エンジン”を確認🧩🐳

Docker Desktop を起動して、設定でここをチェックします👇

* **Settings → General → “Use WSL 2 based engine”** がON
  （対応環境ならデフォルトONになりがち） ([Docker Documentation][2])

さらに👇

* **Settings → Resources → WSL Integration**

  * “Enable integration with my default WSL distro” をON
  * Ubuntu を使うなら Ubuntu をON ✅ ([Microsoft Learn][4])

> もし「WSL Integration」が見当たらない場合は、Windowsコンテナモードになってる可能性ありです。タスクバーのDockerメニューから **Linux containers に切り替え**がヒントになります🧠✨ ([Docker Documentation][2])

---

## ステップ4：Dockerが動くか“最短で”確認（Hello World）🎉

### ① Windows（PowerShell）で確認🪟

```powershell
docker --version
docker run hello-world
```

### ② WSL（Ubuntu）で確認🐧

Ubuntuを開いて👇

```bash
docker --version
docker run hello-world
```

この確認手順はMicrosoft側のWSL+Docker案内でも紹介されてる定番です✅ ([Microsoft Learn][4])

---

## ステップ5：VS Code を“WSL編集モード”にする🧑‍💻✨

ここが快適さの分かれ道です😆

### やること（超シンプル）

* VS Code に **Dev Containers** を入れる（後で使う） ([Visual Studio Code][1])
* そして「プロジェクトは **WSLの中（例：`~/projects`）** に置く」←超重要‼️

### なんでWSL内に置くの？📁

Docker公式のWSLベストプラクティスで、**bind mount（マウント）するならLinux側ファイルシステムに置くのが推奨**とされています。速度・ファイル監視（inotify）などで差が出やすいからです⚡ ([Docker Documentation][5])

---

## ここでミニ実践：Todo API用の作業場を作る🌱📦

Ubuntu（WSL）で👇

```bash
mkdir -p ~/projects/todo-api
cd ~/projects/todo-api
```

次に、Windows側のVS Codeから **WSLのフォルダを開く**（Remote WSL）で編集開始！🧑‍💻✨
（この「WSLの中を開く」流れが、後のDocker学習も一気に楽にします😄）

---

## VS Code の Dev Containers って何？（この章のうちに“入口だけ”）🚪🐳

Dev Containers は、**開発環境まるごとコンテナ化**して、VS Codeでそのまま開ける仕組みです✨
`devcontainer.json` に「どういう環境にするか」を書きます📝 ([Visual Studio Code][1])

しかもこの拡張は **Open Dev Containers Specification** に対応していて、環境定義を“ツールに依存しすぎない形”に寄せられます👍 ([Visual Studio Code][6])

このコース後半で超効いてきます🔥

---

## よくある詰まりポイント集（症状→原因→直し方）🪤😵‍💫

### 1) `docker` が動かない / “Docker Engine starting…” で止まる😇

まず確認👇

* Docker Desktop が起動してる？
* Docker Desktop の **WSL 2 engine** がON？ ([Docker Documentation][2])
* `wsl -l -v` で Ubuntu がVERSION 2？ ([Docker Documentation][2])

### 2) WSL内で `docker: command not found` 🥲

* Docker Desktop の **WSL Integration** で Ubuntu がONになってる？ ([Microsoft Learn][4])

### 3) 「WSL Integration」が設定に出てこない🤔

* Windowsコンテナモードの可能性 → **Linux containers に切り替え**を確認！ ([Docker Documentation][2])

### 4) “プロジェクトが重い / npm が遅い / 監視が効かない”🐢

* だいたい **Windows側（例：`C:\...`）のフォルダをマウントしてる**のが原因になりがち
  → **WSL側（`~/projects`）に置く**が推奨✅ ([Docker Documentation][5])

---

## AI活用コーナー🤖🔍（この章の使い方が一番効くやつ）

エラー出たら、こう投げるのが強いです👇✨
（GitHub Copilot / OpenAI Codex どっちでもOK）

### 🧠プロンプト例：原因候補トップ3を出させる

```text
Windows + Docker Desktop + WSL2 で docker が動きません。
以下のログ/エラーから、原因候補トップ3と確認手順を短く出してください。
（私は初心者なので、確認コマンドもセットで）
--- エラーここから ---
（貼る）
--- ここまで ---
```

### 🧠プロンプト例：手順を“最短チェックリスト化”

```text
この状況で「まず何を確認する？」を、上から順に5個のチェックリストにしてください。
1行ずつ、コマンド付きで。
```

---

## 章末チェック✅🎓（できたら次へ！）

次の3つが通ればOKです🏁✨

1. PowerShellで👇が通る

```powershell
docker run hello-world
```

2. Ubuntu（WSL）で👇が通る

```bash
docker run hello-world
```

3. プロジェクト用フォルダがWSL側にある（例：`~/projects/todo-api`）📁
   （これが後の章の快適さを決めます⚡） ([Docker Documentation][5])

---

## おまけ：覚えておくと助かる豆知識🫘✨

* Docker Desktop（WSL2 backend）のデータ保存場所は既定で `C:\Users\[USERNAME]\AppData\Local\Docker\wsl` あたりに置かれます（移動も設定から可能）💾 ([Docker Documentation][2])
* Docker Desktop 4.30以降の“新規インストール”では、以前あった `docker-desktop-data` が作られないケースがある（仕様変更）ので、古い記事と食い違っても焦らなくてOKです😄 ([Docker Documentation][2])

---

次の第03章では、いよいよ `run` で「とにかく動かす」体験に入ります🎉🐳
（ここまでできた人は、もう半分勝ってます💪😆）

[1]: https://code.visualstudio.com/docs/devcontainers/create-dev-container?utm_source=chatgpt.com "Create a Dev Container"
[2]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
[3]: https://docs.docker.com/desktop/setup/install/windows-install/?utm_source=chatgpt.com "Install Docker Desktop on Windows"
[4]: https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers?utm_source=chatgpt.com "Get started with Docker remote containers on WSL 2"
[5]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[6]: https://code.visualstudio.com/docs/devcontainers/containers?utm_source=chatgpt.com "Developing inside a Container"
