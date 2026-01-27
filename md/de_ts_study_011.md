# 第11章 イベントはどこで発火する？（集約ルート）🔥🏛️

## この章のゴール🎯✨

* 「ドメインイベントは**どこで作る（発火させる）べきか**」を説明できるようになる💬
* “なんとなく便利そう”じゃなくて、「ここで出すのが筋だよね！」って判断できるようになる🧠⚖️

---

## まず結論：イベントは「集約ルート」で出すのが基本🥇🏛️

ドメインイベントは、**状態変更が起きた瞬間**に生まれるのが自然です💥
そして、その状態変更を“正しく”起こす責任を持つのが **集約ルート（Aggregate Root）** です🧱🔒

* 集約は「ひとまとまりのドメインオブジェクト」を**1つの単位**として扱う考え方です。([martinfowler.com][1])
* その単位のルール（不変条件）を守るために、更新は「集約ルートという1つの入口」で行うのが大事です。([Microsoft Learn][2])

だから、**集約ルートで状態を変えた瞬間に、集約ルートがイベントを作る**のがいちばんスッキリします😊✨

---

## “どこで発火？”が大事な理由😵‍💫➡️😌

イベントの発火場所を間違えると、こんな事故が起きやすいです💣

* ルール違反の状態でもイベントが出ちゃう（嘘のニュース速報）📢❌
* いろんな場所で勝手にイベントが出て、追跡不能になる🌀
* 「保存に失敗したのにイベントだけ出た」みたいな悲劇が起きる😭（この辺は後半章でガッツリやるよ！）

だからこの章では、まず **“イベントは集約ルートが出す”** を体にしみこませます💪✨

---

## 集約ルートって、超ざっくり何？🏛️🧸

イメージはこれ👇
**集約ルート＝そのドメインの“門番”**🚪🛡️

* ルールを守って状態を変える（不変条件を守る）🔒
* 外からの更新は、基本この門を通す🚪
* だから「何が起きたか」を一番わかってる👀✨

MicrosoftのDDD系ガイドでも、集約ルートが「ルールを守るための単一の入口（gate）」になることが重要だと言っています。([Microsoft Learn][2])

---

## 発火のタイミングはいつ？⏳💥

コツはシンプル👇

### ✅ 状態変更が「確定」した直後

* チェック（不変条件）OK ✅
* 状態を更新 ✅
* その“事実”としてイベントを積む🧾✨

つまり順番はだいたいこれ👇

1. ルールチェック🔒
2. 状態を変える🔁
3. イベントを追加📌

---

## 良い例 / 悪い例 👀⚖️

### ✅ 良い例：集約ルートのメソッド内でイベントを作る🏛️✨

* `order.pay()` の中で、支払い完了を確定させたあと `OrderPaid` を積む💳✅➡️🧾

### ❌ 悪い例：アプリ層（ユースケース）でイベントを作る🙅‍♀️

* `usecase.payOrder()` で DB保存の前後とかで雑に `OrderPaid` を作る
  → もしドメイン的に支払い不可だったら？😇
  → “本当は起きてないのにイベントだけ出る”危険が増える💣

### ❌ 悪い例：ハンドラがドメインイベントを作る🙅‍♀️

* 通知ハンドラの中で「じゃあ次は `OrderShipped` 出しとくか！」
  → それは“通知担当”の仕事じゃないよ〜〜😵‍💫
  → 発送は「注文の状態変更」なので、注文（集約）側が責任を持つべき📦🏛️

---

## TypeScriptでの基本形：集約ルートがイベントを“ためる”🫙🧩

この章では「イベントを発火＝**イベントを作って、集約の中に貯める**」までやります📌
（実際に配る流れは次の章で登場📣🚚）

### 1) ドメインイベントの共通型🧾🛡️

```ts
// domain/events/DomainEvent.ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  occurredAt: string; // ISO文字列にしておくと扱いやすいよ📅
  aggregateId: string;
  type: TType;
  payload: TPayload;
}>;
```

### 2) AggregateRoot：イベントを貯めて取り出す🫙📤

