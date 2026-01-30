# 第32章：卒業制作（ミニ分散EC）🛒📦🎓✨

## 0. この章で作るもの（完成イメージ）🎯✨

**「注文はすぐ受付」→「あとで確定 or 失敗に収束」**する、ミニ分散ECを作ります💪
ポイントはこれ👇

* 注文APIはすぐ返す（**A寄り**）⚡
* 裏でWorkerが在庫確保→決済→注文確定へ進める（**最終的整合性**）⏳
* リトライしても壊れない（**冪等**）🧷
* 相関IDで一連の流れを追える（**観測**）🕵️‍♀️📈

---

## 1. アーキテクチャ（全体図）🗺️✨

```text
[Client]
  |
  |  POST /orders  (Idempotency-Key, Correlation-Id)
  v
[API] ----(Outboxにイベント書く)----> [SQLite(DB)]
  |                                     |
  |  202 Accepted (PENDING)             |  outbox: OrderPlaced
  v                                     v
(ClientはGET /orders/:idで状態確認)   [Worker] ----HTTP----> [Inventory Service]
                                         |                   (reserve/release)
                                         |
                                         +----HTTP----> [Payment Service]
                                                     (charge)
```

* **APIは「受付」担当**（速さ重視）🚀
* **Workerが「後処理」担当**（失敗・遅延が普通の世界で頑張る）🔁
* DBはシンプルにSQLiteでOK（Nodeの `node:sqlite` を使うよ）🗄️ ([Node.js][1])

---

## 2. この卒業制作の「合格ライン」✅🎓

最低限クリアしたい要件はこれ👇

1. **注文は受付（A寄り）** → 返すのは `PENDING` ⏳
2. **最終的に収束** → Workerが `CONFIRMED / FAILED` に更新✅❌
3. **二重送信でも壊れない**（Idempotency-Key）🧷
4. **リトライしても破綻しない**（在庫確保・決済も冪等）🔁
5. **相関IDで追える**（ログに `correlationId` を常に出す）🕵️‍♀️

---

## 3. 最新ツールの「いま」メモ（2026-01時点）🧾✨

この章では、今の定番どころを使います👇

* Node.js：**v24 が Active LTS**（安定運用向け） ([Node.js][2])
* TypeScript：**最新は 5.9 系** ([TypeScript][3])
* `node:sqlite`：Node組み込みのSQLite（開発中ステータスだけど使える） ([Node.js][1])
* tsx：TSをサクッと実行（4.21.0） ([npm][4])
* Vitest：テスト（4.0リリース済み） ([Vitest][5])
* pino：ログ（10.x） ([npm][6])

---

## 4. フォルダ構成（4プロセス）📁✨

```text
mini-ec/
  data/
    ec.db
  packages/
    shared/
      src/
        ids.ts
        hash.ts
        retry.ts
        time.ts
        http.ts
        db.ts
  apps/
    api/
      src/server.ts
    worker/
      src/worker.ts
    inventory/
      src/server.ts
    payment/
      src/server.ts
  package.json
  tsconfig.base.json
```

---

## 5. まずは「共通パッケージ」🧩✨（packages/shared）

### 5.1 `packages/shared/src/ids.ts`（ID生成）🆔✨

```ts
import { randomUUID } from "node:crypto";

export function newId(prefix: string) {
  return `${prefix}_${randomUUID()}`;
}
```

### 5.2 `packages/shared/src/time.ts`（時刻）⏰

```ts
export function nowIso() {
  return new Date().toISOString();
}
```

### 5.3 `packages/shared/src/hash.ts`（リクエスト同一性チェック用）🔐

```ts
import { createHash } from "node:crypto";

export function sha256(text: string) {
  return createHash("sha256").update(text).digest("hex");
}

export function stableJson(value: unknown) {
  // “完全な安定化”は難しいけど、学習用としてはこれでOK
  return JSON.stringify(value);
}
```

### 5.4 `packages/shared/src/retry.ts`（指数バックオフ＋ジッター）🔁✨

