# 第13章：ログはstdoutへ：まず“見える化”📜👀

この章は「本番で困った時、**ログだけで状況が追える**」状態を作る回だよ💪
コンテナ運用って、最終的に **“ログが命綱”** になりがち😇（逆にログが弱いと、原因不明で詰みます💥）

---

## この章のゴール🏁✨

ここまでできたら勝ち🎉

* ✅ **ログはファイルじゃなく stdout/stderr に出す**（コンテナの基本）
* ✅ ログを **JSON（構造化ログ）** で出す（検索しやすい）
* ✅ **アクセスログ**（どのURLに何msかかった？）を最低限入れる
* ✅ **requestId** を付けて「この1リクエストのログ」を追えるようにする
* ✅ エラー時に **requestId を返して**「そのIDのログ見て！」ができる

---

## 1) なんで stdout に出すの？🤔➡️📤

コンテナでは「ログファイルを育てる」より、**プロセスが stdout に吐く**のが基本形🧠
そしてログの収集・保存・検索は外側（プラットフォーム）がやってくれる、という考え方だよ🚀
これは “ログはイベントストリーム” という有名な原則にもそのまま載ってる📌 ([12 Factor][1])

さらに、Cloud 環境（例：Google Cloud の Cloud Run）では **stdout/stderr のログが Cloud Logging に自動で送られる**ので、まずはそこに素直に乗せるのが最短ルート💨 ([Google Cloud Documentation][2])

---

## 2) 「構造化ログ」ってなに？🧩📦

ログをただの文字列で出すと、あとで検索がつらい😵
そこで **JSONで出す**と、ログが `jsonPayload` として扱われ、**特定フィールドで検索したり、絞り込みが強くなる**よ✨ ([Google Cloud Documentation][3])

例：こんな感じの1行JSONログを出す（※このあと実装するよ）👇

```txt
{"level":"info","msg":"user fetched","requestId":"...","userId":123,"time":"..."}
```

---

## 3) “最低限の良いログ”の設計🧠📋

まずはこれだけ入っていればOKライン✅（欲張り禁止😆）

## まず入れるキー（おすすめ）🧷

* `msg`：短い説明（何が起きた？）
* `level`：info / warn / error（重要度）
* `requestId`：1リクエストの紐づけID
* `method` / `path` / `statusCode`：アクセスログの核
* `durationMs`：どれくらい時間かかった？
* `err`：エラー情報（stack含む）

## 絶対に入れないもの🙅‍♂️🔑

* パスワード、APIキー、トークン、Cookieの中身、Authorizationヘッダ
  → これはログに出した瞬間に事故率が跳ね上がる💥

---

## 4) ハンズオン：Express + Pino で“速くて使いやすい”ログを作る🌲🚀

ここでは **Pino + pino-http** を使うよ。
Pino は **JSONで高速にログを吐く**のが得意で、Web APIの本番ログに相性が良い👌 ([betterstack.com][4])
`pino-http` は **アクセスログ + request単位の紐づけ**をやりやすくするミドルウェアだよ📌 ([GitHub][5])

---

## 4-1) 依存を入れる📦

```bash
npm i pino pino-http
npm i -D @types/pino-http
```

> TypeScript構成によっては型が不要な場合もあるけど、入れておくと安心😌✨

---

## 4-2) logger を作る（src/logger.ts）🧱

```ts
// src/logger.ts
import pino from "pino";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  // PinoはJSONで吐くのが基本（本番向き）
  // ローカルで見やすくしたいのは後半でやるよ😉
});
```

---

## 4-3) requestId 付きのアクセスログを入れる（src/httpLogger.ts）🪪🧵

```ts
// src/httpLogger.ts
import pinoHttp from "pino-http";
import { randomUUID } from "node:crypto";

export const httpLogger = pinoHttp({
  // 1リクエストに1IDを付与
  genReqId: (req, res) => {
    const incoming = req.headers["x-request-id"];
    const requestId = typeof incoming === "string" && incoming.length > 0 ? incoming : randomUUID();
    res.setHeader("x-request-id", requestId);
    return requestId;
  },

  // 自動アクセスログ（method, url, status, responseTimeなど）
  autoLogging: true,

  // 余計な情報を減らして「必要最低限」に寄せる（初心者向け）
  serializers: {
    req(req) {
      return { method: req.method, url: req.url };
    },
    res(res) {
      return { statusCode: res.statusCode };
    },
  },

  // ログに毎回追加したい情報（ここでは requestId を明示）
  customProps(req) {
    return { requestId: req.id };
  },
});
```

---

## 4-4) Express に組み込む（src/app.ts）🧩

