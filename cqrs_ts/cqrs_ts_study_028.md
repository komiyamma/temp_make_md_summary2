# 第28章　イベントハンドラ（Readモデルを育てる係）🌱🔧✨

この章はね、**「ドメインイベントが起きた！→ Readモデル（表示用のデータ）をいい感じに育てる！」**っていう役目の人（＝イベントハンドラ）を作る回だよ〜😊📣

---

### ここでできるようになること ✅🎯

* 「イベントハンドラって何の係？」を説明できる🙂
* **Write（更新）と Read（表示）をつなぐ“投影係”**を実装できる🪞✨
* Readモデル更新の処理を **CommandHandler から追い出して**、スッキリ分離できる🧹
* 将来の「非同期投影」「最終的整合性」「冪等性」につながる“型”が身につく🔁🛡️🕒

---

## 1) まず全体像：イベント→ハンドラ→Readモデル 🧩🪞

イメージはこれ👇

* Command（例：注文する、支払う）を実行
* ドメインで「起きた事実」を **イベント** として出す（OrderPlaced / OrderPaid）
* **イベントハンドラ** がそれを受けて
* Readモデル（一覧・集計など）を更新する

ざっくり図にすると…✨

```text
[CommandHandler] 
   └─(ドメイン更新 & 永続化) 
        └─ publish(Event) 📣
               ├─ [EventHandler A] → Readモデル「注文一覧」を更新 📋
               └─ [EventHandler B] → Readモデル「売上集計」を更新 📊
```

ポイントはここ👇😊

* **ビジネスルール（不変条件・状態遷移）はドメインに置く**
* **表示の都合（一覧・集計・並び替え）はReadモデルに寄せる**
* その橋渡しが **イベントハンドラ** 🌉✨

---

## 2) “Readモデルを育てる”ってどういう意味？🪴🙂

Readモデルは「画面が欲しい形」に合わせたデータだよね📱💻
例えば学食アプリなら：

* 注文一覧：`orderId / 注文者 / 合計 / ステータス / 注文時刻`
* 売上集計：`日別売上 / メニュー別TOP / 支払い済み件数`

これ、Writeモデル（ドメイン）そのままだと作りにくい…😵‍💫
だから **イベントが来たら、Readモデル側を“育てる（更新する）”** のが気持ちいいの✨

---

## 3) 2026時点の “TS実行まわり” 小ネタ 🤖✨（さらっと）

最近の流れとして、Node.js は **TypeScriptを（型を剥がす方式で）直接実行**する方向に寄ってきてるよ〜🧡
公式ドキュメントでも `--experimental-strip-types` での実行が案内されてるよ。 ([Node.js][1])

Node.js のサポート状況も、**v24がActive LTS、v25がCurrent** みたいな感じで進んでる（2026-01時点の一覧）。 ([Node.js][2])

TypeScriptは GitHubのReleases上だと **5.9.3 が最新安定版扱い**になってる（少なくともReleasesの表示上は “Latest”）。 ([GitHub][3])
そして Microsoft は TypeScript 6/7 の大きい話（移行・再実装）も公開してるよ。 ([Microsoft for Developers][4])

※この章の内容（イベントハンドラ/投影）は、実行手段が `tsx` でも `node --experimental-strip-types` でも、ぜんぜん同じ考え方でいけるよ🙂✨

---

## 4) 今回のゴール：2つのReadモデルを育てる🌱📋📊

第27章で作った（想定の）イベント：

* `OrderPlaced`（注文が作成された）
* `OrderPaid`（支払いが完了した）

これを受けて、Read側をこう更新するよ👇

* **注文一覧（OrderList）**：新規追加＆ステータス更新
* **売上集計（SalesSummary）**：日別売上に加算、件数カウント

---

## 5) ハンズオン：イベントハンドラを作ろう！🛠️✨

ここからコードいくよ〜！😆💪
（フォルダ名は例。あなたの構成に合わせてOKだよ🙂）

---

### Step 1：イベントの「共通フォーマット」を決める📦✨

イベントって、最低限こういう情報があると強いよ👇