```ts
export function backoffMs(attempt: number) {
  // attempt: 1,2,3...
  const base = 200;                 // 0.2s
  const cap = 10_000;               // 10s
  const exp = Math.min(cap, base * 2 ** (attempt - 1));
  const jitter = Math.floor(Math.random() * 200); // 0〜199ms
  return exp + jitter;
}
```

### 5.5 `packages/shared/src/http.ts`（fetch + timeout）🌐⏳

```ts
export async function fetchJson(
  url: string,
  init: RequestInit & { timeoutMs?: number } = {}
) {
  const { timeoutMs = 1500, ...rest } = init;

  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(url, { ...rest, signal: controller.signal });
    const text = await res.text();
    const json = text ? JSON.parse(text) : undefined;
    return { ok: res.ok, status: res.status, json };
  } finally {
    clearTimeout(t);
  }
}
```

### 5.6 `packages/shared/src/db.ts`（SQLite接続＋マイグレーション）🗄️✨

`node:sqlite` の `DatabaseSync` を使います（同期APIで分かりやすい） ([Node.js][1])

```ts
import { DatabaseSync } from "node:sqlite";

export function openDb(path: string) {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL;");
  db.exec("PRAGMA foreign_keys = ON;");
  migrate(db);
  return db;
}

function migrate(db: DatabaseSync) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      status TEXT NOT NULL,
      total INTEGER NOT NULL,
      correlation_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS order_items (
      order_id TEXT NOT NULL,
      sku TEXT NOT NULL,
      qty INTEGER NOT NULL,
      price INTEGER NOT NULL,
      PRIMARY KEY(order_id, sku),
      FOREIGN KEY(order_id) REFERENCES orders(id)
    ) STRICT;

    CREATE TABLE IF NOT EXISTS outbox (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      correlation_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      processed_at TEXT,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_retry_at TEXT,
      last_error TEXT
    ) STRICT;

    CREATE TABLE IF NOT EXISTS idempotency (
      key TEXT PRIMARY KEY,
      request_hash TEXT NOT NULL,
      response_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS inventory_stock (
      sku TEXT PRIMARY KEY,
      available INTEGER NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS inventory_reservations (
      reservation_id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL UNIQUE,
      sku TEXT NOT NULL,
      qty INTEGER NOT NULL,
      created_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS payments (
      payment_id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL UNIQUE,
      amount INTEGER NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL
    ) STRICT;
  `);
}
```

---

## 6. API（apps/api）📮✨：注文は「受付して返す」

### 6.1 注文APIの仕様（超シンプル）🧾

* `POST /orders`

  * ヘッダ：

    * `Idempotency-Key`（同じ注文の二重送信対策）🧷
    * `X-Correlation-Id`（なければAPI側で発行）🕵️‍♀️
  * レスポンス： `202 Accepted` + `{ orderId, status: "PENDING" }`

* `GET /orders/:id`

  * いまの状態（PENDING/CONFIRMED/FAILED）を返す👀

### 6.2 `apps/api/src/server.ts` 🚀

```ts
import express from "express";
import pino from "pino";
import { openDb } from "../../packages/shared/src/db.js";
import { newId } from "../../packages/shared/src/ids.js";
import { nowIso } from "../../packages/shared/src/time.js";
import { sha256, stableJson } from "../../packages/shared/src/hash.js";

const logger = pino();
const db = openDb(new URL("../../data/ec.db", import.meta.url).pathname);

const app = express();
app.use(express.json());

// correlation id middleware
app.use((req, res, next) => {
  const cid = (req.header("x-correlation-id") || newId("cid")).toString();
  (req as any).cid = cid;
  res.setHeader("x-correlation-id", cid);
  next();
});

