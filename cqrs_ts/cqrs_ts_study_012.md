# 第12章　コマンド設計②（PayOrder：支払う）💳✨

今回は「状態が変わる更新（ORDERED → PAID）」を、**壊れない形で**作る章だよ〜！😊🌸
“支払い”って、ただフラグを立てるだけに見えて…実は **ルールの塊** なのです😆🧠

---

### まず最初に：今日時点の“最新メモ”🗓️✨

（教材を2026年の空気で作るための、軽いメモだよ〜🙂）

* TypeScript は npm の `latest` が **5.9.3**（2026/01/24時点）だよ📦✨ ([NPM][1])
* Node.js は **v24 系が Active LTS** で、直近だと **24.13.0（2026-01-13）** が出てるよ🔐🟢 ([nodejs.org][2])
* テストはこの後の章でやるけど、最近は **Vitest 4.0（2025-10-22）** みたいな選択肢が主流寄りだよ🧪⚡ ([vitest.dev][3])
* バリデーション用の定番ライブラリだと Zod の `latest` が **4.3.6** になってるよ（超よく使われるやつ）🧩✨ ([NPM][4])

---

## 1) この章のゴール🎯✨

PayOrder（支払う）を作って、次を達成するよ😊

* ✅ **状態遷移**（ORDERED → PAID）をきれいに表現できる
* ✅ **禁止条件**（未注文は払えない / すでに支払い済みはダメ等）を “仕様” として固定できる
* ✅ Handler に詰め込まず、**ドメインにルールを置ける**

---

## 2) 状態遷移ってなに？（いちばん大事）🧠🔁

PayOrder は「値を更新」じゃなくて、**状態が変わるイベント級の更新**だよ📣✨
だから、まずはこれを図にしちゃうのが最強☺️🖊️

```text
ORDERED  -- PayOrder -->  PAID
   ▲                      │
   └------ (PayOrder NG) --┘  ※すでにPAIDなら支払い禁止🙅‍♀️
```

### PayOrder の禁止条件（この章の主役）🚫✨

最低限これだけは守ろうね😊

* 🙅‍♀️ 注文が存在しない（Order が見つからない）
* 🙅‍♀️ 注文が ORDERED じゃない（例：PAID）
* 🙅‍♀️ すでに支払い済み（＝二重決済の芽🌱）

> ポイント：**禁止条件は“仕様”**だよ！
> 「例外が出たからエラー」じゃなくて、「仕様としてこう返す」って決めるのが設計🥰

---

## 3) 実装の置き方（どこに何を書く？）📦🧩

ざっくりこうするのが気持ちいいよ〜😊✨

* **Command（PayOrder）**：やりたいことの入力（orderId, paymentId…）🧾
* **Handler**：流れ（取得→ドメイン実行→保存）🚶‍♀️
* **Domain（Order.pay）**：ルール（支払える条件、状態遷移）🛡️

> Handler に if を積み上げると、後で死ぬほど太るよ😇（経験者は語る）

---

## 4) 型を用意しよう（Result と DomainError）🧰✨

「成功 or 失敗」を **型で表す** と、設計が急にスッキリするよ😊🌸

### Result（成功/失敗の共通型）

```ts
// src/application/common/result.ts
export type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });
```

### DomainError（仕様エラー）

```ts
// src/domain/errors.ts
export type DomainError =
  | { type: "OrderNotFound"; orderId: string }
  | { type: "OrderNotPayable"; status: OrderStatus }
  | { type: "AlreadyPaid"; paymentId?: string };

export type OrderStatus = "ORDERED" | "PAID";
```

> “例外 throw しないの？”ってなるけど、ここでは **仕様エラーは値で返す**のが学習しやすいよ😊✨
> （例外は「予期せぬバグ」と混ざりやすいの💦）

---

## 5) ドメイン：Order に「支払う」を生やす🌱💳

ここが本丸だよ〜！😆✨
「支払えるか？」は **Order 自身が知ってる**のが自然👍

```ts
// src/domain/order.ts
import { Result, ok, err } from "../application/common/result";
import { DomainError, OrderStatus } from "./errors";

export type OrderId = string;

export class Order {
  private constructor(
    public readonly id: OrderId,
    public readonly status: OrderStatus,
    public readonly total: number,
    public readonly paidAt?: Date,
    public readonly paymentId?: string,
  ) {}

  // ここは第10章の PlaceOrder 側で作られてる想定🙂
  static place(params: { id: OrderId; total: number }): Order {
    // 超ミニマム（合計が負なら作れない、みたいなのは第11章でやったよね✨）
    return new Order(params.id, "ORDERED", params.total);
  }

  pay(params: { paymentId: string; paidAt?: Date }): Result<Order, DomainError> {
    // ✅ すでに支払い済み
    if (this.status === "PAID") {
      return err({ type: "AlreadyPaid", paymentId: this.paymentId });
    }

    // ✅ 状態が違う（今は ORDERED のみ許可）
    if (this.status !== "ORDERED") {
      return err({ type: "OrderNotPayable", status: this.status });
    }

    // ✅ “支払い”で変わることを明示する
    const paidAt = params.paidAt ?? new Date();
    const next = new Order(this.id, "PAID", this.total, paidAt, params.paymentId);
    return ok(next);
  }
}
```

