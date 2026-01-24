# 第11章　不変条件（Invariants）を入口で守る🚪🛡️✨

この章は「**途中で壊れない**」ための超重要回だよ〜！😊
CQRSって“分ける”のが目立つけど、実は **「壊れない設計」** ができると一気にラクになるの🥹💕

---

### 今日のゴール🎯✨

読み終わったら、これができるようになるよ👇

* ✅ 「不変条件」って何か説明できる
* ✅ 学食アプリの **不変条件リスト** を作れる
* ✅ **入口（Commandの受け口）** と **ドメイン（Order自身）** の両方で守れる
* ✅ テストで「壊れない」を固定できる🧪✨

---

## 1) 不変条件ってなに？🤔🛡️

**不変条件（Invariants）**は、いちどシステムに入ったら **常に守られててほしいルール** のことだよ✨

たとえば…

* ❌ 注文の数量が 0 個（注文なのに何も頼んでない）
* ❌ 合計金額が -100 円（バグか不正かどっちか）
* ❌ メニューIDが空（何を頼んだの…？😇）

こういう「**ありえない状態**」を **作らせない** のが不変条件🛡️✨

### 入力チェックと何が違うの？📝

* **入力チェック**：画面・APIから来た値の“形”を整える（空文字・型・桁など）
* **不変条件**：ドメインとして“成立する状態”かを保証する（意味・ルール）

👉 つまり、不変条件は「**仕様の憲法**」みたいなものだよ📜✨

---

## 2) 学食アプリの不変条件リストを作ろう🍙🧾✨

題材「学食モバイル注文（PlaceOrder）」の例でいくね😊

### Order（注文）の不変条件📦🛡️

* ✅ 注文明細（items）が **1件以上**
* ✅ 各明細の quantity は **1以上**
* ✅ menuId は **必須（空はダメ）**
* ✅ price は **0以上**（無料はOKでもマイナスはNG）
* ✅ 合計 total は **0以上**
* ✅ total は **itemsの合計と一致**（ズレたら改ざん疑い😱）

ここまで守れれば、「注文データが壊れる」事故が激減するよ👍✨

---

## 3) どこで守る？“入口”と“中心”の二段構え💡🛡️

不変条件は基本 **二段構え** が強いよ💪✨

### A. 入口（Commandの受け口）で守る🚪✅

* 変な入力を **早く** 返す（ユーザー体験が良い😊）
* 例：menuId が空なら即NG、quantity が数字じゃないなら即NG

### B. ドメイン（Order自身）で守る📦🛡️

* 入口をすり抜けても **最後の砦** で守る
* 将来、別の入口（バッチ・管理画面・イベント等）が増えても安全

👉 結論：**入口チェックは親切**、**ドメインチェックは安全保障**🛡️✨

---

## 4) 実装してみよう✍️✨（ガード関数＋DomainError）

まず「失敗の形」を揃えるよ😊
（エラー設計の本格回は後でやるけど、ここは最低限でOK！）

### `domain/errors.ts` 🧨

```ts
export class DomainError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

// 小さく始める用（あとでResult型にしてもOK）
export function invariant(condition: unknown, code: string, message: string): asserts condition {
  if (!condition) throw new DomainError(code, message);
}
```

---

## 5) OrderItem と Money で不変条件を守る🍽️💰🛡️

### `domain/money.ts` 💰

```ts
import { invariant } from "./errors";

export class Money {
  private constructor(readonly amount: number) {}

  static yen(amount: number): Money {
    invariant(Number.isFinite(amount), "money.notFinite", "金額が数値じゃないよ🥺");
    invariant(amount >= 0, "money.negative", "金額がマイナスはダメだよ🥺");
    return new Money(amount);
  }

  add(other: Money): Money {
    return Money.yen(this.amount + other.amount);
  }

  multiply(n: number): Money {
    invariant(Number.isInteger(n), "money.multiplier.notInt", "数量は整数にしてね🥺");
    invariant(n >= 0, "money.multiplier.negative", "数量がマイナスはダメだよ🥺");
    return Money.yen(this.amount * n);
  }
}
```

