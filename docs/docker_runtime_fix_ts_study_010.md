# 第10章：最小Dockerfileを作る（まずはJS）🧱✨

この章は「**最小で再現できるDockerfile**」を、手を動かして“完成”させる回です🐳💨
ゴールはこれ👇

* ✅ `docker build` が通る
* ✅ `docker run` でJSが動く
* ✅ 依存は `npm ci` で毎回クリーンに入る
* ✅ ベースは **Active LTSのNode v24** を使う（安定路線） ([nodejs.org][1])

---

## 1) まず全体像を1分で理解しよう🧠✨

Dockerfileは「**アプリが動く箱（イメージ）を作るレシピ**」です🍳📄

* `FROM`：どの土台（Node入りOS）から始める？
* `WORKDIR`：作業する場所（フォルダ）どこ？
* `COPY`：必要なファイルを箱に入れる
* `RUN`：箱の中でコマンドを実行（例：依存インストール）
* `CMD`：箱を起動したときに動く“最後の命令”🚀

今回の土台は `node:24-bookworm-slim` を採用します🟢
`bookworm` みたいな名前は **Debianのリリース名**で、これを明示すると将来の揺れが減りやすいよ、という考え方です ([hub.docker.com][2])

---

## 2) 最小プロジェクトを用意する📁✨（ホストにNode不要ルート）

ここ、ちょっと気持ちいいポイントです😆✨
`npm init` や `npm i` も **DockerのNodeで実行**して、最初から揺れを減らします🔒

## フォルダ構成（完成形）🧩

```text
runtime-fixed-js/
  ├─ src/
  │   └─ index.js
  ├─ package.json
  ├─ package-lock.json
  └─ Dockerfile
```

## 2-1) フォルダとJSファイルを作る✍️

`runtime-fixed-js` を作って、`src/index.js` を作成👇

```js
const dayjs = require("dayjs");

console.log("Hello from container! 🐳✨");
console.log("Now:", dayjs().format("YYYY-MM-DD HH:mm:ss"));
```

## 2-2) `package.json` と lockfile を“コンテナのnpm”で作る📦🔧（PowerShell想定）

VS Codeのターミナルで、フォルダ直下で実行👇

```powershell
## package.json を作る
docker run --rm -it -v "${PWD}:/app" -w /app node:24-bookworm-slim npm init -y

## 依存を1個だけ入れる（lockfile を確実に作るため）
docker run --rm -it -v "${PWD}:/app" -w /app node:24-bookworm-slim npm i dayjs
```

これで `package-lock.json` ができて、次の `npm ci` が使える状態になります👍✨

---

## 3) 最小Dockerfileを書く🧱✨（この章の主役）

プロジェクト直下に `Dockerfile` を作って、これを書いてください👇

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
CMD ["node", "src/index.js"]
```

## 1行ずつ“意図”を理解しよう👀🧠

* `FROM node:24-bookworm-slim`
  Node入りの土台を選ぶ。v24はActive LTSで、基本はこの路線が安心 ([nodejs.org][1])

* `WORKDIR /app`
  これ以降の作業場所を `/app` に固定。迷子防止🧭

* `COPY package.json package-lock.json ./` → `RUN npm ci`
  **ここが型**です⚡
  依存定義だけ先に入れて `npm ci` することで、ソースをちょっと変えたくらいでは依存の層がキャッシュされやすい（速くなりやすい）
  そして `npm ci` は **lockfile前提のクリーンインストール**で、ズレたら止めてくれるのが強い ([docs.npmjs.com][3])

* `COPY . .`
  最後にソース全部を箱に入れる📦

* `CMD ["node", "src/index.js"]`
  起動したらこれを実行！🚀

---

## 4) ビルドして動かす🐳💨

プロジェクト直下で👇

```powershell
docker build -t runtime-fixed-js:dev .
docker run --rm runtime-fixed-js:dev
```

成功すると、こんな感じで出ます👇

* `Hello from container! 🐳✨`
* 日付が表示される🕒

---

## 5) “固定できてる？”を一瞬で確かめる✅🔁

## 5-1) Nodeの版を確認（コンテナの中で）🔍

```powershell
docker run --rm runtime-fixed-js:dev node -v
```

`v24...` になっていればOK🙆‍♂️（Active LTSの枝であることは公式表にも出ています） ([nodejs.org][1])

---

## 6) つまずきポイント集（ここで詰まりがち）💣🧯

## ❌ `npm ci` が「package-lock がない」って怒る

**原因**：`package-lock.json` が無い
**対処**：一度 `npm i` を実行して lockfile を作る（さっきの手順）
`npm ci` は lockfile 前提で、クリーンに入れるコマンドです ([docs.npmjs.com][3])

## ❌ `npm ci` が「package.json と lock の内容が違う」って怒る

**原因**：`package.json` を編集したのに lockfile を更新してない
**対処**：コンテナで `npm i` を実行して lock を更新 → その後 `npm ci` に戻す
`npm ci` は「ズレたら止める」が仕事です（えらい） ([docs.npmjs.com][3])

## ❌ ビルドが遅い（毎回依存を入れ直してる気がする）

**原因**：`COPY . .` が先に来てる、などでキャッシュが効かない
**対処**：依存系だけ先に `COPY` → `npm ci` → 最後にソース `COPY` の順にする（今のDockerfileがその形）
（一般論としても、Dockerは“キャッシュが効く並べ方”が重要） ([Docker Documentation][4])

---

## 7) ミニ演習（理解が一気に定着する）🎯🔥

## 演習A：依存を増やしてみる📦✨

1. `src/index.js` に1行足して、例えば `dayjs().add(1, "day")` を表示
2. `docker build` → `docker run`
3. 「JSだけ変えたのに、依存インストールは再実行されにくい」を体感⚡

## 演習B：起動時に“固定チェックログ”を出す✅

`src/index.js` に👇を追加（超おすすめ癖）

```js
console.log("Node:", process.version);
```

---

## 8) AIに手伝わせるコツ🤖✨（速く・でも丸投げしない）

* **GitHubのGitHub Copilot** に頼むなら：
  「このフォルダ構成で最小のDockerfileとpackage.jsonを作って。`npm ci` 前提で、Nodeは `node:24-bookworm-slim`」
* **OpenAI Codex** 系に頼むなら：
  「Dockerfileの各行の意図を“初心者向け”にコメント付きで説明して」

そして最後は必ず自分の目で👇だけ確認👀✅

* `COPY package*.json → npm ci → COPY .` の順になってる？
* `npm ci` を使ってる？（`npm install`じゃない？） ([docs.npmjs.com][3])

---

## まとめ🎁✨

この章で手に入れたのは、**最小で再現できるDockerfileの“型”**です🧱✨
特にこの2つが核👇

* `node:24-bookworm-slim` で土台を固定（安定路線） ([nodejs.org][1])
* `npm ci` で依存を毎回クリーンに揃える ([docs.npmjs.com][3])

次の章（第11章）は、`npm ci` をもっと味方につけて「ズレを検知して直す」運用に入ります🧼📦🔥

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://hub.docker.com/_/node?utm_source=chatgpt.com "node - Official Image"
[3]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[4]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
