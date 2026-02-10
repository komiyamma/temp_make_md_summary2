# 第04章：プロジェクトの最小セットを作る📦

## 1) この章のゴール🎯

* **TypeScriptで動くAPIサーバ**を1本だけ作る（エンドポイントは2つでOK😊）
* **ビルドして起動できる**（`npm run build` → `npm start`）✨
* 次章以降（ホットリロード/テスト/Lint/Compose）で育てやすい形にしておく🧩

ここでは **Node v24（Active LTS）** が中心の世代感で進めます。([nodejs.org][1])
TypeScript は現時点の最新版として **5.9.3** を基準にします。([npmjs.com][2])

---

## 2) まず作る“最小API”の完成イメージ🧠✨

* `GET /health` → `{ ok: true }`
* `GET /hello?name=komi` → `{ message: "Hello, komi!" }`

フレームワークは **Express v5** を使います（すでに正式リリース済み）。([expressjs.com][3])
Express 5 は Node 18+ が要件なので、Node 24なら余裕でOKです👍([expressjs.com][4])

---

## 3) 作業手順（コピペで進めてOK）🛠️✨

### Step 0: フォルダ作成 → VS Codeで開く📂

PowerShellでOKです😊

```bash
mkdir dx-min-api
cd dx-min-api
code .
```

---

### Step 1: npmプロジェクトを初期化📦

```bash
npm init -y
```

---

### Step 2: 依存関係を入れる📥

**実行時**：Express
**開発時**：TypeScript・Node型・Express型

```bash
npm i express
npm i -D typescript @types/node @types/express
```

ポイント：`@types/express` は Express v5 でも使います（v4と混ぜないのが大事！）🧯
「express@5 なら @types/express@5 を使う」が基本です。([GitHub][5])

---

### Step 3: tsconfig.json を作る🧩

まず雛形を作ってから、内容を上書きします✍️

```bash
npx tsc --init
```

次に `tsconfig.json` をこれに置き換え👇（“後で育てやすい最小”に寄せてます😊）

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",

    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "skipLibCheck": true,

    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src"]
}
```

TypeScript 5.9 系の話題（新機能や方向性）は公式リリースノートで追えます👀([typescriptlang.org][6])

---

### Step 4: package.json の scripts を整える🧰

`package.json` の `scripts` をこんな感じにします👇（**最低限**！）

```json
{
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "start": "node dist/server.js"
  }
}
```

---

### Step 5: ソースを作る（育てやすい2ファイル構成）🌱

`src` フォルダを作って、2ファイル置きます。

```bash
mkdir src
```

#### `src/app.ts`（アプリ本体：テストしやすい形）🧠

```ts
import express from "express";

export function createApp() {
  const app = express();

  app.get("/health", (_req, res) => {
    res.json({ ok: true });
  });

  app.get("/hello", (req, res) => {
    const name =
      typeof req.query.name === "string" && req.query.name.trim()
        ? req.query.name.trim()
        : "world";

    res.json({ message: `Hello, ${name}!` });
  });

  return app;
}
```

#### `src/server.ts`（起動だけ担当：後でDocker/Composeに乗せやすい）🚀

```ts
import { createApp } from "./app.js";

const app = createApp();

const port = Number(process.env.PORT ?? 3000);

app.listen(port, () => {
  console.log(`✅ Server running: http://localhost:${port}`);
});
```

> `./app.js` になってるのは **NodeNext（ESM）運用の“あるある”**対策です🙂
> ここが `./app` のままだと、将来ハマりやすいので先に安全側へ寄せてます🧯

---

### Step 6: ビルドして起動する▶️

```bash
npm run build
npm start
```

ブラウザで確認👀✨

* `http://localhost:3000/health`
* `http://localhost:3000/hello?name=komiyanma`

PowerShellでcurlでもOK😄

```bash
curl http://localhost:3000/health
curl "http://localhost:3000/hello?name=komi"
```