### `domain/orderItem.ts` 🍽️

```ts
import { invariant } from "./errors";
import { Money } from "./money";

export class OrderItem {
  private constructor(
    readonly menuId: string,
    readonly unitPrice: Money,
    readonly quantity: number,
  ) {}

  static create(args: { menuId: string; unitPriceYen: number; quantity: number }): OrderItem {
    const menuId = args.menuId?.trim();
    invariant(menuId.length > 0, "orderItem.menuId.required", "メニューIDが必要だよ🥺");

    invariant(Number.isInteger(args.quantity), "orderItem.quantity.notInt", "数量は整数にしてね🥺");
    invariant(args.quantity > 0, "orderItem.quantity.min", "数量は1以上にしてね🥺");

    const unitPrice = Money.yen(args.unitPriceYen);

    return new OrderItem(menuId, unitPrice, args.quantity);
  }

  lineTotal(): Money {
    return this.unitPrice.multiply(this.quantity);
  }
}
```

---

## 6) Order（集約の中心）で「壊れない」を確定する📦🛡️✨

ここが本丸だよ〜！😊
Orderが「正しい状態」しか作れないなら、世界が平和になる🕊️✨

### `domain/order.ts` 🧾

```ts
import { invariant } from "./errors";
import { Money } from "./money";
import { OrderItem } from "./orderItem";

export class Order {
  private constructor(
    readonly id: string,
    readonly items: readonly OrderItem[],
    readonly total: Money,
  ) {}

  static place(args: { id: string; items: OrderItem[] }): Order {
    const id = args.id?.trim();
    invariant(id.length > 0, "order.id.required", "注文IDが必要だよ🥺");

    invariant(args.items.length > 0, "order.items.empty", "注文は1品以上にしてね🥺");

    const total = args.items
      .map((x) => x.lineTotal())
      .reduce((a, b) => a.add(b), Money.yen(0));

    // total は items から計算する（クライアントから受け取らない）🛡️
    return new Order(id, args.items, total);
  }
}
```

### ポイント超大事🔥

* **totalは外から受け取らない**（改ざん防止🛡️）
* 「Orderが作れた＝不変条件OK」になる✨

---

## 7) 入口（Command）側：親切なチェックを足す🤝✨

ここは「ユーザーに優しく返す」ための入口チェック😊
（ドメインでも守ってるから二重でもOK！むしろ安心💞）

### 7-1) まずは軽量：手書きチェック版✍️

```ts
type PlaceOrderCommand = {
  orderId: string;
  items: { menuId: string; unitPriceYen: number; quantity: number }[];
};

export function validatePlaceOrderCommand(cmd: PlaceOrderCommand): string[] {
  const errors: string[] = [];

  if (!cmd.orderId?.trim()) errors.push("orderId が空だよ🥺");
  if (!Array.isArray(cmd.items) || cmd.items.length === 0) errors.push("items は1件以上必要だよ🥺");

  for (const [i, it] of cmd.items.entries()) {
    if (!it.menuId?.trim()) errors.push(`items[${i}].menuId が空だよ🥺`);
    if (!Number.isInteger(it.quantity) || it.quantity <= 0) errors.push(`items[${i}].quantity は1以上の整数だよ🥺`);
    if (!Number.isFinite(it.unitPriceYen) || it.unitPriceYen < 0) errors.push(`items[${i}].unitPriceYen は0以上だよ🥺`);
  }

  return errors;
}
```

### 7-2) 今どき版：Zodで入口チェック✨（おすすめ😊）

Zod は TypeScript で人気のバリデーション/スキーマ系で、最近も v4 系が安定して更新されてるよ📦✨ ([Zod][1])

```ts
import { z } from "zod";

export const PlaceOrderCommandSchema = z.object({
  orderId: z.string().trim().min(1),
  items: z.array(
    z.object({
      menuId: z.string().trim().min(1),
      unitPriceYen: z.number().finite().min(0),
      quantity: z.number().int().min(1),
    }),
  ).min(1),
});

export type PlaceOrderCommand = z.infer<typeof PlaceOrderCommandSchema>;
```

