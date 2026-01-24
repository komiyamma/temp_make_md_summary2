# 第30章　冪等性（同じイベントが2回来ても大丈夫）🔁🛡️

この章は「**イベントが重複して届くのが普通**」って前提で、**Readモデル（投影）が壊れない**ようにする回だよ〜😊✨
現場あるあるの「リトライで同じイベントが2回来た😇」を、ちゃんと吸収できるようになるよ💪💕

---

## この章のゴール 🎯✨

読み終わったら、こんなことができるようになるよ👇

* **重複イベントで集計が2倍になる事故**を説明できる😱➡️🙂
* **「冪等（べきとう）」って何？**を自分の言葉で言える🗣️✨
* **イベントIDで重複排除**して、投影（Projection）を安全にできる🔁✅
* **テストで「2回来ても1回分」**を守れる🧪💕

---

## まず“事故”を想像しよっか 😵‍💫💥

たとえば `OrderPaid`（支払い完了）イベントで、売上集計をこう更新してたとする👇

* `sales_summary.totalYen += paidAmount`

これ、**同じイベントが2回来たら売上が2倍**になるよね😇💸💸

「え、でも同じイベントが2回来るの？」
来るの🥹（しかも珍しくない）

---

## なんで同じイベントが2回来るの？ 🤔📨

メッセージングやイベント配信って、わりと**「少なくとも1回（at-least-once）」**が基本なのね。
つまり「届かないよりは、たまに重複してでも届く」思想👏✨
その結果、**重複は“ありうる仕様”**になりがち。 ([AWS ドキュメント][1])

重複が起きる典型パターン👇

* コンシューマが処理した直後に落ちて、ACK前で再配信😵
* タイムアウトで「失敗扱い」になって、送信側/中継がリトライ🔁
* ネットワーク遅延で「同じのもう一回送っとこ」が発生📡

だからね、**「重複しないように祈る」より「重複しても壊れない」**が勝ち🏆✨

---

## 冪等性ってなに？（超やさしく）🧸✨

**同じ入力を何回やっても、結果が1回と同じ**になる性質だよ🔁✅

イベント処理の世界ではよくこう言うよ👇

> 同じメッセージを何度処理しても、結果が1回と同じであること

これは「Idempotent Consumer（冪等なコンシューマ）」って有名なパターンとして整理されてるよ📚✨ ([microservices.io][2])

---

## 冪等にする方法は3つあるよ🧩✨（まずは全体像）

### ① “上書き型”でそもそも二重適用しても同じにする ✍️🧼

例：一覧の行を `status = "PAID"` で上書き、みたいなやつ
→ 2回やっても結果は同じ🙂

### ② “重複排除”する（イベントIDで「処理済み」を記録）🪪✅

→ 今回のメイン！
**「そのイベント、もうやったよ」**を覚えておくやり方🧠✨

### ③ “DB制約”で二重に入らない形にする（UNIQUEなど）🔒🗄️

例：`(consumerId, eventId)` を主キーにして、2回目のINSERTを弾く
→ ②と相性最高💞

---

## 今日のハンズオン：イベントIDで重複排除して投影を守る🛡️🔁

やることはこれ👇（シンプルで強い✨）

1. `processed_events` テーブルを作る🗄️
2. イベントを処理する前に「処理済み登録」を試す🪪
3. 登録できたときだけ投影する（できなかったらスキップ）🚫
4. **「登録」と「投影」を同じトランザクション**に入れて安全にする🔒✨

ちなみに最近は Node の標準APIに SQLite モジュール（`node:sqlite`）が入ってて、サクッと試せるよ〜！（まだ実験扱いだけど便利） ([Node.js][3])
`statement.run()` が `changes` を返してくれるから、「INSERTできた？（=初回？）」判定がめっちゃやりやすいのも神🙏✨ ([Node.js][3])

---

## 実装：最小セット（コピペで流れが分かる版）✍️✨

### 1) イベント型（イベントIDが超重要🪪✨）

```ts
// src/events.ts
export type DomainEvent<TType extends string, TPayload> = {
  eventId: string;        // ←重複排除のカギ🗝️
  type: TType;
  occurredAt: string;     // ISO文字列
  payload: TPayload;
};

export type OrderPaid = DomainEvent<
  "OrderPaid",
  { orderId: string; paidAmountYen: number; paidAtDay: string } // paidAtDay: "2026-01-24" みたいな
>;
```

> ✅ポイント
>
> * **eventId は“リトライでも同じ”であること**が大事だよ！
>   （ここが変わると重複判定できなくて詰む😇）

---

### 2) SQLiteに「処理済みテーブル」と「Readモデル」を作る🗄️✨