* eventId（重複対策にも使える）
* type（イベント種別）
* occurredAt（いつ起きた？）
* payload（中身）

```ts
// src/domain/events/event.ts
export type EventBase<TType extends string, TPayload> = {
  eventId: string;
  type: TType;
  occurredAt: string; // ISO文字列にしとくと扱いやすいよ🕒
  payload: TPayload;
  version: number; // 将来の拡張用に入れとくと安心🧩
};

export type OrderPlaced = EventBase<
  "OrderPlaced",
  {
    orderId: string;
    userName: string;
    totalYen: number;
    placedAt: string;
  }
>;

export type OrderPaid = EventBase<
  "OrderPaid",
  {
    orderId: string;
    paidAt: string;
  }
>;

export type DomainEvent = OrderPlaced | OrderPaid;
```

> `version` は「イベントの形が変わったとき」に助かるお守り🧿✨（今は使わなくてもOK）

---

### Step 2：イベントバス（publish/subscribe）を超シンプルに作る📨✨

まずは学習用に **インプロセス（同一アプリ内）** でOK🙂
（第26章で見た“非同期”は、仕組みを差し替えるだけで発展できるよ）

```ts
// src/application/eventBus.ts
import type { DomainEvent } from "../domain/events/event";

export type EventHandler<T extends DomainEvent> = {
  type: T["type"];
  handle: (event: T) => Promise<void> | void;
};

export interface EventBus {
  publish(event: DomainEvent): Promise<void>;
  subscribe<T extends DomainEvent>(handler: EventHandler<T>): void;
}

export class InMemoryEventBus implements EventBus {
  private handlers = new Map<string, Array<(event: any) => Promise<void>>>();

  subscribe<T extends DomainEvent>(handler: EventHandler<T>): void {
    const list = this.handlers.get(handler.type) ?? [];
    list.push(async (e) => handler.handle(e));
    this.handlers.set(handler.type, list);
  }

  async publish(event: DomainEvent): Promise<void> {
    const list = this.handlers.get(event.type) ?? [];
    // 同じイベントに複数ハンドラがぶら下がるのがCQRSの気持ちいいところ🪄
    for (const h of list) {
      await h(event);
    }
  }
}
```

---

### Step 3：Readモデル（注文一覧）を用意する📋✨

Readモデルは「画面に寄せてOK」だったよね🙂
なのでドメインっぽい厳密さより、使いやすさ優先でいくよ〜！

```ts
// src/readModel/orderListReadModel.ts
export type OrderListItem = {
  orderId: string;
  userName: string;
  totalYen: number;
  status: "ORDERED" | "PAID";
  placedAt: string;
  paidAt?: string;
};

export interface OrderListReadRepository {
  upsert(item: OrderListItem): Promise<void>;
  findById(orderId: string): Promise<OrderListItem | undefined>;
  list(): Promise<OrderListItem[]>;
}

export class InMemoryOrderListReadRepository implements OrderListReadRepository {
  private items = new Map<string, OrderListItem>();

  async upsert(item: OrderListItem): Promise<void> {
    this.items.set(item.orderId, item);
  }

  async findById(orderId: string): Promise<OrderListItem | undefined> {
    return this.items.get(orderId);
  }

  async list(): Promise<OrderListItem[]> {
    return [...this.items.values()].sort((a, b) => b.placedAt.localeCompare(a.placedAt));
  }
}
```

---

### Step 4：Readモデル（売上集計）を用意する📊✨

「日別売上」だけの最小形でいくね🙂

```ts
// src/readModel/salesSummaryReadModel.ts
export type DailySales = {
  day: string;      // "2026-01-24" みたいに日付だけ
  totalYen: number;
  paidCount: number;
};

export interface SalesSummaryReadRepository {
  addPaid(day: string, amountYen: number): Promise<void>;
  getDaily(day: string): Promise<DailySales>;
}

export class InMemorySalesSummaryReadRepository implements SalesSummaryReadRepository {
  private byDay = new Map<string, DailySales>();

  async addPaid(day: string, amountYen: number): Promise<void> {
    const current = this.byDay.get(day) ?? { day, totalYen: 0, paidCount: 0 };
    this.byDay.set(day, {
      day,
      totalYen: current.totalYen + amountYen,
      paidCount: current.paidCount + 1,
    });
  }

  async getDaily(day: string): Promise<DailySales> {
    return this.byDay.get(day) ?? { day, totalYen: 0, paidCount: 0 };
  }
}
```