app.post("/orders", (req, res) => {
  const cid = (req as any).cid as string;
  const idemKey = (req.header("idempotency-key") || "").toString().trim();
  if (!idemKey) return res.status(400).json({ error: "Idempotency-Key is required" });

  const body = req.body as { items: Array<{ sku: string; qty: number; price: number }> };
  const requestHash = sha256(stableJson(body));

  // 1) 同じIdempotency-Keyがあれば、同じレスポンスを返す
  const found = db
    .prepare("SELECT response_json FROM idempotency WHERE key = ? AND request_hash = ?")
    .get(idemKey, requestHash) as { response_json: string } | undefined;

  if (found) {
    logger.info({ cid, idemKey }, "idempotent hit");
    return res.status(202).json(JSON.parse(found.response_json));
  }

  const orderId = newId("ord");
  const createdAt = nowIso();
  const total = (body.items ?? []).reduce((sum, it) => sum + it.qty * it.price, 0);

  const response = { orderId, status: "PENDING" as const };

  // 2) 注文 + outbox + idempotency を “同じトランザクション感覚” で書く
  //   （SQLiteのexecでBEGIN/COMMITするだけでも学習には十分）
  db.exec("BEGIN");
  try {
    db.prepare(
      "INSERT INTO orders (id, status, total, correlation_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
    ).run(orderId, "PENDING", total, cid, createdAt, createdAt);

    const insertItem = db.prepare(
      "INSERT INTO order_items (order_id, sku, qty, price) VALUES (?, ?, ?, ?)"
    );
    for (const it of body.items ?? []) {
      insertItem.run(orderId, it.sku, it.qty, it.price);
    }

    const eventId = newId("evt");
    db.prepare(
      "INSERT INTO outbox (id, type, payload_json, correlation_id, created_at) VALUES (?, ?, ?, ?, ?)"
    ).run(eventId, "OrderPlaced", JSON.stringify({ orderId }), cid, createdAt);

    db.prepare(
      "INSERT INTO idempotency (key, request_hash, response_json, created_at) VALUES (?, ?, ?, ?)"
    ).run(idemKey, requestHash, JSON.stringify(response), createdAt);

    db.exec("COMMIT");
  } catch (e: any) {
    db.exec("ROLLBACK");
    logger.error({ cid, err: e?.message }, "create order failed");
    return res.status(500).json({ error: "internal error" });
  }

  logger.info({ cid, orderId, total }, "order accepted");
  return res.status(202).json(response);
});

app.get("/orders/:id", (req, res) => {
  const cid = (req as any).cid as string;
  const orderId = req.params.id;

  const order = db.prepare("SELECT * FROM orders WHERE id = ?").get(orderId) as any;
  if (!order) return res.status(404).json({ error: "not found" });

  logger.info({ cid, orderId, status: order.status }, "order read");
  res.json({
    orderId: order.id,
    status: order.status,
    total: order.total,
    updatedAt: order.updated_at,
  });
});

app.listen(3000, () => {
  logger.info("API listening on http://localhost:3000");
});
```

---

## 7. Inventory Service（apps/inventory）📦✨：在庫確保は冪等にする🧷

ここが超大事！
Workerがリトライしても **「在庫が二重に減らない」**ようにします💪

### 7.1 `apps/inventory/src/server.ts`

```ts
import express from "express";
import pino from "pino";
import { openDb } from "../../packages/shared/src/db.js";
import { newId } from "../../packages/shared/src/ids.js";
import { nowIso } from "../../packages/shared/src/time.js";

const logger = pino();
const db = openDb(new URL("../../data/ec.db", import.meta.url).pathname);

const app = express();
app.use(express.json());

function maybeFault() {
  const rate = Number(process.env.FAULT_FAIL_RATE ?? "0");
  const delay = Number(process.env.FAULT_DELAY_MS ?? "0");
  if (delay > 0) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, delay);
  if (Math.random() < rate) throw new Error("inventory fault injection");
}

// seed: 在庫を手で入れる（学習用の裏口）🪄
app.post("/admin/seed", (req, res) => {
  const body = req.body as { sku: string; available: number };
  db.prepare("INSERT INTO inventory_stock (sku, available) VALUES (?, ?) ON CONFLICT(sku) DO UPDATE SET available=excluded.available")
    .run(body.sku, body.available);
  res.json({ ok: true });
});

