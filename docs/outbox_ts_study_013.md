# 第13章：Publisher入門（まずは“疑似送信”でOK）📤🙂

## 13.0 この章でやること（ゴール）🎯✨

この章のゴールはシンプルだよ〜😊
**Outboxテーブルから「未送信」を拾って、疑似的に送って、送信済みに更新する**――これだけ！📦➡️📢➡️✅

* ✅ 未送信（pending）をDBから取る
* ✅ “送信”は最初は **コンソール出力**でOK（疑似送信）📣
* ✅ 送れたら **status を sent に更新**する🧾✅

この「送る係」が **Publisher（または Relay / Message Relay）** だよ〜📤🙂
アウトボックスの基本形として「別プロセスが送る」っていう構造が紹介されてるよ。 ([microservices.io][1])

---

## 13.1 Publisherってなに？（一言で）🧠💡

Publisherは、アプリ本体とは別に動く「配送係」だよ📮✨

* アプリ本体（書き込み側）🛒：注文確定などの業務処理 + Outboxに「送る予定」を記録
* Publisher（送信側）📤：Outboxを見て、外部へ送信して、送れたら「送ったよ」に更新

この分離があると、**業務処理の成功/失敗**と、**送信の成功/失敗**を切り分けられるのが強い💪🌈
（送信は失敗しがちなので、業務ロジックに混ぜると事故りやすい…😵‍💫）

---

## 13.2 まずは「ポーリング型」でいくよ⏱️🔁

この章は **ポーリング（定期的にDBを見る）** で作るよ🙂
「一定間隔で未送信を探す → 送る → 更新する」ってやつ！🔍📤✅

ポーリングでの基本説明（Outboxを定期的に読んで処理して「処理済みにする」）は、こういう形でよく紹介されるよ。 ([decodable.co][2])

---

## 13.3 status設計（最小）🚦✨

第9章で最小カラムを作ってる前提で、この章では **最小の状態**だけ使うよ🙂

* `pending`：未送信📦
* `sent`：送信済み✅
* `failed`：送信失敗（今回は“印を付けるだけ”）❌🥲

> 並行実行（2つのPublisherが同じレコード拾う問題👯‍♀️）は **次章（第14章）** でガッツリやるよ🔒✨
> この章は「まず動く」こと優先でOK😊

---

## 13.4 今どきの実行環境メモ（2026）🪟⚙️

Publisherは「ずっと回る」系だから、**LTS系のNode**が安心だよ🙂
Nodeのリリース状況は公式で、v24がActive LTS、v22がMaintenance LTS になってるよ。 ([Node.js][3])

TypeScriptは **TypeScript 5.9** が正式リリース済み（2025-08-01告知）だよ。 ([Microsoft for Developers][4])

そして便利なのが **tsx**：TypeScriptファイルをそのまま実行しやすいツールだよ（watchもできる）🤖✨
tsx の概要は公式ガイドにまとまってるよ。 ([tsx][5])
npm上でも tsx は継続的に更新されてる（例：2025-11-30更新など）よ。 ([npmjs.com][6])

---

## 13.5 今回のDBは「node:sqlite」で超お手軽にいくよ🗄️✨

学習の最小構成として、**Nodeの組み込み SQLite（node:sqlite）** を使うよ🙂
追加npm installなしでSQLiteを触れるのがうれしいやつ！🎉

* `node:sqlite` は Node v22.5.0 から入ってて
* いまは **実験的（Stability 1.1）** だけど、学習用途にはめちゃ便利だよ🧪✨
* `DatabaseSync` と `prepare().run()` / `prepare().all()` が使えるよ🧾🔧 ([Node.js][7])

---

## 13.6 実装していこう（疑似送信Publisher）🛠️📤🙂

## 13.6.1 Outboxテーブル（例）📦🧾

まずは最小＋ちょい運用っぽい列を足した例だよ（足してもOKなやつだけ）🙂

```sql
CREATE TABLE IF NOT EXISTS outbox (
  id          TEXT PRIMARY KEY,
  event_type  TEXT NOT NULL,
  payload     TEXT NOT NULL,   -- JSON文字列
  status      TEXT NOT NULL,   -- 'pending' | 'sent' | 'failed'
  created_at  TEXT NOT NULL,
  sent_at     TEXT,
  last_error  TEXT,
  attempts    INTEGER NOT NULL DEFAULT 0
) STRICT;
```

