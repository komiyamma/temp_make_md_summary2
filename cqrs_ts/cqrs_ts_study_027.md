# 第27章　ドメインイベント入門（OrderPaidみたいな過去形）📣📦

この章のゴールはシンプル！✨
「更新（Command）をしたら、**“起きた事実（Event）”をちゃんと残せる**」ようになることだよ〜😊

---

## 1) ドメインイベントってなに？🍙➡️📣

**ドメインイベント（Domain Event）**は、アプリの中で「発生した出来事（事実）」を表すオブジェクトだよ📦
ポイントは **“お願い（命令）” じゃなくて “結果（事実）”** ってところ！

* ✅ Command：**「支払って！」**（お願い / 指示）
* ✅ Domain Event：**「支払われた！」**（起きた事実 / 過去形）

Martin Fowler も「Domain Event は、システムの状態変化を引き起こす “出来事” を捉えるもの」って説明してるよ📚 ([martinfowler.com][1])

---

## 2) Command / Event /（ついでに）Integration Event の違い🔀

混ざりやすいから、ここでスッキリさせよ〜😆✨

* **Command（コマンド）**：やってほしいこと（未来）
  例）`PayOrder`
* **Domain Event（ドメインイベント）**：起きた事実（過去）
  例）`OrderPaid`
* **Integration Event（連携イベント）**：別システムに通知するためのイベント（外向き）
  例）`OrderPaidToAccountingSystem` みたいなイメージ（※この章はまだ軽くでOK🙆‍♀️）

MicrosoftのDDD/CQRSガイドでも、ドメインイベントは**ドメインのルールを明示し、関心事の分離に効く**って説明されてるよ🧠✨ ([Microsoft Learn][2])

---

## 3) 命名の鉄則：過去形にする！⏪✅

ドメインイベントはだいたい **過去形** にするのが定番だよ〜😊

* ✅ `OrderPlaced`（注文された）
* ✅ `OrderPaid`（支払われた）
* ✅ `PaymentFailed`（支払いが失敗した）

イベントソーシングの入門でも「注文が支払われた＝`OrderPaid` みたいに過去形で表す」って例が出てくるくらい、王道ルールだよ📌 ([prooph 公式ドキュメント][3])

---

## 4) 何がうれしいの？（なぜイベントを出すの？）🎁✨

### (A) 「副作用」をHandlerから追い出せる🚪💨

たとえば支払いのあとに…

* 売上集計Readモデル更新📊
* 画面の一覧更新🧾
* 通知（メール/Push）📩
* ログ・監査ログ🧾

…みたいなのが増えると、CommandHandlerがムキムキになりがち💪😵
でも **「支払われた」という事実だけ** をイベントにしておけば、あとから外側で好きに育てられる🌱

### (B) テストがめっちゃ書きやすい🧪✨

「支払った結果、`OrderPaid` が出たよね？」って、**“起きたこと”を断言できる**👍

---

## 5) イベントに入れるデータ、どう決める？📦🧩

### まずはこの方針でOK🙆‍♀️

* ✅ **あとで投影（Projection）や通知に必要な最小データ**
* ✅ なるべく **プリミティブ中心**（string/number/boolean）
* ✅ 「その時点の事実」がわかる（発生時刻とか）

イベント設計では「出来事は過去の事実」「サイズ（粒度）は目的に合わせる」みたいな話がよく出てくるよ📌 ([Event-Driven][4])

---

## 6) ハンズオン：OrderPlaced / OrderPaid を作ろう✍️✨

ここからは「学食モバイル注文」題材でいくよ〜🍙📱
この章では **イベントを“作って貯める”** ところまでやる！（配る＝ハンドラは次章🌱）

---

### 6-1) DomainEventの共通形を作る🧱

```ts
// src/domain/events/domainEvent.ts
export type DomainEvent<TType extends string, TPayload> = {
  eventId: string;          // 1イベントを一意にするID
  type: TType;              // "OrderPlaced" みたいな識別子
  occurredAt: string;       // ISO文字列でOK（例: new Date().toISOString()）
  aggregateId: string;      // OrderのID
  payload: TPayload;        // そのイベント固有データ
};
```

