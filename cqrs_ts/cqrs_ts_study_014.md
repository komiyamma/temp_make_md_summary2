# 第14章　Write側の永続化を抽象化（Repository入門）🗄️🔁✨

この章はね、「DBの都合」でアプリの大事なルール（業務ルール）がグチャッとなるのを防ぐための回だよ〜！😊💡
**Repository（リポジトリ）**を入れると、コードがスッキリして、テストも超やりやすくなるよ🧪✨

---

## 1) 今日のゴール🎯✨

この章が終わると、こうなります👇

* 「注文を保存する場所」が **DBでもメモリでも差し替えできる** 🧩🔁
* CommandHandlerが **DBのAPIに直接触らない** 🙅‍♀️
* テストで **in-memory（メモリ）実装**を使ってサクサク検証できる🧪💨
* 「Write側の責務」が太らず、設計がきれいになる🧼✨

---

## 2) Repositoryってなに？（超やさしく）📦🙂

Repositoryは一言でいうと…

> **「ドメイン（Order）を出し入れするための“窓口”」**🪟✨

ポイントはこれ👇

* ドメインは「保存の方法（DB/ファイル/HTTP…）」を知らない🙈
* アプリ（Handler）も「DBの細かい都合」を知らない🙈
* 代わりに **Repository interface**だけ知ってればOK✅

つまり、こういう分離ができるよ👇

* Handler：流れ担当（ユースケース）🧠
* Domain：ルール担当（不変条件・状態遷移）🛡️
* Repository：保存担当（ただし “interface” が境界）🧩

---

## 3) まずは最小のRepositoryを作ろう✍️✨（in-memoryでOK）

ここでは「DB実装」はまだやらないよ😊
まずは **Mapで保存する in-memory 実装**で、Repositoryの気持ちよさを体験しよう〜🪶💕

### 3.1 ファイル配置イメージ📁✨

* `src/domain/order/Order.ts`
* `src/domain/order/OrderRepository.ts`
* `src/infrastructure/memory/InMemoryOrderRepository.ts`

---

## 4) 実装してみよう（コピペOK）🐣✍️

### 4.1 Order（集約ルート）📦

```ts
// src/domain/order/Order.ts
export type OrderId = string;

export type OrderStatus = "ORDERED" | "PAID";

export class Order {
  private constructor(
    public readonly id: OrderId,
    public readonly items: ReadonlyArray<{ menuId: string; qty: number }>,
    public readonly totalYen: number,
    public readonly status: OrderStatus
  ) {}

  static place(params: {
    id: OrderId;
    items: Array<{ menuId: string; qty: number }>;
    totalYen: number;
  }): Order {
    // ざっくり不変条件（第11章の復習💪）
    if (params.items.length === 0) throw new Error("items is empty");
    if (params.items.some((x) => x.qty <= 0)) throw new Error("qty must be > 0");
    if (params.totalYen < 0) throw new Error("totalYen must be >= 0");

    return new Order(params.id, params.items, params.totalYen, "ORDERED");
  }

  pay(): Order {
    if (this.status !== "ORDERED") throw new Error("order is not ORDERED");
    return new Order(this.id, this.items, this.totalYen, "PAID");
  }
}
```

> ここでのコツ💡
> **Orderは「保存」について何も知らない**のが大事！🙆‍♀️✨

---

### 4.2 Repository interface（境界）🧩

```ts
// src/domain/order/OrderRepository.ts
import type { Order, OrderId } from "./Order";

export interface OrderRepository {
  nextId(): OrderId;
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

> ここが超重要ポイント💖
> Handlerは **このinterfaceだけ**に依存するようにするよ（DIPの体験）🧠✨

---

### 4.3 InMemory実装（保存の中身）🪶🗄️

```ts
// src/infrastructure/memory/InMemoryOrderRepository.ts
import type { OrderRepository } from "../../domain/order/OrderRepository";
import type { Order, OrderId } from "../../domain/order/Order";

export class InMemoryOrderRepository implements OrderRepository {
  private seq = 1;
  private store = new Map<OrderId, Order>();

  nextId(): OrderId {
    return `order_${this.seq++}`;
  }

  async findById(id: OrderId): Promise<Order | null> {
    return this.store.get(id) ?? null;
  }

  async save(order: Order): Promise<void> {
    this.store.set(order.id, order);
  }
}
```

> in-memoryは「練習に最強」💪✨
> DBがなくても動くし、テストも速いよ〜🧪💨

---

## 5) HandlerからRepositoryを使ってみよう🚪🧠

### 5.1 PlaceOrderHandler（注文する）🧾✨

```ts
// src/application/commands/placeOrder/PlaceOrderHandler.ts
import type { OrderRepository } from "../../../domain/order/OrderRepository";
import { Order } from "../../../domain/order/Order";

export type PlaceOrderCommand = {
  items: Array<{ menuId: string; qty: number }>;
  totalYen: number;
};

export class PlaceOrderHandler {
  constructor(private readonly repo: OrderRepository) {}

  async handle(cmd: PlaceOrderCommand): Promise<{ orderId: string }> {
    const id = this.repo.nextId();
    const order = Order.place({ id, items: cmd.items, totalYen: cmd.totalYen });

    await this.repo.save(order);

    return { orderId: id };
  }
}
```

### 5.2 PayOrderHandler（支払う）💳✨

```ts
// src/application/commands/payOrder/PayOrderHandler.ts
import type { OrderRepository } from "../../../domain/order/OrderRepository";

