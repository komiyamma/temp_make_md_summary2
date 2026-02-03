# 第22章：総合演習ミニプロジェクト（段階クリア方式）🎓🎉

## 22-0 この章でやること（完成イメージ）🗺️✨

この章は「Outboxを**動く形で**体にしみこませる総合演習だよ〜！💪📦
やることはシンプル👇

1. **注文を確定**する（業務更新）🛒✅
2. 同じトランザクションで **Outboxに“送る予定”を書く**📦🧾
3. 別プロセスのPublisherが **Outboxを拾って送る**📤
4. 失敗したら **リトライ**🔁、ダメなら **Dead Letter**📮
5. 二重送信が起きても壊れない **冪等性**🛡️
6. 困ったら追える **観測（ログ/メトリクス）**🔍📊

---

## 22-1 今回の「ミニ題材」仕様（固定）🧪🍀

**題材：注文確定（Order Confirm）**🛒✅

* 注文が CONFIRMED になったら、外部へ「OrderConfirmed」イベントを送る📨
* 送信は“すぐ”じゃなくてOK（最終的整合性）🕰️🌈
* Outboxのイベントは「送れた/送れてない」が追えること👀
* 二重送信や順序崩れがあっても壊れないこと（最後に仕上げる）🛡️➡️🧱

---

## 22-2 使うツールの“いま”の前提（最低限の情報だけ）🧰✨

* **Node.jsは v24 が Active LTS**（安定運用寄りの選択）📌 ([Node.js][1])
* **TypeScriptは 5.9.3 が Latest**（GitHub Releases）📌 ([GitHub][2])
* テストは **Vitest 4 系**が現行の大きな流れ（4.0は 2025-10 公開）🧪✨ ([Vitest][3])
* SQLiteで「1発で確保して返す」書き方をするなら **RETURNING** が便利（SQLite 3.35+）🧲 ([SQLite][4])

---

## 22-A：最低限クリア（書く→拾う→送る）✅📦📤

## 22-A-1 完成条件（この段階の“合格ライン”）🎯

* 注文を確定すると、Outboxに1件レコードが増える📦
* Publisherを起動すると、その1件が送信され、Outboxが sent になる✅
* 送信先は最初はダミーでOK（コンソール出力でもOK）📢🙂

---

## 22-A-2 データ構造（この章の最小スキーマ）🧾🧠

### orders（業務テーブル）🛒

* id（注文ID）
* status（PENDING / CONFIRMED）
* totalAmount（合計）

### outbox（送信予定テーブル）📦

* id（イベントID）
* eventType（例：OrderConfirmed）
* aggregateId（例：orderId）
* payload（JSON文字列）
* status（pending / processing / sent / failed / dead）
* attempts（試行回数）
* nextRetryAt（次回試行時刻）
* lockedBy / lockedAt（ロック情報）
* createdAt / sentAt
* lastError（失敗理由）

---

## 22-A-3 ざっくりアーキ図（動きの道筋）🧭✨

```text
[Confirm Order API]
   |
   | (transaction)
   v
[orders update] + [outbox insert]
   |
   v
[DB]
   |
   | (poll)
   v
[Publisher] --> [Transport(ダミー送信)] --> (console)
   |
   v
[outbox status = sent]
```

---

## 22-A-4 実装の“骨組み”（ファイル分割）📁🧩

（既に前章までで似た構成があるなら、ここに寄せてOKだよ🙆‍♀️）

```text
src/
  domain/
    order.ts
    events.ts
  app/
    confirmOrderUseCase.ts
  infra/
    db.ts
    orderRepository.ts
    outboxRepository.ts
    publisher.ts
    transport.ts
  scripts/
    initDb.ts
    demoConfirm.ts
tests/
  confirmOrder.test.ts
  publisher.test.ts
```

---

## 22-A-5 コード例：イベント型とpayload（最小）📄✨

```ts
// src/domain/events.ts
export type EventType = "OrderConfirmed";

export type OrderConfirmedPayload = {
  orderId: string;
  totalAmount: number;
  occurredAt: string; // ISO
};

export type OutboxRecord = {
  id: string;
  eventType: EventType;
  aggregateId: string;
  payloadJson: string;
  status: "pending" | "processing" | "sent" | "failed" | "dead";
  attempts: number;
  nextRetryAt: string | null;
  lockedBy: string | null;
  lockedAt: string | null;
  createdAt: string;
  sentAt: string | null;
  lastError: string | null;
};
```

---

## 22-A-6 コード例：注文確定ユースケース（Outbox同時書き込み）🔐🛠️

ポイントはここ👇
**orders更新**と**outbox追加**を「同じトランザクション」でやること💎

