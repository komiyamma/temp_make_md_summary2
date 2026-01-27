# 第18章 最終的整合性の肌感覚（遅れて一致）🌊🕰️

## 🎯 この章のゴール

* 「最終的整合性（Eventual Consistency）」を **“ズレが起きても、最後は一致する設計”** として説明できるようになる✨
* ズレがある前提で、**ユーザーに不安を与えない表示（UX）** を作れるようになる💬💖
* TypeScriptで、**“更新は完了したのに、表示は少し遅れる”** をミニ実装して体感する🧩⚡

---

## 1) 🌱 最終的整合性ってなに？（超ざっくり）

最終的整合性は、ひとことで言うとこう👇

* ✅ **今この瞬間は、データが場所によってズレててもOK**
* ✅ でも、**新しい更新が止まれば、いずれ全部同じ状態にそろう（収束する）**

「すぐ一致」じゃなくて「**遅れて一致**」なんだね〜！🕰️🌊
この考え方自体が、分散システムでよく使われる“整合性モデル”として知られてるよ📚✨ ([ウィキペディア][1])

---

## 2) 🤔 なんでズレるの？（だいたい“非同期”のせい）

ドメインイベントは「起きた事実」をあとから配って、いろんな処理が動くよね📣🚚
このとき、だいたい **非同期** が混ざるからズレが起きるよ〜！

### 🧠 よくあるズレの流れ（ミニEC）

例：支払い（Payment）→ 発送（Shipping）→ 画面表示（UI）

* 🧾 注文は「支払い済み」になった（書き込みは完了！）
* 📣 そのイベントが配送側に届くのが少し後（ネットワーク/キュー/混雑）
* 📦 配送側の「発送状況」が更新されるのがさらに後
* 🖥️ だから、画面が一瞬「まだ発送準備中」みたいに見える

この “ちょい遅れ” が最終的整合性の正体だよ〜🌊🕰️

---

## 3) ⚖️ 強い整合性 vs 最終的整合性（どう選ぶの？）

分散システムは「全部を常に完全一致」にするのが難しいことが多いのね。
そこで **どこまでを“即一致”にして、どこからを“遅れて一致”にするか** を選ぶ感じ！🧠✨

CAP定理として「整合性（C）・可用性（A）・分断耐性（P）」のトレードオフがよく説明に使われるよ📌 ([IBM][2])

### ✅ “即一致（強い整合性）”が欲しいもの（例）

* 💳 二重決済しちゃう/残高がマイナスになる → 絶対NG
* 🧾 注文確定の不変条件（Invariants）が壊れる → 絶対NG

→ これは **第17章の「境界（トランザクション範囲）」の中で守る** イメージ🔒🧱

### ✅ “遅れて一致（最終的整合性）”でOKなもの（例）

* 📩 「メール通知が数秒遅れる」
* 📊 「売上集計が数分遅れる」
* 🚚 「配送ステータスが少し後で反映される」

マイクロサービスでは、分散トランザクションを避けて、**結果整合性＋補償（Compensating）** で扱うことが多いよ〜🧯🔁 ([martinfowler.com][3])
（補償はSagaの考え方にもつながるよ🤝） ([Microsoft Learn][4])

---

## 4) 💬 UXが命！“ズレても安心”にする表示のコツ

最終的整合性でいちばん大事なのはここ😍
**ズレがあること自体は普通**。でもユーザーが不安になると終わる…！😵‍💫

### ✅ コツA：状態を1つ増やす（“処理中”を用意）⏳

いきなり「反映されてない！」に見えるのが怖いので、

* `Pending`（反映待ち）
* `Processing`（処理中）
* `Queued`（順番待ち）
* `Confirmed`（確定）

みたいに、**“途中の状態”をちゃんと名前で持つ**のが強いよ💪✨

### ✅ コツB：言い切らない（断言は事故る）🫣

ズレがある前提なら、画面文言も「少し待ってね」に寄せると安定するよ🧸💕

* ❌「発送しました！」（まだかも）
* ✅「発送準備を進めています🚚✨」
* ✅「反映まで少し時間がかかることがあります🕰️」

### ✅ コツC：ユーザーに“次の行動”を渡す🧭

* 🔄 「更新」ボタン
* 🕵️ 「状況を確認する」リンク
* ⏱️ 自動再読み込み（数秒おきに数回だけ）

---

## 5) 🧪 体感ミニ実装：更新は終わったのに、表示が遅れる世界

ここからは、**“支払い完了 → 配送表示が2秒遅れて更新”** を作ってみるよ〜！🌊🕰️✨
（コンソールUIだけで体感できるやつ！）

### 5.1 📁 フォルダ構成（ミニ）

```text
src/
  domain/
    DomainEvent.ts
    Order.ts
  application/
    EventBus.ts
    OrderService.ts
  readmodel/
    OrderViewStore.ts
  index.ts
```

---

### 5.2 🧾 ドメインイベント型（最小）

