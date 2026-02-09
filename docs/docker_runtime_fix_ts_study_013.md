# 第13章：`.dockerignore` を入れて“地味に爆速”🚀🧹

この章は、ひとことで言うと **「Docker ビルドに持ち込む荷物を減らす」** です📦✨
荷物（＝ビルドコンテキスト）が小さくなると、ビルドが速くなって、事故も減って、秘密も漏れにくくなります😆🔐

---

## 1) まず結論：`.dockerignore` は“引っ越しの荷造りリスト”📦📝

`docker build` するとき、Docker は「ビルドに使う材料一式（＝ビルドコンテキスト）」をビルダーに渡します。
このとき `.dockerignore` があると、**マッチしたファイル・フォルダをコンテキストから外してから**渡してくれます🚚💨 ([Docker Documentation][1])

つまり…

* `node_modules/`（激重）を送らない → 速い⚡
* `.git/`（履歴の塊）を送らない → 速い⚡
* `.env`（秘密）を送らない → 安全🔐

Docker 公式も「関係ないファイルは `.dockerignore` で除外しよう」と明言してます👍 ([Docker Documentation][2])

---

## 2) “速くなるポイント”はここ⚡（地味だけど効く）

ビルドログに、こんな行を見たことない？👀

* `transferring context: xxxMB`

これ、**「材料の搬入」**です🚛
ここが大きいほど、毎回のビルドが遅くなりがちです。`.dockerignore` はこの搬入をスリム化します🧹✨ ([Docker Documentation][1])

---

## 3) 最小テンプレ：Node/TSで“とりあえず勝つ” `.dockerignore` 🏆

まずはこれでOKです（あとで増減できる🙆‍♂️）

```text
## 依存（ホストのは持ち込まない）
node_modules

## ビルド成果物（コンテナ内で build する想定なら除外）
dist

## Git（履歴はビルドに不要）
.git

## ログ・キャッシュ系
npm-debug.log
yarn-error.log
pnpm-debug.log
.DS_Store

## エディタ・OS系
.vscode
.idea

## テスト/カバレッジ
coverage

## 秘密系（うっかり入れない）
.env
.env.*
```

### 💡 `dist` を ignore していい条件

* ✅ コンテナ内で `npm run build` して `dist/` を作る → ignore でOK
* ⚠️ ホストでビルド済み `dist/` をそのまま `COPY` したい → ignore しない方がラク

---

## 4) `.dockerignore` の“基本ルール”だけ覚えよう🧠✨

### ルールA：置き場所は「ビルドコンテキストのルート」📁

`docker build .` の **`.`（ドット）** がコンテキストです。
つまり **そのフォルダ直下**に `.dockerignore` が必要です🧷 ([Docker Documentation][1])

### ルールB：書き方は `.gitignore` っぽい🎯

Docker 公式も「`.gitignore` に似たパターン」と言ってます👌 ([Docker Documentation][2])

### ルールC：`**` が使える（全部の階層に効かせたいとき）🌲

たとえば `**/*.log` みたいな指定ができます。Docker のビルドコンテキスト解説に例が出ています📌 ([Docker Documentation][1])

### ルールD：`Dockerfile` 自体も ignore できる（でもビルドは動く）😲

Docker は `.dockerignore` で `Dockerfile` や `.dockerignore` を除外しても、**ビルドに必要なので別枠でビルダーに送る**と説明しています。
その代わり、`COPY` / `ADD` でイメージに混ぜられなくなります🧼 ([Docker Documentation][1])

---

## 5) 体感してみよう：ビルド前後で“搬入サイズ”を見る👀⚡

### 手順1：まずはログをよく見える形でビルド

```powershell
docker build --progress=plain -t runtime-fixed-demo .
```

ログに出る `transferring context:` のサイズをメモ📝✨

### 手順2：`.dockerignore` を入れてもう一回

同じコマンドでもう一度ビルド🚀
`transferring context:` が **ガクッと減ったら勝ち**です🥳

---

## 6) つまずきポイント集（ここで詰まる人が多い）💣

### つまずき①：「無視されてる気がする…」→ だいたい **マウント（volumes）** です🌀

`.dockerignore` は **ビルド時の話**。
でも `volumes: - .:/app` みたいにフォルダをマウントすると、**ホストのファイルが実行時に見えます**👻

「イメージには入ってないのに、コンテナの中には見える」みたいな現象が起きます。Docker フォーラムでもこのパターンが指摘されています👍 ([Docker Community Forums][3])

✅ 見分け方（イメージの中身だけ見る）

```powershell
docker run --rm runtime-fixed-demo ls -la
```

---

### つまずき②：`.dockerignore` の置き場所が違う📁❌

`docker build` の最後の引数（例：`.`）がコンテキストです。
そこに `.dockerignore` がないと効きません。コンテキストの説明は公式にあります📌 ([Docker Documentation][1])

---

### つまずき③：除外しすぎて `COPY` が失敗する😇

たとえば `dist` を ignore したのに、Dockerfile で `COPY dist ./dist` してたら当然コケます💥
「コンテキストに無いものは `COPY` できない」ってことです。

---

### つまずき④：Dockerfileごとに ignore を変えたい（ちょい上級）🧠

Docker は **Dockerfile専用の ignore ファイル**（例：`build.Dockerfile.dockerignore`）も扱えます。
ルートの `.dockerignore` より **Dockerfile専用の方が優先**されます🎯 ([Docker Documentation][1])

「lint用Dockerfile」「test用Dockerfile」みたいに複数あるときに便利です👌

---

## 7) 最短チェックリスト✅✨

* ✅ `.dockerignore` はコンテキスト直下にある
* ✅ `node_modules` / `.git` / `coverage` / `.env` は基本 ignore
* ✅ `docker build --progress=plain` で `transferring context` が小さくなった
* ✅ “コンテナ内に見える”のがマウント由来じゃないか確認した

---

## 8) Copilot / Codex に投げる“良い一言”🤖✨

「Node+TS の一般的な構成を前提に、`node_modules`・`.git`・`dist`・`coverage`・`.env`・ログ・エディタ設定を除外する `.dockerignore` を作って。`dist` はコンテナ内 build 前提で除外してOK。必要ならコメントも付けて。」

---

## まとめ🎁

`.dockerignore` は **速さ**にも **安全**にも効く、コスパ最強の1枚です🧹⚡🔐
次の章（実行モードの分け方🎭）に進むと、「開発」と「本番」で何を入れる/入れないが、もっと気持ちよく整理できますよ😆✨

[1]: https://docs.docker.com/build/concepts/context/?utm_source=chatgpt.com "Build context"
[2]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
[3]: https://forums.docker.com/t/dockerignore-not-work/148865?utm_source=chatgpt.com "dockerignore not work - General"