```ts
// src/app/confirmOrderUseCase.ts
import { randomUUID } from "node:crypto";
import type { OrderConfirmedPayload } from "../domain/events";
import type { DbTx } from "../infra/db";
import { OrderRepository } from "../infra/orderRepository";
import { OutboxRepository } from "../infra/outboxRepository";

export async function confirmOrderUseCase(tx: DbTx, input: { orderId: string }) {
  const orderRepo = new OrderRepository(tx);
  const outboxRepo = new OutboxRepository(tx);

  const order = await orderRepo.findById(input.orderId);
  if (!order) throw new Error("Order not found");

  if (order.status === "CONFIRMED") {
    // ここは“冪等性”の入口（後で強化するよ）🛡️
    return { ok: true, alreadyConfirmed: true };
  }

  await orderRepo.updateStatus(order.id, "CONFIRMED");

  const payload: OrderConfirmedPayload = {
    orderId: order.id,
    totalAmount: order.totalAmount,
    occurredAt: new Date().toISOString(),
  };

  await outboxRepo.insert({
    id: randomUUID(),
    eventType: "OrderConfirmed",
    aggregateId: order.id,
    payloadJson: JSON.stringify(payload),
  });

  return { ok: true, alreadyConfirmed: false };
}
```

---

## 22-A-7 コード例：Publisher（まずは1件ずつ拾って送る）📤🙂

最初は超シンプルに👇

* pending を1件拾う
* processing にして送る
* 成功したら sent にする

```ts
// src/infra/publisher.ts
import { randomUUID } from "node:crypto";
import { OutboxRepository } from "./outboxRepository";
import { Transport } from "./transport";
import type { Db } from "./db";

export async function runPublisherOnce(db: Db) {
  const workerId = randomUUID();

  await db.transaction(async (tx) => {
    const repo = new OutboxRepository(tx);

    // まずは「最古のpendingを1件取る」だけ（ロック強化は次の段階）👯‍♀️🔒
    const msg = await repo.peekOldestPending();
    if (!msg) return;

    await repo.markProcessing(msg.id, workerId);
  });

  // transactionの外で送る（送信失敗で業務Txを壊さない）✂️🧯
  const msg = await db.outboxFindProcessingBy(workerId);
  if (!msg) return;

  const transport = new Transport();
  await transport.send(msg.eventType, msg.payloadJson);

  await db.transaction(async (tx) => {
    const repo = new OutboxRepository(tx);
    await repo.markSent(msg.id);
  });
}
```

---

## 22-A-8 動作デモ（手順）🎬✨

1. DB初期化（orders/outbox作成）🧱
2. 注文を1件作成（PENDING）🛒
3. 注文確定スクリプトを実行（outboxが増える）📦
4. Publisherを実行（sentになる）✅

（実際のコマンドは、あなたの既存npm scriptsに合わせてOK🙆‍♀️）

---

## 22-A-9 テスト（最低限）🧪✅

**テスト観点**はこれだけでOK👇

* confirmOrderで outbox が1件増える
* Publisherが1回走ると status が sent になる

（Vitest 4系が現行）([Vitest][3])

---

## 22-B：発展クリア（ロック＋リトライ＋バックオフ＋DLQ）🚀🔒🔁📮

ここから「現実の地獄」対策ゾーン😇🔥
でも段階的に足すから大丈夫だよ〜！

---

## 22-B-1 まずロック（複数ワーカーでも二重送信しない）👯‍♀️🔒

### ゴール🎯

* Publisherを2つ起動しても「同じOutboxを同時に処理」しない

### いちばんやさしい作戦🧠

**“確保してから送る”**

* pending → processing を **原子的に**やる（ここが勝負）🧲

SQLiteなら RETURNING があると「確保した行をそのまま返せて便利」だよ📌 ([SQLite][4])

### 例：claim（確保）を1SQLでやるイメージ🧲

（SQLの形はDBで少し違うよ。学習用のイメージとして見てね🙂）

```sql
UPDATE outbox
SET status = 'processing',
    lockedBy = :workerId,
    lockedAt = :now
WHERE id = (
  SELECT id
  FROM outbox
  WHERE status = 'pending'
    AND (nextRetryAt IS NULL OR nextRetryAt <= :now)
  ORDER BY createdAt
  LIMIT 1
)
RETURNING *;
```

### ロックのチェックリスト✅

* processing にしたら「lockedBy/lockedAt」を埋める
* 送信が終わったら sent にする
* もし processing のまま固まったら「一定時間で回収」する（lock TTL）⏳

---

## 22-B-2 リトライ設計（失敗は“前提”）🔁🧠

### ゴール🎯

* 送信が失敗しても、Outboxが消えずに再挑戦できる

### 追加するルール📌

* attempts を +1
* 次回試行は nextRetryAt に入れる
* 恒久失敗っぽいなら dead（DLQ）へ📮

---

## 22-B-3 バックオフ（賢い再送）⏳📈

**指数バックオフ**の超ざっくり例👇

* 1回目：10秒後
* 2回目：30秒後
* 3回目：90秒後
  （最大は上限をつける）🧯

```ts
function calcNextRetry(attempts: number): Date {
  const baseSec = 10;
  const sec = Math.min(baseSec * Math.pow(3, attempts - 1), 15 * 60);
  return new Date(Date.now() + sec * 1000);
}
```

---

## 22-B-4 Dead Letter（隔離して人が直せる）📮🥹➡️🙂

### ゴール🎯

* 何回やっても無理なものを“隔離”できる
* 後から原因が追える（lastErrorやpayloadが残る）

