# 第33章：Read最適化② 集計を速くする発想📊🚀

この章はね、「**集計って重い…😵‍💫**」ってなったときに、CQRSのRead側でスッと解決するための考え方＆手の動かし方を身につける回だよ〜✨
（学食アプリの **売上集計** を題材にいくね🍙）

---

## 今日のゴール🎯✨

終わるころには、これができるようになるよ👇

* 「なぜ集計が遅いのか」を言葉で説明できる🙂🗣️
* **集計用のReadモデル（集計テーブル）** を設計できる📦✨
* イベント（例：`OrderPaid`）で **集計を“増分更新”** する投影を書ける🌱🔁
* 「壊れたらどう直す？」までイメージできる🧯🛠️

---

## まず“遅い集計”を体験しよう😅🐢

売上集計って、最初はこうしたくなる👇

* `orders` と `order_items` をJOINして
* `GROUP BY 日付` して
* `SUM(金額)` して
* `TOP3メニュー`も出して…

これ、データが増えると **毎回“レシートの束を最初から数える”** みたいになるのね📄📄📄😵‍💫
つまり…

> **集計 = 過去全部を何度もなめる処理** になりがち💥

---

## 速くするコツは「計算しないで、貯める」💰✨

ここからがCQRSの気持ちよさ🥹🌸
Read側の集計は、発想をこう変える！

### ✅ 発想チェンジ🧠✨

* ❌ 毎回集計する（その都度SUMする）
* ✅ **集計結果を“Readモデルとして持つ”**（プリ集計して保存）

たとえば👇

* `sales_daily`（日別売上）
* `menu_daily`（日別メニュー別販売数）
* `sales_hourly`（時間帯別売上）

こういう **“ダッシュボード用の完成品テーブル”** を持つのが強いよ📊✨

---

## 集計最適化の代表3パターン🍣（まずは①でOK！）

### ① 集計テーブル（プリ集計）を増分更新する🌱🔁 ←この章のメイン！

* `OrderPaid` が来たら、そのぶんだけ `+` していく
* 速い！単純！CQRSと相性よすぎ！🥳

### ② DBのマテビュー（Materialized View）を使う🧱✨

* 例：PostgreSQLの **Materialized View** を定期更新する
* `REFRESH MATERIALIZED VIEW CONCURRENTLY` には条件（ユニークインデックスが必要等）があるよ📌 ([PostgreSQL][1])

### ③ キャッシュする（アプリ側/Redisなど）🧊⚡

* 集計の“結果”を数十秒〜数分キャッシュ
* 「最新じゃなくてもOK」な画面でめちゃ効く😊

---

## どんな集計を“持つ”のがいいの？（判断ルール）🧭✨

迷ったら、この3つで決めよ〜👇

1. **画面で頻繁に見る？**（管理画面トップ、日次レポートなど）👀
2. **計算が重い？**（JOIN多い、GROUP BYで全走査するなど）🐘
3. **多少の遅れOK？**（最終的整合性と仲良くできる）🕒🙂

当てはまったら、Read側に“持つ”候補だよ✅✨

---

## ハンズオン：集計用Readモデルを作るよ📦🛠️

今回はこの2つを作るね📊✨

### 作る集計テーブル

* `sales_daily`

  * `day`（YYYY-MM-DD）
  * `total_sales`（合計売上）
  * `order_count`（注文数）

* `menu_daily`

  * `day`
  * `menu_id`
  * `qty`（売れた数）
  * `sales`（売上）

そして超重要なのがこれ👇

### 二重カウント防止テーブル（冪等性）🛡️🔁

* `projection_processed`

  * `event_id`（処理済みイベントID）
  * `processed_at`

> これがあると「同じイベントが2回届いた😱」でも大丈夫になるよ✨
> （第30章の冪等性がここで効く〜！）

---

## 実装例（SQLite + TypeScript）🧪✨

最近のNodeには `node:sqlite` が入ってて、SQLiteを扱えるよ〜！ただし **実験的（Stability 1.1）** なので「学習・小規模用途で使う」くらいの温度感が安心🙂 ([Node.js][2])
（しかも今は **`--experimental-sqlite` なしでも使える** って明記されてるよ！うれしい🎉 ([Node.js 中文网][3])）

---

