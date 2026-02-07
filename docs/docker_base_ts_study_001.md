# 第01章：Dockerってなに？コンテナとイメージの感覚をつかむ🐳✨

この章は「Dockerの正体」を、**むずかしい話ゼロで**つかむ回だよ〜！😄
そして最後に、**人生初コンテナ**を動かして「お、動いた！」まで行きます🎉

---

## この章のゴール🎯

次の3つを、あなたの言葉で言えるようになったら勝ち🏆✨

* **イメージ**：実行に必要なものが入った「設計図」📦
* **コンテナ**：その設計図から起動した「動いてる箱」🚀
* **レジストリ**：設計図（イメージ）を置いてある「倉庫」🏬（例：Docker Hub）

Docker公式の説明でも「イメージ＝実行に必要なもの一式をまとめた標準パッケージ」として整理されてるよ。([Docker Documentation][1])

---

## まずは超ざっくり理解しよ😆🧠

### 🍳 料理でたとえると…

* **イメージ**＝レシピ＋材料セット（固定）📖🥕
* **コンテナ**＝そのレシピで作って、いま火にかけてる鍋（実行中）🍲🔥

ポイントはこれ👇

* イメージは **増えにくい**（何度でも使い回す）♻️
* コンテナは **増えやすい**（起動するたび作られる）🐣🐣🐣
* 1つのイメージから、何個でもコンテナ作れる✨

---

## 「docker run」って何してるの？🤔▶️

結論：**イメージから新しいコンテナを作って、起動して、コマンドを走らせる**やつ！🚀
しかもイメージがPCになければ、**先に勝手に取りに行く（pull）**までやってくれる。([Docker Documentation][2])

---

## ハンズオン：人生初コンテナを動かす🎉🐳

ここから手を動かすよ〜！🧑‍💻✨
（ターミナルは VS Code のターミナルでもOK👌）

### 1) Dockerが動いてるか確認👀

まずはバージョン確認！

```bash
docker version
docker info
```

* `docker version` が出れば、まず第一関門クリア✅
* `docker info` は「Docker Engineが起動してるか」の健康診断🩺

もしここでコケたら、第2章でガッツリ直すけど、まずは次の「よくある詰まり」も見てね👇

---

### 2) hello-world を実行してみる🎈

```bash
docker run hello-world
```

✅ うまくいくと、途中でイメージを取得して（初回だけ）、最後に “Hello from Docker!” 的なメッセージが出るよ🎉
この `hello-world` はDocker公式の “Official Image” で、Docker Hub 側の情報もちゃんと整備されてるやつ👍([Docker Hub][3])

> ちなみに Docker Hub の `hello-world` ページには「Docker Desktop 4.37.1以降が必要」みたいな条件も書かれてるので、もし古い場合は更新が吉！([Docker Hub][3])

---

### 3) 「何が起きたか」を見える化する👁️📋

#### コンテナ一覧（停止中も含めて）を見る

```bash
docker ps -a
```

* `hello-world` はメッセージ出したら終了するタイプなので、だいたい **Exited** になってるはず😄

#### イメージ一覧を見る

```bash
docker images
```

* ここに `hello-world` が入ってたら「設計図をゲット済み」ってこと🎉

---

## もう一回 run すると何が変わる？🔁😳

同じコマンドをもう一度！

```bash
docker run hello-world
```

初回と違って…

* もうイメージはあるので、**ダウンロード工程が減る**（ことが多い）⚡
* でもコンテナは **毎回“新しく”作られる**🐣✨

この「イメージは再利用、コンテナは使い捨て気味」って感覚が、最初の超重要ポイントだよ💡

---

## よくある詰まりポイント集🪤😵‍💫

### ❌ `docker: command not found` / `docker コマンドが見つからない`

* Docker Desktop が起動してない
* PATHが通ってない（まれ）
* そもそもインストールできてない

Windowsへのインストールや要件はDocker公式手順にまとまってるよ。([Docker Documentation][4])

---

### ❌ WSL まわりで怒られる😣

Docker Desktop は **WSL 2 連携**が超重要になりがち。
Docker公式も「WSLを使うときの設定・確認手順」をちゃんと案内してるよ。([Docker Documentation][5])

よく使う確認・設定コマンド（覚えなくてOK、コピペでOK）👇

```powershell
wsl.exe --set-default-version 2
wsl.exe --list --verbose
```

---

## セキュリティの超大事メモ🛡️🔒

Docker Desktop は過去に **重大な脆弱性**が修正されたことがあるので、**アップデートは正義**⚠️
例として、CVE-2025-9074 は **Docker Desktop 4.44.3（2025-08-20）で修正**と公式に案内されてるよ。([Docker Documentation][6])

「最新版がどれか」はリリースノートで追える（段階配信で少し遅れて見えることもある）ので、更新が気になるときはここを見るのが安心！([Docker Documentation][7])

---

## AI活用コーナー🤖✨（理解が爆速になるやつ）

そのまま貼って使ってOK👌

### ① 用語を超やさしくしてもらう📘

* 「Dockerの **イメージ** と **コンテナ** の違いを、中学生にもわかる例えで説明して」

### ② runの裏側を一瞬で整理🧠

* 「`docker run hello-world` が内部でやっていることを、順番つきで箇条書きにして」

### ③ エラー文を“人間語”に翻訳🧾

* 「このエラー文を、原因候補トップ3と確認コマンドつきで説明して：
  （ここにエラーを貼る）」

---

## ミニチェックテスト🎓✅

次の質問にスラスラ答えられたら、今日はもう勝ち🏆✨

1. **イメージ**って何？
2. **コンテナ**って何？
3. `docker run` は何をしてる？（最低2つ言えたらOK）
4. `docker ps -a` と `docker images` は何が違う？

---

## まとめ🎉

* イメージ＝設計図📦、コンテナ＝動いてる箱🚀
* `docker run` は「なければ取る → 作る → 起動 → 実行」までやってくれる💡([Docker Documentation][2])
* hello-world を動かせたら、もうDocker初心者の最初の壁は越えた！🧱➡️🌈
* Docker Desktop は定期的に更新しよう（安全第一）🛡️([Docker Documentation][6])

---

次の第2章では、Windowsでハマりがちな「WSL2 / Docker Desktop / VS Code連携」を、**詰まりやすい順に**ぜんぶ潰していくよ🪛😄✨

[1]: https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/?utm_source=chatgpt.com "What is an image? | Docker Docs"
[2]: https://docs.docker.com/reference/cli/docker/container/run/?utm_source=chatgpt.com "docker container run"
[3]: https://hub.docker.com/_/hello-world?utm_source=chatgpt.com "hello-world - Official Image"
[4]: https://docs.docker.com/desktop/setup/install/windows-install/?utm_source=chatgpt.com "Install Docker Desktop on Windows - Docker Docs"
[5]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
[6]: https://docs.docker.com/security/security-announcements/?utm_source=chatgpt.com "Docker security announcements"
[7]: https://docs.docker.com/desktop/release-notes/?utm_source=chatgpt.com "Docker Desktop release notes"
