# 第15章　トランザクション境界の考え方（集約の肌感）🔒📦✨

この章はね、「**1回の更新で“絶対にズレちゃダメな範囲”ってどこ？**」を決められるようになる回だよ〜！😊💡
CQRSのWrite側（Command側）って、更新が増えるほど「途中で失敗して半端な状態になる」事故が起きやすいのね😱💥
だから **トランザクション境界** をちゃんと決めて、**全部成功 or 全部なかったこと** にできるようにするよ🔒✨

（ちなみに、いまのTypeScriptは **5.9系** が最新として案内されてるよ🧡 ([TypeScript][1]) / Node.jsは **24がActive LTS** で、24.13.0みたいなセキュリティ更新が出てる感じ！🛡️ ([Node.js][2])）

---

## 1. トランザクションって結局なに？🤔💭

超ざっくり言うと…

* ✅ **全部の更新が成功したらコミット（確定）**
* ❌ 途中でコケたら **ロールバック（なかったことにする）**

っていう「**安全装置**」だよ🔒✨

たとえば学食アプリで…

* 注文を「PAID」にした ✅
* でも支払い記録が保存できなかった ❌

みたいな状態になると、
**“払ったことになってるのに記録がない”** って地獄が生まれる😇🔥

---

## 2. “トランザクション境界”ってなに？📦🔒

トランザクション境界は、

> **このCommandで守りたい“まとまり”はどこまで？**

っていう線引きのことだよ✍️✨

そしてCQRS/DDDっぽい世界では、よくこう考えるの👇

### ✅ 「集約（Aggregate）」＝ 一貫性を守る単位 📦✨

学食アプリなら、多くの場合…

* **Order（注文）** が「集約ルート」になって
* その中に

  * OrderItems（明細）
  * Total（合計）
  * Status（状態：ORDERED/PAID…）
  * PaymentInfo（支払い情報：あるなら）

みたいなのが “ひとかたまり” になることが多いよ😊🍙

---

## 3. この章のいちばん大事なルール💎✨

### ✅ 1 Command = 1 Transaction（基本形）🔒

* CommandHandlerの中で

  1. 注文（Order）を読み込む
  2. ルールに沿って変更する
  3. 保存する
* これを **1回のトランザクション** で包む🎁✨

そしてもう1個大事！

### ✅ “同時に必ず一致してないと困るもの”だけを同じトランザクションに入れる💡

逆に言うと…

* 📧 メール送信
* 📊 集計の更新
* 🔔 通知
* 🧾 レシートPDF作成

みたいな「あとからでもOK」なものは、**同じトランザクションに入れない**方がラク＆強いことが多いよ🙂✨
（このへんは後半の「イベント」「投影」「Outbox」に繋がっていくよ〜！📮✨）

---

## 4. ハンズオン：In-Memoryで“トランザクション感”を体験しよ🧪🧡

DBなしでも「コミット/ロールバックの気持ち」を体験できるように、
**In-Memoryだけで“疑似トランザクション”** を作っちゃうよ😆✨

### 4.1 ざっくり構成📁

* `Order`（ドメイン）
* `OrderRepository`（保存の窓口）
* `runInTransaction`（全部成功したら確定、失敗したら破棄）

---

### 4.2 ドメイン：Order（集約ルート）📦✨

```ts
// src/domain/order/Order.ts
export type OrderStatus = "ORDERED" | "PAID";

export class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DomainError";
  }
}

export class Order {
  private constructor(
    public readonly id: string,
    private status: OrderStatus,
    private totalYen: number,
    private paidAt: Date | null
  ) {}

  static place(id: string, totalYen: number) {
    if (totalYen < 0) throw new DomainError("合計金額がマイナスはダメ🙅‍♀️");
    return new Order(id, "ORDERED", totalYen, null);
  }

  pay(paidAt: Date) {
    if (this.status !== "ORDERED") {
      throw new DomainError("未注文以外は支払えないよ🙅‍♀️");
    }
    // ここが「一貫性を守るルール」✨
    this.status = "PAID";
    this.paidAt = paidAt;
  }

  snapshot() {
    // 外に出す用（Read側にそのまま渡さない前提でも、デバッグには便利🙂）
    return {
      id: this.id,
      status: this.status,
      totalYen: this.totalYen,
      paidAt: this.paidAt,
    };
  }
}
```

---

### 4.3 Repository：トランザクションを“箱”として提供する🗄️🔒

```ts
// src/domain/order/OrderRepository.ts
import { Order } from "./Order";

export interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  save(order: Order): Promise<void>;

  // ここが今日の主役！✨
  runInTransaction<T>(fn: (repo: OrderRepository) => Promise<T>): Promise<T>;
}
```

---

### 4.4 InMemory実装：成功したらコミット、失敗したらロールバック🧠✨

ポイントは「**トランザクション中はコピーに書き込む**」ことだよ🙂🪄