```ts
// domain/shared/AggregateRoot.ts
import { DomainEvent } from "../events/DomainEvent";

export abstract class AggregateRoot {
  private domainEvents: DomainEvent<string, unknown>[] = [];

  protected addDomainEvent(event: DomainEvent<string, unknown>) {
    this.domainEvents.push(event);
  }

  // アプリ層が取り出して配るための出口📤
  pullDomainEvents(): DomainEvent<string, unknown>[] {
    const events = [...this.domainEvents];
    this.domainEvents = [];
    return events;
  }
}
```

この「集約がイベントを保持して、あとで取り出す」スタイルは実務でもよく出てきます。([GitHub][3])

---

## ミニEC例：Order（注文）集約で発火する🔥📦

ここからが本番！🎉
注文は「作成→支払い→発送」って状態遷移するよね🧾➡️💳➡️📦

### 1) Orderの状態とイベント型を用意🧩

```ts
// domain/order/OrderTypes.ts
export type OrderStatus = "Placed" | "Paid" | "Shipped";

export type OrderPlaced = {
  type: "OrderPlaced";
  payload: { customerId: string; totalAmount: number };
};

export type OrderPaid = {
  type: "OrderPaid";
  payload: { paymentId: string; paidAmount: number };
};

export type OrderShipped = {
  type: "OrderShipped";
  payload: { shippingId: string; shippedAt: string };
};

export type OrderDomainEvent = OrderPlaced | OrderPaid | OrderShipped;
```

### 2) Order集約ルート：状態変更の瞬間にイベントを積む🏛️🔥

```ts
// domain/order/Order.ts
import { AggregateRoot } from "../shared/AggregateRoot";
import { DomainEvent } from "../events/DomainEvent";
import { OrderStatus, OrderDomainEvent } from "./OrderTypes";

const newId = () => crypto.randomUUID();
const nowIso = () => new Date().toISOString();

export class Order extends AggregateRoot {
  private status: OrderStatus;

  private constructor(
    public readonly id: string,
    private customerId: string,
    private totalAmount: number,
    status: OrderStatus
  ) {
    super();
    this.status = status;
  }

  static place(params: { customerId: string; totalAmount: number }) {
    // ✅ ここで不変条件チェック（例）
    if (params.totalAmount < 0) throw new Error("totalAmount must be >= 0");

    const order = new Order(newId(), params.customerId, params.totalAmount, "Placed");

    // ✅ 状態が確定した直後にイベントを積む🔥
    order.addDomainEvent(order.toEvent("OrderPlaced", {
      customerId: params.customerId,
      totalAmount: params.totalAmount,
    }));

    return order;
  }

  pay(params: { paymentId: string; paidAmount: number }) {
    if (this.status !== "Placed") throw new Error("Order is not payable");
    if (params.paidAmount !== this.totalAmount) throw new Error("Paid amount mismatch");

    this.status = "Paid";

    this.addDomainEvent(this.toEvent("OrderPaid", {
      paymentId: params.paymentId,
      paidAmount: params.paidAmount,
    }));
  }

  ship(params: { shippingId: string }) {
    if (this.status !== "Paid") throw new Error("Order is not shippable");

    this.status = "Shipped";

    this.addDomainEvent(this.toEvent("OrderShipped", {
      shippingId: params.shippingId,
      shippedAt: nowIso(),
    }));
  }

  private toEvent<TType extends OrderDomainEvent["type"]>(
    type: TType,
    payload: Extract<OrderDomainEvent, { type: TType }>["payload"]
  ): DomainEvent<TType, typeof payload> {
    return {
      eventId: newId(),
      occurredAt: nowIso(),
      aggregateId: this.id,
      type,
      payload,
    };
  }
}
```

ポイントはここ👇✨

* `pay()` や `ship()` の中で **状態を変えた直後**にイベントを積んでる🔥
* “支払い完了”という事実は、Orderがいちばん正しく知ってる👀🏛️
* だから Order（集約ルート）が `OrderPaid` を出すのが筋💳✅➡️🧾

