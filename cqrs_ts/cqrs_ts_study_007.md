# 第7章　CQRSの最小形（CommandHandler / QueryService）🧩✨

今日は **CQRSの“骨格だけ”** を作ります☺️💡
「難しいことは後回し！」で、まずは **分けた瞬間にスッキリする体験** を優先します🎀

---

## 0. いまどき前提の“超ざっくり最新メモ”🗒️✨

* TypeScriptは **5.9系が安定版**（2025/08公開）で、6.0/7.0は“橋渡し＆ネイティブ化”の流れが進行中です📦🚀 ([Microsoft for Developers][1])
* Node.jsは **v24がActive LTS**（v25はCurrent）になっています🟢 ([nodejs.org][2])
* Nodeは `.ts` を“型だけ落として”実行する仕組み（type stripping）も育ってますが、制限もあるので教材では **tsxで気持ちよく動かす** 方が事故りにくいです🙂‍↕️✨ ([nodejs.org][3])

---

## 1. 今日つくる“最小のCQRS”の形（これだけ覚えればOK）🧠✨

### ✅ CQRS最小形ルール

* **Command（更新）**：やりたいこと（注文する、支払う…）を表す✍️
* **CommandHandler**：Commandを受け取り、**処理の流れを組み立てる**（でも“ルール本体”は持ちすぎない）🧩
* **Query（参照条件）**：欲しい画面の条件（一覧を出して、絞って…）🔎
* **QueryService**：**読むだけ**（副作用ゼロ）🧼🚫

> つまり…
> **Command側 = 書く入口**、**Query側 = 読む入口** を作るだけで、もうCQRSっぽい！🎉

---

## 2. 完成イメージ（ミニ図）🗺️✨

* `PlaceOrderHandler` が注文を保存する🧾✅
* `OrderQueryService` が注文一覧を返す📋🔎

同じデータを使っててもOK！
**今は“入口が分かれてること”が大事**です☺️🌸

---

## 3. ハンズオン：最小CQRSを動かすよ〜！🏃‍♀️💨

### 3-1. プロジェクト作成（超シンプル）🧰✨

```bash
mkdir cqrs-mini
cd cqrs-mini
npm init -y

npm i
npm i -D typescript tsx @types/node

npx tsc --init
```

---

## 4. ファイル構成（今日の最小セット）📁✨

```text
src/
  domain/
    order.ts
  infrastructure/
    orderStore.ts
  commands/
    placeOrder.ts
  queries/
    orderQueryService.ts
  main.ts
```

---

## 5. 実装していくよ✍️✨（コピペでOK！）

### 5-1. domain：注文の“形”だけ作る📦🙂

`src/domain/order.ts`

```ts
export type OrderId = string;

export type OrderStatus = "ORDERED" | "PAID";

export type OrderItem = {
  menuId: string;
  name: string;
  unitPrice: number;
  quantity: number;
};

export type Order = {
  id: OrderId;
  items: readonly OrderItem[];
  total: number;
  status: OrderStatus;
  createdAt: Date;
};

export function calcTotal(items: readonly OrderItem[]): number {
  return items.reduce((sum, it) => sum + it.unitPrice * it.quantity, 0);
}

export function createOrder(params: { id: OrderId; items: readonly OrderItem[] }): Order {
  // ※ “強い不変条件”は第11章でガッツリやるので、今日は最小だけ🙂
  if (params.items.length === 0) throw new Error("items is empty");
  for (const it of params.items) {
    if (it.quantity <= 0) throw new Error("quantity must be > 0");
    if (!it.menuId) throw new Error("menuId is required");
  }

  const total = calcTotal(params.items);

  return {
    id: params.id,
    items: params.items,
    total,
    status: "ORDERED",
    createdAt: new Date(),
  };
}
```

💡ポイント

* Domainは「データの意味」を持つけど、今日は薄めでOK☺️
* ルールを増やしすぎるのは次の章でやろうね🧁✨

🤖AIに頼むなら（例）

* 「Orderを最小で表現して。enumは使わず union typeで。items合計も計算して」

---

### 5-2. infrastructure：超かんたん保存先（in-memory）🗄️🪶

`src/infrastructure/orderStore.ts`

```ts
import { Order, OrderId } from "../domain/order.js";

export class OrderStore {
  private readonly orders = new Map<OrderId, Order>();

  save(order: Order): void {
    this.orders.set(order.id, order);
  }

  findById(id: OrderId): Order | undefined {
    return this.orders.get(id);
  }

  listAll(): Order[] {
    return [...this.orders.values()];
  }
}
```

💡ポイント

* 今日はDBの話はしないよ〜！軽く体験が大事🥳
* `OrderStore` は “書く/読む” 両方に使ってOK（ただし入口は分ける）✨

---

### 5-3. commands：PlaceOrderCommand と Handler を作る🧾✅

`src/commands/placeOrder.ts`

```ts
import { createOrder, OrderItem } from "../domain/order.js";
import { OrderStore } from "../infrastructure/orderStore.js";

export type PlaceOrderCommand = {
  orderId: string;
  items: OrderItem[];
};

export type PlaceOrderResult = {
  orderId: string;
  total: number;
};

export class PlaceOrderHandler {
  constructor(private readonly store: OrderStore) {}

  handle(command: PlaceOrderCommand): PlaceOrderResult {
    // Handlerは “流れ” を担当🧩（ルール全部を抱えない）
    const order = createOrder({ id: command.orderId, items: command.items });

    this.store.save(order);

    return { orderId: order.id, total: order.total };
  }
}
```