### 1) スキーマ作成🗄️✨

```ts
// src/schema.ts
import sqlite from "node:sqlite";

export function setup(db: sqlite.DatabaseSync) {
  db.exec(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS projection_processed (
      event_id TEXT PRIMARY KEY,
      processed_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS sales_daily (
      day TEXT PRIMARY KEY,
      total_sales INTEGER NOT NULL,
      order_count INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS menu_daily (
      day TEXT NOT NULL,
      menu_id TEXT NOT NULL,
      qty INTEGER NOT NULL,
      sales INTEGER NOT NULL,
      PRIMARY KEY (day, menu_id)
    );

    -- 集計テーブルは“読み取り用”なので、検索しやすい索引も最初から✨
    CREATE INDEX IF NOT EXISTS idx_menu_daily_day_sales
      ON menu_daily(day, sales DESC);
  `);
}
```

---

### 2) `OrderPaid` イベントで集計を増分更新（投影）🌱🔁

```ts
// src/projectors/orderPaidProjector.ts
import sqlite from "node:sqlite";

type OrderPaid = {
  eventId: string;
  occurredAt: string; // ISO文字列
  orderId: string;
  total: number; // 円
  items: Array<{ menuId: string; qty: number; unitPrice: number }>;
};

function toDay(iso: string) {
  // まずは単純に "YYYY-MM-DD" を切り出し（タイムゾーン設計は後で育てるでOK🙂）
  return iso.slice(0, 10);
}

export function applyOrderPaid(db: sqlite.DatabaseSync, ev: OrderPaid) {
  const day = toDay(ev.occurredAt);

  const isProcessed = db
    .prepare("SELECT 1 FROM projection_processed WHERE event_id = ?")
    .get(ev.eventId);

  if (isProcessed) return; // ✅ 冪等性：二重適用しない🛡️

  db.exec("BEGIN");

  try {
    // ① 日別売上をUPsert（加算）
    db.prepare(`
      INSERT INTO sales_daily(day, total_sales, order_count)
      VALUES (?, ?, 1)
      ON CONFLICT(day) DO UPDATE SET
        total_sales = total_sales + excluded.total_sales,
        order_count = order_count + 1
    `).run(day, ev.total);

    // ② メニュー別（日別）もUPsert（加算）
    const upsertMenu = db.prepare(`
      INSERT INTO menu_daily(day, menu_id, qty, sales)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(day, menu_id) DO UPDATE SET
        qty = qty + excluded.qty,
        sales = sales + excluded.sales
    `);

    for (const it of ev.items) {
      const sales = it.qty * it.unitPrice;
      upsertMenu.run(day, it.menuId, it.qty, sales);
    }

    // ③ 処理済みマーク
    db.prepare(`
      INSERT INTO projection_processed(event_id, processed_at)
      VALUES (?, ?)
    `).run(ev.eventId, new Date().toISOString());

    db.exec("COMMIT");
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }
}
```

**ポイント🧠✨**

* 集計の更新は **“足し算”だけ** に寄せると超強い💪
* 取り消し（返金/キャンセル）も、イベントで **マイナス加算** にすると整合性が保ちやすいよ🔁🙂

---

### 3) QueryService：集計は“完成品テーブル”から取る📊✨

```ts
// src/queries/getSalesSummary.ts
import sqlite from "node:sqlite";

export function getDailySales(db: sqlite.DatabaseSync, dayFrom: string, dayTo: string) {
  return db.prepare(`
    SELECT day, total_sales, order_count
    FROM sales_daily
    WHERE day BETWEEN ? AND ?
    ORDER BY day ASC
  `).all(dayFrom, dayTo);
}