```ts
// src/infra/InMemoryOrderRepository.ts
import { OrderRepository } from "../domain/order/OrderRepository";
import { Order } from "../domain/order/Order";

export class InMemoryOrderRepository implements OrderRepository {
  private store = new Map<string, Order>();

  async findById(id: string) {
    return this.store.get(id) ?? null;
  }

  async save(order: Order) {
    this.store.set(order.id, order);
  }

  async runInTransaction<T>(fn: (repo: OrderRepository) => Promise<T>): Promise<T> {
    // ★ スナップショット（コピー）を作る
    const snapshot = new Map(this.store);

    // ★ トランザクション中だけ snapshot に書き込む repo
    const txRepo: OrderRepository = {
      findById: async (id) => snapshot.get(id) ?? null,
      save: async (order) => { snapshot.set(order.id, order); },
      runInTransaction: async (innerFn) => innerFn(txRepo), // ネストは簡易対応
    };

    try {
      const result = await fn(txRepo);
      // ★ 成功したらコミット（本体を差し替え）
      this.store = snapshot;
      return result;
    } catch (e) {
      // ★ 失敗したらロールバック（何もしない＝差し替えない）
      throw e;
    }
  }
}
```

---

### 4.5 CommandHandler：PayOrderを“1トランザクション”で包む💳🔒

```ts
// src/app/commands/PayOrderHandler.ts
import { OrderRepository } from "../../domain/order/OrderRepository";
import { DomainError } from "../../domain/order/Order";

export class PayOrderHandler {
  constructor(private readonly repo: OrderRepository) {}

  async handle(orderId: string) {
    return this.repo.runInTransaction(async (txRepo) => {
      const order = await txRepo.findById(orderId);
      if (!order) throw new DomainError("注文が見つからないよ🥺");

      order.pay(new Date());
      await txRepo.save(order);

      return { ok: true as const, order: order.snapshot() };
    });
  }
}
```

---

### 4.6 動作確認：わざと失敗させて“ロールバック”を体感😆💥

```ts
// src/dev/playground.ts
import { InMemoryOrderRepository } from "../infra/InMemoryOrderRepository";
import { Order } from "../domain/order/Order";
import { PayOrderHandler } from "../app/commands/PayOrderHandler";

const repo = new InMemoryOrderRepository();
await repo.save(Order.place("order-1", 900));

const handler = new PayOrderHandler(repo);

// 成功パターン
console.log("✅ before:", (await repo.findById("order-1"))?.snapshot());
console.log(await handler.handle("order-1"));
console.log("✅ after:", (await repo.findById("order-1"))?.snapshot());

// 失敗パターン：2回目のpayはDomainErrorで落ちる（＝ロールバック感を確認）
try {
  await handler.handle("order-1");
} catch (e) {
  console.log("❌ expected error:", (e as Error).message);
}
console.log("🔒 finally:", (await repo.findById("order-1"))?.snapshot());
```

これで「**途中で落ちたら、確定しない**」って感覚が掴めるはず！🧡✨

---

## 5. ミニ演習：どこまで同時更新すべき？🎯📝

次の更新、**同じトランザクションに入れる？入れない？** を考えてみてね🙂✨
（答えもすぐ下に書くよ！）

### お題：PayOrder（支払う）でやりたいこと

1. Orderの状態を PAID にする
2. 支払い日時を保存する
3. 注文履歴テーブルに「支払い完了」を追加する（監査ログ）
4. 売上集計（Readモデル）を更新する
5. 「支払い完了しました🎉」通知を送る

### 目安の答え💡✨

* ✅ **同じトランザクション**：1) 2) 3)
  → **“Orderの一貫性”＋“監査ログ”はズレると困る**ことが多いから
* ⏳ **別（あとで）**：4) 5)
  → 集計や通知は、**遅れても致命傷じゃない**ことが多い（UXでカバー可能🙂🔄）

---

## 6. AI活用：トランザクション境界レビューをやらせよう🤖🔍✨

そのままコピペで使えるやつ置いとくね🧡

### 6.1 境界チェック用プロンプト

* 「このCommandで**同一トランザクションに入れるべき処理**と、**分けるべき処理**を理由つきで分けて。前提は“注文(Order)が集約”です。」

### 6.2 集約の範囲チェック用プロンプト

* 「`Order`集約に含めるべき属性/振る舞いと、外に出すべきものを分類して。判断基準は“同時に一貫性が必要か”で！」

### 6.3 ありがちな罠の指摘をさせるプロンプト

* 「この実装で“半端な状態が残る”ケースを3つ挙げて、修正案も出して🙂」

AIは便利だけど、最後はあなたの判断でOKだよ〜！😊🧠✨

---

## 7. まとめ🎀✨（ここ超重要！）

* トランザクションは「**全部成功 or 全部なし**」の安全装置🔒
* トランザクション境界は「**このCommandで守るべきまとまり**」📦
* 基本は **1 Command = 1 Transaction** ✅
* “絶対に一致してないと困るもの”だけを同じトランザクションへ💡
* 集計・通知みたいなものは後回しでOKなことが多い（次の章以降で強くなる！）⏳✨

---

次の第16章では、「同時更新（競合）」で **“同時に支払われたらどうする!?”** みたいな現実のつらさを扱うよ😆💥🔁

[1]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
