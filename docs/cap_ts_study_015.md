# 第15章：書き方を選ぶ（同期/非同期/キュー）✍️📬

## 今日の結論1行✨

**「重い処理」はAPIの外に出して、APIは“受付”だけ返す（= 非同期＋キュー）と、A寄りで強くなるよ🧡**

---

# 15.1 「同期 / 非同期 / キュー」って何が違うの？🤔💭

同じ「注文を作る」でも、**書き方（処理の置き場所）**で世界が変わるよ〜🌍✨

## ① 同期（Sync）⚡

APIが **全部やり切って** から返す。
例：在庫引当→決済→DB確定→レスポンス✅

* 👍 いいところ：シンプル／「完了」をすぐ言える
* 👎 つらいところ：遅い⏳／タイムアウトしやすい💥／途中で落ちると地獄😇

## ② 非同期（Async）🏃‍♀️💨

APIは **受付だけ** して、重い処理は後でやる。
このとき「後でやる」を **何で支えるか** が大事！

* 「後でやる」をメモリだけで持つ → 落ちたら消える😱
* だから **キュー（Queue）** がほしくなる📬✨

## ③ キュー（Queue）📮

「やることリスト」を **消えない形で貯める箱**。
Worker（別プロセス）が順番に処理するよ🧑‍🏭🔁

* 👍 いいところ：落ちても復活できる／負荷を平準化できる📈
* 👎 つらいところ：少し設計が増える（でも価値がデカい！）💎

> HTTPで「受付だけ返す」時に便利なのが **202 Accepted**。
> **“処理は受け取ったけど、まだ終わってないよ”** の意味だよ📨✨ ([rfc-editor.org][1])

---

# 15.2 どれを選ぶ？超ざっくり判断🍙🧭

## 同期が向く✅

* その場で確定が必要（例：残高チェック必須の引き落とし💸）
* 失敗したら即エラーで止めたい⚠️

## 非同期＋キューが向く✅

* 多少遅れてOK（最終的整合性でUX支えるやつ🎨⏳）
* 重い処理・外部API呼び出しがある（決済・メール送信など📩）
* 失敗が起きる前提で「再試行」したい🔁

---

# 15.3 ハンズオン：注文APIを「受付→キュー→Worker」にする🛒📦✨

この章ではこうするよ👇
**API：注文を“受付”してキューに積む** → **Worker：後で在庫処理して注文を確定** ✅

## つくる状態（超ミニ）🧩

* Order（注文）

  * `pending`（処理中⏳）
  * `confirmed`（確定✅）
  * `failed`（失敗❌）
* Job（キューのタスク）

  * `queued` → `processing` → `done` / `failed`

---

# 15.4 今回の「最小キュー」方針📦（外部サービスなし版）

本物の現場では Redis などを使うキュー（例：BullMQ）がよく使われるよ📮✨
BullMQは **Redis backed のジョブキュー**で、バックグラウンド処理を作れる定番の一つだよ。([bullmq.io][2])

でも今回は学習用に、まず **ファイル（JSON）＋ロック**で「キューっぽさ」を体感するよ🧪
（後で BullMQ に差し替えるのも簡単になる✨）

---

# 15.5 実装：共通の保存先（dataフォルダ）を用意📁🧡

ルートに `data/` を作って、2つのファイルを使うよ👇

* `data/orders.json`（注文の配列）
* `data/jobs.json`（ジョブの配列）
* `data/.lock`（排他ロック用）

最初は空でOK：

```json
[]
```

---

# 15.6 実装：ロック付きのJSONストア（API/Worker共通）🔒🧰

## `apps/api/src/store.ts`（Workerにも同じものを置く）📄✨

