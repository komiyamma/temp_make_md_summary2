# 第19章 冪等性入門（同じイベントが来ても平気）🔁🧷

## 🎯 ゴール

* 「同じドメインイベントが2回以上来ても壊れない」ってどういうことか説明できる😊
* TypeScriptで「二重実行でもポイントが2回付かない」ハンドラを作れる🪙✅
* **eventIdで重複排除**と、**業務キー（orderIdなど）で重複排除**の使い分けができる🧠✨

---

## 1) まず結論：イベントは “重複する前提” で設計するよ🧯

メッセージングやリトライがある世界では、**同じイベントがもう一度届く**のはわりと普通に起きます😵‍💫
だから「1回しか来ない前提」で作ると、だいたい事故ります💥

---

## 2) 冪等性（Idempotency）ってなに？🧠🔁

ざっくり言うと👇

> **同じ入力を何回やっても、結果が1回分と同じになる性質**✨

イベントハンドラで言えば👇

* ✅ `OrderPaid` が2回来ても **ポイントは1回だけ付与**
* ✅ `OrderPaid` が2回来ても **在庫は1回だけ減る**
* ✅ `OrderPaid` が2回来ても **DBの状態が壊れない**

---

## 3) よくある事故ストーリー（ミニEC）🛒💥

たとえば `OrderPaid` を受けて「ポイント付与」するハンドラがあるとします🪙

1回目のイベントでポイント付与 ✅
でも…ネットワークの都合とかで、同じイベントが **もう一度** 届いた😇
→ 2回目でもポイント付与してしまう😱
→ ユーザー大喜び（運営は真っ青）🫠

**これを防ぐのが冪等性**です🧷✨

---

## 4) 重複排除の考え方は大きく2系統あるよ🧠📌

### A. eventId で重複排除（いちばん基本）🧾🔒

イベントには `eventId` が入ってる（第9章の共通フォーマットのやつ）前提で👇
「この eventId は処理済み？」を見て、処理するか決めます✅

* 👍 “同じイベントの再配送” に強い
* 👀 ただし「同じ内容だけど eventId が別」だと効かないことがある⚠️

`eventId` を作るのに、Node.js なら `crypto.randomUUID()` が使えます🧬✨（Node公式で `crypto.randomUUID([options])` が定義されています） ([Node.js][1])

### B. 業務キーで重複排除（orderId とか）🧾🧠

「注文ID（orderId）×イベント種別（type）」みたいな **業務的に一意** なキーで弾く方法✨

* 👍 “eventId が変わって再発行された” みたいなケースにも強い
* ⚠️ ただし「同じ注文で2回起きうる正当なイベント」があると、弾きすぎて事故る😵‍💫

---

## 5) 実装の鉄板パターン3つ（初心者向けに超重要）🥇✨

### パターン①：処理済みイベント表（Processed Events）🗂️✅

* `processed_events` に `eventId` を保存
* すでにあればスキップ

**DBのユニーク制約**と組み合わせると強い💪
（insertできた人だけが処理する、みたいな感じ）

### パターン②：副作用そのものを “一回だけ” にする（ポイント付与向き）🪙🔒

「ポイント付与」を **ポイント取引（transaction）** として保存して、
`eventId` を **取引の一意キー**にするやり方✨

* 👍 “ポイントが2回付く” を根本から防げる
* 👍 途中で落ちても再実行しやすい
* ✅ いちばんおすすめ（内部DBで完結する副作用に強い）🌟

### パターン③：外部API側の冪等性キーを使う（メール/決済など）📨🧾

外部サービスが「Idempotency-Key」みたいなのをサポートしてたら最強🥹✨
（この章では詳細は扱わないけど、知ってると得するやつ💡）

---

## 6) ハンズオン：ポイント付与ハンドラを冪等にする🪙🔁

ここでは **パターン②（副作用そのものを一回だけ）** を作るよ💖
「同じイベントが2回届いても、ポイント残高が1回ぶんしか増えない」✅

### 6.1 まずイベント型を用意しよう🧾

```ts
// src/domain/events.ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  occurredAt: string; // ISO文字列
  aggregateId: string;
  type: TType;
  payload: TPayload;
}>;

export type OrderPaid = DomainEvent<
  "OrderPaid",
  {
    orderId: string;
    userId: string;
    totalYen: number;
  }
>;
```

### 6.2 eventId を作るヘルパ（Nodeの crypto.randomUUID）🧬✨

```ts
// src/domain/eventFactory.ts
import { randomUUID } from "node:crypto"; // Nodeの crypto.randomUUID が使えるよ :contentReference[oaicite:1]{index=1}

export function newEventId(): string {
  return randomUUID();
}
```

### 6.3 ポイント付与を “取引” として記録する🪙🧾

ここがミソ！
「ポイント残高を直接 +10 する」だけだと二重で増えちゃうので、
**eventId をキーにした取引**を作って「同じ eventId は2回登録できない」ようにするよ🔒✨

```ts
// src/infrastructure/pointsRepository.ts
export type PointTransaction = Readonly<{
  eventId: string;  // ここが冪等性キー✨
  userId: string;
  points: number;
  createdAt: string;
}>;

export class PointsRepository {
  // 学習用のインメモリ実装（本番はDBでやるイメージ🗄️）
  private transactions = new Map<string, PointTransaction>(); // key = eventId
  private balances = new Map<string, number>(); // key = userId

  /**
   * eventId が未登録ならポイントを反映して true。
   * すでに登録済みなら何もしないで false。
   */
  async addPointsOnce(tx: PointTransaction): Promise<boolean> {
    if (this.transactions.has(tx.eventId)) return false; // 重複イベントだね👀

    // 取引を保存（本番ならユニーク制約のあるテーブルに INSERT するイメージ🗂️🔒）
    this.transactions.set(tx.eventId, tx);

    const current = this.balances.get(tx.userId) ?? 0;
    this.balances.set(tx.userId, current + tx.points);
    return true;
  }

  async getBalance(userId: string): Promise<number> {
    return this.balances.get(userId) ?? 0;
  }
}
```