---

### Step 5：イベントハンドラを実装する🌱🔧✨

ここが主役〜！😆🎉
**「イベントが来たらReadモデルを更新するだけ」**に集中するよ。

#### 5-1) OrderPlaced → 注文一覧に追加📋

```ts
// src/application/eventHandlers/onOrderPlaced.ts
import type { EventHandler } from "../eventBus";
import type { OrderPlaced } from "../../domain/events/event";
import type { OrderListReadRepository } from "../../readModel/orderListReadModel";

export class OnOrderPlaced implements EventHandler<OrderPlaced> {
  readonly type = "OrderPlaced" as const;

  constructor(private orderList: OrderListReadRepository) {}

  async handle(event: OrderPlaced): Promise<void> {
    const { orderId, userName, totalYen, placedAt } = event.payload;

    await this.orderList.upsert({
      orderId,
      userName,
      totalYen,
      status: "ORDERED",
      placedAt,
    });
  }
}
```

#### 5-2) OrderPaid → 注文一覧のステータス更新 + 売上集計更新📋📊

```ts
// src/application/eventHandlers/onOrderPaid.ts
import type { EventHandler } from "../eventBus";
import type { OrderPaid } from "../../domain/events/event";
import type { OrderListReadRepository } from "../../readModel/orderListReadModel";
import type { SalesSummaryReadRepository } from "../../readModel/salesSummaryReadModel";

function toDay(iso: string): string {
  // "2026-01-24T..." → "2026-01-24"
  return iso.slice(0, 10);
}

export class OnOrderPaid implements EventHandler<OrderPaid> {
  readonly type = "OrderPaid" as const;

  constructor(
    private orderList: OrderListReadRepository,
    private sales: SalesSummaryReadRepository
  ) {}

  async handle(event: OrderPaid): Promise<void> {
    const { orderId, paidAt } = event.payload;

    const item = await this.orderList.findById(orderId);
    if (!item) {
      // Readモデルに無い＝投影の順序や遅延があるかも🕒
      // ここで例外にすると詰まりやすいので、まずはログでOK🙂
      console.warn("⚠️ OrderPaid received but order not found in read model:", orderId);
      return;
    }

    // 注文一覧を更新📋
    const updated = { ...item, status: "PAID" as const, paidAt };
    await this.orderList.upsert(updated);

    // 売上集計を更新📊（ここでは「支払い確定」ベース）
    await this.sales.addPaid(toDay(paidAt), item.totalYen);
  }
}
```

ここ、超大事な肌感ポイント👇🙂✨

* `OrderPaid` が来たのに `OrderPlaced` がまだ投影されてない…みたいなことは
  **非同期投影だと普通に起こりえる**（第29章で“ズレ”と仲良くなるよ🕒🙂）
* なので今は「見つからないならログ」くらいでOK（あとで設計を強くする💪）

---

### Step 6：配線（登録）して動かす🚀✨

「イベントバスにハンドラ登録」→「publishしたら勝手にReadが育つ」を確認しよう😊

