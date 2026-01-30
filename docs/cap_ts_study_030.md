# 第30章：観測（ログ/相関ID/主要メトリクス）🕵️‍♀️📈

## この章のゴール 🎯✨

* 「ズレた・遅れた・二重になった」が起きても、**どこで何が起きたか追える**ようになる 🧵🔍
* **相関ID（Correlation ID）**で、API → Worker の流れを1本の糸でつなぐ 🧶
* **主要メトリクス**で「遅延」「失敗」「リトライ」「キュー詰まり」を数値で見える化する 📈✅

---

# 1) 観測がないと、分散は“手品”になる 🎩😵‍💫

最終的整合性の世界って、ユーザー画面は「処理中」なのに裏では進んでたり、遅れて確定したりしますよね⏳
このとき観測が弱いと…

* 「どこが遅いの？」→ 分からない 🫥
* 「二重送信で二重処理した？」→ 分からない 👻
* 「失敗の原因は？」→ “たぶんネットワーク”で終わる 😭

だからこの章では、**追跡できる形**を先に作ります 🛠️✨

---

# 2) 観測の3点セット（この教材の型）🧰🧡

## ✅ 2-1. ログ：出来事の記録 📒🖊️

* 「何が起きたか」を残す（イベント、状態遷移、失敗理由、リトライ回数…）

## ✅ 2-2. 相関ID：出来事を“同じ流れ”で束ねる 🧵

* 1つの注文の流れを、APIログとWorkerログで同じIDで追えるようにする

## ✅ 2-3. メトリクス：傾向を数字で見る 📈

* 「遅延が増えてる」「失敗率が上がった」を**気づける**ようにする

さらに将来、分散トレース（traceparent など）へ自然につなげられる形にします🧠✨
W3Cの **Trace Context** は、`traceparent` などの標準ヘッダで“分散トレースの文脈”を伝搬する仕様です📨🔗 ([W3C][1])

---

# 3) 相関IDの設計：requestId と correlationId を分けよう 🧩✨

ここ、超大事です‼️🧷

* **correlationId**：その注文（または1つの処理フロー）を表す“流れのID”

  * API→Worker→（将来の別サービス）まで **ずっと同じ** 🧵
* **requestId**：1回のHTTP試行のID

  * リトライすると **変わる** 🔁

イメージ👇

* correlationId：**「この注文の人生」** 👶➡️👩‍🎓
* requestId：**「今日の1回の挑戦」** 🏃‍♀️💨

---

# 4) 実装：AsyncLocalStorageで“勝手に”引き回す 🪄🧠

`correlationId` を毎回関数引数で渡すの、しんどいです😵‍💫
そこで **AsyncLocalStorage** を使うと、非同期の中でも “今のリクエストの文脈” を取り出せます✨
Node.js公式でも、非同期文脈追跡は AsyncLocalStorage が安定した選択肢として案内されています📌 ([nodejs.org][2])

---

# 5) ハンズオン：APIに「相関ID付きログ」を入れる 🧵📒✨

## 5-1. 追加するもの（最小）🧰

* `AsyncLocalStorage` で context を保持
* `traceparent` or `x-correlation-id` を受け取って correlationId にする
* JSONログ（あとで検索しやすい✨）

## 5-2. context.ts（API側）🧠

```ts
// apps/api/src/observability/context.ts
import { AsyncLocalStorage } from "node:async_hooks";

export type ObsContext = {
  correlationId: string; // “流れのID”
  requestId: string;     // 1回のHTTP試行のID
};

export const obsContext = new AsyncLocalStorage<ObsContext>();

export function getCtx(): ObsContext | undefined {
  return obsContext.getStore();
}
```

## 5-3. traceparent を雑に読む（最小パーサ）📨🔍

W3C Trace Context の `traceparent` は
`version-traceId-parentId-flags` の形です（例は後で出すね） ([W3C][3])

```ts
// apps/api/src/observability/traceparent.ts
export function parseTraceparent(
  value?: string | null
): { traceId: string; parentId: string } | null {
  if (!value) return null;

  // 例: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  const m = value.trim().match(/^[\da-f]{2}-([\da-f]{32})-([\da-f]{16})-[\da-f]{2}$/i);
  if (!m) return null;

  return { traceId: m[1].toLowerCase(), parentId: m[2].toLowerCase() };
}
```

## 5-4. middleware：correlationIdを作って context に入れる 🧵✨

```ts
// apps/api/src/observability/middleware.ts
import { randomUUID } from "node:crypto";
import type { Request, Response, NextFunction } from "express";
import { obsContext } from "./context";
import { parseTraceparent } from "./traceparent";

export function observabilityMiddleware(req: Request, res: Response, next: NextFunction) {
  const requestId = randomUUID();

  // ① traceparent があれば traceId を correlationId として採用
  // ② なければ x-correlation-id
  // ③ それもなければ新規生成
  const correlationId =
    parseTraceparent(req.header("traceparent"))?.traceId ??
    req.header("x-correlation-id") ??
    randomUUID();

  // 返す（フロントや次のサービスが拾える✨）
  res.setHeader("x-correlation-id", correlationId);

  obsContext.run({ correlationId, requestId }, () => next());
}
```

