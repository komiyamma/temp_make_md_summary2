# 第20章　Readモデルの置き場（最初はシンプルでOK）📦🪶

この章でやることはシンプルだよ〜😊✨
**「Readモデル（表示用データ）って、どこに置くのがいいの？」**を、迷わず決められるようになるのがゴール！🎯💕

---

## 1) Readモデルの「置き場」を決めると何が嬉しいの？🤔💡

Readモデルって、**画面が欲しい形に整形された“表示専用データ”**だよね📋✨
だから置き場は、ざっくりこういう性格があるとラク！

* **Queryが速い**🚀（一覧、検索、集計がサクサク）
* **Write側（更新ルール）と分離できる**🧼（更新ロジックが汚れない）
* **あとで作り直せる**🔄（Readは投影で再構築できる）

「Readは壊れても作り直せる」って考え方、めっちゃ大事🫶✨
（もちろんユーザー影響は最小にするけどね！）

---

## 2) 置き場の選択肢はこの3つでOKだよ 😊🧭

### A. まずはメモリ（in-memory）🧠✨

**おすすめ度：開発初期は最強！**

* 👍 超カンタン、爆速、依存ゼロ
* 👎 再起動で消える、複数台に弱い

**向いてる場面**

* 1プロセスで動かす間（学習・試作）🧪
* 「まずCQRSの分け方」を体で覚える時💃

---

### B. SQLite（ローカルファイル）🗃️✨

**おすすめ度：初学者の“ちょうどいい永続化”**
最近のNodeは **SQLiteを標準で扱える `node:sqlite`** が入ってて、`':memory:'` だけじゃなく**ファイルDB**にもできるよ📌
しかも **`--experimental-sqlite` のフラグなしで使える版が増えてきてる**（ただしまだ “experimental” 扱い）だよ〜🧡 ([Node.js][1])

* 👍 再起動しても残る、セットアップ軽い、SQLで一覧/集計が書きやすい
* 👎 同期API中心なので、重いクエリを雑に叩くと詰まることがある

**向いてる場面**

* 「学食アプリ」をローカルでそれっぽく動かす🍙📱
* 一覧・集計のSQLを体験したい📊✨

---

### C. 外部DB / 別サービス（Postgres、Read API、libSQL/Turso など）🌐🏗️

**おすすめ度：複数台・本番っぽくなると必要**

* 👍 複数インスタンスに強い、運用しやすい構成も取りやすい
* 👎 設計・運用コストが上がる

特に **libSQL は SQLite互換を保ちつつ拡張していく方針**が明言されてて、SQLiteの感覚のまま “外に出す” 選択肢になりやすいよ🧠✨ ([Turso][2])
Node向けの `libsql-js` もあって、**better-sqlite3互換APIを目指す**って説明があるよ〜🔧 ([GitHub][3])

---

## 3) 迷ったらこの「4問」で決めよっか 🧭✨

### Q1. 再起動してもデータ残したい？🔄

* **No** → **A: メモリ**でOK🙆‍♀️
* **Yes** → Q2へ

### Q2. サーバーを複数台で動かす予定ある？🖥️🖥️

* **No** → **B: SQLite**がちょうどいい🗃️
* **Yes** → Q3へ

### Q3. Readモデルを別プロセス/別チームでも触る？👥

* **Yes** → **C: 外部DB/Read API**が強い🌐
* **No** → Q4へ

### Q4. “学習・試作” ？それとも “運用前提” ？🎓🏁

* 学習・試作 → **A→Bの順で成長**が一番スムーズ✨
* 運用前提 → 早めに **C** を検討🛠️

---

## 4) ハンズオン：ReadRepositoryを差し替え可能にする 🧩✨

ここが第20章のいちばん大事ポイント！
**「置き場は後で変えてOK」**にするために、Read側は **Repositoryをインターフェース化**しておくよ💕

### 4-1. Readモデル（一覧用DTO）を用意 📋✨