```ts
import { promises as fs } from "node:fs";
import path from "node:path";

const DATA_DIR = path.resolve(process.cwd(), "../../data");
const LOCK_PATH = path.join(DATA_DIR, ".lock");
const ORDERS_PATH = path.join(DATA_DIR, "orders.json");
const JOBS_PATH = path.join(DATA_DIR, "jobs.json");

export type OrderStatus = "pending" | "confirmed" | "failed";
export type JobStatus = "queued" | "processing" | "done" | "failed";

export type Order = {
  id: string;
  sku: string;
  qty: number;
  status: OrderStatus;
  createdAt: number;
  updatedAt: number;
};

export type Job = {
  id: string;
  type: "ReserveStock";
  payload: { orderId: string; sku: string; qty: number };
  status: JobStatus;
  attempts: number;
  availableAt: number; // この時刻以降に処理してOK
  lastError?: string;
  createdAt: number;
  updatedAt: number;
};

async function ensureFiles() {
  await fs.mkdir(DATA_DIR, { recursive: true });
  for (const p of [ORDERS_PATH, JOBS_PATH]) {
    try {
      await fs.access(p);
    } catch {
      await fs.writeFile(p, "[]", "utf8");
    }
  }
}

async function sleep(ms: number) {
  await new Promise((r) => setTimeout(r, ms));
}

// 超かんたんロック：.lock を “作れた人が勝ち”
async function withLock<T>(fn: () => Promise<T>): Promise<T> {
  await ensureFiles();

  const start = Date.now();
  while (true) {
    try {
      const fh = await fs.open(LOCK_PATH, "wx"); // 既にあれば失敗
      await fh.close();
      break;
    } catch (e: any) {
      if (e?.code !== "EEXIST") throw e;
      if (Date.now() - start > 2000) throw new Error("Lock timeout 😵");
      await sleep(20 + Math.floor(Math.random() * 40)); // ちょいジッター
    }
  }

  try {
    return await fn();
  } finally {
    await fs.unlink(LOCK_PATH).catch(() => {});
  }
}

async function readJson<T>(p: string): Promise<T> {
  const txt = await fs.readFile(p, "utf8");
  return JSON.parse(txt) as T;
}
async function writeJson(p: string, v: unknown) {
  await fs.writeFile(p, JSON.stringify(v, null, 2), "utf8");
}

export async function createOrderAndEnqueue(job: Job, order: Order) {
  return withLock(async () => {
    const orders = await readJson<Order[]>(ORDERS_PATH);
    const jobs = await readJson<Job[]>(JOBS_PATH);

    orders.push(order);
    jobs.push(job);

    await writeJson(ORDERS_PATH, orders);
    await writeJson(JOBS_PATH, jobs);
  });
}

export async function getOrder(orderId: string) {
  return withLock(async () => {
    const orders = await readJson<Order[]>(ORDERS_PATH);
    return orders.find((o) => o.id === orderId) ?? null;
  });
}

export async function pickNextJob(now: number) {
  return withLock(async () => {
    const jobs = await readJson<Job[]>(JOBS_PATH);
    const idx = jobs.findIndex((j) => j.status === "queued" && j.availableAt <= now);
    if (idx === -1) return null;

    const j = jobs[idx]!;
    jobs[idx] = { ...j, status: "processing", updatedAt: now };
    await writeJson(JOBS_PATH, jobs);
    return jobs[idx]!;
  });
}

export async function completeJob(jobId: string, now: number) {
  return withLock(async () => {
    const jobs = await readJson<Job[]>(JOBS_PATH);
    const idx = jobs.findIndex((j) => j.id === jobId);
    if (idx === -1) return;
    jobs[idx] = { ...jobs[idx]!, status: "done", updatedAt: now };
    await writeJson(JOBS_PATH, jobs);
  });
}

export async function failOrRetryJob(jobId: string, now: number, err: Error, maxAttempts = 5) {
  return withLock(async () => {
    const jobs = await readJson<Job[]>(JOBS_PATH);
    const idx = jobs.findIndex((j) => j.id === jobId);
    if (idx === -1) return;

    const cur = jobs[idx]!;
    const nextAttempts = cur.attempts + 1;

    // ざっくりバックオフ（後の章でちゃんとやる🔁✨）
    const delayMs = Math.min(10_000, 300 * Math.pow(2, nextAttempts)); // 0.6s,1.2s,2.4s...
    const next: Job =
      nextAttempts >= maxAttempts
        ? { ...cur, status: "failed", attempts: nextAttempts, lastError: err.message, updatedAt: now }
        : {
            ...cur,
            status: "queued",
            attempts: nextAttempts,
            availableAt: now + delayMs,
            lastError: err.message,
            updatedAt: now,
          };

    jobs[idx] = next;
    await writeJson(JOBS_PATH, jobs);
  });
}

export async function updateOrderStatus(orderId: string, status: OrderStatus, now: number) {
  return withLock(async () => {
    const orders = await readJson<Order[]>(ORDERS_PATH);
    const idx = orders.findIndex((o) => o.id === orderId);
    if (idx === -1) return;
    orders[idx] = { ...orders[idx]!, status, updatedAt: now };
    await writeJson(ORDERS_PATH, orders);
  });
}
```