* `payload` は JSON を **文字列で保存**（まずはこれでOK）📄✨
* `attempts` と `last_error` は、失敗の雰囲気を残すため（第15〜16章で本格化）🔁📝

---

## 13.6.2 Publisherの処理フロー（超重要）🧠🗺️

頭の中はこれだけでOK😊

1. `pending` を古い順に最大N件取る🔍
2. 1件ずつ疑似送信する📢
3. 成功したら `sent` に更新✅
4. 失敗したら `failed` にして `attempts++` と `last_error` を入れる🥲

---

## 13.6.3 TypeScriptコード（そのまま動く最小構成）✅✨

### (A) `src/db.ts`：DB初期化とステートメント準備🗄️

```ts
import { DatabaseSync } from "node:sqlite";

export type OutboxRow = {
  id: string;
  eventType: string;
  payload: string;   // JSON文字列
  status: "pending" | "sent" | "failed";
  createdAt: string; // ISO文字列
  sentAt: string | null;
  lastError: string | null;
  attempts: number;
};

export function openDb(dbPath = "./dev.db") {
  const db = new DatabaseSync(dbPath);

  db.exec(`
    CREATE TABLE IF NOT EXISTS outbox (
      id          TEXT PRIMARY KEY,
      event_type  TEXT NOT NULL,
      payload     TEXT NOT NULL,
      status      TEXT NOT NULL,
      created_at  TEXT NOT NULL,
      sent_at     TEXT,
      last_error  TEXT,
      attempts    INTEGER NOT NULL DEFAULT 0
    ) STRICT;
  `);

  const stmts = {
    fetchPending: db.prepare(`
      SELECT
        id,
        event_type AS eventType,
        payload,
        status,
        created_at AS createdAt,
        sent_at AS sentAt,
        last_error AS lastError,
        attempts
      FROM outbox
      WHERE status = 'pending'
      ORDER BY created_at
      LIMIT ?
    `),

    markSent: db.prepare(`
      UPDATE outbox
      SET status = 'sent', sent_at = ?, last_error = NULL
      WHERE id = ?
    `),

    markFailed: db.prepare(`
      UPDATE outbox
      SET status = 'failed', attempts = attempts + 1, last_error = ?
      WHERE id = ?
    `),

    insertDemo: db.prepare(`
      INSERT INTO outbox (id, event_type, payload, status, created_at)
      VALUES (?, ?, ?, 'pending', ?)
    `),
  };

  return { db, stmts };
}
```

### (B) `src/publisher.ts`：本体（ポーリング＋疑似送信）📤⏱️

```ts
import { openDb, OutboxRow } from "./db.js";

const POLL_INTERVAL_MS = 1000; // 1秒ごと
const BATCH_SIZE = 10;

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

function nowIso() {
  return new Date().toISOString();
}

/** 疑似送信：まずはコンソールに出すだけ📢 */
async function sendDummy(row: OutboxRow) {
  // payloadはJSON文字列なので、送る前にパースして人間が見やすくするよ🙂
  const body = JSON.parse(row.payload) as unknown;
  console.log("📤 SEND (dummy)", {
    id: row.id,
    eventType: row.eventType,
    body,
  });

  // 送信に時間がかかる感じを演出（学習用）⏳
  await sleep(100);
}

async function main() {
  const { stmts } = openDb();

  console.log("🚀 Publisher started!");

  // Ctrl+C で綺麗に止めたいのでフラグ管理するよ🧯
  let running = true;
  process.on("SIGINT", () => {
    console.log("\n🛑 SIGINT received. stopping...");
    running = false;
  });

  while (running) {
    const rows = stmts.fetchPending.all(BATCH_SIZE) as OutboxRow[];

    if (rows.length === 0) {
      // 未送信が無いなら少し待つ😴
      await sleep(POLL_INTERVAL_MS);
      continue;
    }

    console.log(`🔍 found ${rows.length} pending message(s)`);

    for (const row of rows) {
      try {
        await sendDummy(row);
        stmts.markSent.run(nowIso(), row.id);
        console.log(`✅ marked as sent: ${row.id}`);
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        stmts.markFailed.run(message, row.id);
        console.log(`❌ failed: ${row.id} (${message})`);
      }
    }
  }

  console.log("👋 Publisher stopped.");
}

main().catch((e) => {
  console.error("💥 Publisher crashed:", e);
  process.exitCode = 1;
});
```

### (C) `src/demo-write.ts`：未送信データを入れるテスト用🧪📦

