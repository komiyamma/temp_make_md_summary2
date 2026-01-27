# 第12章 イベントを“ためる”設計（ドメイン内バッファ）🫙🧩

## この章のゴール🎯

* ドメインモデル（集約）が「イベントを作って、いったん保持する」流れを作れる✨
* `pullDomainEvents()` でイベントを “まとめて取り出して、空にする” を実装できる📤🧹
* 「ドメインは外部I/Oしない」ってルールを、コードの形で守れるようになる🚫🌍

---

## ちょい今どきメモ🗞️✨（2026年感）

* TypeScript は npm 上で **5.9.3** が “Latest” として案内されてるよ📦([NPM][1])
* Node.js は **v24 が Active LTS** 扱い（表で確認できる）🟩([Node.js][2])
* テストに Vitest を使うなら **v4 系**に移行ガイドがあるよ🧪🧭([vitest.dev][3])

（この章の内容は、バージョンが変わっても “設計の考え方” はそのまま使えるよ👌）

---

## 12.1 「ためる」ってどういうこと？🤔🫙

ドメインイベントは「起きた事実」だよね⏳✨
でも、その瞬間に **メール送信📩** とか **外部API呼び出し🌐** をドメインがやりだすと…

* ドメインが外の都合に引っ張られてグチャる🌀
* テストがめんどい（外部通信のモック地獄）😵‍💫
* 失敗時の責任が不明（誰がリトライするの？）💥

そこでこの章の主役👇

✅ **ドメインは「イベントを作る」だけ**
✅ **イベントはドメインの中にいったん“ためる”**
✅ **取り出して配るのは “外側（アプリ層）” の仕事**

---

## 12.2 イメージ図🗺️📦➡️📣

1. 集約のメソッドが状態変更する（例：支払い）💳
2. その瞬間にイベントを生成する（例：`OrderPaid`）🔥
3. でも配らない。集約の中に保持する🫙
4. アプリ層が保存した後、まとめて取り出す📤
5. ディスパッチ（次章でやるやつ）📣

---

## 12.3 設計ルール（ここ超だいじ）📏🔒

### ルール1：ドメインは外部I/Oをしない🚫🌍

* DB・メール・HTTP・キュー…ぜんぶ外側へ！

### ルール2：イベントは「状態が変わった瞬間」に作る💥

* “結果として起きた事実” を残すよ⏳

### ルール3：集約はイベントを **内部バッファ** に貯める🫙

* `record(event)` みたいなメソッドで追加するだけ✨

### ルール4：イベントは **まとめて取り出して、空にする**📤🧹

* 同じイベントを二回配っちゃう事故を減らす🔁💣

### ルール5：取り出しは “アプリ層のユースケース” からやる🎮

* 保存→取り出し→配布、の順にしやすいから💾➡️📤➡️📣

---

## 12.4 実装：イベントの型（最低限）🧾🛡️

まずはイベント共通フォーマットを用意するよ✨
（第9章の流れを踏まえて、めっちゃ王道の形にするね）

```ts
// domain/event/DomainEvent.ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  type: TType;
  occurredAt: Date;
  aggregateId: string;
  payload: TPayload;
  version: number; // 将来の進化用（第31-32章に効いてくる✨）
}>;
```

ポイント👇

* `Readonly` で「あとから書き換え」を防ぐ🛡️
* `version` は今すぐ使わなくても、後で助かる保険🔖

---

## 12.5 実装：AggregateRoot に “ためる箱” を持たせる🧱🫙

集約の共通親みたいなクラス（または mixin）を作るとラクだよ✨

```ts
// domain/shared/AggregateRoot.ts
import type { DomainEvent } from "../event/DomainEvent";

export abstract class AggregateRoot {
  private _domainEvents: DomainEvent<string, unknown>[] = [];

  protected record(event: DomainEvent<string, unknown>): void {
    this._domainEvents.push(event);
  }

  /**
   * ためてたイベントを取り出して、箱を空にする📤🧹
   */
  pullDomainEvents(): DomainEvent<string, unknown>[] {
    const events = this._domainEvents;
    this._domainEvents = [];
    return events;
  }
}
```

✨ここが「ためる設計」の心臓🫀

* `record()`：入れるだけ
* `pullDomainEvents()`：出したら空にする

---

## 12.6 実装：注文（Order）がイベントをためる🧾💳🔥

例として「注文が支払われた」をやってみるよ〜📦✨

```ts
// domain/order/Order.ts
import { AggregateRoot } from "../shared/AggregateRoot";
import type { DomainEvent } from "../event/DomainEvent";

// イベント定義（type安全にしたいので Order 専用の union を作る）
type OrderEvent =
  | DomainEvent<"OrderPlaced", { orderId: string; total: number }>
  | DomainEvent<"OrderPaid", { orderId: string; paidAt: string }>;

type OrderStatus = "Placed" | "Paid";

export class Order extends AggregateRoot {
  private constructor(
    private readonly id: string,
    private status: OrderStatus,
    private total: number
  ) {
    super();
  }

  static place(orderId: string, total: number): Order {
    if (total <= 0) throw new Error("total must be > 0"); // 不変条件の例🔒

    const order = new Order(orderId, "Placed", total);

    const event: OrderEvent = {
      eventId: crypto.randomUUID(),
      type: "OrderPlaced",
      occurredAt: new Date(),
      aggregateId: orderId,
      payload: { orderId, total },
      version: 1,
    };
    order.record(event);

    return order;
  }

  pay(): void {
    if (this.status === "Paid") throw new Error("already paid"); // 不変条件🔒

    this.status = "Paid";

    const event: OrderEvent = {
      eventId: crypto.randomUUID(),
      type: "OrderPaid",
      occurredAt: new Date(),
      aggregateId: this.id,
      payload: { orderId: this.id, paidAt: new Date().toISOString() },
      version: 1,
    };
    this.record(event);
  }

  // 外側が読むための最低限ゲッター
  getId(): string {
    return this.id;
  }
}
```