---

# 15.7 API：注文は「受付」だけ返す（202）📨✨

## `apps/api/src/index.ts` 🧡

```ts
import Fastify from "fastify";
import { randomUUID } from "node:crypto";
import { createOrderAndEnqueue, getOrder, type Job, type Order } from "./store.js";

const app = Fastify({ logger: true });

app.post("/orders", async (req, reply) => {
  const body = (req.body ?? {}) as any;
  const sku = String(body.sku ?? "");
  const qty = Number(body.qty ?? 0);

  if (!sku || !Number.isFinite(qty) || qty <= 0) {
    return reply.code(400).send({ message: "sku と qty を正しく入れてね🥺" });
  }

  const now = Date.now();
  const orderId = randomUUID();

  const order: Order = {
    id: orderId,
    sku,
    qty,
    status: "pending",
    createdAt: now,
    updatedAt: now,
  };

  const job: Job = {
    id: randomUUID(),
    type: "ReserveStock",
    payload: { orderId, sku, qty },
    status: "queued",
    attempts: 0,
    availableAt: now,
    createdAt: now,
    updatedAt: now,
  };

  await createOrderAndEnqueue(job, order);

  // 202: 受付はしたけど、処理はまだ終わってないよ📨
  return reply.code(202).send({
    orderId,
    status: "pending",
    check: `/orders/${orderId}`,
  });
});

app.get("/orders/:id", async (req, reply) => {
  const id = (req.params as any).id as string;
  const order = await getOrder(id);
  if (!order) return reply.code(404).send({ message: "見つからないよ〜😢" });
  return reply.send(order);
});

await app.listen({ port: 3000 });
```

> 202 Accepted は「処理を受け付けたけど、まだ完了してない」ケース向けだよ📨✨ ([rfc-editor.org][1])

---

# 15.8 Worker：キューから取って処理する🧑‍🏭🔁

## `apps/worker/src/index.ts` 🛠️

```ts
import { setTimeout as sleep } from "node:timers/promises";
import {
  pickNextJob,
  completeJob,
  failOrRetryJob,
  updateOrderStatus,
  type Job,
} from "./store.js";

function logWith(orderId: string, msg: string) {
  console.log(`[order:${orderId}] ${msg}`);
}

// わざと遅くしたり失敗させたりして、分散のリアルを体感🧪
async function reserveStock(job: Job) {
  const { orderId, sku, qty } = job.payload;

  logWith(orderId, `在庫引当スタート sku=${sku} qty=${qty} 🧺`);
  await sleep(600 + Math.floor(Math.random() * 800)); // 0.6〜1.4秒くらい待つ

  // 20%で失敗（外部API失敗みたいな想定）💥
  if (Math.random() < 0.2) {
    throw new Error("在庫サービスが一時的に死んだ😵（想定）");
  }

  logWith(orderId, `在庫引当OK ✅`);
}

while (true) {
  const now = Date.now();
  const job = await pickNextJob(now);

  if (!job) {
    await sleep(200); // 暇ならちょい待つ
    continue;
  }

  const { orderId } = job.payload;

  try {
    logWith(orderId, `job picked! attempts=${job.attempts} 🎯`);
    await reserveStock(job);

    await updateOrderStatus(orderId, "confirmed", Date.now());
    await completeJob(job.id, Date.now());
    logWith(orderId, `注文確定 🎉 confirmed`);
  } catch (e: any) {
    const err = e instanceof Error ? e : new Error(String(e));
    logWith(orderId, `失敗: ${err.message} 💥 -> retry...`);

    await failOrRetryJob(job.id, Date.now(), err, 5);

    // 最大試行を超えたら、注文も failed に（今回は単純化）
    // ※本当は job の status を見て反映するのが丁寧
    if (job.attempts + 1 >= 5) {
      await updateOrderStatus(orderId, "failed", Date.now());
      logWith(orderId, `注文失敗 ❌ failed`);
    }
  }
}
```

---

# 15.9 動作確認（“受付→後で確定” を体で覚える）💃🧠✨