app.post("/reserve", (req, res) => {
  const cid = req.header("x-correlation-id") || "no-cid";
  try {
    maybeFault();
    const body = req.body as { orderId: string; items: Array<{ sku: string; qty: number }> };

    // すでに予約済みなら同じ結果を返す（冪等）🧷
    const existing = db
      .prepare("SELECT reservation_id FROM inventory_reservations WHERE order_id = ?")
      .get(body.orderId) as { reservation_id: string } | undefined;

    if (existing) {
      logger.info({ cid, orderId: body.orderId }, "reserve idempotent hit");
      return res.status(200).json({ reservationId: existing.reservation_id });
    }

    db.exec("BEGIN");
    try {
      for (const it of body.items) {
        const row = db.prepare("SELECT available FROM inventory_stock WHERE sku = ?").get(it.sku) as any;
        const available = row?.available ?? 0;
        if (available < it.qty) {
          db.exec("ROLLBACK");
          return res.status(409).json({ error: "OUT_OF_STOCK", sku: it.sku, available });
        }
      }

      // 減らす＆予約記録
      for (const it of body.items) {
        db.prepare("UPDATE inventory_stock SET available = available - ? WHERE sku = ?").run(it.qty, it.sku);
        db.prepare("INSERT INTO inventory_reservations (reservation_id, order_id, sku, qty, created_at) VALUES (?, ?, ?, ?, ?)")
          .run(newId("res"), body.orderId, it.sku, it.qty, nowIso());
      }

      db.exec("COMMIT");
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }

    logger.info({ cid, orderId: body.orderId }, "reserved");
    return res.status(201).json({ ok: true });
  } catch (e: any) {
    logger.error({ cid, err: e?.message }, "reserve failed");
    return res.status(500).json({ error: "TEMPORARY_FAILURE" });
  }
});

app.post("/release", (req, res) => {
  const cid = req.header("x-correlation-id") || "no-cid";
  const body = req.body as { orderId: string };
  try {
    maybeFault();

    db.exec("BEGIN");
    try {
      const rows = db.prepare("SELECT sku, qty FROM inventory_reservations WHERE order_id = ?").all(body.orderId) as any[];
      for (const r of rows) {
        db.prepare("UPDATE inventory_stock SET available = available + ? WHERE sku = ?").run(r.qty, r.sku);
      }
      db.prepare("DELETE FROM inventory_reservations WHERE order_id = ?").run(body.orderId);
      db.exec("COMMIT");
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }

    logger.info({ cid, orderId: body.orderId }, "released");
    res.json({ ok: true });
  } catch (e: any) {
    logger.error({ cid, err: e?.message }, "release failed");
    res.status(500).json({ error: "TEMPORARY_FAILURE" });
  }
});

app.listen(3001, () => logger.info("Inventory listening on http://localhost:3001"));
```

---

## 8. Payment Service（apps/payment）💳✨：決済も冪等にする🧷

**orderId で UNIQUE**にして、同じ注文を2回課金しないようにします💥防止！

### 8.1 `apps/payment/src/server.ts`

```ts
import express from "express";
import pino from "pino";
import { openDb } from "../../packages/shared/src/db.js";
import { newId } from "../../packages/shared/src/ids.js";
import { nowIso } from "../../packages/shared/src/time.js";

const logger = pino();
const db = openDb(new URL("../../data/ec.db", import.meta.url).pathname);

const app = express();
app.use(express.json());

function maybeFault() {
  const rate = Number(process.env.FAULT_FAIL_RATE ?? "0");
  const delay = Number(process.env.FAULT_DELAY_MS ?? "0");
  if (delay > 0) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, delay);
  if (Math.random() < rate) throw new Error("payment fault injection");
}