### ここでの気持ちいいポイント😍✨

* `status` を **書き換える**んじゃなくて、**新しい Order を作る**（不変っぽく）
* 「支払いできない理由」を **DomainError として型で固定**

---

## 6) Repository（保存の入り口）🗄️✨

Handler は Repository 経由で Order を取って、保存するだけにするよ😊

```ts
// src/domain/orderRepository.ts
import { Order, OrderId } from "./order";

export interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

（ここでは in-memory でもOKだよ🪶）

```ts
// src/infrastructure/inMemoryOrderRepository.ts
import { OrderRepository } from "../domain/orderRepository";
import { Order, OrderId } from "../domain/order";

export class InMemoryOrderRepository implements OrderRepository {
  private store = new Map<OrderId, Order>();

  async findById(id: OrderId): Promise<Order | null> {
    return this.store.get(id) ?? null;
  }

  async save(order: Order): Promise<void> {
    this.store.set(order.id, order);
  }

  // デモ用（本番では不要🙂）
  seed(order: Order) {
    this.store.set(order.id, order);
  }
}
```

---

## 7) Command と Handler：流れだけを書く🚶‍♀️✨

### PayOrderCommand（入力）

```ts
// src/application/commands/payOrder/payOrderCommand.ts
export type PayOrderCommand = {
  orderId: string;
  paymentId: string; // 決済のトラッキング用（あとで冪等性にも効く🔁✨）
  paidAt?: Date;
};
```

### PayOrderHandler（取得→実行→保存）

```ts
// src/application/commands/payOrder/payOrderHandler.ts
import { Result, ok, err } from "../../common/result";
import { OrderRepository } from "../../../domain/orderRepository";
import { DomainError } from "../../../domain/errors";
import { PayOrderCommand } from "./payOrderCommand";

export class PayOrderHandler {
  constructor(private readonly repo: OrderRepository) {}

  async handle(cmd: PayOrderCommand): Promise<Result<void, DomainError>> {
    const order = await this.repo.findById(cmd.orderId);

    if (!order) {
      return err({ type: "OrderNotFound", orderId: cmd.orderId });
    }

    const paid = order.pay({ paymentId: cmd.paymentId, paidAt: cmd.paidAt });

    if (!paid.ok) {
      return err(paid.error);
    }

    await this.repo.save(paid.value);
    return ok(undefined);
  }
}
```

> ね？Handler が **薄い**でしょ😊✨
> “流れ”だけになってるのが理想だよ〜🌸

---

## 8) 動作チェック：シナリオで確認しよう👀✅

テスト章の前だけど、最低限ここは手で確認しよ〜🙂✨

### ✅ シナリオ1：正常系（ORDERED → PAID）

* PlaceOrder で ORDERED の注文を作る
* PayOrder を呼ぶ
* status が PAID になる🎉

### ✅ シナリオ2：二重支払い（PAID に PayOrder）

* 1回 PayOrder
* もう1回 PayOrder
* `AlreadyPaid` が返る🙅‍♀️

### ✅ シナリオ3：存在しない注文

* orderId を適当にして PayOrder
* `OrderNotFound` が返る🫥

---

## 9) AIに手伝ってもらうプロンプト例🤖✨

（そのままコピペで使えるやつだよ〜😆）

* 「PayOrder の禁止条件、漏れがないかレビューして。ORDERED→PAID のルールを前提に、追加すべきエラーケースも提案して」🔎✨
* 「Order.pay の責務が肥大化しないように、どこまでをドメインに置くべきかコメントして」🧠💬
* 「Result/DomainError の設計が読みやすいか、型の改善案を3つ出して」🧩✨

> AIが書いたコードは、**“仕様（禁止条件）”が守れてるか**だけ最優先でチェックしよ😊✅

---

## 10) まとめ：この章で身についたこと🎀✨

* PayOrder は「更新」じゃなくて **状態遷移**💡
* 禁止条件は if の寄せ集めじゃなく、**仕様として型で固定**📌
* Handler は薄く、ルールは Order（ドメイン）へ🛡️

---

## ミニ課題（ちょいムズだけど楽しい😆🎓）

1. `OrderNotPayable` に「なぜ払えないか（理由文字列）」も入れて、UI向けに親切にしてみて💬✨
2. `paymentId` を保存した上で、すでに PAID のときに `paymentId` を返せるようにしてみて🔁✨
   （次の冪等性の章でめちゃ効くよ〜！）

---

必要なら、ここで作った PayOrder を「APIの入口（POST）」に繋ぐ形まで、最小で組み立てるサンプルも出せるよ😊🌐✨

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://nodejs.org/en/blog/release/v24.13.0?utm_source=chatgpt.com "Node.js 24.13.0 (LTS)"
[3]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[4]: https://www.npmjs.com/package/zod?utm_source=chatgpt.com "Zod"