```ts
// src/domain/DomainEvent.ts
export type DomainEvent<TType extends string, TPayload> = {
  eventId: string;
  type: TType;
  occurredAt: string; // ISO文字列でOK（簡単優先）
  aggregateId: string;
  payload: TPayload;
};
```

---

### 5.3 🛒 Order集約：支払いでイベントをためる

```ts
// src/domain/Order.ts
import { DomainEvent } from "./DomainEvent.js";

export type OrderStatus = "Created" | "Paid";

export class Order {
  private domainEvents: DomainEvent<string, any>[] = [];

  constructor(
    public readonly id: string,
    private status: OrderStatus = "Created",
  ) {}

  getStatus() {
    return this.status;
  }

  pay(nowIso: string) {
    if (this.status === "Paid") {
      throw new Error("すでに支払い済みだよ💳❌");
    }

    this.status = "Paid";

    this.domainEvents.push({
      eventId: crypto.randomUUID(),
      type: "OrderPaid",
      occurredAt: nowIso,
      aggregateId: this.id,
      payload: { orderId: this.id },
    });
  }

  pullDomainEvents() {
    const events = [...this.domainEvents];
    this.domainEvents = [];
    return events;
  }
}
```

---

### 5.4 📣 EventBus：イベントを購読者に配る（今回は超シンプル）

```ts
// src/application/EventBus.ts
import { DomainEvent } from "../domain/DomainEvent.js";

type Handler = (event: DomainEvent<string, any>) => Promise<void>;

export class EventBus {
  private handlers: Record<string, Handler[]> = {};

  on(eventType: string, handler: Handler) {
    this.handlers[eventType] ??= [];
    this.handlers[eventType].push(handler);
  }

  async publish(events: DomainEvent<string, any>[]) {
    for (const e of events) {
      const list = this.handlers[e.type] ?? [];
      // “非同期っぽさ”を出すため、handlerはawaitするけど中で遅延してOK
      for (const h of list) {
        await h(e);
      }
    }
  }
}
```

---

### 5.5 🪟 ReadModel：画面が見る“注文表示”はここ（遅れて更新される）

```ts
// src/readmodel/OrderViewStore.ts
export type OrderView = {
  orderId: string;
  paymentStatus: "Unpaid" | "Paid";
  shippingStatus: "NotReady" | "Preparing" | "Ready";
};

export class OrderViewStore {
  private store = new Map<string, OrderView>();

  get(orderId: string): OrderView {
    return (
      this.store.get(orderId) ?? {
        orderId,
        paymentStatus: "Unpaid",
        shippingStatus: "NotReady",
      }
    );
  }

  upsert(view: OrderView) {
    this.store.set(view.orderId, view);
  }
}
```

---

### 5.6 🧩 アプリ層：支払いは即完了、配送表示は2秒遅れで更新！

```ts
// src/application/OrderService.ts
import { Order } from "../domain/Order.js";
import { EventBus } from "./EventBus.js";
import { OrderViewStore } from "../readmodel/OrderViewStore.js";

export class OrderService {
  private orders = new Map<string, Order>();

  constructor(
    private readonly bus: EventBus,
    private readonly views: OrderViewStore,
  ) {}

  createOrder(orderId: string) {
    const order = new Order(orderId);
    this.orders.set(orderId, order);

    // 画面用の初期表示も作っておく
    const v = this.views.get(orderId);
    this.views.upsert(v);
  }

  async payOrder(orderId: string) {
    const order = this.orders.get(orderId);
    if (!order) throw new Error("注文が見つからないよ🧾❌");

    // ✅ 書き込み（ドメイン更新）は“今ここで”終わる
    order.pay(new Date().toISOString());

    // ✅ 画面用ReadModelは “支払いだけ” 先に反映（すぐ見える）
    const before = this.views.get(orderId);
    this.views.upsert({
      ...before,
      paymentStatus: "Paid",
      shippingStatus: "Preparing", // ここがUXの肝！⏳
    });

    // ✅ イベントは後で配る（配送更新は遅れて起きる想定）
    const events = order.pullDomainEvents();
    await this.bus.publish(events);
  }
}
```

---

### 5.7 🚚 ハンドラ：配送表示の更新は“2秒後”に来る（遅れて一致！）