---

# 6) ログ：JSONにすると“検索が神”になる 🔎✨

## 6-1. logger.ts（例：pinoでJSONログ）📒⚡

```ts
// apps/api/src/observability/logger.ts
import pino from "pino";
import { getCtx } from "./context";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  base: null, // pid/hostnameを消して見やすく（好みでOK）
  mixin() {
    const ctx = getCtx();
    return ctx ? { correlationId: ctx.correlationId, requestId: ctx.requestId } : {};
  },
});
```

> ここで「ログに必ず correlationId が乗る」状態を作るのが勝ちです🏆🧵

## 6-2. リクエスト終了時にログを吐く（超よく使う形）🕒🧾

```ts
// apps/api/src/observability/request-logging.ts
import type { Request, Response, NextFunction } from "express";
import { logger } from "./logger";

export function requestLogging(req: Request, res: Response, next: NextFunction) {
  const start = performance.now();

  res.on("finish", () => {
    const ms = performance.now() - start;
    logger.info(
      { method: req.method, path: req.originalUrl, status: res.statusCode, durationMs: ms },
      "http"
    );
  });

  next();
}
```

---

# 7) Workerへ“相関IDを持ち越す” 🧵➡️⚙️

HTTPの次はキュー（またはジョブ）です📨
ここで **correlationId をメッセージ本文に入れて渡す**のがコツ✨

## 7-1. メッセージ（イベント）例 📨

```ts
// apps/shared/src/messages.ts（みたいな場所に置く想定）
export type OrderAccepted = {
  type: "OrderAccepted";
  orderId: string;
  correlationId: string; // ←これが超重要！
  createdAt: string;     // ISO文字列（遅延測定に使う）
  attempt: number;       // リトライ回数（観測に効く）
};
```

## 7-2. Worker側でも AsyncLocalStorage を使う 🧠✨

```ts
// apps/worker/src/observability/run-with-context.ts
import { randomUUID } from "node:crypto";
import { obsContext } from "./context"; // APIと同じ形（コピーでもOK）

export function runWithMessageContext<T>(
  correlationId: string,
  fn: () => T
): T {
  const requestId = randomUUID(); // Workerの1処理単位のID
  return obsContext.run({ correlationId, requestId }, fn);
}
```

## 7-3. Worker処理でログが“つながる”🥹🧵

```ts
// apps/worker/src/handlers/order-accepted.ts
import { logger } from "../observability/logger";
import { runWithMessageContext } from "../observability/run-with-context";
import type { OrderAccepted } from "../../shared/messages";

export async function handleOrderAccepted(msg: OrderAccepted) {
  return runWithMessageContext(msg.correlationId, async () => {
    logger.info({ orderId: msg.orderId, attempt: msg.attempt }, "worker start");

    // ... 在庫引き当て・決済・状態更新など ...

    logger.info({ orderId: msg.orderId }, "worker done");
  });
}
```

---

# 8) 主要メトリクス：最低これだけ押さえよう 📈✅

メトリクスは「平均」より **増減と分布** が大事です📊✨
Prometheus の考え方は「アプリが HTTP endpoint に数値を出して、外から scrape する」方式が基本です🧲 ([prometheus.io][4])
Node.js なら `prom-client` が定番です📦 ([npm][5])

## 8-1. APIで持つべき（最低ライン）🌱

* **リクエスト数**：`http_requests_total`（method/route/status）📨
* **レイテンシ**：`http_request_duration_ms`（Histogram推し）⏱️
* **エラー率**：status=500 などの比率 😱
* **受け付けた注文数**：`orders_accepted_total` 🛒✅

## 8-2. Workerで持つべき（最低ライン）⚙️

* **処理成功/失敗数**：`jobs_processed_total` / `jobs_failed_total` ✅💥
* **リトライ回数**：`job_retries_total` 🔁
* **キュー滞留**：`queue_depth`（Gauge）📦📦📦
* **遅延（超重要！）**：`event_lag_ms`（作成→処理開始まで）⏳🔥

> 最終的整合性の“体感”は、**lag（遅延）を数字で持つ**と一気に現実になります📈✨

---

# 9) ハンズオン：prom-clientで /metrics を生やす 🌿📈

## 9-1. metrics.ts（API側）📊

```ts
// apps/api/src/observability/metrics.ts
import client from "prom-client";

export const register = new client.Registry();
register.setDefaultLabels({ service: "api" });

client.collectDefaultMetrics({ register });

export const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "HTTP requests total",
  labelNames: ["method", "route", "status"] as const,
  registers: [register],
});

export const httpRequestDurationMs = new client.Histogram({
  name: "http_request_duration_ms",
  help: "HTTP request duration in ms",
  labelNames: ["method", "route", "status"] as const,
  buckets: [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000],
  registers: [register],
});
```

## 9-2. リクエスト終了時にメトリクス更新 🧮✨