---

### 6-2) 具体イベント型を作る（discriminated union）🧷✨

```ts
// src/domain/events/orderEvents.ts
import type { DomainEvent } from "./domainEvent";

export type OrderPlaced = DomainEvent<
  "OrderPlaced",
  {
    userId: string;
    items: Array<{ menuId: string; quantity: number; unitPrice: number }>;
    totalPrice: number;
  }
>;

export type OrderPaid = DomainEvent<
  "OrderPaid",
  {
    paidAmount: number;
    paymentMethod: "CARD" | "CASH" | "QR";
  }
>;

export type OrderDomainEvent = OrderPlaced | OrderPaid;
```

---

### 6-3) Order集約で「イベントをためる」📦🧲

Orderの中で状態が変わったら、イベントを `push` するよ〜✨

```ts
// src/domain/order/order.ts
import { randomUUID } from "node:crypto";
import type { OrderDomainEvent, OrderPlaced, OrderPaid } from "../events/orderEvents";

type OrderStatus = "NEW" | "ORDERED" | "PAID";

export class Order {
  private domainEvents: OrderDomainEvent[] = [];

  private constructor(
    private readonly id: string,
    private status: OrderStatus,
    private readonly userId: string,
    private totalPrice: number,
  ) {}

  static place(params: {
    orderId: string;
    userId: string;
    items: Array<{ menuId: string; quantity: number; unitPrice: number }>;
  }): Order {
    // 超ミニマムな不変条件（本気のバリデーションは前章の復習ね😉）
    if (params.items.length === 0) throw new Error("items is required");
    if (params.items.some(i => i.quantity <= 0)) throw new Error("quantity must be > 0");

    const total = params.items.reduce((sum, i) => sum + i.quantity * i.unitPrice, 0);

    const order = new Order(params.orderId, "ORDERED", params.userId, total);

    const ev: OrderPlaced = {
      eventId: randomUUID(),
      type: "OrderPlaced",
      occurredAt: new Date().toISOString(),
      aggregateId: params.orderId,
      payload: { userId: params.userId, items: params.items, totalPrice: total },
    };

    order.domainEvents.push(ev);
    return order;
  }

  pay(params: { paidAmount: number; paymentMethod: "CARD" | "CASH" | "QR" }): void {
    if (this.status !== "ORDERED") throw new Error("order is not payable");
    if (params.paidAmount !== this.totalPrice) throw new Error("paidAmount mismatch");

    this.status = "PAID";

    const ev: OrderPaid = {
      eventId: randomUUID(),
      type: "OrderPaid",
      occurredAt: new Date().toISOString(),
      aggregateId: this.id,
      payload: { paidAmount: params.paidAmount, paymentMethod: params.paymentMethod },
    };

    this.domainEvents.push(ev);
  }

  // 👇 次章でイベントを配るために「取り出せる」ようにする
  pullDomainEvents(): OrderDomainEvent[] {
    const events = this.domainEvents;
    this.domainEvents = [];
    return events;
  }

  getId(): string {
    return this.id;
  }
}
```

**ここがこの章のキモ！**
「状態を変えたらイベントを積む」＝**ドメインの出来事を記録する** って感じ📌✨

---

## 7) CQRS的に、イベントはどこで“配る”の？📨（超ざっくり図）

この章は“作る”がメインだけど、流れだけ先に見せるね👀✨

```text
[CommandHandler]
  ↓  (Orderを呼ぶ)
[Order Aggregate]  --(domainEventsにpush)-->  eventsが溜まる
  ↓  (保存)
[Repository]
  ↓  (コミット後)
[EventDispatcher]  --(publish)-->  [EventHandler/Projection/通知...]
```

「コミット後に投影する」みたいな話は、まさにこの後の章でがっつりやるやつ〜🌱✨

---

## 8) よくある失敗あるある💥😵‍💫

### (1) イベント名が現在形になる

