# 第24章 ログと相関ID（追跡できる設計）👀🔗

## 24.1 「この注文、いまどうなってる？」を“すぐ答えられる”状態にする🧾💨

ドメインイベントを使うと、処理が「保存→配る→ハンドラで副作用」みたいに分かれていきますよね📣🚚
でも分かれたぶん、障害が起きたときにログが散らばって **追跡できない** と地獄です…😵‍💫

そこで必要になるのが👇

* **相関ID（correlationId）**：この一連の流れは“同じストーリー”って示すID🔗
* **リクエストID（requestId）**：その入口のリクエスト1回を示すID🚪
* （発展）**traceId / spanId**：分散トレーシングで「どのサービス→どの処理」を追うID🧵
  ※分散トレーシングの土台は **W3C Trace Context（traceparent / tracestate）** で運ぶのが標準です📦 ([W3C][1])

---

## 24.2 まず整理！ requestId / correlationId / traceId の違い🧠📌

### ✅ requestId（入口の“1回”）

* APIを1回叩いた、その **1回分** を表すID
* 例：`POST /orders/pay` を押した“その1回”🎫

### ✅ correlationId（ストーリー全体の“ひも”）

* 「支払い→在庫確保→メール送信→ポイント付与」みたいに
  **複数の処理にまたがる流れ** を、同じIDでまとめる🔗✨
* HTTPの外に出ても（Outbox→ワーカー→別サービス）持っていけるのが強い💪

### ✅ traceId / spanId（“処理の地図”：分散トレーシング）

* **traceId**：一連の処理の地図ID🗺️
* **spanId**：その中の区間（1処理）🚏
* OpenTelemetryは「トレース・メトリクス・ログ」を関連付けるのが目的で、**コンテキスト伝搬** が中心概念です🧵 ([OpenTelemetry][2])
* ログにも traceId / spanId を入れると、ログ↔トレースの行き来が速くなります🏃‍♀️💨 ([OpenTelemetry][3])

> ここでは、まず **correlationId を軸に “追えるログ” を作れる** ようになって、余裕が出たら traceId も足す流れにします🌱

---

## 24.3 “最低限”そろえるログ項目（迷ったらコレ）🧰✨

ログは「文章」より **構造（JSON）** が命です🧾➡️🤖
Node.jsでは高速な構造化ログとして **Pino** が定番扱いされがちです⚡ ([Dash0][4])

### 🌟 最低限のおすすめフィールド（まずは5つ！）

* `timestamp`（いつ）⏰
* `level`（重要度）🚦
* `message`（何が起きた）📝
* `correlationId`（この流れのひも）🔗
* `eventType` or `action`（何のイベント/処理）🏷️

### 💎 できれば追加（運用で効く！）

* `requestId`（入口の1回）🎫
* `eventId`（冪等性や重複調査にも効く）🧾
* `aggregateId`（OrderIdなど）🆔
* `handler`（どのハンドラが動いた？）🧩
* `durationMs`（遅い原因追跡）🐢
* `error.name / error.message`（例外の要点）💥

### 🧠 フィールド名の“寄せ方”（後で楽）

Elastic系を使うなら、`trace.id` / `span.id` みたいなフィールド名が一般的です🧵 ([Elastic][5])
（今すぐElasticを使わなくても、将来ツールに載せやすい形にできます👍）

---

## 24.4 相関IDは“運ぶ”のが本番（HTTP / Outbox / イベント）📦🚚

### ① HTTP：ヘッダーで受け取る or 作る📨

* 受け取る例：`x-correlation-id`
* 無ければ生成：`crypto.randomUUID()`✨

さらに分散トレーシングをするなら、W3C標準の `traceparent` を運びます📦 ([W3C][1])

### ② Outbox：DBに“相関IDも一緒に保存”する🗃️🔗

Outboxは「イベント発行の取りこぼし」を避ける仕組みでしたよね🧯
ここで correlationId を一緒に保存しておくと、ワーカー側ログが一瞬で繋がります✨

---

## 24.5 実装：TypeScriptで“どのログにも correlationId を自動で付ける”🪄🔗

ポイントはこれ👇
**処理の途中で毎回 correlationId を手で渡さない**（絶対忘れる😇）
だから、**AsyncLocalStorage** で「いまの処理コンテキスト」を保持します🧠

---

### 24.5.1 `context`：相関IDをしまう箱📦

```ts
// src/observability/context.ts
import { AsyncLocalStorage } from "node:async_hooks";

export type RequestContext = {
  correlationId: string;
  requestId: string;
  // 発展：traceId / spanId を入れたくなったらここに追加できる✨
  // traceId?: string;
  // spanId?: string;
};

const storage = new AsyncLocalStorage<RequestContext>();

export function runWithContext<T>(ctx: RequestContext, fn: () => T): T {
  return storage.run(ctx, fn);
}

export function getContext(): RequestContext | undefined {
  return storage.getStore();
}
```

---

### 24.5.2 `logger`：Pinoで構造化ログ + 自動でID添付🧾⚡

```ts
// src/observability/logger.ts
import pino from "pino";
import { getContext } from "./context.js";

export const logger = pino({
  // ここは最小でOK。出力はJSONが基本🧾
  level: process.env.LOG_LEVEL ?? "info",
  base: {
    service: "mini-ec",
  },
  messageKey: "message",
  formatters: {
    level(label) {
      return { level: label };
    },
  },
  mixin() {
    const ctx = getContext();
    if (!ctx) return {};
    return {
      correlationId: ctx.correlationId,
      requestId: ctx.requestId,
    };
  },
});
```

> PinoはJSONで出す前提なので、あとで検索・集計・相関が超ラクになります📈 ([Dash0][4])