```ts
// src/index.ts
import { EventBus } from "./application/EventBus.js";
import { OrderService } from "./application/OrderService.js";
import { OrderViewStore } from "./readmodel/OrderViewStore.js";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function render(view: { paymentStatus: string; shippingStatus: string }) {
  if (view.paymentStatus === "Paid" && view.shippingStatus !== "Ready") {
    console.log("✅ 支払い完了！ただいま発送準備中だよ…🚚💨（少し待ってね🕰️）");
    return;
  }
  if (view.shippingStatus === "Ready") {
    console.log("🎉 発送準備が整ったよ！まもなく発送されるよ📦✨");
    return;
  }
  console.log("🛒 注文を待ってるよ〜");
}

async function main() {
  const bus = new EventBus();
  const views = new OrderViewStore();
  const app = new OrderService(bus, views);

  // 配送更新ハンドラ（遅れて一致の主役🌊）
  bus.on("OrderPaid", async (e) => {
    console.log("📣 OrderPaid を受け取ったよ！（配送側で処理するね）");
    await sleep(2000); // ← ここが“遅れ”！

    const v = views.get(e.payload.orderId);
    views.upsert({ ...v, shippingStatus: "Ready" });
    console.log("🚚 配送ステータス更新完了！（ReadModelが追いついた✨）");
  });

  const orderId = "ORDER-001";
  app.createOrder(orderId);

  console.log("🖥️ 支払い前の画面：");
  render(views.get(orderId));

  console.log("\n💳 支払い実行！");
  await app.payOrder(orderId);

  console.log("\n🖥️ 支払い直後の画面（配送はまだ…）：");
  render(views.get(orderId));

  console.log("\n🕵️ 3秒後にもう一回見るよ〜（追いつくかな？）");
  await sleep(3000);

  console.log("\n🖥️ 3秒後の画面：");
  render(views.get(orderId));
}

await main();
```

---

### ✅ 期待する動き（これが“肌感覚”！）🌊🕰️

* 支払い直後：
  **「支払い完了！発送準備中…」**（不安にさせない⏳💖）
* 数秒後：
  **「発送準備が整った！」**（ReadModelが追いついた✨）

イベント駆動で「別の処理（プロジェクション/ReadModel更新）」が遅れると、**一定期間は“結果整合性”になる**っていう説明は、イベントソーシングの解説でもよく出てくるよ📚 ([Microsoft Learn][5])

---

## 6) 📝 演習（手を動かすと一気に理解できるよ！）

### 演習1：文言を3つ作ってみよう💬✨

「反映待ち」でも不安にさせない文言を3案作ってみてね🧸
例：

* 「ただいま反映中です⏳」
* 「処理を進めています🚚💨」
* 「数秒で更新されます🕰️」

---

### 演習2：自動更新（ポーリング）をつけてみよう🔄🕵️‍♀️

`shippingStatus === "Ready"` になるまで、
1秒おきに最大5回だけ `views.get()` を確認して、画面を更新してみよう！

ヒント：`for` + `sleep(1000)` + `break` でOK👌✨

---

### 演習3：“強い整合性が必要なもの”を仕分けしよう⚖️

ミニECで、次を「即一致が必要」「遅れて一致でOK」に分類してみよう📌

* 在庫の確保📦
* メール通知📩
* 売上ランキング📈
* 注文確定🧾

---

## 7) 🤖 AI活用（Copilot/Codex向け）プロンプト例✨

### 7.1 UX文言を整える💬

```text
「反映に数秒かかる」状況でユーザーが不安にならない日本語メッセージを、
短いもの3つ、丁寧なもの3つ、カジュアル3つ作って。
前向きで、責任逃れっぽくならないように。
```

### 7.2 “状態設計”を手伝ってもらう🧩

```text
注文の状態遷移（Created → Paid → Shipped…）に、
最終的整合性を前提にした「中間状態」を追加したい。
候補の状態名と、それぞれの意味（いつ入っていつ抜ける）を提案して。
```

### 7.3 実装レビュー（不安ポイント検出）🔍

```text
このコードは最終的整合性がある前提です。
ユーザーが「反映されてない」と感じるポイントを洗い出し、
UX表示（文言/ボタン/自動更新）での改善案を出して。
```

---

## 8) ✅ この章のチェックリスト（合格ライン💮）

* [ ] 「遅れて一致」を一言で説明できる🌊
* [ ] “ズレる期間”に **状態（Processing/Pending）** を用意できる⏳
* [ ] ユーザー向け表示が **断言しすぎてない**（事故りにくい）🫣
* [ ] 「即一致が必要な範囲」と「遅れてOK」を仕分けできる⚖️

---

## 🧁 おまけ：2026っぽいTypeScript小ネタ（超短く）✨

最近はTypeScriptのコンパイラや言語サービスをネイティブ化して高速化する流れが強くて、Visual Studio側でも **TypeScriptのネイティブ版プレビュー** が出てたりするよ🚀（大規模コードほど体験が変わりやすい！） ([Microsoft Developer][6])
※この章の内容（最終的整合性）は、TypeScriptのバージョンが変わっても考え方がそのまま使えるよ🧠✨

[1]: https://en.wikipedia.org/wiki/Eventual_consistency?utm_source=chatgpt.com "Eventual consistency"
[2]: https://www.ibm.com/think/topics/cap-theorem?utm_source=chatgpt.com "What Is the CAP Theorem? | IBM"
[3]: https://martinfowler.com/articles/microservices.html?utm_source=chatgpt.com "Microservices"
[4]: https://learn.microsoft.com/en-us/azure/architecture/patterns/saga?utm_source=chatgpt.com "Saga Design Pattern - Azure Architecture Center"
[5]: https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing?utm_source=chatgpt.com "Event Sourcing pattern - Azure Architecture Center"
[6]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
