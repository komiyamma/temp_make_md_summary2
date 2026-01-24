# 第36章　観測と復旧（ログ・相関ID・再投影）🧭🧰

この章は「**動かした後に困らない**」ための章だよ〜！😆✨
CQRSって作って終わりじゃなくて、**運用（うんよう）＝障害対応・調査・復旧**がめちゃ大事なんだ。

---

## 0. 今日のストーリー（あるある）📣🍙

学食アプリでこんな報告が来たとするね👇

* 「支払い押したのに、一覧が“未払い”のままです😭」
* 「たまにだけ起きるっぽい…」

このとき必要なのは **勘** じゃなくて、**手がかり**！🔎✨
その手がかりを作るのが「観測（Observability）」で、直すのが「復旧（Recovery）」だよ🙂

---

## 1. 観測ってなに？（超ざっくり）👀✨

観測 = **“あとから原因を特定できるように、情報を残すこと”** だよ📝

観測の三兄弟（よくセットで言われるやつ）👇

* **ログ**：出来事の記録（いちばん身近）🧾
* **トレース**：1回の処理がどこを通ったか（分散だと最強）🧵
* **メトリクス**：数で見る健康診断（エラー率、レイテンシなど）📈

この章ではまず **ログ** をガッチリ固めて、余裕があれば **トレース** も触るよ〜🤖✨

---

## 2. “良いログ”の条件（女子大生でも守れるやつ）💡😊

ログでやりたいことは、この3つに集約されるよ👇

1. **「いつ・何が・誰の操作で」起きた？** ⏰👤
2. **どこで失敗した？** 😵‍💫
3. **同じ操作に紐づくログを、まとめて追える？** 🧵

そのために、最低限つけたい項目はこれ👇（超重要⭐）

* `correlationId`（相関ID）🧷
* `commandName` / `queryName`（何した？）🧾
* `orderId`（対象）🍙
* `eventId`（投影や再処理に超効く）📨
* `durationMs`（遅い原因探しに必須）🐢
* `result`（OK/NG、エラー分類）✅❌

---

## 3. 相関ID（correlationId）って何者？🧷✨

**相関ID**は「このユーザー操作に関係するログ全部に同じIDを付ける」仕組みだよ！

* API入口で1個作る（or クライアントから来たのを使う）
* その後の処理ぜんぶで同じIDをログに混ぜる
* すると「この操作のログだけ」を一瞬で追える😆🔎

さらに上位互換として、分散トレースの世界には **W3C Trace Context** って標準ヘッダーがあって、`traceparent` / `tracestate` で“処理のつながり”を伝搬できるよ📦✨ ([W3C][1])

---

## 4. 実装ハンズオン①：相関IDを“自動で”ログに混ぜる（AsyncLocalStorage）🪄

ポイントはこれ👇

* 関数引数で `correlationId` を渡し回るのは…しんどい😵‍💫
* だから **AsyncLocalStorage** で「今この処理の相関ID」を保持する✨
  （これ、Node系の観測ツールもよく使う王道パターンだよ🧠）([dash0.com][2])

### 4-1) context（相関ID保管庫）を作る🧰

```ts
// src/observability/context.ts
import { AsyncLocalStorage } from "node:async_hooks";

export type RequestContext = {
  correlationId: string;
  // 将来ここに userId, tenantId などを足してもOK（個人情報は注意⚠️）
};

const als = new AsyncLocalStorage<RequestContext>();

export function runWithContext<T>(ctx: RequestContext, fn: () => T): T {
  return als.run(ctx, fn);
}

export function getContext(): RequestContext | undefined {
  return als.getStore();
}
```

### 4-2) logger（Pino）を“毎回コンテキスト付き”で出せるようにする🧾✨

Pinoは高速でJSONログに向いてる定番だよ〜🚀（実務でも超よく使われる）([betterstack.com][3])

```ts
// src/observability/logger.ts
import pino from "pino";
import { getContext } from "./context";

const base = pino({
  level: process.env.LOG_LEVEL ?? "info",
  // ここでログの形を整える。最初は素直でOK🙂
});

export function log() {
  const ctx = getContext();
  // ctx があれば子ロガーで自動付与
  return ctx ? base.child({ correlationId: ctx.correlationId }) : base;
}
```

### 4-3) API入口ミドルウェアで相関IDを作る（Express例）🚪🧷

```ts
// src/api/requestContextMiddleware.ts
import type { Request, Response, NextFunction } from "express";
import { randomUUID } from "node:crypto";
import { runWithContext } from "../observability/context";
import { log } from "../observability/logger";

export function requestContextMiddleware(req: Request, res: Response, next: NextFunction) {
  const incoming = req.header("x-correlation-id");
  const correlationId = incoming && incoming.length > 0 ? incoming : randomUUID();

  // 返すレスポンスにも付けておくと、フロントが拾えて最高🙆‍♀️✨
  res.setHeader("x-correlation-id", correlationId);

  const started = performance.now();

  runWithContext({ correlationId }, () => {
    log().info({ method: req.method, path: req.path }, "request:start");

    res.on("finish", () => {
      const durationMs = Math.round(performance.now() - started);
      log().info({ status: res.statusCode, durationMs }, "request:end");
    });

    next();
  });
}
```

