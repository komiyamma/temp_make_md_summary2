# 第11章：Compose Watchで“手放し更新”へ👀✨

この章はひとことで言うと、**「保存したら勝手にコンテナへ反映される」**を作る回です🪄
しかも、ただのホットリロードじゃなくて **「ファイルの種類によって反映方法を変える」** のがポイント！😎

---

## 1) Compose Watchって何が嬉しいの？🤩

Compose Watchは、`compose.yaml` に「どの変更を、どう反映するか」を書いておくと、
**ファイル保存 → 自動で sync / rebuild / restart** をやってくれる仕組みです👀✨ ([Docker Documentation][1])

しかも bind mount（ソースマウント）を置き換えるものではなく、**開発用の“相棒”**みたいな位置づけです🤝
「ここは同期したい」「ここは無視したい」を細かく書けるのが強い！ ([Docker Documentation][1])

---

## 2) まず覚えるのは3つのアクション💡

Compose Watchは、変更を見つけたら次のどれかをします👇 ([Docker Documentation][1])

## ✅ sync（同期）📤

* ホスト側の変更を、**そのままコンテナ内にコピー**してくれる
* ただし **アプリが自力でホットリロードできる前提**（例：Vite / tsx / Nodemon / Nodeのwatch など） ([Docker Documentation][1])

## ✅ rebuild（再ビルド）🏗️

* **イメージをビルドし直して、コンテナを入れ替える**
* 動きは `docker compose up --build <svc>` と同じ ([Docker Documentation][1])
* 典型：`package.json` やロックファイル更新、ビルド成果物が必要な変更

## ✅ sync+restart（同期して再起動）🔁

* コピーしたあと **コンテナのメインプロセスを再起動**
* 典型：`nginx.conf` みたいな **設定ファイル**更新（ビルド不要だけど再起動は必要） ([Docker Documentation][1])

---

## 3) Windowsでハマらないための最重要ポイント🪤💥

**プロジェクトは “Linux側のファイルシステム” に置くのが鉄板です**🧊
理由は2つ：

* Linuxコンテナがファイル変更イベント（inotify）を受け取りやすい
* Windows側（`/mnt/c` など）からのマウントは性能が落ちやすい ([Docker Documentation][2])

なのでおすすめは👇

* WSL2のUbuntu内の `~/projects/xxx` に置く
* VS Codeはそのフォルダを開く（Remote/WSLでOK）🪟➡️🐧

---

## 4) Compose Watchの“書き方”はここだけ覚えればOK🧠✨

Compose Watchは **`develop: watch:`** にルールを書く形式です📌 ([Docker Documentation][1])
そして重要ルール：

* `path` はプロジェクトディレクトリ相対
* 監視はディレクトリなら再帰
* **glob（`**/*.ts` みたいなやつ）は非対応**
* `.dockerignore` のルールが効く
* `.git` は自動で無視される ([Docker Documentation][1])

---

## 5) 実装例：Node/TSを “sync + rebuild” で気持ちよくする⚡

「ソースは sync」「依存関係は rebuild」が王道です👑
（**node_modulesは同期しない**のが基本！） ([Docker Documentation][1])

## `compose.yaml`（例：apiサービス）

```yaml
services:
  api:
    build: .
    command: npm run dev
    ports:
      - "3000:3000"
    develop:
      watch:
        # ① ソースコードは同期（保存→即反映）
        - action: sync
          path: ./src
          target: /app/src
          initial_sync: true
          ignore:
            - node_modules/

        # ② 依存関係が変わったら再ビルド（保存→作り直し）
        - action: rebuild
          path: package.json

        # （任意）ロックファイルも変わるなら、これもrebuild対象にすると安心
        - action: rebuild
          path: package-lock.json
```

ポイント：

* `ignore` のパターンは **その watch ルールの `path` からの相対**です🧩 ([Docker Documentation][1])
* `initial_sync: true` を付けると、watch開始前に「まず同期」をしてくれます🧹✨ ([Docker Documentation][1])

---

## 6) 起動コマンド：2つの流儀🕹️

## 流儀A：ログもまとめて見たい（簡単）📺

```bash
docker compose up --watch
```