### 6.4 `OrderPaid` → ポイント付与ハンドラを作る🎯🪙

```ts
// src/application/handlers/grantPointsOnOrderPaid.ts
import type { OrderPaid } from "../../domain/events";
import { PointsRepository } from "../../infrastructure/pointsRepository";

export class GrantPointsOnOrderPaidHandler {
  constructor(private readonly pointsRepo: PointsRepository) {}

  async handle(event: OrderPaid): Promise<void> {
    // 例：100円につき1ポイント（適当ルール）
    const points = Math.floor(event.payload.totalYen / 100);

    const applied = await this.pointsRepo.addPointsOnce({
      eventId: event.eventId,
      userId: event.payload.userId,
      points,
      createdAt: new Date().toISOString(),
    });

    if (!applied) {
      // ここが冪等性！同じイベントが来ても安全にスキップ✅
      return;
    }

    // ここに「ログ」などを入れると運用が楽👀（第24章につながる）
  }
}
```

---

## 7) テスト：同じイベントを2回流しても1回分しか増えない🧪💖

テストランナーは Vitest が便利です（Vitest 4 がリリースされています） ([Vitest][2])

```ts
// test/grantPointsOnOrderPaid.test.ts
import { describe, it, expect } from "vitest";
import { PointsRepository } from "../src/infrastructure/pointsRepository";
import { GrantPointsOnOrderPaidHandler } from "../src/application/handlers/grantPointsOnOrderPaid";
import type { OrderPaid } from "../src/domain/events";

describe("GrantPointsOnOrderPaidHandler (idempotent)", () => {
  it("同じ eventId の OrderPaid が2回来てもポイントは1回しか増えない🪙", async () => {
    const repo = new PointsRepository();
    const handler = new GrantPointsOnOrderPaidHandler(repo);

    const event: OrderPaid = {
      eventId: "evt-001",
      occurredAt: new Date().toISOString(),
      aggregateId: "order-123",
      type: "OrderPaid",
      payload: { orderId: "order-123", userId: "user-1", totalYen: 1200 },
    };

    await handler.handle(event);
    await handler.handle(event); // 2回目（重複）🔁

    expect(await repo.getBalance("user-1")).toBe(12); // 1200/100 = 12 ✅
  });
});
```

---

## 8) 演習：「ポイント付与」二重実行対策を2案書こう🪙🧠

### 📝 お題

`OrderPaid` を受けてポイントを付与したい！でも重複イベントが来るかも！

### 案1（eventId で重複排除）🧾✅

* `processed_events(eventId)` を作る
* `eventId` がなければ処理、あればスキップ

**メリット**：単純！
**注意**：処理の途中で失敗したときの扱いを考える必要あり（後の章で深掘りするやつ）🧯

### 案2（業務キーで重複排除）🧾🧠

* `point_transactions(type, orderId)` をユニークにする
  例：`("OrderPaid", "order-123")` は1回だけOK
* eventId が変わっても弾ける

**メリット**：eventId が変わっても耐えやすい
**注意**：同じ注文で “正当な2回目” がありうるなら弾きすぎる⚠️

---

## 9) AI活用（Copilot / Codex向け）🤖✨

そのまま投げてOKなお願い例だよ💬💖

* 「`OrderPaid` ハンドラを冪等にしたい。eventId をキーにしてポイント二重付与を防ぐ設計を3案出して」🧠
* 「このハンドラは “業務キー” と “eventId” どっちで冪等にすべき？メリデメ付きで」⚖️
* 「Vitestで “同一イベント2回” のテストケースを追加して。境界値も」🧪✨
* 「eventIdが変わって再発行された場合の対策案を、壊れにくい順に並べて」🧯

---

## 10) まとめ（ここだけ覚えればOK）✅✨

* イベントは **重複する前提**で作るのが普通🔁
* 冪等性は「同じイベントを何回処理しても結果が1回分と同じ」🧷
* いちばん実装しやすいのは **eventIdで重複排除**🧾
* “ポイント付与” みたいな内部処理は **取引テーブル化（eventIdをユニークキー）**が強い🪙🔒
* `crypto.randomUUID()` で eventId を作るのも定番だよ🧬 ([Node.js][1])

---

## ✅ チェックリスト（自分のハンドラを見直す用）👀📝

* [ ] 同じイベントが2回来たらどうなる？（ポイント2倍？メール2通？😱）
* [ ] 冪等性キーは決まってる？（eventId / orderId / type+orderId など）🧾
* [ ] “一回だけ” を **DBのユニーク制約**で守れる？🔒
* [ ] テストで「同一イベント2回」を必ず入れてる？🧪💖

---

### 🌟 おまけ：最新ツール周りの小ネタ（知ってると嬉しい）💡

* Node.js は **Active LTS / Maintenance LTS** を本番向けにするのが基本、という方針が公式に書かれています🧱 ([Node.js][3])
* TypeScript は「ネイティブ版プレビュー（TypeScript 7 native preview）」の話が進んでいて、コンパイルが大幅に速くなる方向みたい👀⚡ ([developer.microsoft.com][4])

[1]: https://nodejs.org/api/crypto.html "Crypto | Node.js v25.4.0 Documentation"
[2]: https://vitest.dev/blog/vitest-4 "Vitest 4.0 is out! | Vitest"
[3]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[4]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026 "TypeScript 7 native preview in Visual Studio 2026 - Microsoft for Developers"