```ts
// src/queries/readmodel/OrderListRow.ts
export type OrderStatus = "ORDERED" | "PAID" | "CANCELLED";

export type OrderListRow = {
  orderId: string;
  status: OrderStatus;
  totalYen: number;
  itemCount: number;
  createdAt: string; // ISO文字列でOK（まずは）
  paidAt?: string;   // 未払いなら undefined
};
```

### 4-2. ReadRepositoryのインターフェース 🧼🚫（副作用ゼロ）

```ts
// src/queries/readmodel/OrderReadRepository.ts
import type { OrderListRow } from "./OrderListRow";

export interface OrderReadRepository {
  getOrderList(limit: number, offset: number): Promise<OrderListRow[]>;
  getOrderById(orderId: string): Promise<OrderListRow | undefined>;
}
```

---

## 5) 置き場A：in-memory 実装 🧠✨（最速で動く！）

```ts
// src/queries/readmodel/InMemoryOrderReadRepository.ts
import type { OrderReadRepository } from "./OrderReadRepository";
import type { OrderListRow } from "./OrderListRow";

export class InMemoryOrderReadRepository implements OrderReadRepository {
  private rows: OrderListRow[];

  constructor(seed: OrderListRow[] = []) {
    this.rows = [...seed];
  }

  async getOrderList(limit: number, offset: number): Promise<OrderListRow[]> {
    return this.rows.slice(offset, offset + limit);
  }

  async getOrderById(orderId: string): Promise<OrderListRow | undefined> {
    return this.rows.find(x => x.orderId === orderId);
  }
}
```

**これで「Queryの形」を先に固められる**のが超えらい👏✨
Readモデルの置き場を悩む前に、まず動かせる💨

---

## 6) 置き場B：SQLite 実装 🗃️✨（Node標準の `node:sqlite` を使う）

Nodeのドキュメントに `node:sqlite` があって、`DatabaseSync(':memory:')` みたいに使える例が載ってるよ📌 ([Node.js][1])
同じ要領でファイルDBにもできる！（例：`./data/read.db`）

### 6-1. SQLiteテーブル設計（Readモデルは“画面都合”でOK）🎁

* テーブル名：`read_order_list`
* “一覧で欲しい列だけ”持つ（ドメインを丸ごとコピーしない）✂️✨

### 6-2. 実装例

```ts
// src/queries/readmodel/SqliteOrderReadRepository.ts
import type { OrderReadRepository } from "./OrderReadRepository";
import type { OrderListRow, OrderStatus } from "./OrderListRow";
import { DatabaseSync } from "node:sqlite";

type DbRow = {
  orderId: string;
  status: OrderStatus;
  totalYen: number;
  itemCount: number;
  createdAt: string;
  paidAt: string | null;
};

export class SqliteOrderReadRepository implements OrderReadRepository {
  private db: DatabaseSync;

  constructor(dbPath: string) {
    this.db = new DatabaseSync(dbPath);
    this.init();
  }

  private init() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS read_order_list (
        orderId   TEXT PRIMARY KEY,
        status    TEXT NOT NULL,
        totalYen  INTEGER NOT NULL,
        itemCount INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        paidAt    TEXT
      ) STRICT;
    `);
  }

  async getOrderList(limit: number, offset: number): Promise<OrderListRow[]> {
    const stmt = this.db.prepare(`
      SELECT orderId, status, totalYen, itemCount, createdAt, paidAt
      FROM read_order_list
      ORDER BY createdAt DESC
      LIMIT ? OFFSET ?
    `);

    const rows = stmt.all(limit, offset) as DbRow[];
    return rows.map(this.toDto);
  }

  async getOrderById(orderId: string): Promise<OrderListRow | undefined> {
    const stmt = this.db.prepare(`
      SELECT orderId, status, totalYen, itemCount, createdAt, paidAt
      FROM read_order_list
      WHERE orderId = ?
      LIMIT 1
    `);

    const row = stmt.get(orderId) as DbRow | undefined;
    return row ? this.toDto(row) : undefined;
  }

  private toDto(row: DbRow): OrderListRow {
    return {
      orderId: row.orderId,
      status: row.status,
      totalYen: row.totalYen,
      itemCount: row.itemCount,
      createdAt: row.createdAt,
      paidAt: row.paidAt ?? undefined,
    };
  }
}
```

> メモ：`node:sqlite` は “Active development” で experimental 扱いが残ってる点は把握してね〜🧡（でも学習・試作には超便利！） ([Node.js][1])

---

## 7) QueryService 側は「置き場を意識しない」✨🧼

```ts
// src/queries/OrderQueryService.ts
import type { OrderReadRepository } from "./readmodel/OrderReadRepository";
import type { OrderListRow } from "./readmodel/OrderListRow";