これで **起動＋watch** まで一発です🚀 ([Docker Documentation][1])

## 流儀B：ログを分けたい（見やすい）🧠

watchのイベント（sync/rebuild）ってログが混ざりがちなんですよね😵‍💫
そういう時は、専用コマンドもあります👇 ([Docker Documentation][1])

* まず普通に起動：

```bash
docker compose up
```

* 別ターミナルで watch：

```bash
docker compose watch
```

---

## 7) “反映されてる感”の確認方法（超だいじ）🔍✨

## ✅ sync が効いてるか？

1. `src` のファイルを編集して保存💾
2. ターミナルに sync のログが出る👀
3. アプリ側（tsx / Node watch / nodemon / Vite等）が再読み込みする🔁

※ **Compose Watchはコピーするだけ**なので、アプリ側のwatchが無いと「反映はされるけど再起動されない」になります🙏
そういうファイルは `sync+restart` を使うのが手です🔁 ([Docker Documentation][1])

## ✅ rebuild が効いてるか？

1. `package.json` を編集して保存
2. 自動でビルドが走る🏗️
3. コンテナが入れ替わる（再作成される） ([Docker Documentation][1])

---

## 8) ミニ課題（10〜20分）🏁😺

## 課題A：sync体験⚡

* `src/hello.ts` の文字列を変えて保存
* 画面 or APIレスポンスが変わるのを確認🎉

## 課題B：rebuild体験🏗️

* `package.json` に適当な依存（軽いもの）を追加して保存
* 自動でrebuild→コンテナ入れ替えが起きるのを確認👀 ([Docker Documentation][1])

## 課題C：sync+restart体験🔁（任意）

* 例えば `config/dev.json` を作り、読み込んでるなら
  そのファイルを `sync+restart` 対象にして、保存→再起動を確認！

---

## 9) よくある詰まり集🧯（ここで9割助かる）

## 😭 変更しても何も起きない

* Composeのバージョンが古い（Watchは **Compose 2.22.0以降**が必要） ([Docker Documentation][1])
* `image:` だけのサービスをwatchしてる（Watchは **`build:` 前提**で、`image:` だけだと追跡しない） ([Docker Documentation][1])
* プロジェクトをWindows側に置いていてイベントが届きにくい（WSL側に置くのが安定） ([Docker Documentation][2])

## 😭 node_modulesが同期されて激重

* `ignore` に `node_modules/` を入れる（基本これ） ([Docker Documentation][1])
* そもそも Watchは `node_modules` を同期しないのが推奨（ネイティブコードを含むことがある） ([Docker Documentation][1])

## 😭 `ignore` 書いたのに無視されない

* `ignore` は **watchルールの `path` からの相対**です（ここが落とし穴）🪤 ([Docker Documentation][1])

## 😭 syncは動いてるのにアプリが反応しない

* Composeはコピーしただけ → アプリ側のwatchが必要
* そのファイルは `sync+restart` にするのが簡単な解決策🔁 ([Docker Documentation][1])

---

## 10) AI拡張で時短するコツ🤖✨（ただし最後は人間が確認！）

おすすめの使い方👇

* 「この構成の Node/TS で、Compose Watchの最適な watch ルール案を出して」
* 「同期対象・rebuild対象・sync+restart対象を分類して提案して」
* 「`ignore` に入れるべきもの（node_modules, dist, .git 等）を理由付きで列挙して」

そして、出てきた案をチェックするポイントは3つだけ✅

1. `build:` のサービスに入ってる？ ([Docker Documentation][1])
2. `path/target/ignore` の相対関係あってる？ ([Docker Documentation][1])
3. rebuild対象が広すぎない？（`src/` を rebuild にしちゃうと地獄😇）

---

## まとめ🎁

Compose Watchは **「保存→同期」** だけじゃなく、
**「保存→再ビルド」「保存→同期して再起動」** まで自動化できるのが本体です👀✨ ([Docker Documentation][1])

次の章（第12章）では、この“自動反映”の上に **VS Codeデバッグ（ブレークポイント）** を通して、さらに気持ちよくしていきます🧲🚦

[1]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[2]: https://docs.docker.com/desktop/features/wsl/best-practices/ "Best practices | Docker Docs"
