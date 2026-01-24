# 第9章　ドメイン超入門（Orderって何を持つ？）📦🙂

* **Order / OrderItem / Money** の「言葉」を揃える🗣️✨
* Orderが持つ情報を**“必要最小限”**にできる（KISS！）🧊
* **ドメイン＝業務ルールの置き場**って感覚がわかる🧠💡
* 次章の `PlaceOrder` がスッと書ける状態にする🧾✅

---

## 第1章　そもそも「ドメイン」ってなに？📦🙂

ドメインは一言でいうと、

**「アプリの目的そのもの（学食注文）を、コードで表した中心部分」**だよ✨

* 画面の都合（ボタン表示とか）じゃない🙅‍♀️
* DBの都合（テーブル構造）でもない🙅‍♀️
* 「注文って何？支払いって何？ダメな注文って何？」みたいな
  **業務のルール**が主役👑✨

CQRSだと特に、**Write側（更新側）**でドメインが大活躍するよ💪🙂

---

## 2. まずは「言葉」を揃えよ〜🗂️✨（ユビキタス言語の超入門）

いきなりクラス作らず、先にメモ📝✨

### このアプリの“言葉”候補🍙📱

* Order（注文）
* OrderItem（注文明細）
* Menu（メニュー）
* Money（金額）
* Quantity（数量）
* Status（状態：注文済み/支払い済み…）
* Total（合計）
* OrderedAt（注文日時）
* PaidAt（支払い日時）

ここで大事なのは、**技術用語じゃなくて、業務の言葉**で話すことだよ🙂✨
（例：`OrderEntity` より `Order` の方が会話しやすい🙆‍♀️）

---

## 3. Orderは「何を持つべき？」をKISSで決める🧊✨

ここ、盛りすぎると死ぬポイント😇💥
だからルールはこれ👇

> **「今から作る機能（注文する・払う）に必要な分だけ持つ」**✅

### 今回の最小セット（おすすめ）📦✨

**Order**

* `id`（注文ID）
* `items`（注文明細の配列）
* `status`（状態）
* `orderedAt`（注文した時刻）
* `paidAt?`（支払った時刻：支払い後だけ）

**OrderItem**

* `menuId`（メニューID）
* `name`（表示名：注文時点のスナップショットとして持つのアリ）
* `unitPrice`（単価：これも注文時点で固定したいので持つのアリ）
* `quantity`（数量）

**Money**

* `amount`（金額。今回は “円” 固定でOK💴）

> ✅「name/priceはMenuから引けばいいのでは？」
> → それもアリ！
> でも注文は「当時の価格」で残したいことが多いから、**スナップショットとしてOrderItemに持つ**のは実務的にかなり多いよ🙂✨

---

## 4. ドメイン設計の“超ざっくり基本”🧠✨

### Entity（エンティティ）って？🪪

* **IDで区別されるもの**
* 例：Order（注文IDがあるから、同じ内容でも別注文）

### Value Object（値オブジェクト）って？💎

* **値そのものが大事**（同じ値なら同じ扱い）
* 例：Money（100円は100円で同じ）

OrderはEntity、MoneyはValue Object、って覚えるとラクだよ🙂✨

---

## 5. TypeScriptで“気持ちよく”書く：最小ドメイン実装✍️✨

ここからコードいくよ〜🧁✨
（ドメインは **副作用なし** が基本！fetchしない！DB触らない！）

### 5-1. IDを「ただのstring」にしない（超おすすめ）🧷✨

`OrderId` と `MenuId` が混ざる事故、あるある😇
TypeScriptなら**Brand型**で防げるよ🛡️✨

```ts
// domain/types.ts
export type Brand<T, B extends string> = T & { readonly __brand: B };

export type OrderId = Brand<string, "OrderId">;
export type MenuId  = Brand<string, "MenuId">;

export const OrderId = (value: string) => value as OrderId;
export const MenuId  = (value: string) => value as MenuId;
```

---

### 5-2. Money（値オブジェクト）を作る💴✨

ポイントは👇

* 円なら `amount` は **整数**にしよ（小数は事故りやすい🥺）
* 足し算・掛け算を **Moneyの責務**に寄せると読みやすい✨

```ts
// domain/money.ts
export class Money {
  private constructor(public readonly amount: number) {
    if (!Number.isInteger(amount)) throw new Error("Money.amount must be integer (JPY).");
    if (amount < 0) throw new Error("Money.amount must be >= 0.");
  }

  static yen(amount: number): Money {
    return new Money(amount);
  }

  add(other: Money): Money {
    return Money.yen(this.amount + other.amount);
  }

  multiply(n: number): Money {
    if (!Number.isInteger(n)) throw new Error("multiply: n must be integer.");
    if (n < 0) throw new Error("multiply: n must be >= 0.");
    return Money.yen(this.amount * n);
  }
}
```

---

### 5-3. OrderItem（明細）を作る🍙✨

```ts
// domain/orderItem.ts
import { MenuId } from "./types";
import { Money } from "./money";

export type OrderItem = Readonly<{
  menuId: MenuId;
  name: string;
  unitPrice: Money;
  quantity: number;
}>;

export function createOrderItem(input: {
  menuId: MenuId;
  name: string;
  unitPrice: Money;
  quantity: number;
}): OrderItem {
  if (!input.name.trim()) throw new Error("OrderItem.name is required.");
  if (!Number.isInteger(input.quantity) || input.quantity <= 0) {
    throw new Error("OrderItem.quantity must be integer > 0.");
  }

  return {
    menuId: input.menuId,
    name: input.name,
    unitPrice: input.unitPrice,
    quantity: input.quantity,
  };
}
```

