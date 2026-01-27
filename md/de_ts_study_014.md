# 第14章 イベントハンドラ入門（副作用を外へ）🔔🧩

## 14.0 この章でできるようになること 🎯✨

* ドメインイベントを「受け取って処理する側」＝**イベントハンドラ**を説明できるようになる😊
* 「通知」「ポイント付与」みたいな**副作用（外部に影響する処理）**を、ドメインの外に出して整理できる🌍✨
* **1ハンドラ＝1関心**で、増えても破綻しにくい形の第一歩が作れる🍱🧠
* 最小の **Dispatcher（配る人）** と **Handler（受け取る人）** をTypeScriptで書ける✍️🧪

---

## 14.1 イベントハンドラってなに？🧩🔔

ドメインイベントは「業務で起きた事実」だったよね⏳
例：`OrderPaid`（注文が支払われた）

**イベントハンドラ**は、その事実を受け取って、

* メール送る📩
* Slack通知する💬
* ポイントを付与する🪙
* 外部サービスに連携する🔗

みたいな **“外へ出る処理”** を担当する人だよ〜😊✨

---

## 14.2 なんで副作用（外部I/O）をドメインから追い出すの？🏃‍♀️💨

ドメインの中に副作用が混ざると、だんだん地獄になりがち😵‍💫

### よくある混ざり方（つらい）😵

* `Order.pay()` の中でメール送信📩
* `Order.pay()` の中で外部API呼び出し📡
* `Order.pay()` の中でログ出力や通知が山盛り🪵

こうなると…

* テストが書きにくい（ネットワーク絡むと不安定）🧪💥
* 変更が怖い（通知仕様変更でドメイン触る羽目）😱
* 責務が増殖して、読めなくなる📚🌀

### いい分け方（スッキリ）✨

* ドメイン：状態を変えて、**イベントを溜める**だけ🫙
* アプリ層：保存したあと、**イベントを配る**📣
* ハンドラ：受け取って、**外部I/Oをやる**🌍

つまり、ドメインは「静かに事実を残す」担当、ハンドラが「外で動く」担当だよ😌🔔

---

## 14.3 超重要ルール：1ハンドラ＝1関心 🎯✂️

例：`OrderPaid` が起きたらやりたいことが2つあるとするね👇

* お客さんに支払い完了メール📩
* ポイント付与🪙

ここで **1つのハンドラに2つ詰める**と、あとで壊れやすい😵‍💫
だから基本はこう👇

* `SendPaymentEmailHandler`（通知だけ）📩
* `GrantPointsOnPaymentHandler`（ポイントだけ）🪙

✅ 分けると嬉しいこと

* 片方だけ仕様変更しても、もう片方に影響しにくい✨
* テストがシンプルになる🧪
* 失敗したときに「どれが失敗？」が分かりやすい🔎

---

## 14.4 最小の形を作ろう：Handler と Dispatcher 🧰📣

ここでは「最低限動く」形を作るよ😊
（失敗時の高度な運用は、後ろの章で育てるイメージ🪴）

### 14.4.1 イベント型（共通フォーマット）🧾🛡️

```ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  occurredAt: string;      // ISO文字列にしておくと扱いやすいよ📅
  aggregateId: string;
  type: TType;
  payload: TPayload;
}>;
```

---

### 14.4.2 ハンドラの型（受け取って処理する）🔔🧩

```ts
export interface DomainEventHandler<TEvent extends DomainEvent<string, any>> {
  readonly eventType: TEvent["type"];
  handle(event: TEvent): Promise<void>;
}
```

* `eventType`：どのイベント担当？📌
* `handle`：処理本体（外部I/OはここでOK）🌍✨

---

### 14.4.3 Dispatcher（イベントを配る係）📣🚚

「イベントtypeごとに、登録されてるハンドラ全員に配る」だけ😊

```ts
export class DomainEventDispatcher {
  private readonly handlerMap = new Map<string, DomainEventHandler<any>[]>();

  register<TEvent extends DomainEvent<string, any>>(handler: DomainEventHandler<TEvent>) {
    const list = this.handlerMap.get(handler.eventType) ?? [];
    list.push(handler);
    this.handlerMap.set(handler.eventType, list);
  }

  async dispatch(event: DomainEvent<string, any>) {
    const handlers = this.handlerMap.get(event.type) ?? [];

    // まずは「順番に実行」でOK（後の章で並列や順序制御を育てる🌱）
    for (const handler of handlers) {
      await handler.handle(event);
    }
  }

  async dispatchAll(events: DomainEvent<string, any>[]) {
    for (const e of events) {
      await this.dispatch(e);
    }
  }
}
```