🎉 これで以後、`log().info(...)` したログ全部に `correlationId` が自動で混ざるよ！

---

## 5. 実装ハンズオン②：Command / Event / Projection に“復旧できるメタ情報”を足す📨🧩

### 5-1) Commandをログで追えるようにする🧾✨

例：`PayOrder` のHandlerで「開始・成功・失敗」を揃えるだけで、調査が激ラクになるよ😆

```ts
// src/commands/payOrderHandler.ts
import { log } from "../observability/logger";

export type PayOrderCommand = {
  orderId: string;
  paymentMethod: "CARD" | "CASH";
};

export async function payOrderHandler(cmd: PayOrderCommand) {
  const started = performance.now();
  log().info({ commandName: "PayOrder", orderId: cmd.orderId }, "command:start");

  try {
    // 例: ドメイン処理 + 永続化 + イベント生成（章の前提に合わせて）
    // ...

    const durationMs = Math.round(performance.now() - started);
    log().info({ commandName: "PayOrder", orderId: cmd.orderId, durationMs, result: "OK" }, "command:success");
  } catch (e) {
    const durationMs = Math.round(performance.now() - started);
    log().error(
      { commandName: "PayOrder", orderId: cmd.orderId, durationMs, result: "NG", err: e },
      "command:failed"
    );
    throw e;
  }
}
```

### 5-2) Domain Eventに `eventId` と `correlationId` を入れる📨🧷

OpenTelemetryでも「ログとトレースを相関できるように、ログに traceId/spanId を含める」思想があるよ。([OpenTelemetry][4])
同じノリで、イベントにも“追跡用メタ”を入れると復旧が強くなる🔥

```ts
// src/events/eventEnvelope.ts
export type EventEnvelope<TType extends string, TPayload> = {
  eventId: string;
  type: TType;
  occurredAt: string; // ISO
  correlationId: string; // 入口の相関IDを持ち回す🧷
  payload: TPayload;
};
```

投影（Projection）側はこの `eventId` を使って

* 「処理済みイベントか？」（冪等性）✅
* 「どこまで処理したか？」（チェックポイント）📍
  を管理できるよ！

---

## 6. 復旧の本丸：再投影（Reprojection）って何？🧱🔄

再投影は一言でいうと👇

**Readモデルを “作り直す”** こと！🛠️✨

Readモデルは（便利だけど）

* バグで壊れる
* 途中から仕様を変えたくなる
* 投影処理が失敗して欠ける
  …が普通に起きる😇

だから「作り直せる設計」にするのが超大事！

実務でも「Readモデルの安全なリビルド / バックフィル」はよく話題になるよ。イベントが増えながら再構築する難しさとかね🧩([Event-Driven][5])

---

## 7. “安全な再投影”の基本手順テンプレ（これ覚えたら勝ち）🏆✨

ここは **手順として暗記** しちゃってOK😆

### 手順A：いちばん安全（影武者＝シャドーで作って切り替え）👤➡️👤

1. **新しいReadモデル置き場**を用意（例：`orders_read_v2`）📦
2. 古いイベント（またはWrite DB）から **全部リプレイ**して埋める🔄
3. リプレイ中に増えた分を **追いかけ処理（catch-up）** する🏃‍♀️
4. 準備できたら **参照先を切り替える**（設定 or テーブル名）🔁
5. 古いのを片付ける🧹

これが“止めずに直す”王道だよ〜！([Event-Driven][5])

---

## 8. 実装ハンズオン③：超ミニ再投影スクリプト（イベントをJSONLでリプレイ）🔄🧪

ここでは学習用に、イベントストアを **JSONL（1行1イベント）** として扱うよ📄✨
（本番ではDBやメッセージ基盤でも同じ発想！）

### 8-1) イベントログ例 `event-store.jsonl` 🧾

```json
{"eventId":"e1","type":"OrderPlaced","occurredAt":"2026-01-24T00:00:00.000Z","correlationId":"c1","payload":{"orderId":"o1","total":780}}
{"eventId":"e2","type":"OrderPaid","occurredAt":"2026-01-24T00:01:00.000Z","correlationId":"c2","payload":{"orderId":"o1","paidAt":"2026-01-24T00:01:00.000Z"}}
```

### 8-2) 再投影スクリプト `scripts/reproject.ts` 🛠️