> ここでのコツ💡
>
> * `OrderItem` はただのデータにして、チェックは `createOrderItem` に寄せる
> * こうすると「不正なOrderItemが存在しない」状態にしやすいよ🛡️✨

---

### 5-4. Order（集約ルートっぽい主役）を作る📦✨

ここでは “注文する” と “合計を計算する” まで入れちゃう🙂
（支払いは次章以降で濃くやる想定💳✨）

```ts
// domain/order.ts
import { OrderId } from "./types";
import { Money } from "./money";
import { OrderItem } from "./orderItem";

export type OrderStatus = "ORDERED" | "PAID";

export class Order {
  private constructor(
    public readonly id: OrderId,
    private readonly _items: OrderItem[],
    public readonly status: OrderStatus,
    public readonly orderedAt: Date,
    public readonly paidAt?: Date,
  ) {}

  static place(input: {
    id: OrderId;
    items: OrderItem[];
    orderedAt?: Date;
  }): Order {
    if (input.items.length === 0) throw new Error("Order must have at least 1 item.");

    return new Order(
      input.id,
      [...input.items],
      "ORDERED",
      input.orderedAt ?? new Date(),
      undefined
    );
  }

  get items(): readonly OrderItem[] {
    return this._items;
  }

  total(): Money {
    return this._items.reduce((sum, item) => {
      const line = item.unitPrice.multiply(item.quantity);
      return sum.add(line);
    }, Money.yen(0));
  }

  // ここでは軽く形だけ（禁止条件は次章以降で強化💪）
  pay(paidAt: Date = new Date()): Order {
    if (this.status === "PAID") throw new Error("Order is already paid.");
    return new Order(this.id, [...this._items], "PAID", this.orderedAt, paidAt);
  }
}
```

---

### 5-5. 動作イメージ（使い方）👀✨

```ts
import { OrderId, MenuId } from "./domain/types";
import { Money } from "./domain/money";
import { createOrderItem } from "./domain/orderItem";
import { Order } from "./domain/order";

const item1 = createOrderItem({
  menuId: MenuId("menu-001"),
  name: "鮭おにぎり",
  unitPrice: Money.yen(180),
  quantity: 2,
});

const order = Order.place({
  id: OrderId("order-1001"),
  items: [item1],
});

console.log(order.total().amount); // 360
const paid = order.pay();
console.log(paid.status); // "PAID"
```

---

## 6. この章の“設計センス”ポイント集🧠✨（超だいじ）

### ✅ 1) Orderに「画面の都合」を入れない🙅‍♀️🖥️

例：`isPayButtonEnabled` とかはドメインじゃないよ〜😆
それはUI側が決めること！

### ✅ 2) 迷ったら「今必要？」で削る✂️✨

たとえば👇

* クーポン？ポイント？割引？
  → まだやらないなら入れないでOK🙂
  （必要になったときに追加した方が安全！）

### ✅ 3) “不正な状態”を作らない🛡️✨

* quantity は 1以上
* money は 0以上（今回は）
* items は空じゃない
  こういうのは早めに守ると、あとがラク🥰

---

## 7. ミニ演習（5〜10分）📝✨

### 演習A：Orderに「メモ」を足したくなったら？🧐

例：`note?: string`

* ✅ いる：ユーザーが備考を書ける仕様がある
* ❌ いらない：ただ“あったら便利そう”レベル

**「仕様にあるか？」で判断する**のが正解だよ🙂✨

### 演習B：OrderItemに `subtotal()` を生やす？🍙💴

* あり🙆‍♀️（読みやすくなる）
* でも今は `Order.total()` だけでも十分なら、後回しでもOK🧊

---

## 8. AI活用🤖✨（この章でめちゃ効く使い方）

### 8-1. “盛りすぎ”を止める質問🚦

AIにこう聞いてみて👇

* 「学食注文のOrderに入れがちな**過剰プロパティ**を10個出して。なぜ不要かも書いて」
* 「今回の最小機能（注文・支払い）に必要なプロパティだけに削って」

→ AIは盛りがちだから、**削る目的**で使うのがコツ😆✂️✨

### 8-2. 不変条件の漏れチェック✅

* 「Order/OrderItem/Money の不変条件（壊れない条件）を列挙して」

---

## 9. できたかチェック（ミニクイズ）🎓✨

1. MoneyはEntity？Value Object？💎🪪
2. Orderに `menuName` を持つのはアリ？なし？（理由も）🙂
3. `OrderId` と `MenuId` を分けると何が嬉しい？🛡️

---

## 10. プチ最新メモ（2026/01時点）🗞️✨

* TypeScriptは **5.7（2024/11）→ 5.8（2025/2）** の流れで改善が進んでるよ。([GitHub][1])
* Node.js は **v24 が Active LTS**、**v22 は Maintenance LTS** という位置づけになってる（2026/01更新）。([nodejs.org][2])
* Vite は **Vite 7（2025/6発表）**、**Vite 8 Beta（2025/12発表）** まで進んでるよ。([vitejs][3])

（この章はドメイン中心だから軽く触れるだけにしたよ🙂✨）

---

## 次章へのつながり🚪✨

第10章では、このドメインを使って

* `PlaceOrder`（注文する🧾✅）

をCommandとして設計していくよ〜！
今日作った `Order.place(...)` と `createOrderItem(...)` が、そのまま主役になるからね🥰✨

---

必要なら、この第9章の内容をベースに「章末の小テスト（回答つき）」とか「ありがちな失敗例集😇」も追加で作れるよ〜📚💕

[1]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://vite.dev/blog?utm_source=chatgpt.com "Latest From the Vite Blog"