* ❌ `PayOrder`（これコマンドっぽい）
* ✅ `OrderPaid`

### (2) イベントに “重すぎる情報” を全部入れる

* ❌ Order全オブジェクト丸ごとドーン💣
* ✅ Readモデル更新に必要な最小情報だけ

### (3) 「イベントを出すこと」が目的になる

イベントは “便利な道具” であって “正義の儀式” じゃないよ😂
必要なところからでOK👌

---

## 9) ミニ演習（超たいせつ！）📝✨

### 演習A：これはCommand？Event？どっち？🎯

次を分類してみてね👇

1. `PlaceOrder`
2. `OrderPlaced`
3. `PayOrder`
4. `OrderPaid`
5. `RebuildReadModel`

（答え：1/3/5はCommand寄り、2/4はEvent寄り。※5は運用コマンドっぽい！）

### 演習B：OrderPaidのpayloadに何入れる？🤔💭

* 最低限いるのは何？
* 「あとで集計したい」を考えると何が必要？

---

## 10) テストの書き方（イベントが出たかを確認）🧪✨

「支払いしたら `OrderPaid` が出る」を確かめる例ね👇

```ts
import { Order } from "../src/domain/order/order";

test("pay emits OrderPaid", () => {
  const order = Order.place({
    orderId: "o-1",
    userId: "u-1",
    items: [{ menuId: "m-1", quantity: 2, unitPrice: 300 }],
  });

  order.pay({ paidAmount: 600, paymentMethod: "CARD" });

  const events = order.pullDomainEvents();
  expect(events.some(e => e.type === "OrderPaid")).toBe(true);
});
```

---

## 11) AI活用🤖✨（Copilot/Codexに頼むコツ）

### そのまま使えるお願い文（コピペOK）🧁

* 「`OrderPlaced` と `OrderPaid` のイベント型を、discriminated unionで提案して。payloadは“投影に必要な最小限”にしてね」
* 「この `Order` のメソッドが“イベントを出す位置”として適切かレビューして。イベント名が過去形になってるかも見て」
* 「イベントに入れるべき項目と、入れない方がいい項目を表で出して」

AIが盛りがちなので、最後にこう言うと良いよ👇
「それ、Readモデル更新に本当に必要？削っても成立しない？」✂️😆

---

## 12) この章のまとめ🎉

* ドメインイベントは **“起きた事実”**（過去形）📣
* Commandは **“やってほしい”**、Eventは **“起きた”** 🔀
* 集約（Order）の中で **状態変化→イベントpush** が基本📦
* テストは **“何が起きたか”を検証**できて強い🧪✨

---

## 📌 最新情報メモ（2026/01 時点）🗞️✨

* TypeScriptは **5.9系が最新の安定版**として案内されているよ（公式Downloadでも “currently 5.9” 表記）📌 ([TypeScript][5])
* npm上の `typescript` も **Latest が 5.9.3** になってる（少なくとも直近更新ではそう）🧩 ([npm][6])
* さらに先として、TypeScript公式は **6.0（橋渡し）→7.0（ネイティブ移行）** の話も公開してるよ🚀 ([Microsoft for Developers][7])

---

次の第28章では、今日作った `OrderPaid` みたいなイベントを **受け取ってReadモデルを育てる係（イベントハンドラ）** を作るよ🌱🔧
「イベントをどう配る？二重配信きたら？順番は？」みたいな現実の話も、やさしくやるね😊✨

[1]: https://martinfowler.com/eaaDev/DomainEvent.html?utm_source=chatgpt.com "Domain Event"
[2]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation?utm_source=chatgpt.com "Domain events: Design and implementation - .NET"
[3]: https://docs.getprooph.org/tutorial/event_sourcing_basics.html?utm_source=chatgpt.com "Event Sourcing Basics"
[4]: https://event-driven.io/en/events_should_be_as_small_as_possible/?utm_source=chatgpt.com "Events should be as small as possible, right?"
[5]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[6]: https://www.npmjs.com/package/typescript?activeTab=versions&utm_source=chatgpt.com "typescript"
[7]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