```ts
// src/main.ts
import { InMemoryEventBus } from "./application/eventBus";
import { InMemoryOrderListReadRepository } from "./readModel/orderListReadModel";
import { InMemorySalesSummaryReadRepository } from "./readModel/salesSummaryReadModel";
import { OnOrderPlaced } from "./application/eventHandlers/onOrderPlaced";
import { OnOrderPaid } from "./application/eventHandlers/onOrderPaid";
import type { OrderPlaced, OrderPaid } from "./domain/events/event";
import { randomUUID } from "node:crypto";

const bus = new InMemoryEventBus();
const orderList = new InMemoryOrderListReadRepository();
const sales = new InMemorySalesSummaryReadRepository();

// ハンドラ登録🌱
bus.subscribe(new OnOrderPlaced(orderList));
bus.subscribe(new OnOrderPaid(orderList, sales));

// ダミーでイベントを発行してみる📣（本来はCommandHandlerから出る）
const orderId = "order-001";

const placed: OrderPlaced = {
  eventId: randomUUID(),
  type: "OrderPlaced",
  occurredAt: new Date().toISOString(),
  version: 1,
  payload: {
    orderId,
    userName: "こみやんま",
    totalYen: 780,
    placedAt: new Date().toISOString(),
  },
};

const paid: OrderPaid = {
  eventId: randomUUID(),
  type: "OrderPaid",
  occurredAt: new Date().toISOString(),
  version: 1,
  payload: {
    orderId,
    paidAt: new Date().toISOString(),
  },
};

await bus.publish(placed);
await bus.publish(paid);

console.log("📋 注文一覧:", await orderList.list());

const day = new Date().toISOString().slice(0, 10);
console.log("📊 今日の売上:", await sales.getDaily(day));
```

---

## 6) ここが“設計のキモ”だよ💡🧠✨

### ✅ イベントハンドラに入れていいもの / ダメなもの🙅‍♀️

**入れていいもの（Readモデル育成の作業）** 🌱

* Readモデルへの upsert / 集計更新
* 表示の整形（並び順、欠損値の埋め、単位変換）
* ログ、メトリクス（観測）📈

**入れちゃダメなもの（ドメインのルール）** 🚫

* 「支払える条件」みたいな業務ルール判断
* 不変条件チェック（数量>0とか）
* 状態遷移の可否（ORDERED→PAID できる？）

それは **ドメインがやる係** だったよね🙂🛡️
ハンドラは **“起きた事実を材料に、表示用データを更新するだけ”** が最強にラク✨

---

## 7) ミニ演習（3つ）📝🎀

### 演習1：OrderCanceled を追加して一覧を更新してみよう🙅‍♀️📋

* イベント `OrderCanceled` を作る
* Readモデルのステータスを `"CANCELED"` にする
* 一覧でキャンセルが見えるようにする

### 演習2：売上集計を「メニュー別TOP3」に拡張してみよう🏆🍙

* `addPaid()` の代わりに、`addPaidItem(menuId, qty, price)` を作る
* 日別 × メニュー別のカウントを持つ

### 演習3：「投影の順序が逆」になるケースをわざと作って観察🕒👀

* `OrderPaid` を先に publish してみる
* ログが出るのを確認
* 「どう補強したらいい？」をメモ（次章が超わかりやすくなる✨）

---

## 8) AI活用🤖✨（この章にめちゃ効くやつ！）

### 🔍 イベントの粒度チェック（細かすぎ問題）

**プロンプト例：**

* 「OrderPlaced / OrderPaid のイベント設計、粒度が細かすぎたり冗長じゃないかレビューして。足りない情報も指摘して🙂」

### 🧹 イベントハンドラ肥大化チェック（“やりすぎ警報”🚨）

**プロンプト例：**

* 「このイベントハンドラの責務が投影以外に広がってないか確認して。ドメインに戻すべき処理があれば教えて！」

### 🧩 Readモデル設計レビュー（画面の言葉になってる？）

**プロンプト例：**

* 「OrderListItem / DailySales が、画面で使いやすい形になってるかレビューして。項目の過不足を指摘して🙂」

---

## 9) まとめ 🎉✨

* **イベントハンドラは“Readモデル育成係”** 🌱
* CommandHandlerからRead更新を追い出すと、CQRSが一気にスッキリする🧹✨
* 非同期投影では「順序の逆転・遅延」が普通に起こるので、まずはログ＆設計の余白を持つ🙂🕒
* 次章（第29章）で、その“ズレ”と仲良くなる方法（UX含む）に進むよ〜🔄✨

---

もしよければ、この第28章の続きとして「**CommandHandlerからイベントを出す位置（永続化→publish）をどうするか**」も、学食アプリのコードに合わせて“いい感じの最小形”を追加で書けるよ😊📣

[1]: https://nodejs.org/en/learn/typescript/run-natively?utm_source=chatgpt.com "Running TypeScript Natively"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[4]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