```ts
// src/readmodel/db.ts
import { DatabaseSync } from "node:sqlite";

export function openReadDb(file = "readmodel.db") {
  const db = new DatabaseSync(file);

  db.exec(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS processed_events (
      consumer_id TEXT NOT NULL,
      event_id    TEXT NOT NULL,
      processed_at TEXT NOT NULL,
      PRIMARY KEY (consumer_id, event_id)
    ) STRICT;

    CREATE TABLE IF NOT EXISTS order_list (
      order_id TEXT PRIMARY KEY,
      status   TEXT NOT NULL,
      total_yen INTEGER NOT NULL,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS sales_summary (
      day TEXT PRIMARY KEY,
      total_yen INTEGER NOT NULL,
      updated_at TEXT NOT NULL
    ) STRICT;
  `);

  return db;
}
```

---

### 3) “冪等ガード”を作る（ここが主役👑）

* `INSERT OR IGNORE` で **「初回だけ changes=1」** にする
* 0なら「もう処理済み」なので投影しない
* さらに **同じトランザクション**で投影までやる（安全🔒✨）

```ts
// src/readmodel/idempotency.ts
import type { DatabaseSync } from "node:sqlite";

export function runIdempotently(opts: {
  db: DatabaseSync;
  consumerId: string;
  eventId: string;
  fn: () => void; // 投影（副作用）
}) {
  const { db, consumerId, eventId, fn } = opts;

  db.exec("BEGIN");
  try {
    const inserted = db
      .prepare(
        `INSERT OR IGNORE INTO processed_events (consumer_id, event_id, processed_at)
         VALUES (?, ?, ?)`
      )
      .run(consumerId, eventId, new Date().toISOString());

    if (inserted.changes === 0) {
      // もう処理済みなので何もしない🙂
      db.exec("ROLLBACK");
      return { applied: false as const };
    }

    fn(); // ←ここで投影を実行✨

    db.exec("COMMIT");
    return { applied: true as const };
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }
}
```

> `node:sqlite` の `statement.run()` が `changes` を返す仕様を使ってるよ✅ ([Node.js][3])
> これがあるから「INSERTできた？＝初回？」をキレイに判定できるの🥰

---

### 4) `OrderPaid` の投影を冪等にする💳✨

```ts
// src/readmodel/projectors.ts
import type { DatabaseSync } from "node:sqlite";
import type { OrderPaid } from "../events.js";
import { runIdempotently } from "./idempotency.js";

const CONSUMER_ID = "readmodel.orderProjection.v1"; // ←この文字列は固定が大事🧷

export function projectOrderPaid(db: DatabaseSync, ev: OrderPaid) {
  return runIdempotently({
    db,
    consumerId: CONSUMER_ID,
    eventId: ev.eventId,
    fn: () => {
      // ① 注文一覧：支払い済みにする（上書き系）
      db.prepare(
        `UPDATE order_list
         SET status = 'PAID', updated_at = ?
         WHERE order_id = ?`
      ).run(new Date().toISOString(), ev.payload.orderId);

      // ② 売上集計：加算（本来は二重適用で事故るけど、ガードが守る🛡️）
      db.prepare(
        `INSERT INTO sales_summary(day, total_yen, updated_at)
         VALUES(?, ?, ?)
         ON CONFLICT(day) DO UPDATE SET
           total_yen = total_yen + excluded.total_yen,
           updated_at = excluded.updated_at`
      ).run(ev.payload.paidAtDay, ev.payload.paidAmountYen, new Date().toISOString());
    },
  });
}
```

---

## デモ：同じイベントを2回流しても1回分になる😆🔁✅

```ts
// src/demo.ts
import { openReadDb } from "./readmodel/db.js";
import { projectOrderPaid } from "./readmodel/projectors.js";
import type { OrderPaid } from "./events.js";

const db = openReadDb(":memory:");

// 事前に注文がある体にする（前章までの流れの続きっぽく）
db.prepare(
  `INSERT INTO order_list(order_id, status, total_yen, updated_at)
   VALUES(?, 'ORDERED', ?, ?)`
).run("order-1", 700, new Date().toISOString());

const ev: OrderPaid = {
  eventId: "evt-001", // ←同じIDで2回届く想定
  type: "OrderPaid",
  occurredAt: new Date().toISOString(),
  payload: { orderId: "order-1", paidAmountYen: 700, paidAtDay: "2026-01-24" },
};

console.log(projectOrderPaid(db, ev)); // { applied: true }
console.log(projectOrderPaid(db, ev)); // { applied: false } ←ここ大事😍