### DLQ行きの判断例👇

* attempts >= 10
* payloadが壊れてる（JSON parseできない）
* eventTypeが未知

---

## 22-C：仕上げクリア（冪等性＋順序＋観測）🛡️➡️🍱🔍📊

ここまで来たら「実戦っぽさ」一気に上がるよ〜！🎮✨

---

## 22-C-1 冪等性（同じのが2回来ても壊れない）🛡️🔁

### ゴール🎯

* 二重送信が起きても、受け側（コンシューマ）が二重処理しない

### 学習用の“受け側テーブル”を作る🧾

inbox_processed（処理済みイベント）

* eventId（UNIQUE）
* processedAt

**受け側の処理**はこう👇

* eventId を inbox_processed に INSERT
* UNIQUE違反なら「もう処理済み」→ 何もせずOK✅

```ts
// 疑似コンシューマ（学習用）
export async function consumeOnce(db: Db, msg: { id: string; payloadJson: string }) {
  const inserted = await db.tryInsertProcessed(msg.id);
  if (!inserted) return { ok: true, deduped: true }; // 二重でも壊れない🛡️

  // ここで本来の副作用（例：通知登録など）
  return { ok: true, deduped: false };
}
```

---

## 22-C-2 順序（Ordering）🍱➡️🍱

### ゴール🎯

* 同じ orderId のイベントは、順序が崩れても最終的に正しい順で処理される

### やり方（学習用の軽い方式）🙂

Outboxに sequence を追加（同じaggregateId内で 1,2,3…）
受け側に checkpoint を置く👇

aggregate_checkpoint

* aggregateId（orderId）
* lastProcessedSeq

処理条件👇

* seq === lastProcessedSeq + 1 のときだけ処理
* 先の番号が来たら「一時失敗」にして後で再挑戦🔁

---

## 22-C-3 観測（ログ・メトリクス）🔍📊✨

### ゴール🎯

* 「何が起きた？」を追える
* 「溜まってる？」を見える化できる

### 最低限ログに入れるもの📝

* eventId
* eventType
* aggregateId
* attempts
* status遷移（pending→processing→sent）
* lastError（失敗時）

### 最低限メトリクス（数だけでもOK）📈

* pending件数
* processing件数
* failed件数
* dead件数
* 平均遅延（createdAt→sentAt）

---

## 22-D：AIレビュー会（“設計の見落とし”を潰す）🤖✅🎉

最後は AI を「レビュー役」にするよ👀✨
ここは**プロンプト例**をそのまま投げればOK！

---

## 22-D-1 SoC（責務分離）チェック✂️🧠

```text
次の観点でレビューして：
- domainにDBや外部I/Oが混ざってない？
- app/usecaseが「やることの順序」を握れてる？
- infraが詳細（SQL/transport）に閉じてる？
該当箇所のファイル名と改善案を箇条書きで。
```

---

## 22-D-2 例外境界（エラーモデリング）🚦😇

```text
送信処理の失敗を次に分類して、コード上でどう扱っているか確認して：
- 一時的（リトライで治る）
- 恒久的（リトライしても無理）
- バグ/未知（調査が必要）
分類が曖昧な箇所があれば修正案も出して。
```

---

## 22-D-3 冪等性と順序の穴🕳️🛡️🍱

```text
二重送信・順序逆転・欠番のケースを想定して、
今の実装が壊れないか確認して。
壊れるなら、最小の修正で守る方法を提案して。
```

---

## 22-D-4 KISS/YAGNIバランス⚖️🧊

```text
今の実装で「学習用に過剰」な部分があれば指摘して。
逆に「現実で最低限必要」なのに抜けてる部分も指摘して。
理由も短く添えて。
```

---

## 22-最終：段階クリアのチェックリスト（提出用）🧾✅✨

## ✅ 22-A（最低限）

* [ ] confirmOrder で orders 更新 + outbox insert が同一トランザクション
* [ ] publisher が outbox を拾って送る
* [ ] sent に更新される

## ✅ 22-B（発展）

* [ ] 複数publisherでも二重処理しない（claim/lock）
* [ ] 失敗で attempts / nextRetryAt が更新される
* [ ] 上限超えで dead になる（DLQ）

## ✅ 22-C（仕上げ）

* [ ] inbox_processed による冪等性（二重でもOK）
* [ ] aggregate_checkpoint による順序制御（必要範囲だけ）
* [ ] ログ/メトリクスで追跡できる

## ✅ 22-D（AIレビュー）

* [ ] 責務分離の指摘を反映
* [ ] 失敗分類が整理され、DLQ基準が明確
* [ ] 冪等性・順序の“穴”が埋まった

---

## 22-おまけ：TypeScriptの今後の流れ（超短く）🧠⚡

TypeScriptは 6.0 が“橋渡し”で、7.0（ネイティブ化）に向けて大きく動いてるよ、という公式の進捗も出てるよ📌 ([Microsoft for Developers][5])

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[3]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[4]: https://sqlite.org/releaselog/3_35_0.html?utm_source=chatgpt.com "SQLite Release 3.35.0 On 2021-03-12"
[5]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