app.post("/charge", (req, res) => {
  const cid = req.header("x-correlation-id") || "no-cid";
  try {
    maybeFault();
    const body = req.body as { orderId: string; amount: number };

    const existing = db.prepare("SELECT payment_id, status FROM payments WHERE order_id = ?").get(body.orderId) as any;
    if (existing) {
      logger.info({ cid, orderId: body.orderId }, "charge idempotent hit");
      return res.status(200).json({ paymentId: existing.payment_id, status: existing.status });
    }

    const paymentId = newId("pay");
    db.prepare(
      "INSERT INTO payments (payment_id, order_id, amount, status, created_at) VALUES (?, ?, ?, ?, ?)"
    ).run(paymentId, body.orderId, body.amount, "CHARGED", nowIso());

    logger.info({ cid, orderId: body.orderId, paymentId }, "charged");
    return res.status(201).json({ paymentId, status: "CHARGED" });
  } catch (e: any) {
    logger.error({ cid, err: e?.message }, "charge failed");
    return res.status(500).json({ error: "TEMPORARY_FAILURE" });
  }
});

app.listen(3002, () => logger.info("Payment listening on http://localhost:3002"));
```

---

## 9. Worker（apps/worker）🧰🔁：Outboxを処理して収束させる

### 9.1 Workerの処理ルール（超重要）📌✨

* outboxを読む（`processed_at IS NULL`）📨
* `OrderPlaced` を処理する
* 成功→注文 `CONFIRMED` ✅ + outbox `processed_at` 更新
* 在庫不足→注文 `FAILED` ❌（これは「正常な失敗」）
* 一時エラー→ outbox に `next_retry_at` を入れて **あとで再挑戦** 🔁

### 9.2 `apps/worker/src/worker.ts`

```ts
import pino from "pino";
import { openDb } from "../../packages/shared/src/db.js";
import { nowIso } from "../../packages/shared/src/time.js";
import { backoffMs } from "../../packages/shared/src/retry.js";
import { fetchJson } from "../../packages/shared/src/http.js";

const logger = pino();
const db = openDb(new URL("../../data/ec.db", import.meta.url).pathname);

const INVENTORY_URL = "http://localhost:3001";
const PAYMENT_URL = "http://localhost:3002";

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