```ts
import express from "express";
import { httpLogger } from "./httpLogger";
import { logger } from "./logger";

const app = express();

app.use(httpLogger); // ← いちばん上の方に置くのがコツ💡

app.get("/hello", (req, res) => {
  // pino-http は req.log を生やしてくれる（requestIdが自動で付く）
  req.log.info({ feature: "hello" }, "hello endpoint called");
  res.json({ ok: true, requestId: req.id });
});

// 例：エラーをわざと起こす
app.get("/boom", () => {
  throw new Error("boom!");
});

// エラーハンドラ（重要🔥）
app.use((err: unknown, req: express.Request, res: express.Response, _next: express.NextFunction) => {
  req.log.error({ err }, "unhandled error");
  res.status(500).json({ ok: false, requestId: req.id });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, "0.0.0.0", () => {
  logger.info({ port }, "server started");
});

export default app;
```

ここで起きてること🎯

* アクセスごとに `requestId` が発行される🪪
* `req.log.*` を使うと **その requestId が勝手にログに入る**🧵
* エラーが起きたらログに残して、レスポンスにも `requestId` を返せる📩

---

## 5) Docker で動かしてログを見る🐳👀

例：`curl` で叩く

```bash
curl -i http://localhost:3000/hello
curl -i http://localhost:3000/boom
```

ログが JSON で1行ずつ出てればOK🎉
Cloud Run みたいな環境だと、その stdout が **Cloud Logging に流れて検索できる**ようになるよ📌 ([Google Cloud Documentation][2])

---

## 6) Cloud Logging で“探しやすいログ”にするコツ🔎✨

構造化ログ（JSON）だと、フィールドで検索がしやすい。
公式にも「JSONオブジェクトだと `jsonPayload` になって検索・インデックスが強い」って説明があるよ📌 ([Google Cloud Documentation][3])

おすすめの検索軸（例）🎯

* `jsonPayload.requestId = "..."`（この1件の流れを追う）
* `severity>=ERROR`（エラーだけ拾う）
  ※Cloud Runログは Cloud Logging と連携して、エラー検出（Error Reporting）にもつながる動きがあるよ ([Qiita][6])

---

## 7) ローカルで“見やすくしたい”場合（おまけ）👓✨

本番は JSON のままが基本。
ローカルだけ見やすくするなら `pino-pretty` を **開発時だけ** 使うのが定番だよ（※本番で有効にすると、構造化が崩れて検索性が落ちやすいので注意⚠️）

（今回は章の本筋じゃないので、やるなら「devスクリプトだけで有効化」くらいに留めよう😌）

---

## 8) よくある詰まりポイントTop3😵‍💫🛠️

## ❶ ログが Cloud 側で見つからない

* まず stdout/stderr に出てる？（ファイルに書いてない？）
* Cloud Run は stdout/stderr のログを Cloud Logging に送る前提だよ📌 ([Google Cloud Documentation][2])

## ❷ JSONログが“ただの文字列”扱いになる

* ログが **1行JSON** になってる？（途中で改行してない？）
* 余計な整形（pretty出力）が混ざってない？（本番は避ける）

## ❸ requestId がログに出ない

* `app.use(httpLogger)` がルーティングより後ろにない？
* `console.log` じゃなく `req.log.info(...)` を使ってる？

---

## 9) ミニ課題🧪🔥（5〜15分）

1. `/users/:id` を作って、

* `req.log.info({ userId: id }, "user fetched")` を入れる👤

2. `/users/:id` でエラーをわざと投げて、

* エラー時レスポンスに `requestId` が入ってるか確認✅

3. その `requestId` でログを検索して、流れが追えるかチェック🔎

---

## 10) AIに投げるプロンプト例🤖💬

* 「Express + pino-http で requestId を付けて、全ログに含める最小コードを書いて」
* 「このエラーハンドラに、機密情報をログに出さない対策（redact案）も足して」
* 「アクセスログを“うるさすぎない”粒度に調整する方針を提案して」

---

## この章のまとめ📌✨

* ログは **stdout/stderr** に出すのがコンテナの基本📤（イベントストリーム） ([12 Factor][1])
* **JSON（構造化ログ）** にすると後がめちゃ楽🔎 ([Google Cloud Documentation][3])
* **requestId** があると「その1件」を追える🧵
* エラー時に requestId を返せると、運用で強い💪

---

次の章（第14章）は、デプロイやスケール時に突然プロセスが止められる世界で生き残るための **Graceful shutdown（SIGTERM対応）** に入るよ🧯⏳

[1]: https://12factor.net/logs?utm_source=chatgpt.com "Treat logs as event streams"
[2]: https://docs.cloud.google.com/run/docs/logging?utm_source=chatgpt.com "Logging and viewing logs in Cloud Run"
[3]: https://docs.cloud.google.com/logging/docs/structured-logging?utm_source=chatgpt.com "Structured logging | Cloud Logging"
[4]: https://betterstack.com/community/guides/logging/how-to-install-setup-and-use-pino-to-log-node-js-applications/?utm_source=chatgpt.com "A Complete Guide to Pino Logging in Node.js"
[5]: https://github.com/pinojs/pino-http?utm_source=chatgpt.com "pinojs/pino-http: 🌲 high-speed HTTP logger for Node.js"
[6]: https://qiita.com/AoTo0330/items/f6e1ca508384a3b8fc7a?utm_source=chatgpt.com "Cloud Run services ログ監視「だいたいぜんぶ」 #GoogleCloud"