ポイント👀✨

* `pay()` の中で **メール送信してない**📩❌
* 代わりに `OrderPaid` を作って **record しただけ**🫙✅
* これでドメインはキレイに保てる🧼

---

## 12.7 アプリ層：保存したあとに “まとめて取り出す”📤💾

アプリ層（ユースケース）は、だいたいこんな順番が気持ちいいよ👇

1. 集約を作る / 変更する
2. Repository で保存する
3. `pullDomainEvents()` で取り出す
4. Dispatcher に渡す（次章で本格化）📣

```ts
// application/placeOrder.ts
import { Order } from "../domain/order/Order";

export interface OrderRepository {
  save(order: Order): Promise<void>;
}

export interface EventDispatcher {
  dispatch(events: { type: string }[]): Promise<void>;
}

export async function placeOrderUseCase(
  repo: OrderRepository,
  dispatcher: EventDispatcher,
  input: { orderId: string; total: number }
): Promise<void> {
  const order = Order.place(input.orderId, input.total);

  await repo.save(order);

  const events = order.pullDomainEvents();
  await dispatcher.dispatch(events);
}
```

ここでの大事な感覚🥺✨

* 「保存が成功したら配りたい」気持ちが自然に書ける💾➡️📣
* 失敗の設計（取りこぼし問題）は Outbox 章でガッツリやるよ⚠️📤

---

## 12.8 テスト：ためた？取り出したら空？🧪💖

「ためる設計」はテストが超やりやすいのが最高〜✨
イベントが **出たかどうか** だけ見ればいいからね👀

```ts
// domain/order/Order.test.ts
import { describe, it, expect } from "vitest";
import { Order } from "./Order";

describe("Order domain events", () => {
  it("place() で OrderPlaced がためられる", () => {
    const order = Order.place("o-1", 1000);

    const events1 = order.pullDomainEvents();
    expect(events1).toHaveLength(1);
    expect(events1[0].type).toBe("OrderPlaced");

    const events2 = order.pullDomainEvents();
    expect(events2).toHaveLength(0); // 📤したら空！🧹✨
  });

  it("pay() で OrderPaid がためられる", () => {
    const order = Order.place("o-2", 2000);
    order.pullDomainEvents(); // place の分は一旦捨てとく（テスト都合）

    order.pay();

    const events = order.pullDomainEvents();
    expect(events).toHaveLength(1);
    expect(events[0].type).toBe("OrderPaid");
  });
});
```

✅ テストの気持ちよさポイント

* 外部サービスのモック、要らない🤲✨
* “状態変更→イベント” のセットだけ確認できる🧾💥

---

## 12.9 ありがち事故あるある😵‍💫🧯（回避もセット）

### 事故1：pull し忘れてイベントが配られない📭

* 回避：ユースケースの最後に “必ず pull” の型にする✅

### 事故2：pull してもイベントが残って二重配信🔁💣

* 回避：`pullDomainEvents()` は **必ず空にする設計**🧹

### 事故3：イベント payload にデカいオブジェクトを詰める🎒💥

* 回避：payload は “必要最小限” にする（第10章の方針）✂️

### 事故4：ドメインでメール送信しちゃう📩😇

* 回避：「ドメインは事実を作るだけ」って唱える🪄
  送信はハンドラ側へ（第14章）🔔

---

## 12.10 演習✍️✨（手を動かすよ〜！）

### 演習A：自作集約に “ためる箱” を付けよう🫙

* 例：`Inventory`（在庫）や `User`（会員）でもOK🙆‍♀️
* 状態変更メソッドを1つ作って、イベントを `record()` してみてね🔥

### 演習B：pull の “空になる” をテストで保証🧪

* 「1回目はイベント1個、2回目は0個」を必ず書く📤🧹

### 演習C：イベントに version を入れてみよう🔖

* いまは `1` 固定でOK
* 「将来 v2 になったら？」を想像して、コメントを残すと強い🧠✨

---

## 12.11 AI活用プロンプト集🤖🪄（コピペでOK）

### ① イベント候補の命名サポート🧾✨

* 「`Order` の `pay()` が成功した事実を表すイベント名を10個。過去形。命令形は禁止。粒度もコメントして」

### ② payload 最小化チェック🎒✂️

* 「このイベントpayload、入れすぎ？ “今必要” と “後で参照” を分けて、最小案を作って」

### ③ 責務混ざり検出🔍🧼

* 「この `Order` のコード、外部I/Oや通知っぽい責務が混ざってない？混ざってたらどこが危険？」

### ④ テストケース穴あき検査🧪🕳️

* 「`pullDomainEvents()` のテスト、抜けやすいケースを追加で3つ提案して（例：複数イベント、例外時など）」

---

## まとめ✨🫙

* **ドメインはイベントを作って “ためる”**（外部に配らない）
* **アプリ層が保存後に `pullDomainEvents()` で取り出す**
* **pull は “取り出して空にする” が事故を減らす**📤🧹

次章は、取り出したイベントをどう “配る” か（ディスパッチの流れ）に進むよ〜📣🚚

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://vitest.dev/blog?utm_source=chatgpt.com "Latest From the Vitest Blog"