async function processOne() {
  const evt = db.prepare(`
    SELECT id, type, payload_json, correlation_id, attempts
    FROM outbox
    WHERE processed_at IS NULL
      AND (next_retry_at IS NULL OR next_retry_at <= ?)
    ORDER BY created_at
    LIMIT 1
  `).get(nowIso()) as any;

  if (!evt) return false;

  const cid = evt.correlation_id as string;
  const payload = JSON.parse(evt.payload_json) as { orderId: string };
  const orderId = payload.orderId;

  const log = logger.child({ cid, orderId, eventId: evt.id });

  // まず「注文がすでに確定/失敗してない？」を確認（冪等の土台）🧷
  const order = db.prepare("SELECT status, total FROM orders WHERE id = ?").get(orderId) as any;
  if (!order) {
    db.prepare("UPDATE outbox SET processed_at = ? WHERE id = ?").run(nowIso(), evt.id);
    log.warn("order not found -> mark event processed");
    return true;
  }
  if (order.status !== "PENDING") {
    db.prepare("UPDATE outbox SET processed_at = ? WHERE id = ?").run(nowIso(), evt.id);
    log.info({ status: order.status }, "already settled -> mark event processed");
    return true;
  }

  // 失敗したら attempts+1 して next_retry_at を入れる
  const attempt = (evt.attempts as number) + 1;

  try {
    log.info({ attempt }, "start processing");

    // 1) 在庫確保（冪等）📦🧷
    const reserve = await fetchJson(`${INVENTORY_URL}/reserve`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-correlation-id": cid },
      body: JSON.stringify({
        orderId,
        items: db.prepare("SELECT sku, qty FROM order_items WHERE order_id = ?").all(orderId),
      }),
      timeoutMs: 1200,
    });

    if (reserve.status === 409) {
      // 在庫不足は「正常な失敗」→ 注文をFAILEDにして終わり
      db.exec("BEGIN");
      try {
        db.prepare("UPDATE orders SET status = ?, updated_at = ? WHERE id = ?")
          .run("FAILED", nowIso(), orderId);
        db.prepare("UPDATE outbox SET processed_at = ?, attempts = ? WHERE id = ?")
          .run(nowIso(), attempt, evt.id);
        db.exec("COMMIT");
      } catch (e) {
        db.exec("ROLLBACK");
        throw e;
      }
      log.warn({ reason: "OUT_OF_STOCK" }, "order failed");
      return true;
    }

    if (!reserve.ok) throw new Error(`reserve failed status=${reserve.status}`);

    // 2) 決済（冪等）💳🧷
    const charge = await fetchJson(`${PAYMENT_URL}/charge`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-correlation-id": cid },
      body: JSON.stringify({ orderId, amount: order.total }),
      timeoutMs: 1200,
    });

    if (!charge.ok) {
      // 決済に失敗したら「在庫を戻す」補償（ここもリトライで安全に）
      await fetchJson(`${INVENTORY_URL}/release`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-correlation-id": cid },
        body: JSON.stringify({ orderId }),
        timeoutMs: 1200,
      });
      throw new Error(`charge failed status=${charge.status}`);
    }

    // 3) 注文を確定 ✅
    db.exec("BEGIN");
    try {
      db.prepare("UPDATE orders SET status = ?, updated_at = ? WHERE id = ?")
        .run("CONFIRMED", nowIso(), orderId);
      db.prepare("UPDATE outbox SET processed_at = ?, attempts = ? WHERE id = ?")
        .run(nowIso(), attempt, evt.id);
      db.exec("COMMIT");
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }

    log.info("order confirmed ✅");
    return true;
  } catch (e: any) {
    const wait = backoffMs(attempt);
    const next = new Date(Date.now() + wait).toISOString();

    db.prepare(
      "UPDATE outbox SET attempts = ?, next_retry_at = ?, last_error = ? WHERE id = ?"
    ).run(attempt, next, String(e?.message ?? e), evt.id);

    log.error({ attempt, nextRetryAt: next, err: e?.message }, "temporary failure -> retry");
    return true;
  }
}

async function main() {
  logger.info("Worker started");
  while (true) {
    const did = await processOne();
    if (!did) await sleep(300);
  }
}

main().catch((e) => {
  logger.error({ err: String(e) }, "worker crashed");
  process.exit(1);
});
```

---

## 10. 動かしてみよう（手動デモ）🎬✨

### 10.1 在庫を入れる（SKUを1個だけにして “売り切れ” を体験）📦

```bash
curl -X POST http://localhost:3001/admin/seed ^
  -H "content-type: application/json" ^
  -d "{\"sku\":\"coffee\",\"available\":1}"
```

### 10.2 注文を2回投げる（2回目は同じIdempotency-Keyで）🧷🧷

```bash
curl -X POST http://localhost:3000/orders ^
  -H "content-type: application/json" ^
  -H "Idempotency-Key: demo-001" ^
  -H "X-Correlation-Id: cid-demo-001" ^
  -d "{\"items\":[{\"sku\":\"coffee\",\"qty\":1,\"price\":500}]}"
```

同じのをもう一度👇（二重送信の再現）

```bash
curl -X POST http://localhost:3000/orders ^
  -H "content-type: application/json" ^
  -H "Idempotency-Key: demo-001" ^
  -H "X-Correlation-Id: cid-demo-001" ^
  -d "{\"items\":[{\"sku\":\"coffee\",\"qty\":1,\"price\":500}]}"