```ts
// apps/api/src/observability/request-metrics.ts
import type { Request, Response, NextFunction } from "express";
import { httpRequestDurationMs, httpRequestsTotal } from "./metrics";

export function requestMetrics(req: Request, res: Response, next: NextFunction) {
  const start = performance.now();

  res.on("finish", () => {
    const ms = performance.now() - start;
    const route = req.route?.path ?? req.path;

    httpRequestsTotal.labels(req.method, route, String(res.statusCode)).inc();
    httpRequestDurationMs.labels(req.method, route, String(res.statusCode)).observe(ms);
  });

  next();
}
```

## 9-3. /metrics エンドポイントを追加 🌐📈

```ts
// apps/api/src/app.ts（など）
import { register } from "./observability/metrics";

app.get("/metrics", async (_req, res) => {
  res.setHeader("Content-Type", register.contentType);
  res.end(await register.metrics());
});
```

---

# 10) “追える”か確認するテスト 🧪🧵✅

## 10-1. 1リクエストをIDで追う（やること）🏃‍♀️💨

1. 注文APIを叩く
2. APIログに `correlationId` が出る
3. Workerログにも **同じ correlationId** が出る
4. `event_lag_ms` が増えたり減ったりする

## 10-2. Windowsでログを追跡（例）🔍🪟

PowerShellでざっくり探す👇

```powershell
# correlationId をコピって検索
Select-String -Path .\logs\api.log -Pattern "YOUR_CORRELATION_ID"
Select-String -Path .\logs\worker.log -Pattern "YOUR_CORRELATION_ID"
```

---

# 11) 事故りやすいポイント（初心者あるある）😵‍💫🧯

## 11-1. メトリクスの“ラベル爆発”💣

* メトリクスの label に **userId / orderId を入れない**でね⚠️
  → ログに入れるのが正解 🙆‍♀️✨
  （メトリクスは集計用、ログは詳細追跡用）

## 11-2. correlationId を途中で作り直す 😭

* Workerで新規生成しちゃうと、APIとつながらない🧵✂️
  → **メッセージに入れて持ち越す**！

## 11-3. ログが“文章”だけで検索しづらい 🫠

* `logger.info("注文を作りました")` だけだと後で泣く😭
  → `{ orderId, correlationId, status }` みたいに **構造化**しよ✨

---

# 12) ちょい背伸び：traceparent と OpenTelemetry の入口 🚪✨

* `traceparent` はW3C標準で、分散トレースの文脈をヘッダで運べます📨 ([W3C][1])
* **OpenTelemetry** はトレース/メトリクスの計装をまとめて扱う枠組みで、Node.js向けの公式Getting Startedもあります🧭 ([OpenTelemetry][6])
* ただしNode.js向けのログ連携は状況が変わりやすく、公式でもログ周りは発展途上として扱われています📌 ([OpenTelemetry][6])

なのでこの教材では、まず **ログはJSON＋相関IDで堅く**、メトリクスも **prom-clientで堅く**いきます💪✨

---

# 13) ミニ課題（やると一気に身につく）📝💖

## 課題A：遅延の原因を特定せよ 🔍⏳

* Workerにランダム遅延（0〜2000ms）を入れる
* `event_lag_ms` とログの `durationMs` を見て、
  「遅いのはAPI？Worker？キュー待ち？」を説明する🧠✨

## 課題B：二重送信を“観測で”暴け 👻➡️🔦

* 同じ注文を2回送る（冪等が効く前提）
* ログで「同じ correlationId だけど requestId が違う」を確認
* 「二重送信が来たけど壊れなかった」を証拠付きで書く🧾✅

---

# 14) AI活用（この章は相性よすぎ🤖💞）

## 14-1. ログ項目テンプレを作らせる 📋✨

* 「注文APIとWorkerで共通化すべきログ項目をJSONで提案して」
* 「相関ID設計（correlationId/requestId）を初心者向けに説明して」

## 14-2. メトリクス案を出させる 📈🤖

* 「最終的整合性の遅延を観測するメトリクス案を10個。優先度も付けて」
* 「prom-clientでHistogramを使うときのバケット設計の考え方を教えて」

## 14-3. “ラベル爆発”チェック役にする 💣🧯

* 「このメトリクス設計、ラベル爆発の危険ある？どこ直す？」

---

## この章のまとめ（結論1行）✍️✨

**相関IDでログをつなぎ、遅延・失敗・リトライをメトリクスで数字にすると、分散の“モヤモヤ”が追跡可能になる🧵📈**

[1]: https://www.w3.org/TR/trace-context/?utm_source=chatgpt.com "Trace Context"
[2]: https://nodejs.org/api/async_context.html?utm_source=chatgpt.com "Asynchronous context tracking | Node.js v25.5.0 ..."
[3]: https://www.w3.org/TR/trace-context-2/?utm_source=chatgpt.com "Trace Context Level 2"
[4]: https://prometheus.io/docs/instrumenting/clientlibs/?utm_source=chatgpt.com "Client libraries"
[5]: https://www.npmjs.com/package/prom-client?utm_source=chatgpt.com "prom-client"
[6]: https://opentelemetry.io/docs/languages/js/getting-started/nodejs/?utm_source=chatgpt.com "Node.js"