export function getTopMenus(db: sqlite.DatabaseSync, day: string, limit = 3) {
  return db.prepare(`
    SELECT menu_id, qty, sales
    FROM menu_daily
    WHERE day = ?
    ORDER BY sales DESC
    LIMIT ?
  `).all(day, limit);
}
```

ここでの気持ちよさ👇🥹✨

* もう `orders` 全走査しない
* 画面表示は **ほぼ集計済みを読むだけ**
* データが増えても「日数ぶん」くらいの処理で済むことが多い🙆‍♀️

---

## “キャッシュ”はどう足す？（軽いやつでOK）🧊✨

集計って「同じ条件で何回も見る」から、キャッシュが刺さるよ〜⚡

* **今日の売上（管理画面トップ）** は 10秒〜60秒キャッシュでも体感ほぼ変わらないこと多い🙂
* まずは **インメモリTTL（Map）** でOK
* 将来、サーバー複数台ならRedisに昇格🎮➡️🏢

（このへんは次章のフロント視点にもつながるよ〜🖥️🔄）

---

## 壊れたらどうする？（再投影テンプレ）🧯🛠️

集計テーブルは「派生物」なので、最悪こうできるのが強み💪✨

1. `sales_daily` / `menu_daily` を空にする
2. すべての `OrderPaid`（＋必要ならCancel/Refund）イベントを古い順に流す
3. 投影で作り直す（再投影）🔁

> だから「Read側は壊れても直せる」設計にしやすいんだ〜😊🌸

---

## AI活用🤖💡（この章でめっちゃ相性いい！）

### ① 集計指標のアイデア出し📊✨

コピペして使ってOK👇

* 「学食アプリの管理画面で見たい指標を10個。**運用で嬉しい理由**も添えて。過剰なら“削る候補”も出して」

### ② 「それ、Readに持つべき？」診断🧠

* 「この集計クエリはReadモデル化すべき？判断理由と、**増分更新できる形**に直して」

### ③ スキーマレビュー🗄️

* 「この集計テーブル設計、将来詰まるポイントある？（タイムゾーン/キャンセル/二重適用/再投影）」

---

## ミニ演習✍️✨（やると強くなるやつ！）

### 演習A：平均客単価（AOV）を出す🍙💰

* `sales_daily` に `total_sales` と `order_count` があるから

  * `avg = total_sales / order_count` を **Query側で計算**して返してみよう🙂

### 演習B：TOP3を「個数」基準にもする🏆

* `ORDER BY qty DESC` のクエリも作って、
  「売上TOP」と「個数TOP」両方出してみてね✨

### 演習C：返金イベント（Refunded）を追加する🔁

* `OrderRefunded` が来たら `-total` してみよう（マイナス投影）🧾➡️🧊

---

## 理解チェック✅🧠（サクッと！）

1. 集計が遅くなる最大の理由は？
   A. TypeScriptが遅いから
   B. 毎回“過去全部”を走査しがちだから
   C. CPUがかわいそうだから

2. 二重カウントを防ぐのに効くのは？
   A. 乱数
   B. `projection_processed` みたいな処理済み記録
   C. 気合い

（答え：1=B、2=B 😆✨）

---

## ちょい最新コラム🗞️✨（2026っぽい話）

* TypeScriptは **5.9** がリリースされてるよ（`tsc --init` の見直しや最適化なども話題） ([Microsoft for Developers][4])
* Nodeは **v24がActive LTS** として更新され続けてる（2026-01-12時点でActive LTS扱い） ([Node.js][5])
* さらに先の話だけど、TypeScriptはネイティブ移植（プレビュー）も進んでて、でかいプロジェクトほど恩恵が出そうって流れもあるよ⚡ ([Microsoft for Developers][6])

---

## まとめ🎉🏁

この章の結論はこれっ👇✨

* **集計はRead側に“完成品”として持つと速い📊🚀**
* 更新イベントで **増分更新** すれば、計算が“足し算”中心になって安定する🌱
* **冪等性（重複排除）** と **再投影** をセットで考えると怖くない🛡️🔁

---

次の章（第34章）は、いよいよ **API設計（CommandとQueryの出入口）🌐🚪** に入るよ！
この章で作った「集計Readモデル」を、APIでどう公開するかがめっちゃ自然につながるはず〜😊✨

[1]: https://www.postgresql.org/docs/current/sql-refreshmaterializedview.html "PostgreSQL: Documentation: 18: REFRESH MATERIALIZED VIEW"
[2]: https://nodejs.org/api/sqlite.html?utm_source=chatgpt.com "SQLite | Node.js v25.4.0 Documentation"
[3]: https://nodejs.cn/api/sqlite.html?utm_source=chatgpt.com "sqlite 轻型数据库| Node.js v24 文档"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/ "Announcing TypeScript 5.9 - TypeScript"
[5]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[6]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