---

## 子エンティティからイベント出したいときは？👶➡️🏛️

たとえば `OrderItem` が「数量が多すぎ！」みたいな事実を検知することもあります📦😵‍💫
その場合でも、**集約ルートがそれを受け取ってまとめて扱う**形がよく使われます。
Microsoftのガイドでも「子エンティティがイベントを上げ、それを集約ルートが受け取る」方針が紹介されています。([Microsoft Learn][4])

---

## よくある“置き場所ミス”チェックリスト🧯✅

次の質問に「YES」なら、集約ルートで発火が濃厚だよ👀✨

* それって「ドメインの事実」？（過去形で言える？）⏳
* 集約の状態が変わった？（Placed→Paidみたいに）🔁
* 不変条件チェックの結果で起きたり起きなかったりする？🔒
* “いちばん正しく状況を知ってるのは誰？” → 集約ルート？🏛️

逆に、これがYESなら「ハンドラ側の仕事」寄りかも👇

* 外部API呼び出し（メール、決済連携、通知）🌍📩
* 集計、検索用テーブル更新、ログ強化📈🧾
* “ドメインの状態”ではなく“周辺の反応”💡

---

## 演習📝💖（ミニECでやってみよう）

### 演習1：どこでイベントを出す？🏛️🧠

次の出来事について、**集約ルートで発火？それともハンドラ？** を決めて理由も書いてね✍️✨

1. 注文が作成された🧾
2. 支払いが完了した💳
3. 注文確認メールを送った📩
4. 出荷指示を倉庫APIに送った📡
5. 売上集計のグラフ用データを更新した📈

ヒント：1,2は「注文の状態」そのもの！ 3〜5は「周辺の反応」っぽいかも👀

### 演習2：命令っぽいイベント名を直す✍️🔁

次の名前を「事実（過去形）」に直してね✨

* `SendOrderConfirmationEmail` 📮❌
* `DoPayment` 💳❌
* `UpdateSalesReport` 📈❌

### 演習3：イベントが出たかテストする🧪✨

`Order.place()` したら `OrderPlaced` が1件入ってるか、テストで確認してみよう💖

---

## 🤖 AI活用プロンプト例（コピペOK）✨

### 1) 発火場所の判定を手伝ってもらう🧭

```text
次の処理について「集約ルートで発火するドメインイベント」か「ハンドラ側の副作用」か判定して、
理由を3つ、初心者にも分かる言葉で説明して。
題材：ミニEC（注文→支払い→発送）
処理：〇〇〇
```

### 2) イベント粒度レビューしてもらう🔍

```text
このイベント設計は粒度が大きすぎる/小さすぎる？
event: OrderUpdated
payload: { orderId, status, items, customer, address, ... }
改善案を2つ出して。
```

### 3) “過去形の事実”になってるかチェック✅

```text
次のイベント名が「過去形の事実」になっているかチェックして、
命令っぽい場合は言い換え候補を10個出して。
[ ...イベント名一覧... ]
```

---

## 章のまとめ📌✨

* イベントは「状態変更が確定した瞬間」に生まれるのが自然💥
* 状態変更の責任者は基本「集約ルート」🏛️
* だから **集約ルートのメソッド内でイベントを作って貯める** が基本形🫙✨
* 子エンティティ発の気づきも、最終的に集約ルートでまとめる設計が定番👶➡️🏛️ ([Microsoft Learn][4])

次章では、この“貯めたイベント”を **どういう順番で配る？いつ配る？** を扱うよ📣🚚

[1]: https://martinfowler.com/bliki/DDD_Aggregate.html?utm_source=chatgpt.com "D D D_ Aggregate"
[2]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice?utm_source=chatgpt.com "Designing a DDD-oriented microservice - .NET"
[3]: https://github.com/BeameryHQ/ddd-ts?utm_source=chatgpt.com "BeameryHQ/ddd-ts: Build (multi-tenanted) NodeJS ..."
[4]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation?utm_source=chatgpt.com "Domain events: Design and implementation - .NET"