---

## 14.5 例：`OrderPaid` から「通知」「ポイント付与」を分ける 📩🪙

### 14.5.1 イベント定義 🧾

```ts
export type OrderPaid = DomainEvent<
  "OrderPaid",
  Readonly<{
    orderId: string;
    userId: string;
    paidAmount: number;
  }>
>;
```

---

### 14.5.2 外部I/Oは “Port（口）” を用意して差し替えやすくする 🔌🎭

「メール送信」と「ポイント付与」は外の世界の都合が強いから、まずは口だけ定義するよ😊

```ts
export interface EmailSender {
  send(toUserId: string, subject: string, body: string): Promise<void>;
}

export interface PointsService {
  addPoints(userId: string, points: number, reason: string): Promise<void>;
}
```

---

### 14.5.3 通知ハンドラ（通知だけやる）📩✨

```ts
export class SendPaymentEmailHandler implements DomainEventHandler<OrderPaid> {
  readonly eventType = "OrderPaid" as const;

  constructor(private readonly emailSender: EmailSender) {}

  async handle(event: OrderPaid): Promise<void> {
    const { userId, orderId, paidAmount } = event.payload;

    await this.emailSender.send(
      userId,
      "お支払い完了のお知らせ🎉",
      `注文 ${orderId} のお支払い（${paidAmount}円）を確認しました！ありがとう💖`
    );
  }
}
```

---

### 14.5.4 ポイント付与ハンドラ（ポイントだけやる）🪙✨

```ts
export class GrantPointsOnPaymentHandler implements DomainEventHandler<OrderPaid> {
  readonly eventType = "OrderPaid" as const;

  constructor(private readonly points: PointsService) {}

  async handle(event: OrderPaid): Promise<void> {
    const { userId, paidAmount } = event.payload;

    // 例：100円で1pt（超適当ルール🧸）
    const pointsToAdd = Math.floor(paidAmount / 100);

    if (pointsToAdd <= 0) return;

    await this.points.addPoints(userId, pointsToAdd, "OrderPaid🧾");
  }
}
```

---

## 14.6 「保存 → イベントを配る」ユースケースの流れ 🧠💾➡️📣

やりたい順番はこれ👇（前章のおさらいだよ😊）

1. ドメイン操作で状態変更🔥
2. ドメインがイベントを溜める🫙
3. Repositoryで保存💾
4. そのあとに Dispatcher で配る📣

イメージコード👇

```ts
export class PayOrderUseCase {
  constructor(
    private readonly orderRepo: { save(order: any): Promise<void> },
    private readonly dispatcher: DomainEventDispatcher
  ) {}

  async execute(order: any) {
    // 1) ドメイン操作（ここでイベントが溜まる前提）
    order.pay();

    // 2) イベント取り出し
    const events = order.pullDomainEvents();

    // 3) 先に保存
    await this.orderRepo.save(order);

    // 4) あとで配る
    await this.dispatcher.dispatchAll(events);
  }
}
```

✅ ここでのポイント

* ドメインは外部I/Oしない😌
* 配信は「保存のあと」📌（保存できてないのに通知だけ飛ぶの、怖いよね😱）

---

## 14.7 よくある落とし穴（初心者あるある）😵‍💫🧯

### 落とし穴1：ハンドラで“何でもやる”🍲

* 通知もポイントも集計も…全部1個に詰める
  → ❌ 後で爆発しがち💥
  → ✅ まずは **1関心1ハンドラ** 🎯

### 落とし穴2：イベントpayloadに情報詰め込みすぎ🎒

* 氏名・住所・明細ぜんぶ乗せる
  → ❌ 個人情報や巨大データで事故りやすい
  → ✅ まずは **最小限**（IDと必要な数値くらい）✨

### 落とし穴3：ハンドラの失敗を無視する🙈