```

### 10.3 状態確認（最終的にCONFIRMEDへ）👀⏳

```bash
curl http://localhost:3000/orders/ord_（返ってきたIDをここに）
```

### 10.4 もう一回注文（今度は在庫不足でFAILEDになる）😱➡️❌

在庫が1個なら、2回目は **OUT_OF_STOCK → FAILED** が見えるはず！

---

## 11. 故障注入で「分散っぽさ」を出す🧪🎲

Inventory/Paymentに環境変数を入れて、落としたり遅くしたりします💥

例：30%失敗 + 500ms遅延

* Inventory側：`FAULT_FAIL_RATE=0.3` / `FAULT_DELAY_MS=500`
* Payment側：`FAULT_FAIL_RATE=0.3` / `FAULT_DELAY_MS=500`

Workerのログで👇が見えたら勝ち✨

* `temporary failure -> retry`
* `nextRetryAt` が伸びていく
* それでも最終的に **CONFIRMED / FAILED に収束** ✅❌

---

## 12. テスト（最低ライン）🧪✅

卒業制作なので、「壊れやすいところ」だけでもテストを付けると強いです💪

### 12.1 テスト観点（これだけでOK）📋✨

* **Idempotency-Keyが同じなら orderId が同じ** 🧷
* Workerが同じイベントを2回処理しても **二重課金されない** 💳🧷
* Fault injectionで一時失敗しても、最終的に収束する 🔁✅

（テストランナーは Vitest 4 を想定） ([Vitest][5])

---

## 13. 提出物（成果物）📝🎓

### 13.1 スクショ or 動画（おすすめスクショ5枚）📸✨

1. `POST /orders` のレスポンス（PENDING）
2. `GET /orders/:id` が PENDING → CONFIRMED に変わる瞬間
3. 同じIdempotency-Keyを2回送っても同じ結果になる
4. 故障注入でリトライが走るログ
5. 在庫不足でFAILEDになる例

### 13.2 「C/Aどっち寄り？なぜ？」説明テンプレ ✍️⚖️

そのまま貼って埋めればOK👇

* **今回の設計は A（可用性）寄り**です。理由は、`POST /orders` が **在庫や決済の結果を待たずに** 受付して返すからです。⚡
* **整合性（C）は最終的に担保**します。Workerが在庫確保→決済→注文確定を進め、最終的に `CONFIRMED/FAILED` に収束させます。⏳✅❌
* **Partition（分断）が起きると**、Workerや下位サービスに到達できない時間がありえます。その間も受付を止めない選択をしました（A優先）。🔌💥
* 代わりに、ユーザー体験として **「処理中（PENDING）」を見せる**ことで、ズレをUXで支えます。🎨
* 二重送信・リトライ前提なので、**Idempotency-Key** と **在庫/決済の冪等**で壊れないようにしました。🧷🔁

---

## 14. Copilot/AIに聞くプロンプト例 🤖✨（そのままコピペOK）

* 「このリポジトリ構成で、各サービスのpackage.jsonとtsconfigを整えて。ESMでお願い」
* 「Idempotency-Key設計の落とし穴をレビューして、改善点だけ箇条書きして」
* 「相関IDをログに必ず出すためのチェックリスト作って」
* 「Workerのリトライで“やっちゃダメなミス”を列挙して」

---

## 15. ちょい注意（2026っぽい安全策）🛡️

依存パッケージは便利だけど、供給網攻撃（悪意ある更新）が現実に起きています。ロックファイル管理＆監査（`npm audit` など）は習慣にすると安心です🔒 ([TechRadar][7])

---

## 参考（公式・一次情報）📚✨

* Node.js リリース状況（LTS/Current） ([Node.js][2])
* Node.js `node:sqlite` ドキュメント ([Node.js][1])
* TypeScript ダウンロードページ（最新版表示） ([TypeScript][3])
* tsx（npm） ([npm][4])
* Vitest 4.0 アナウンス ([Vitest][5])
* pino（npm） ([npm][6])

[1]: https://nodejs.org/api/sqlite.html "SQLite | Node.js v25.5.0 Documentation"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[4]: https://www.npmjs.com/package/tsx?utm_source=chatgpt.com "tsx"
[5]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[6]: https://www.npmjs.com/package/pino?utm_source=chatgpt.com "Pino"
[7]: https://www.techradar.com/pro/security/more-popular-npm-packages-hijacked-to-spread-malware?utm_source=chatgpt.com "More popular npm packages hijacked to spread malware"