export type PayOrderCommand = { orderId: string };

export class PayOrderHandler {
  constructor(private readonly repo: OrderRepository) {}

  async handle(cmd: PayOrderCommand): Promise<void> {
    const order = await this.repo.findById(cmd.orderId);
    if (!order) throw new Error("order not found");

    const paid = order.pay();
    await this.repo.save(paid);
  }
}
```

> HandlerがDBを知らない！🎉
> これだけで設計がグッと強くなるよ😊✨

---

## 6) ここが最高：テストがラクになる🧪💕

in-memoryを差し込めば、DBなしでユニットテストできるよ〜！

```ts
// src/application/commands/placeOrder/PlaceOrderHandler.test.ts
import { InMemoryOrderRepository } from "../../infrastructure/memory/InMemoryOrderRepository";
import { PlaceOrderHandler } from "./placeOrder/PlaceOrderHandler";

test("place order saves an order", async () => {
  const repo = new InMemoryOrderRepository();
  const handler = new PlaceOrderHandler(repo);

  const res = await handler.handle({
    items: [{ menuId: "karaage", qty: 2 }],
    totalYen: 900,
  });

  const saved = await repo.findById(res.orderId);
  expect(saved?.status).toBe("ORDERED");
});
```

> これ、ほんと気持ちいいやつ…！🥹✨
> 「DBの準備」で詰まらなくなるのが嬉しいポイント💖

---

## 7) ありがちなミス集（ここ踏むとつらい）😵‍💫📌

### ❌ ミス1：Repositoryに検索機能を盛りすぎる🔎💥

Write側のRepositoryは基本「集約を保存/取得」くらいでOK。
一覧検索・集計は **Query側**でやる（第16章以降）😊✨

### ❌ ミス2：HandlerがDBライブラリに直依存する🧱

Prisma/Drizzle/SQL直書き…どれでもいいけど、
Handlerがそれに触ると **差し替え不能＆テストが重い** 🙅‍♀️💦

### ❌ ミス3：RepositoryがDTOを返しはじめる📦➡️🧩

Write側は **Order（ドメイン）を返す**のが基本だよ。
DTOが欲しいのは基本Query側（表示用）📋✨

---

## 8) 「じゃあDB実装って何を使うの？」（2026の空気だけ）🌬️🗄️

ここ章のゴールは「抽象化」なので、今は **in-memoryで大正解**🙆‍♀️✨
でも将来DBに行くなら、2026年1月時点だと例えばこんな雰囲気👇

* Nodeは v24 系が Active LTS として案内されてるよ（リリース表）🟢✨ ([Node.js][1])
* Prisma は 2025年後半〜2026年初頭にかけて v7 系の情報が増えてて、Rust-free（TS/WASMコア）を強く打ち出してるよ🧠⚡ ([Prisma][2])
* Drizzle は drizzle-kit の更新が2026年1月にも出てて、SQLiteのUNIQUE扱いなど改善が続いてるよ🔧✨ ([GitHub][3])

> 大事なのは「どのDB/ORMでも、Repositoryの差し替えで吸収できる」ってこと😊🧩
> ここができてると、技術選定がめちゃ楽になるよ〜！

---

## 9) AI活用（この章でめちゃ効く！）🤖💕

Copilot / Codex に投げると便利なお願い👇✨

* 「`OrderRepository` のメソッド、最小で足りてる？増やしすぎ？」🧠
* 「`InMemoryOrderRepository` をスレッドセーフにする必要ある？」🧵
* 「Place/Payのテストケース、境界値を追加して」🧪
* 「Repositoryの命名、ドメイン用語になってる？」📚

AIに作らせたら、最後に自分でこうチェックしてね👇
**“Handlerがドメインルールを持ってない？”**（持ってたら太りすぎ警報🚨）

---

## 10) ミニ演習（5〜15分）⏱️✨

### 演習A：Repositoryを差し替えてもHandlerが動くのを確認🔁

* `InMemoryOrderRepository` をもう1個作って
  「保存するとログが出る版」を作ってみよ📣😆
* Handlerは1行も変更しないのが正解✅✨

### 演習B：PayOrderの禁止条件テストを書く🧪

* すでにPAIDの注文に `pay()` したらエラーになることをテストで確認💳🙅‍♀️

---

## 11) 今日のまとめ🎉✨

* Repositoryは「保存の方法」から業務を守るための仕組み🛡️🗄️
* HandlerはRepository interfaceにだけ依存すると強い（差し替え・テスト最強）🧩💪
* まずはin-memoryで十分！ここを固めると後がラク😊🪶

次の章では、「どこまでを一回の更新で守る？」っていう **トランザクション境界（集約の肌感）**に進むよ〜🔒📦✨

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.prisma.io/blog/announcing-prisma-orm-7-0-0?utm_source=chatgpt.com "Prisma 7 Release: Rust-Free, Faster, and More Compatible"
[3]: https://github.com/drizzle-team/drizzle-orm/releases?utm_source=chatgpt.com "Releases · drizzle-team/drizzle-orm"