* 例：メール送信が落ちたのに「成功扱い」
  → いったんこの章では「失敗したら例外で止める」でもOK
  → 本格的な運用（リトライ/保管）は後の章で育てる🌱

### 落とし穴4：ドメインがハンドラを直接呼ぶ☎️

* `order.pay()` の中で `emailSender.send()`
  → ❌ それは混ざってるサイン🌀
  → ✅ payはイベントを出すだけにして、外で反応する🔔

---

## 14.8 ミニ演習（やってみよう）✍️💖

### 演習1：`OrderPaid` のハンドラを2つに分ける📩🪙

* すでに例があるから、コピって動かしてOK😊
* 「メール本文」「ポイント計算ルール」を少し変えてみてね✨

### 演習2：3つ目のハンドラを追加する📊

例：`RecordSalesHandler`（売上集計に記録する）📈

* `SalesRecorder` みたいなPortを作って、そこに渡すだけにする🧩

### 演習3：Dispatcherにハンドラを登録して動かす📣

* `dispatcher.register(new SendPaymentEmailHandler(...))`
* `dispatcher.register(new GrantPointsOnPaymentHandler(...))`
* `dispatchAll([orderPaidEvent])` で両方動くのを確認✅

---

## 14.9 ハンドラのテスト超入門（“呼ばれた？”を見る）🧪👀

ハンドラのテストはシンプルでOK😊
「外部I/OのPortが、期待通り呼ばれたか？」を見るだけ！

### 例：通知ハンドラのテスト（Vitest想定）🧪📩

VitestはTypeScriptを扱いやすい設計のテストフレームワークだよ🧪✨ ([Vitest][1])

```ts
import { describe, it, expect, vi } from "vitest";

describe("SendPaymentEmailHandler", () => {
  it("OrderPaid を受けたらメール送信を呼ぶ📩", async () => {
    const emailSender = {
      send: vi.fn().mockResolvedValue(undefined),
    };

    const handler = new SendPaymentEmailHandler(emailSender);

    const event = {
      eventId: "e1",
      occurredAt: new Date().toISOString(),
      aggregateId: "order-1",
      type: "OrderPaid",
      payload: { orderId: "order-1", userId: "user-1", paidAmount: 1200 },
    } as const;

    await handler.handle(event);

    expect(emailSender.send).toHaveBeenCalledTimes(1);
    expect(emailSender.send).toHaveBeenCalledWith(
      "user-1",
      expect.any(String),
      expect.stringContaining("order-1")
    );
  });
});
```

---

## 14.10 AI活用（ハンドラ設計が一気にラクになる）🤖✨

### 相談プロンプト例（コピペOK）📋

* 「`OrderPaid` が起きたときに考えられる副作用を10個出して。通知/集計/連携で分類して」🔍
* 「この副作用は“ドメインの責務”？それとも“ハンドラの責務”？理由もつけて」🧭
* 「1関心1ハンドラに分けた名前案を出して。命名が“事実”っぽいかもチェックして」✂️

AIに出させた案は、そのまま採用じゃなくて、**粒度が大きすぎ/小さすぎ**を一回見直すと強いよ⚖️✨

---

## 14.11 2026ミニ情報：いまどきTypeScript/Nodeの現状メモ 🗓️🧠

* Node.js は **v24 系が Active LTS**、v25 系は Current（最新版系）として更新されているよ📌 ([Node.js][2])
* TypeScript は npm の latest が **5.9.3**（本日時点）だよ🧩 ([NPM][3])
* TypeScript 5.9 のリリースノートは **2026-01-26 更新**になっていて、Node向け設定（例：`--module node20` の安定オプション）みたいな話も整理されてるよ🔧 ([typescriptlang.org][4])

---

## 14.12 この章のまとめ ✅💖

* ハンドラは「イベントを受けて、副作用を実行する係」🔔
* ドメインから外部I/Oを追い出すと、設計もテストも一気にラクになる✨
* まずは **1ハンドラ＝1関心** 🎯 で分けるのが最強の第一歩🍱
* 最小構成（Handler + Dispatcher）が書ければ、次の章で増殖しても整理できる土台ができるよ🪴✨

[1]: https://vitest.dev/?utm_source=chatgpt.com "Vitest | Next Generation testing framework"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[4]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