## ① API と Worker を別ターミナルで起動🖥️🖥️

（例：2つターミナル開いて）

* API（ポート3000）
* Worker（ずっと回る）

## ② 注文を投げる🛒

PowerShell ならこんな感じ：

```powershell
curl -Method POST http://localhost:3000/orders `
  -H "Content-Type: application/json" `
  -Body '{"sku":"APPLE","qty":2}'
```

返ってくるのは **202** ＋ `pending` のはず📨✨
（まだ確定してないのがポイント！）

## ③ 状態を見に行く👀

レスポンスの `check` にGETする：

```powershell
curl http://localhost:3000/orders/<orderId>
```

最初は `pending` ⏳
ちょっと待つと `confirmed` 🎉（失敗したら `failed` もありえる💥）

---

# 15.10 ここが「最終的整合性の入口」だよ🚪✨

この構成にすると、ユーザー視点ではこうなるよ👇

* すぐ返事が来る（A寄り）⚡
* でも結果は後で確定（最終的整合性）⏳
# * だから **UI/UX** で “待ち” を支える必要がある（第10章の世界🎨）

そして現実のキュー実装（Redis + BullMQ など）に進むと、
「永続化」「並列処理」「再試行」「遅延ジョブ」などがガチで強くなるよ📮🔥 ([bullmq.io][2])

---

## 15.11 よくある事故（今のうちに“言葉”で押さえる）⚠️😇

### ✅ 事故1：APIで全部やってタイムアウト⏳💥

→ **重い処理を外へ**（今日やったやつ！）

### ✅ 事故2：非同期だけど「キューが消える」😱

→ メモリだけに置かない。**消えない箱（キュー）**が必要📦

### ✅ 事故3：Workerが途中で落ちたら？🧟‍♀️

→ だから **processing のまま放置**を回収する仕組み（ウォッチドッグ）とかが要る
（この教材の後半で“運用の肌感覚”としてやっていくよ🕵️‍♀️）

---

## 15.12 AI（Copilot/Codex）活用コーナー🤖💡

### ① まず“設計の言語化”をAIにやらせる✍️

* 「注文を `pending→confirmed` にする状態遷移を書いて」
* 「Jobの状態 `queued/processing/done/failed` の遷移表を作って」

### ② コード生成は“部品単位”で頼むのが勝ち🏆

* 「`withLock` を `wx` で作って、タイムアウト付きで」
* 「jobs.jsonから “availableAt <= now の queued” を1件取って processing にする関数を書いて」

### ③ 最後はAIに“事故レビュー”させる👀

* 「この実装の競合・落ちポイントを10個指摘して」
* 「本番ならどう直す？（RedisキューやDBキュー案）」

---

## まとめ🧡✨

* **同期**は簡単だけど、遅延・失敗に弱い😵‍💫
* **非同期＋キュー**にすると、APIは“受付”で返せてA寄りになる⚡
* その代わり、**後で確定する世界（最終的整合性）**になるので、状態設計が大事🧩
* 202 Accepted は「終わってない処理を受付だけする」時の代表選手📨 ([rfc-editor.org][1])

---

## ミニ課題🎓✨（5分でOK）

1. 失敗率を 20%→60% にして、`pending` が長くなるのを観察👀💥
2. `failOrRetryJob` の `maxAttempts` を 2 にして、すぐ `failed` になるUXを体感😇
3. `availableAt` の遅延を大きくして、「待ち」をUIでどう見せるか文章で書く✍️🎨

---

### （参考：この章で使ってる“最新寄り”の土台）🧱✨

* Node.js は v24 が Active LTS、v25 が Current として運用されてるよ（リリース表で確認できる）([nodejs.org][3])
* TypeScript は 5.9 系が安定版として提供されていて、`tsc --init` の出力なども更新されてるよ([Microsoft for Developers][4])
* TypeScript 7 のネイティブ版プレビュー（高速化）も公式から情報が出てるよ🚀([Microsoft Developer][5])

[1]: https://www.rfc-editor.org/rfc/rfc9110.html?utm_source=chatgpt.com "RFC 9110: HTTP Semantics"
[2]: https://bullmq.io/?utm_source=chatgpt.com "BullMQ - Background Jobs processing and message queue ..."
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/ "Announcing TypeScript 5.9 - TypeScript"
[5]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
