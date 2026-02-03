# 第11章：トランザクション入門（なぜOutboxとセット？）🔐🪄

## 0. この章のゴール🎯✨

この章を読み終えると…

* トランザクションが「何を守ってるのか」を説明できる🙂
* Outboxが **トランザクションと“セット必須”** な理由が腹落ちする😵‍💫➡️😌
* TypeScriptで「失敗しても事故らない書き込み」を最小コードで体験できる🛠️✅

---

## 1. トランザクションってなに？（超ざっくり）🍙✨

トランザクションは、ひとことで言うと…

> **「この一連の処理、ぜんぶ成功したら確定。どれか失敗したら“ぜんぶ無かったこと”にする」** 仕組み✅❌

たとえば、コンビニで「おにぎり🍙＋お茶🍵」を買う時に
**おにぎりだけお金が引かれて、お茶が渡らない**…みたいな事故は嫌だよね😱
それを防ぐのがトランザクションの感覚だよ🧯✨

---

## 2. なぜOutboxとトランザクションが“セット”なの？📦🔐

Outboxでいちばん怖い事故はこれ👇

### 2-1. 事故パターンA：業務DBは更新できたのに、Outboxに書けなかった📭😱

例：注文を「確定」にした✅ でもOutboxレコードが無い📦❌
→ つまり「外部通知イベントが永遠に飛ばない」＝ **送信漏れ**📭

```text
注文テーブルUPDATE ✅
    ↓（この瞬間にクラッシュ💥）
Outbox INSERT ❌
```

### 2-2. 事故パターンB：Outboxには書けたのに、業務DBが更新できなかった📨😱

例：Outboxに「注文確定イベント」📨 が入ったのに、注文は未確定のまま❌
→ 外側の世界が「確定した」と誤解して、状態がねじれる🌀

```text
Outbox INSERT ✅
    ↓（この瞬間にクラッシュ💥）
注文テーブルUPDATE ❌
```

---

## 3. トランザクションで何が起きる？（絵で理解）🧠🎨

トランザクションにすると、こうなる👇

<!-- img: outbox_ts_study_011_transaction.png -->
```text
BEGIN（ここから1セット）🔐
  注文テーブルUPDATE
  Outbox INSERT
COMMIT（ぜんぶ成功なら確定）✅
   or
ROLLBACK（どれか失敗なら全部取り消し）❌
```

ポイントはコレ👇✨

* ✅ **両方成功なら“同時に確定”**
* ❌ **片方でも失敗なら“両方なかったこと”**

これで「ズレ事故」が激減するんだよ🛡️✨

---

## 4. ACIDって聞くけど…ここでは2つだけ覚えよ🙂📚

トランザクションにはよく **ACID** って言葉が出てくるけど、Outbox入門では **まず2つ** でOK🫶

* **A（Atomicity：原子性）**：全部成功 or 全部失敗 ✅❌
* **D（Durability：耐久性）**：確定（COMMIT）したら、落ちても残る💾🔒

Outboxで今いちばん大事なのは **A（全部成功 or 全部失敗）** だよ🎯✨

---

## 5. 実装で体験しよう（SQLiteで最小）🧪📦

### 5-1. 2026時点の“現実的”な選択（超重要）🧭

* Nodeには組み込みSQLite（`node:sqlite`）があるけど、**実験的APIとして扱われ、フラグが必要なケースがある**よ⚠️（学習では混乱しやすい）([docs.redhat.com][1])
* なのでこの章は、学習がラクでトランザクションが分かりやすい **better-sqlite3** を使うね🙂✨

  * 2026年1月時点でも更新が続いてる版が出てるよ📦([security.snyk.io][2])
  * さらに `transaction()` が用意されてて、実装がかなり簡単🪄([GitHub][3])

（ついでに：Nodeは 2026年2月時点だと v24 がActive LTS、v25がCurrent だよ🧠）([Node.js][4])

---

## 6. テーブル（最小サンプル）🧾📦

```ts
// schema.ts（例）
import Database from "better-sqlite3";

export function initDb(db: Database.Database) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      status TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS outbox (
      id TEXT PRIMARY KEY,
      eventType TEXT NOT NULL,
      payload TEXT NOT NULL,
      status TEXT NOT NULL,
      createdAt TEXT NOT NULL
    );
  `);
}
```

* orders：業務データ（注文）🛒
* outbox：送る予定（イベント）📨

---

## 7. まず“事故る書き方”を見てみる😈💥（トランザクション無し）

```ts
import Database from "better-sqlite3";

type OrderConfirmed = {
  orderId: string;
  confirmedAt: string;
};