```ts
import crypto from "node:crypto";
import { openDb } from "./db.js";

function uuid() {
  return crypto.randomUUID();
}
function nowIso() {
  return new Date().toISOString();
}

const { stmts } = openDb();

const payload = {
  orderId: "ORDER-123",
  userId: "USER-999",
  totalYen: 3980,
  confirmedAt: nowIso(),
};

const id = uuid();
stmts.insertDemo.run(
  id,
  "OrderConfirmed",
  JSON.stringify(payload),
  nowIso()
);

console.log("📦 inserted pending outbox:", id);
```

---

## 13.6.4 実行方法（VS Codeで2ターミナル）🪟🧑‍💻

1. **ターミナルA**：Publisher起動📤
2. **ターミナルB**：demo-writeでOutbox投入📦

tsx を使うと楽ちんだよ（TypeScriptをそのまま実行しやすい） ([tsx][5])

`package.json` の例：

```json
{
  "type": "module",
  "scripts": {
    "publisher": "tsx src/publisher.ts",
    "write:demo": "tsx src/demo-write.ts"
  },
  "devDependencies": {
    "tsx": "^4.21.0",
    "typescript": "^5.9.0"
  }
}
```

* `npm run publisher` → 🚀 起動
* `npm run write:demo` → 📦 追加
* Publisher側で `📤 SEND (dummy)` が出て、`✅ marked as sent` が出たら成功🎉✨

---

## 13.7 つまずきポイント集（ありがち）🧯💡

## 13.7.1 「ずっと回るとCPUが心配」😵‍💫

* 未送信が0件のときに **sleep** が入ってればOK😴
* もしログがうるさければ「0件時は何も出さない」でもOK🙂

## 13.7.2 「payloadが壊れててJSON.parseで落ちる」💥

* それも立派な“送信失敗”だから、`failed` にして `last_error` に残せばOK📝
* 第15章で「失敗の分類」として扱いやすくなるよ🔁✨

---

## 13.8 AI（Copilot/Codex）で爆速に進めるプロンプト例🤖💨

## 雛形生成（Publisherクラス化したい時）🏗️

```text
TypeScriptでOutbox Publisherを作りたいです。
要件:
- OutboxRow型
- OutboxRepositoryインターフェース（fetchPending, markSent, markFailed）
- Publisherがポーリングして1件ずつ処理する
- 例外は1件単位で握りつぶして次へ進む
最小の実装例をください。
```

## コードレビュー（責務混ざってない？）👀

```text
このpublisher.tsをレビューして、責務が混ざっている箇所と改善案を指摘して。
「DB」「送信」「ポーリング制御」「ログ」を分離したい。
```

## テスト案（次の章への布石）🧪

```text
Outbox Publisherのテスト観点を列挙して。
特に「送信成功」「送信失敗」「payload不正」「0件」「大量件数」をカバーしたい。
```

---

## 13.9 小テスト＆課題（手を動かすやつ）✍️🎓

1. **送信失敗をわざと起こす**😈

   * `eventType === "OrderConfirmed"` のときだけ `throw new Error("boom")` してみてね
   * `failed` に更新され、`last_error` が入ればOK✅

2. **batch size を 1→10 に変えて挙動観察**👀

   * まとめて処理される感じが掴めるよ📦📦📦

3. **sent のレコードは二度と拾われないことを確認**🔁❌

   * `WHERE status='pending'` が効いてるようならOK👍

---

## 13.10 この章のまとめ📌🎉

* Publisherは **Outboxから拾って送って更新する係**📤🙂
* 最小構成は **pendingを取得 → 疑似送信 → sentに更新** でOK✅
* Nodeの組み込み `node:sqlite` を使うと学習が超ラク（ただし実験的）🗄️🧪 ([Node.js][7])
* 次章（第14章）は「複数Publisherで二重送信しない」ためのロック・並行実行の話へ進むよ👯‍♀️🔒✨

[1]: https://microservices.io/patterns/data/transactional-outbox.html "Pattern: Transactional outbox"
[2]: https://www.decodable.co/blog/revisiting-the-outbox-pattern?utm_source=chatgpt.com "Revisiting the Outbox Pattern"
[3]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/ "Announcing TypeScript 5.9 - TypeScript"
[5]: https://tsx.is/ "TypeScript Execute (tsx) | tsx"
[6]: https://www.npmjs.com/package/tsx?utm_source=chatgpt.com "tsx"
[7]: https://nodejs.org/api/sqlite.html "SQLite | Node.js v25.5.0 Documentation"
