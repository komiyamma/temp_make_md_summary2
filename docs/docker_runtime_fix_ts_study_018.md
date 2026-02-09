# 第18章：Composeで“開発用の型”を作る📄✨

この章は、**「長い `docker run ...` を卒業して、`docker compose up` だけで開発を始める」**回です😆💨
ここで“型”を作れると、以後の章がぜんぶラクになります👍

---

#### この章でできるようになること🎯

* `compose.yaml`（または `compose.yml`）を置いて、**`docker compose up` で起動**できる🆙
* **ソースをマウント**して、編集→反映が速い📝⚡
* **node_modules をホストと混ぜない**（地獄回避）💣➡️😇

> Composeファイルは、作業フォルダに **`compose.yaml`（推奨）/ `compose.yml`** を置けばOKです📄
> 旧名の `docker-compose.yml` も互換で読めます。([Docker Documentation][1])

---

## 1) Composeって何がうれしいの？🤔🧩

`docker run` で開発環境を作ると、こうなりがち👇

* ポート指定、マウント、コマンド…が**長い**😵‍💫
* チームや未来の自分が、**同じ起動手順を再現できない**😇

Composeにすると👇

* 起動手順を **YAMLに固定**できる📌
* 以後は **`docker compose up` / `down` / `logs`** で運用できる📎([Docker Documentation][1])

---

## 2) まずは“開発用の最小compose”を書こう✍️🐳

ファイル名は **`compose.yaml`**（推奨）でいきます（`compose.yml` でもOK）📄✨
※最近のComposeでは、トップレベルの `version:` は **obsolete（書くと警告）** です。([Docker Documentation][2])

#### ✅ 最小構成（Node固定 + ソース共有 + node_modulesはvolume）

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    command: npm run dev

volumes:
  node_modules:
```

**これだけで**「開発の型」ができます🥳🎉

* `build: .` → 手元の `Dockerfile` からイメージ作る🧱
* `ports` → ブラウザで見られるようにする🌐
* `volumes`

  * `.:/app` → ソースを共有📝
  * `node_modules:/app/node_modules` → **依存だけはコンテナ側に隔離**（重要）🔒

---

## 3) 起動コマンドはこれだけ✅🚀

```bash
docker compose up --build
```

止める（後片付け）🧹

```bash
docker compose down
```

ログを見る👀

```bash
docker compose logs -f
```

> これらの基本コマンドは公式の “Key commands” にも載っています📘([Docker Documentation][1])

---

## 4) なぜ node_modules を volume にするの？💣📦➡️😇

ここ、初心者がほぼ100%踏みます😂

### 🔥 事故パターン

`.:/app` をマウントすると、コンテナ内の `/app` が **ホストの中身で上書き**されます。
つまり、コンテナ内で入れた `/app/node_modules` も、消えたように見える…😵‍💫

### ✅ 回避策

`/app/node_modules` だけ別枠で **named volume** を刺すと、
「ソースはホスト共有」＋「依存はコンテナ内」になります✨

---

## 5) Windowsで詰まりやすいポイント🪟⚠️（ここ超重要）

### ① マウントが遅い／監視が効かない😢

Windows環境だと、置き場所によっては

* ファイル共有が遅い🐢
* “変更検知”（inotify）が届かず、ホットリロードが動かない🫠
  が起きやすいです。

公式のおすすめは超シンプル👇
**バインドマウントするプロジェクトは、Linux（WSL）のファイルシステム側に置く**のが高パフォーマンスで、変更イベントも届きやすいよ、という話です。([Docker Documentation][3])

イメージとしては👇

* ✅ 速い：`\\wsl$\<distro>\home\<user>\project`（WSL側）
* ❌ 遅くなりがち：`C:\...` を `/mnt/c/...` でマウント

---

### ② それでもホットリロードが効かない時🧯👀

開発サーバや監視ツールによっては、ポーリングが必要なことがあります（特にWindows絡み）😅
よくある回避の方向性👇

* 環境変数でポーリング有効化（例：`CHOKIDAR_USEPOLLING=1` 系）
* `npm run dev` 側の監視設定をポーリング寄りにする

（このへんは第19章の “watch” でも整理します👀🔁）

---

## 6) 2026っぽい強化：Compose Watch も知っておく👁️✨

最近のComposeには **ファイル変更を見て、同期や再起動をしてくれる watch 機能**があります。
使い方は、`compose.yaml` に `develop: watch:` を書いて、**`docker compose up --watch`** です。([Docker Documentation][4])

例（雰囲気だけ掴めればOK）👇

```yaml
services:
  app:
    build: .
    command: npm run dev
    develop:
      watch:
        - action: sync
          path: .
          target: /app
          ignore:
            - node_modules/
```

* `sync`：ファイルをコンテナへ同期
* `sync+restart`：同期して再起動
* `restart` / `sync+exec`：より高度（必要になったらでOK）([Docker Documentation][5])

> 「マウントが重い」「監視が不安定」みたいな時の“別ルート”として覚えておくと強いです💪

---

## 7) ミニ演習🧪🎮（10分でできる）

### 演習A：まず動かす🚀

1. `compose.yaml` を作る
2. `docker compose up --build`
3. ブラウザで `http://localhost:3000` を開く🌐

### 演習B：node_modules を“わざと”壊して直す🧨➡️🛠️

1. `volumes` の `node_modules:/app/node_modules` を一旦消して起動
2. 何が起きるか観察（エラーや挙動）👀
3. 元に戻して、**安定する理由を言語化**🧠✨

### 演習C：依存を入れ直したい時🧽

「node_modules（volume）を捨てて入れ直す」👇

```bash
docker compose down -v
docker compose up --build
```

---

## まとめ🏁🎉

* Composeで **開発起動の型**ができたら勝ち🏆
* `.:/app` + `node_modules volume` が、初心者の事故を消してくれる🧯
* Windowsは **WSL側にプロジェクトを置く**と快適になりやすい📌([Docker Documentation][3])
* 余裕が出たら **Compose Watch** も選択肢👀([Docker Documentation][4])

---

次の第19章（watch）につながる“布石”として、**`npm run dev` をどう作るか**（Nodeの `--watch` / `tsx` / `tsc -w` どれにするか）も、ここから一気に気持ちよく進められます😆🔥

[1]: https://docs.docker.com/compose/intro/compose-application-model/ "How Compose works | Docker Docs"
[2]: https://docs.docker.com/reference/compose-file/version-and-name/ "Version and name top-level elements | Docker Docs"
[3]: https://docs.docker.com/desktop/features/wsl/best-practices/ "Best practices | Docker Docs"
[4]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[5]: https://docs.docker.com/reference/compose-file/develop/ "Compose Develop Specification | Docker Docs"