```ts
// scripts/reproject.ts
import { createReadStream } from "node:fs";
import readline from "node:readline";
import { log } from "../src/observability/logger";
import { runWithContext } from "../src/observability/context";

// 学習用：Readモデル（本番ならDB）
type OrderRead = { orderId: string; total: number; status: "ORDERED" | "PAID" };
const readModel = new Map<string, OrderRead>();

function applyEvent(e: any) {
  switch (e.type) {
    case "OrderPlaced": {
      readModel.set(e.payload.orderId, {
        orderId: e.payload.orderId,
        total: e.payload.total,
        status: "ORDERED",
      });
      return;
    }
    case "OrderPaid": {
      const current = readModel.get(e.payload.orderId);
      if (!current) return; // ここは設計次第（警告ログでもOK）
      readModel.set(e.payload.orderId, { ...current, status: "PAID" });
      return;
    }
  }
}

async function main() {
  const file = process.argv[2] ?? "event-store.jsonl";

  log().info({ file }, "reproject:start");

  readModel.clear();

  const rl = readline.createInterface({
    input: createReadStream(file),
    crlfDelay: Infinity,
  });

  let count = 0;

  for await (const line of rl) {
    if (!line.trim()) continue;
    const e = JSON.parse(line);

    // イベントに入ってる correlationId を “そのイベントの文脈” として使う
    runWithContext({ correlationId: e.correlationId ?? "reproject" }, () => {
      log().info({ eventId: e.eventId, type: e.type }, "reproject:apply");
      applyEvent(e);
    });

    count++;
  }

  log().info({ count, size: readModel.size }, "reproject:done");

  // 学習用に出力
  console.log([...readModel.values()]);
}

main().catch((err) => {
  log().error({ err }, "reproject:failed");
  process.exit(1);
});
```

✅ これが「再投影＝イベントを先頭から流してReadモデルを作り直す」だよ！
（イベントソーシングっぽい世界でも“リプレイ”は中核アイデアとしてよく出てくるよ）([algomaster.io][6])

---

## 9. “調査→復旧”の実践ミニ演習🎮✨

### 演習①：相関IDからログを辿る🔎🧷

1. ユーザーが見せてくれた `x-correlation-id` をメモ📝
2. ログ検索でそのIDを絞り込む
3. `command:start → command:failed` の間で何が起きたか見る👀

（ログがJSONなら、まずは文字列検索でも勝てるよ😆）

### 演習②：Readが壊れた想定で“再投影”する🔄

1. Readモデルを空にする（または `v2` を作る）🧹
2. 再投影スクリプト実行🚀
3. 直ったReadを見て「復旧できた！」を体験🎉

---

## 10. 余裕があれば：OpenTelemetryでトレースも付ける（最短）🧵✨

OpenTelemetryは “観測の共通規格” みたいなやつで、Nodeでも公式手順がまとまってるよ📚([OpenTelemetry][7])
そして **自動計装**の代表パッケージとして `@opentelemetry/auto-instrumentations-node` が提供されてる（2026年1月にも更新されてるよ）([NPM][8])

トレースまで入ると、ログにも `trace_id` / `span_id` が付いて相関できる世界に行ける（ログとトレースの相関は王道）🧠✨ ([OpenTelemetry][4])

---

## 11. AI活用（この章はAIと相性よすぎ）🤖💕

そのままコピペで使える “頼み方” を置いとくね👇

* 「このログスキーマ（項目）で、障害対応に不足してる情報ある？」🧾🔍
* 「CommandHandlerにログ入れたい。開始/成功/失敗のテンプレ作って」🧩✨
* 「再投影の安全な切り替え手順を、手順書（runbook）にして」📘✅
* 「このエラー分類（ドメイン/インフラ/バグ）で、PayOrderの失敗パターン洗い出して」⚠️🧠

---

## まとめ（この章で身についたこと）🎉

* 相関IDで「1操作のログ」を一本の線で追えるようになった🧷🧵
* Command / Event / Projection に “復旧できるメタ情報” を仕込めた📨✨
* Readモデルは壊れても **再投影で作り直せる** と体感できた🔄🏗️
* 余裕があれば、W3C Trace Context / OpenTelemetryで“さらに強く”できる🧵🌐 ([W3C][1])

---

次の第37章は「ADR＋卒業制作」だね🎓🏁
もしよければ、今の章の流れに合わせて「学食アプリ用の“障害対応runbook雛形”」も一緒に作れるよ📘✨

[1]: https://www.w3.org/TR/trace-context/?utm_source=chatgpt.com "Trace Context"
[2]: https://www.dash0.com/guides/contextual-logging-in-nodejs?utm_source=chatgpt.com "Contextual Logging Done Right in Node.js with ..."
[3]: https://betterstack.com/community/guides/logging/how-to-install-setup-and-use-pino-to-log-node-js-applications/?utm_source=chatgpt.com "A Complete Guide to Pino Logging in Node.js"
[4]: https://opentelemetry.io/docs/specs/otel/logs/?utm_source=chatgpt.com "OpenTelemetry Logging"
[5]: https://event-driven.io/en/rebuilding_event_driven_read_models/?utm_source=chatgpt.com "Rebuilding Event-Driven Read Models in a safe and ..."
[6]: https://algomaster.io/learn/system-design/event-sourcing?utm_source=chatgpt.com "Event Sourcing | System Design"
[7]: https://opentelemetry.io/ja/docs/languages/js/getting-started/nodejs/?utm_source=chatgpt.com "Node.js"
[8]: https://www.npmjs.com/package/%40opentelemetry/auto-instrumentations-node?utm_source=chatgpt.com "@opentelemetry/auto-instrumentations-node"