console.log(db.prepare("SELECT * FROM sales_summary").all());
```

---

## テスト：冪等性は“テストで守る”のが安心🧪💕

「同じイベント2回 → 変化は1回分」って、**未来の自分を救うテスト**だよ🥹✨

```ts
// test/idempotency.test.ts
import { describe, it, expect } from "vitest";
import { openReadDb } from "../src/readmodel/db.js";
import { projectOrderPaid } from "../src/readmodel/projectors.js";
import type { OrderPaid } from "../src/events.js";

describe("idempotency", () => {
  it("同じ OrderPaid を2回処理しても売上が1回分になる🔁✅", () => {
    const db = openReadDb(":memory:");

    db.prepare(
      `INSERT INTO order_list(order_id, status, total_yen, updated_at)
       VALUES(?, 'ORDERED', ?, ?)`
    ).run("order-1", 700, new Date().toISOString());

    const ev: OrderPaid = {
      eventId: "evt-001",
      type: "OrderPaid",
      occurredAt: new Date().toISOString(),
      payload: { orderId: "order-1", paidAmountYen: 700, paidAtDay: "2026-01-24" },
    };

    projectOrderPaid(db, ev);
    projectOrderPaid(db, ev); // 2回目

    const row = db
      .prepare("SELECT day, total_yen FROM sales_summary WHERE day = ?")
      .get("2026-01-24") as { day: string; total_yen: number };

    expect(row.total_yen).toBe(700); // 1400にならない！🥳
  });
});
```

---

## “実務あるある罠”まとめ 🕳️⚠️（ここ超大事）

### 罠1：イベントIDがリトライで変わる 😇

→ それ、重複判定できないよ〜！
**eventId は「発生した事実のID」**として固定しよ🪪✨

### 罠2：`consumerId` を変えると、別コンシューマ扱いになる🙂

→ `(consumerId, eventId)` がキーなので、consumerIdが変わると全部初回扱い！
バージョン付けするなら計画的にね（`v1`→`v2`）🧷✨

### 罠3：`processed_events` が増え続ける📈

→ いつか掃除が必要🧹
「最大でどれくらいリトライされる？」に合わせて、保持期間を決めるのが定番だよ🙂

### 罠4：“順序の逆転”は別問題🙃

冪等性は「重複」には効くけど、**順序が逆**（Paid→Placed みたいな）には別対策が必要！
ここは後半章の「観測と復旧」「再投影」あたりで強くなるやつ💪✨

---

## 発展：ブローカー側で重複が減るケースもあるよ📬✨（でも冪等は必須）

たとえば SQS の FIFO は「重複を抑える仕組み」があったりする（重複排除ウィンドウ等）けど、設計としては **冪等コンシューマを前提にするのが安全**だよ🛡️ ([AWS ドキュメント][4])
（ブローカーを変えた瞬間に壊れるの、あるあるだから…🥹）

---

## AI活用コーナー🤖💕（この章と相性よすぎ）

### 1) 重複シナリオを10個作ってもらう📝

「どんなタイミングで2回届く？」を増やすと強くなるよ💪✨
例プロンプト👇

* 「イベントが重複配信される原因を、実装目線で10個出して。タイムアウト/再試行/クラッシュ系を混ぜて！」

### 2) テスト観点を増やす🧪

* 「冪等性テストの追加ケースを5つ。特に“別イベントID”“別consumerId”“失敗→リトライ”を含めて！」

### 3) コードレビュー（地味に効く）👀✨

* 「この投影は冪等？重複で壊れる可能性ある？危ない行を指摘して！」

---

## 章末ミニ課題 🎓✨

最後にこれやると定着するよ〜😊💕

1. `OrderPlaced` 側の投影にも同じ冪等ガードを入れる🪪✅
2. `processed_events` に `type` 列を足して、ログ調査しやすくする🔍✨
3. 「2回目は applied:false」になった時のログを1行だけ入れる🧾🙂

---

次の第31章（Outbox）に行くと、「イベントを“落とさない”」話になって、**冪等性がさらに重要**になってくるよ📮✨
続けて作るなら、第30章のこの `runIdempotently` を“部品化”して使い回せる形にも整えていこ〜😊🔧

[1]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html?utm_source=chatgpt.com "Amazon SQS queue types - Amazon Simple Queue Service"
[2]: https://microservices.io/patterns/communication-style/idempotent-consumer.html?utm_source=chatgpt.com "Pattern: Idempotent Consumer"
[3]: https://nodejs.org/api/sqlite.html "SQLite | Node.js v25.4.0 Documentation"
[4]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html?utm_source=chatgpt.com "Exactly-once processing in Amazon SQS"