💡ポイント

* **Command = 入力の塊**（「注文する」に必要なものだけ）🎁
* **Handler = 手順係**（作る→保存→結果返す）🧑‍🍳✨
* ルールは `createOrder()`（Domain）へ寄せるのが気持ちいい☺️

🤖AIに頼むなら（例）

* 「PlaceOrderHandlerを作って。handle()は createOrder→save→result の順で。例外はそのままでOK」

---

### 5-4. queries：QueryService（読むだけ）を作る🔎📋

`src/queries/orderQueryService.ts`

```ts
import { OrderStatus } from "../domain/order.js";
import { OrderStore } from "../infrastructure/orderStore.js";

export type GetOrderListQuery = {
  status?: OrderStatus;
  limit?: number;
};

export type OrderListItemDto = {
  id: string;
  status: OrderStatus;
  total: number;
  createdAt: string;
};

export class OrderQueryService {
  constructor(private readonly store: OrderStore) {}

  getOrderList(query: GetOrderListQuery = {}): OrderListItemDto[] {
    // ✅ QueryServiceは “読むだけ” 🧼（saveしない！）
    let orders = this.store.listAll();

    if (query.status) {
      orders = orders.filter((o) => o.status === query.status);
    }

    // 新しい順（画面で嬉しいやつ🙂）
    orders.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    if (query.limit !== undefined) {
      orders = orders.slice(0, query.limit);
    }

    return orders.map((o) => ({
      id: o.id,
      status: o.status,
      total: o.total,
      createdAt: o.createdAt.toISOString(),
    }));
  }
}
```

💡ポイント

* QueryServiceが返すのは **DTO（画面用）** 🎁
  Domain（Order）をそのまま返すと、あとで地味に詰みやすいよ〜😇（第18章で詳しくやる！）

---

### 5-5. main：つなげて動かす🎮✨

`src/main.ts`

```ts
import { OrderStore } from "./infrastructure/orderStore.js";
import { PlaceOrderHandler } from "./commands/placeOrder.js";
import { OrderQueryService } from "./queries/orderQueryService.js";

const store = new OrderStore();

const placeOrder = new PlaceOrderHandler(store);
const queryService = new OrderQueryService(store);

// 注文する（Command）🧾✅
const result = placeOrder.handle({
  orderId: "order-001",
  items: [
    { menuId: "m-001", name: "からあげ丼", unitPrice: 680, quantity: 1 },
    { menuId: "m-010", name: "味噌汁", unitPrice: 120, quantity: 1 },
  ],
});

console.log("✅ placed:", result);

// 一覧を見る（Query）🔎📋
const list = queryService.getOrderList({ limit: 10 });

console.log("📋 orders:", list);
```

実行👇

```bash
npx tsx src/main.ts
```

だいたいこんな出力になればOK🥳✨

```text
✅ placed: { orderId: 'order-001', total: 800 }
📋 orders: [ { id: 'order-001', status: 'ORDERED', total: 800, createdAt: '...' } ]
```

---

## 6. “できた感”チェックリスト✅✨

* [ ] `PlaceOrderHandler` は **保存（更新）** だけしてる🧾✅
* [ ] `OrderQueryService` は **読むだけ**（saveしてない）🧼🚫
* [ ] Queryの返り値は **DTO**（Orderそのままじゃない）🎁
* [ ] 「更新の入口」と「参照の入口」が **別ファイル/別クラス** になってる🧩✨

---

## 7. ミニ演習（5〜15分）⏳🧠✨

### 演習A：一覧に「合計点数」を出す🍙➕

* DTOに `itemCount` を追加してみよ〜☺️
  （合計のquantityの合算）

### 演習B：Queryに `minTotal` を追加して絞り込み💰

* `total >= minTotal` の注文だけ返す

### 演習C：やっちゃダメ確認😈（学びが深い）

* QueryService内で `store.save()` をわざと呼んでみる
  → 「うわ、これ混ざった…😵」って感覚を味わう（すぐ戻してね！）

---

## 8. よくあるつまずき（先に潰す🪤）😵‍💫

* **Queryで更新しちゃう**：ログ用カウンタ更新とかも“最初は”我慢！🥲
* **CommandHandlerが太りだす**：分岐まみれになったら、Domainへ寄せる合図🚨
* **Domainをそのまま返す**：画面都合が混ざって壊れやすい🧨（DTOに逃がすのが正解🙆‍♀️）

---

## 9. 次（第8章）へのつなぎ🌈✨

第7章で作ったのは「CQRSの骨格」🦴✨
次の第8章で、これを **迷子にならないフォルダ構成** に整理していきます📁🎀

---

続けて、第7章のコードを「もう少し学食アプリっぽく」したバージョン（注文を2件入れて、一覧が気持ちいい例）もそのまま書けるよ〜🥳💖

[1]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[2]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[3]: https://nodejs.org/en/blog/release/v22.6.0 "Node.js — Node.js 22.6.0 (Current)"