export class OrderQueryService {
  constructor(private readonly repo: OrderReadRepository) {}

  async getOrderList(): Promise<OrderListRow[]> {
    return this.repo.getOrderList(20, 0);
  }

  async getOrderDetail(orderId: string) {
    return this.repo.getOrderById(orderId);
  }
}
```

ここが最高にCQRSっぽいところ！😍✨
**QueryServiceは「どこに置いてるか」を知らない**＝後で差し替えが効く！🔁

---

## 8) ミニ演習：「今は何を選ぶ？」🧩🧭✨

次の要件を読んで、A/B/Cのどれにするか決めてみてね😊💕

### ケース1：とにかく学習最優先！🧪

* ローカルで動けばOK
* リセットされても気にしない

➡️ **A：メモリ** 🧠✨

### ケース2：再起動しても一覧が残ってほしい📌

* でも運用はまだ
* SQLで集計も試したい📊

➡️ **B：SQLite** 🗃️✨（`node:sqlite` が楽！） ([Node.js][1])

### ケース3：サーバー2台以上で動かす前提🖥️🖥️

* 台ごとにReadがズレたら困る
* 監視・バックアップも考えたい

➡️ **C：外部DB/Read API** 🌐🏗️
（SQLite互換のまま外に出すなら libSQL/Turso も候補になるよ） ([Turso][2])

---

## 9) AI活用プロンプト（コピペでOK）🤖💕

* 「`OrderListRow` に必要な列だけに絞って。画面は “注文一覧” で、表示は `注文ID/状態/合計/点数/作成日時/支払日時` だけ」
* 「`OrderReadRepository` の実装を **in-memory と SQLite** の2種類で作って。どっちも同じインターフェースで」
* 「SQLの `ORDER BY` と `INDEX` を提案して。想定データ件数は1万件」
* 「QueryServiceが “更新” をしてないか監査して。副作用がある行があったら指摘して」🕵️‍♀️✨

---

## 10) よくある落とし穴（ここだけ注意！）⚠️😵‍💫

* **Readに“更新ロजिक”を入れちゃう** → 第19章の「副作用ゼロ」を破るやつ🙅‍♀️
* **Readモデルにドメインを丸ごとコピー** → 後で変更が地獄👹（必要な列だけ！）
* **置き場選びで詰まって前に進めない** → 最初は **A→B** が正解ルートになりやすいよ😊🫶

---

次の第21章（エラー設計）に行く前に、もしよければ💕
あなたの「学食アプリ」の想定で、**“一覧画面に出したい項目”**を一緒に確定して、Readモデル（テーブル/DTO）をもっと気持ちよく整えよっか？😍📋✨

[1]: https://nodejs.org/api/sqlite.html "SQLite | Node.js v25.4.0 Documentation"
[2]: https://docs.turso.tech/libsql?utm_source=chatgpt.com "libSQL"
[3]: https://github.com/tursodatabase/libsql-js?utm_source=chatgpt.com "tursodatabase/libsql-js: A better-sqlite3 compatible API for ..."