export function confirmOrder_NO_TX(db: Database.Database, orderId: string) {
  const now = new Date().toISOString();

  // ① 業務更新（注文を確定）
  db.prepare(
    `UPDATE orders SET status = ?, updatedAt = ? WHERE id = ?`
  ).run("CONFIRMED", now, orderId);

  // 💥ここでクラッシュしたら…Outboxが残らない（送信漏れ）📭
  // わざと落とす実験（学習用）
  // throw new Error("Simulated crash after order update");

  const event: OrderConfirmed = { orderId, confirmedAt: now };

  // ② Outboxにイベントを積む
  db.prepare(
    `INSERT INTO outbox (id, eventType, payload, status, createdAt)
     VALUES (?, ?, ?, ?, ?)`
  ).run(
    crypto.randomUUID(),
    "OrderConfirmed",
    JSON.stringify(event),
    "PENDING",
    now
  );
}
```

この `throw` を有効にして実行すると…

* ordersは **CONFIRMED** になってるのに
* outboxが **1件も増えてない**

みたいな「Outbox最大の事故」を自分で再現できるよ😱📭

---

## 8. 正しい書き方：トランザクションで“セット確定”✅🔐

better-sqlite3は `db.transaction(() => { ... })` があって超ラク🪄([GitHub][3])

```ts
import Database from "better-sqlite3";

type OrderConfirmed = {
  orderId: string;
  confirmedAt: string;
};

export function confirmOrder_TX(db: Database.Database, orderId: string) {
  const tx = db.transaction((orderId: string) => {
    const now = new Date().toISOString();

    // ① 業務更新
    db.prepare(
      `UPDATE orders SET status = ?, updatedAt = ? WHERE id = ?`
    ).run("CONFIRMED", now, orderId);

    // 💥途中で落ちても…
    // throw new Error("Simulated crash inside transaction");

    const event: OrderConfirmed = { orderId, confirmedAt: now };

    // ② Outbox追加
    db.prepare(
      `INSERT INTO outbox (id, eventType, payload, status, createdAt)
       VALUES (?, ?, ?, ?, ?)`
    ).run(
      crypto.randomUUID(),
      "OrderConfirmed",
      JSON.stringify(event),
      "PENDING",
      now
    );
  });

  // ✅ txを呼ぶと「BEGIN→COMMIT/ROLLBACK」をいい感じにやってくれる
  tx(orderId);
}
```

### 8-1. ここが大事ポイント🌟

* `throw` を有効にしても、**ordersもoutboxも“両方とも反映されない”**（ロールバック）❌
* つまり「片方だけ成功」が消える✨
* Outboxにとってはこれが **生命線**🫀📦

---

## 9. よくある勘違い（超ある）🫣💡

### 9-1. 「Outboxに書いたから安全でしょ？」→ まだ半分😵‍💫

Outboxに書くだけではダメで、
**業務更新とOutbox追加が“同じトランザクション”** になって初めて安全🛡️✨

### 9-2. 「じゃあ“DB更新 + メッセージ送信”を同時にトランザクションにすれば？」→ それが難しい🤯

DBと外部メッセージング（Kafka/SQS/HTTP…）は、別システムで、
**1個のトランザクションにまとめるのが現実では重い/難しい**ことが多いの🥺
だから Outbox は「送信は後でやる」作戦で壊れにくくするんだよ📦➡️📤✨

---

## 10. ミニ演習（やると一気に腹落ち）🧪🎓

### 演習A：事故の再現😈💥

1. `confirmOrder_NO_TX` の `throw` を有効化
2. 実行
3. DBを見て

* ordersがCONFIRMEDになってるのに outboxが増えてない → **送信漏れ完成**📭😱

### 演習B：事故が消える体験🛡️✨

1. `confirmOrder_TX` の `throw` を有効化
2. 実行
3. DBを見ると

* ordersもoutboxも変化してない → **ロールバック成功**❌✅

### 演習C：逆事故（Outboxだけ書けた）も試す🌀

* 先にOutbox INSERTしてから orders UPDATE
* 途中で `throw`
  → トランザクション無しだと「外部へ嘘のイベント」が出せちゃう📨😱
  → トランザクション有りだと防げる🛡️✨

---

## 11. AI活用ミニ型🤖✨（この章向け）

### 11-1. 「事故シナリオ」を増やす🧨

Copilot/Codexにこれ投げる👇

```text
Outboxとトランザクションの学習用に、
「業務更新とOutbox追加がズレる事故」を5パターン作って。
それぞれ (1) 何が起きるか (2) どう検知するか (3) どう防ぐか を短く。
```

### 11-3. 「トランザクション境界レビュー」👀

```text
このユースケースでトランザクション境界が正しいかレビューして。
「DB更新とOutbox追加」が同一トランザクションになってるか、
例外時に中途半端な状態が残らないかを重点的に指摘して。
```

---

## 12. まとめ（この章で覚える1行）🧠✨

> **Outboxは「業務更新＋Outbox追加」を“同じトランザクション”で確定するから、安全装置として機能する**📦🔐✅

[1]: https://docs.redhat.com/ja/documentation/red_hat_build_of_node.js/22/html/release_notes_for_node.js_22/technology-preview-features-nodejs?utm_source=chatgpt.com "2.3. テクノロジープレビュー機能 | Node.js 22 のリリースノート"
[2]: https://security.snyk.io/package/npm/better-sqlite3?utm_source=chatgpt.com "better-sqlite3 vulnerabilities"
[3]: https://github.com/WiseLibs/better-sqlite3/blob/master/docs/api.md?utm_source=chatgpt.com "better-sqlite3/docs/api.md at master"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