---

## 4) ここで“あえて”入れないもの🚫（次章で入れるやつ）

この章は土台づくりなので、いったん入れません🙂

* ホットリロード（次のホットリロード編で✨）
* テスト（テスト編で🧪）
* ESLint/Prettier/Biome（Lint/整形編で🧹）
* Docker/Compose（ワンコマンド化編で🧱）

入れない理由はシンプルで、**最初から全部盛るとトラブル時に原因が分からなくなる**からです😇
まず「動く」を作って、1個ずつ足していくのが最短ルート🏃‍♂️💨

---

## 5) よくある詰まりポイント集💣（先に潰す）

### ✅ 1) `Cannot use import statement outside a module` 系

* `tsconfig.json` の `module/moduleResolution` が `NodeNext` になってるか確認👀
* `src/server.ts` の import が `./app.js` になってるか確認🔍

### ✅ 2) `EADDRINUSE: address already in use :::3000`

* 3000番を誰かが使ってます😅
  → `PORT=3001` で起動（PowerShell）👇

```bash
$env:PORT=3001; npm start
```

### ✅ 3) 型が合わない/補完が弱い

* `@types/node` と `@types/express` が入ってるか確認🧩([npmjs.com][7])
* VS Code を一回リロード（`Ctrl+Shift+P` → “Reload Window”）で直ることも多いです🔄

---

## 6) ミニ課題（10〜15分）📝✨

### 課題A：`GET /time` を追加⏰

* 返すJSON：`{ now: "2026-02-10T..." }` みたいなISO文字列
  ヒント：`new Date().toISOString()` 🧠

### 課題B：`name` が空文字のときは `world` にする🌍

* すでにそうしてるけど、意図をコメントで説明してみよう✍️🙂

### 課題C：`/hello` に `lang=ja` が来たら日本語で返す🇯🇵

* `Hello` → `こんにちは` に切り替え✨
* 条件分岐の練習です😄

---

## 7) AI拡張での時短ワザ🤖✨（“差分確認”がコツ）

AIに「全部書かせる」より、**小さく頼んで、差分を眺めて採用**が安全です🧯

### 使えるお願いテンプレ（そのまま貼ってOK）📌

* 「`src/app.ts` に `/time` を追加して。既存の書き方に合わせて、余計な依存は増やさないで」
* 「`tsconfig.json` を NodeNext前提で、初心者がハマらない設定にして。理由も1行ずつコメントで」
* 「Express 5 + TypeScript で query param を安全に扱う最小例を出して（型ガチガチにしすぎない）」

最後にやることはこれ👇

* **変更点（diff）だけ見て**「今の段階で理解できる」ものだけ採用✅
* わからない設定は“保留”でOK（後の章で拾える）🙂

---

## 8) できたかチェック✅（ここまでの完成条件）

* `npm run build` が通る✅
* `npm start` で起動できる✅
* `/health` が `{ ok: true }` を返す✅
* `/hello?name=xxx` がメッセージを返す✅

---

次の章からは、この土台に「起動を迷わない形（ワンコマンド）」を被せていきます🧷✨
もし今の時点で「Expressじゃなくて別がいい（Fastifyとか）」みたいな好みがあれば、同じ“最小セット”をその流儀で作り直す版も出せます😄👍

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[3]: https://expressjs.com/2024/10/15/v5-release.html?utm_source=chatgpt.com "Introducing Express v5: A New Era for the Node. ..."
[4]: https://expressjs.com/ja/5x/api.html?utm_source=chatgpt.com "Express 5.x - API リファレンス"
[5]: https://github.com/DefinitelyTyped/DefinitelyTyped/discussions/71444?utm_source=chatgpt.com "Issue with the current [@types/express] upgrade #71444"
[6]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[7]: https://www.npmjs.com/package/%40types/express?utm_source=chatgpt.com "types/express"