---

## 8) PlaceOrderHandlerでつなぐ🧩✨（入口→ドメイン）

```ts
import { PlaceOrderCommandSchema, PlaceOrderCommand } from "./placeOrderCommand";
import { OrderItem } from "../domain/orderItem";
import { Order } from "../domain/order";

export async function placeOrderHandler(raw: unknown) {
  // 入口で shape を固める（親切）😊
  const cmd: PlaceOrderCommand = PlaceOrderCommandSchema.parse(raw);

  // ドメインで意味を固める（安全）🛡️
  const items = cmd.items.map((x) => OrderItem.create(x));
  const order = Order.place({ id: cmd.orderId, items });

  // ここで保存（Repositoryは前後の章で育てる想定）
  return order;
}
```

---

## 9) テストで「壊れない」を固定する🧪💖

不変条件って、**テストで固定**すると最強になるよ✨
（未来の自分を救うやつ🥹）

```ts
import { describe, it, expect } from "vitest";
import { OrderItem } from "../domain/orderItem";
import { Order } from "../domain/order";
import { DomainError } from "../domain/errors";

describe("Order invariants", () => {
  it("quantity が 0 なら DomainError", () => {
    expect(() => OrderItem.create({ menuId: "A001", unitPriceYen: 500, quantity: 0 }))
      .toThrow(DomainError);
  });

  it("items が空なら DomainError", () => {
    expect(() => Order.place({ id: "O-1", items: [] }))
      .toThrow(DomainError);
  });
});
```

---

## 10) AI活用🤖✨（ここ、めっちゃ効く！）

### ① 不変条件リストの漏れチェック✅

プロンプト例👇

* 「学食注文ドメインの不変条件を、注文作成・支払い前提で20個出して。優先度も付けて」

👉 出てきた中から「ほんとに必要？」をあなたが判断すると、設計筋が育つよ🧠✨

### ② テストケース自動生成🧪

* 「上の不変条件それぞれに対して、失敗ケースのテスト案を列挙して」

### ③ “どこに置くべき？”相談💬

* 「このチェックは入口？ドメイン？どっちが正しい？理由も」

---

## 11) ミニ演習🎒✨（10〜20分）

1. 不変条件を3つ追加してみてね👇

* 注文IDのフォーマット（例：`O-` で始まる）
* menuId のフォーマット（英数字だけ等）
* unitPriceYen は 1,000,000 以上は弾く（上限）

2. 追加した不変条件の **テストを1本ずつ** 書く🧪✨

---

## 12) 今どきメモ📌✨（最新情報ちょい足し）

* TypeScript は 2025/10 時点で 5.9.3 がリリースとして示されてるよ📌 ([GitHub][2])
* Node.js は v24 系が LTS として案内されていて、2026/01/13 に v24.13.0 のリリース情報も出てるよ🔐 ([nodejs.org][3])
* TypeScript チームは将来の大きな改善（コンパイラ基盤の刷新など）も進捗を共有してるよ🚀 ([Microsoft for Developers][4])

（この章の内容は、そういう将来の変化があっても “設計の芯” としてそのまま使えるやつだよ🛡️✨）

---

## まとめ🎉✨

* 不変条件は「**ありえない状態を作らない**」ためのルール🛡️
* **入口で親切に弾く**＋**ドメインで絶対に守る** の二段構えが最強💪✨
* total みたいな大事な値は **外から受け取らず、ドメインで計算** すると安全🔥
* テストで固定すると未来の自分が泣いて喜ぶ🥹🧪

---

次の第12章（PayOrder💳✨）では、**状態遷移**の不変条件（ORDERED→PAID のルールとか🙅‍♀️）が出てくるから、今日の“壊れない作法”がそのまま活きるよ〜！😊💖

[1]: https://zod.dev/v4?utm_source=chatgpt.com "Release notes"
[2]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