---

### 24.5.3 `http`入口：ヘッダーから拾う／無ければ作る🚪✨

```ts
// src/observability/httpContext.ts
import { randomUUID } from "node:crypto";
import { runWithContext, type RequestContext } from "./context.js";

export function withHttpContext<T>(
  headers: Record<string, string | string[] | undefined>,
  fn: () => T
): T {
  const correlationId =
    (typeof headers["x-correlation-id"] === "string" && headers["x-correlation-id"]) ||
    randomUUID();

  const requestId =
    (typeof headers["x-request-id"] === "string" && headers["x-request-id"]) ||
    randomUUID();

  const ctx: RequestContext = { correlationId, requestId };
  return runWithContext(ctx, fn);
}
```

---

## 24.6 ドメインイベントの流れにログを刺す（ミニEC：支払い）💳📦

### 24.6.1 イベント発生地点（集約）でログ：**“事実が起きた”** を記録🧠📝

* ドメインイベント自体は「業務の事実」
* ログは「調査用の記録」
* なので、ログには **eventId / eventType / aggregateId** くらいがちょうど良い🎯

```ts
// 例：Order集約のメソッド内（イメージ）
import { logger } from "../observability/logger.js";

logger.info(
  {
    eventType: "OrderPaid",
    aggregateId: orderId,
    eventId: event.eventId,
  },
  "Domain event raised"
);
```

---

### 24.6.2 ディスパッチ前後でログ：**“どこまで進んだ？”** を追える📣⏱️

```ts
import { logger } from "../observability/logger.js";

export async function dispatch(events: Array<{ eventId: string; type: string }>) {
  for (const e of events) {
    const start = Date.now();
    logger.info({ eventId: e.eventId, eventType: e.type }, "Dispatch start");

    try {
      // handlers...
      logger.info(
        { eventId: e.eventId, eventType: e.type, durationMs: Date.now() - start },
        "Dispatch success"
      );
    } catch (err: any) {
      logger.error(
        {
          eventId: e.eventId,
          eventType: e.type,
          durationMs: Date.now() - start,
          error: { name: err?.name, message: err?.message },
        },
        "Dispatch failed"
      );
      throw err;
    }
  }
}
```

---

## 24.7 “ログの見つけ方”が決まると、復旧が速くなる🔍🚑

### 🔎 基本の調査ルート（おすすめ）

1. まず `correlationId` を見つける（入口ログ or エラー画面に表示）🔗
2. `correlationId` で全文検索して流れを1本にまとめる📎
3. どこで止まったかを `Dispatch start/success/failed` で特定する🚦
4. `durationMs` で「遅い犯人」を見つける🐢

分散トレーシングまで行くと、ログとトレースを相互に飛べてさらに速いです🧵✨
OpenTelemetryは、ログに TraceId/SpanId を含めて相関しやすくする考え方を仕様として持っています📌 ([OpenTelemetry][3])

---

## 24.8 やっちゃダメ集（事故るやつ）🚫😇

* ❌ ログが文章だけ（検索しづらい、機械が読めない）
* ❌ correlationId を途中で捨てる（Outboxやキューで途切れる）
* ❌ 1行に全部盛り（個人情報・巨大payload・秘密が漏れる）🫣
* ❌ エラーのログに「何の処理か」が無い（eventType/handlerが無い）

---

## 24.9 演習（手を動かす）📝✨

### 演習1：最低限フィールドを5つ決めよう🧾

あなたのミニECで、ログに必ず入れる項目を5つ選んで書く✍️
（迷ったら：`timestamp, level, message, correlationId, eventType`）

### 演習2：ログ設計チェック✅

次の質問に答えられる？（ログだけで！）

* 「OrderId=123 の支払い、どこで失敗した？」💥
* 「メール送信が遅いのはどのハンドラ？」🐢
* 「同じイベントが二重で処理された？」🔁

### 演習3：Outboxに correlationId を足す🗃️🔗

Outboxのレコードに `correlationId` を追加して、ワーカー側ログにも同じIDが出るようにする🧩

---

## 24.10 AI活用（Copilot / Codexに投げる用）🤖💬

* 「このプロジェクトのログを **JSON構造化** にして、必ず `correlationId` と `eventType` が入るようにして」🧾🔗
* 「このログ設計、**調査に足りない項目** があったら指摘して」🔍
* 「PII（個人情報）をログに出してないかチェックして、危険なら修正案を出して」🫣✅
* 「ログメッセージを短く、同じ言い回しに統一して」📏✨

---

## まとめ🎀

* **correlationId** があると、分かれた処理でもログが1本のストーリーになる🔗✨
* ログは **構造化（JSON）** が基本🧾⚡（Pinoが定番級） ([Dash0][4])
* 入口（HTTP）→Outbox→ワーカーまで **IDを運ぶ** のが勝ち📦🚚
* 余裕が出たら **traceparent（W3C）＋traceId/spanId** で、ログとトレースも繋げられる🧵 ([W3C][1])

[1]: https://www.w3.org/TR/trace-context/?utm_source=chatgpt.com "Trace Context"
[2]: https://opentelemetry.io/docs/concepts/context-propagation/?utm_source=chatgpt.com "Context propagation"
[3]: https://opentelemetry.io/docs/specs/otel/logs/?utm_source=chatgpt.com "OpenTelemetry Logging"
[4]: https://www.dash0.com/guides/nodejs-logging-libraries?utm_source=chatgpt.com "The Top 7 Node.js Logging Libraries Compared"
[5]: https://www.elastic.co/docs/reference/ecs/ecs-tracing?utm_source=chatgpt.com "Elastic Common Schema (ECS) - Tracing fields"
