# 第37章　ADR＋卒業制作（完成条件3つでゴール！）🎉🏁

今日はラスト！✨
「動くCQRS」を完成させつつ、**“なぜそう作ったか”をADRで残して**、自分の型にしちゃおう〜！📝🤖

---

## 0. 今日のゴール（この3つが揃えば卒業🎓✨）✅

### 完成条件✅

1. **Command 2本**：注文する / 支払う 🍙💳
2. **Query 2本**：一覧 / 集計 📋📊
3. **投影 1本**：同期（or 非同期）どっちか1つ 🪞⚡️/⏳

### さらに今日の“本命”💎

* **ADRを最低3本**残す（短文でOK！）📝
  ADRは「重要な決定を、背景・選択肢・理由・結果つきで残す短いメモ」だよ✍️✨ ([technology.blog.gov.uk][1])

---

## 1. ADRってなに？（超ざっくり）📝✨

ADR（Architecture Decision Record）は、**アーキテクチャ上の重要な決定**を、あとから見返せるように残す“決定メモ”だよ📌

* 何を決めた？
* なんでそうした？
* 他にどんな案があった？
* その結果どうなる？（良い点/トレードオフ）

短くて読みやすいのが大事で、「承認書」みたいに重くしないのがコツ！🪶 ([technology.blog.gov.uk][1])

---

## 2. ADRの型（MADRがおすすめ）🧩✨

テンプレはいろいろあるけど、初心者は **MADR（Markdown ADR）** が扱いやすいよ〜！
見出しが決まってて、迷子になりにくい🥰 ([adr.github.io][2])

### よく使う見出し（最小）🧠

* **Title**（タイトル）
* **Status**（Accepted / Proposed / Deprecated など）
* **Context**（背景）
* **Decision**（決めたこと）
* **Consequences**（結果：良い点/悪い点）

この5つでまず十分！([ozimmer.ch][3])

---

## 3. ADR運用のコツ（失敗しがちな所だけ先に回避😆）🚧

* **1 ADR = 1つの決定**（欲張ると読み返せない🥺） ([テックターゲット][4])
* **決めた直後に書く**（1週間後はだいたい忘れる😇） ([technology.blog.gov.uk][1])
* **短くてOK**（3〜10分で書ける量が正義） ([technology.blog.gov.uk][1])
* **後から “Deprecated” にしていい**（変化を怖がらない🫶） ([Amazon Web Services, Inc.][5])
* **PR/Issueに紐づける**（あとで追える） ([DEV Community][6])

---

## 4. VS CodeでADRをラクにする道具（最新寄り）🧰✨

「手でファイル作るのダルい…😵‍💫」ってなったら、これ便利！

* **ADR Utilities（VS Code拡張）**：作成/管理をまとめて支援してくれる系（比較的新しめ） ([Visual Studio Marketplace][7])
* **ADR Manager（VS Code拡張）**：MADRベースで管理しやすい ([Visual Studio Marketplace][8])
* **ADR tools（VS Code拡張）**：コマンドで雛形を作るタイプ（git必要） ([Visual Studio Marketplace][9])
* **madr-kit（CLI）**：MADRを初期化したり、対話的にADRを作れたり、目次生成したり（2025末〜話題） ([Zenn][10])

---

## 5. 卒業制作の進め方（迷子防止ロードマップ🧭✨）

### ステップA：まず“完成形の配線図”を作る（5分）🧠🪄

最低限こうなってればOK：

* Command側

  * `PlaceOrder`（注文）
  * `PayOrder`（支払い）
* Query側

  * `GetOrderList`（注文一覧）
  * `GetSalesSummary`（売上集計）
* 投影（Projection）

  * `OrderPlaced` / `OrderPaid` を受けて、Readモデルを更新

ここで大事なのは **「WriteはWriteの都合」「Readは画面の都合」** を分けることだよ📦✨

---

### ステップB：投影をどっちにする？（同期/非同期）🪞⚡️⏳

**卒業制作は同期投影がラク**（まず動く！）おすすめ👍

* ✅ 実装がシンプル
* ✅ デバッグしやすい
* ❗ Write処理が少し重くなる可能性

非同期投影は“それっぽさ”MAXだけど、仕組みが増える😂

* ✅ Writeが軽い
* ✅ スケールしやすい
* ❗ 遅延・リトライ・重複（冪等性）など考えること増える

「再投影でReadモデルを安全に作り直す」みたいな話も、実運用では超大事になるよ〜🧯🔁 ([Event-Driven][11])

---

## 6. “動く最小実装”サンプル（同期投影版）🧪✨

> 目的：**卒業条件を満たす最小**を、スッと作る💨
> 仕組み：Command → Domain → Event → Projection → ReadModel → Query

（読みやすさ優先で、ファイル分割はコメントで表現するね！）

```ts
// ------------------------------
// src/domain/order.ts
// ------------------------------
export type OrderId = string;
export type MenuId = string;

export type OrderStatus = "ORDERED" | "PAID";

export type OrderItem = {
  menuId: MenuId;
  qty: number;
  unitPrice: number; // 小数を避けたい本気案件は別途（ここは学習用）
};

export type OrderPlaced = {
  type: "OrderPlaced";
  orderId: OrderId;
  items: OrderItem[];
  total: number;
  occurredAt: string;
};

export type OrderPaid = {
  type: "OrderPaid";
  orderId: OrderId;
  paidAt: string;
  occurredAt: string;
};

export type DomainEvent = OrderPlaced | OrderPaid;

export class Order {
  private _status: OrderStatus = "ORDERED";

  private constructor(
    public readonly id: OrderId,
    private _items: OrderItem[],
    private _total: number,
  ) {}

  static place(id: OrderId, items: OrderItem[]): { order: Order; event: OrderPlaced } {
    // 不変条件（超ミニ版）
    if (items.length === 0) throw new Error("items must not be empty");
    for (const it of items) {
      if (!it.menuId) throw new Error("menuId required");
      if (it.qty <= 0) throw new Error("qty must be > 0");
      if (it.unitPrice < 0) throw new Error("unitPrice must be >= 0");
    }
    const total = items.reduce((sum, it) => sum + it.qty * it.unitPrice, 0);
    if (total < 0) throw new Error("total must be >= 0");

    const order = new Order(id, items, total);
    const event: OrderPlaced = {
      type: "OrderPlaced",
      orderId: id,
      items,
      total,
      occurredAt: new Date().toISOString(),
    };
    return { order, event };
  }

  pay(paidAtIso: string): OrderPaid {
    if (this._status !== "ORDERED") throw new Error("Order is not payable");
    this._status = "PAID";
    return {
      type: "OrderPaid",
      orderId: this.id,
      paidAt: paidAtIso,
      occurredAt: new Date().toISOString(),
    };
  }

  get status(): OrderStatus { return this._status; }
  get total(): number { return this._total; }
  get items(): OrderItem[] { return [...this._items]; }
}

// ------------------------------
// src/infrastructure/eventBus.ts
// ------------------------------
export interface EventBus {
  publish(event: DomainEvent): void;
  subscribe(handler: (event: DomainEvent) => void): void;
}

export class InMemoryEventBus implements EventBus {
  private handlers: Array<(event: DomainEvent) => void> = [];
  publish(event: DomainEvent): void {
    for (const h of this.handlers) h(event);
  }
  subscribe(handler: (event: DomainEvent) => void): void {
    this.handlers.push(handler);
  }
}

// ------------------------------
// src/infrastructure/repositories.ts
// ------------------------------
export interface OrderWriteRepo {
  save(order: Order): void;
  findById(id: OrderId): Order | undefined;
}

export class InMemoryOrderWriteRepo implements OrderWriteRepo {
  private map = new Map<OrderId, Order>();
  save(order: Order): void { this.map.set(order.id, order); }
  findById(id: OrderId): Order | undefined { return this.map.get(id); }
}

// Readモデル（画面用に持つ形）
export type OrderListRow = {
  orderId: OrderId;
  status: OrderStatus;
  total: number;
  orderedAt: string;
  paidAt?: string;
};

export type SalesSummary = {
  totalOrders: number;
  totalSales: number;
  paidOrders: number;
};

export interface OrderListReadRepo {
  upsert(row: OrderListRow): void;
  list(): OrderListRow[];
  markPaid(orderId: OrderId, paidAt: string): void;
}

export class InMemoryOrderListReadRepo implements OrderListReadRepo {
  private map = new Map<OrderId, OrderListRow>();
  upsert(row: OrderListRow): void { this.map.set(row.orderId, row); }
  markPaid(orderId: OrderId, paidAt: string): void {
    const row = this.map.get(orderId);
    if (!row) return;
    this.map.set(orderId, { ...row, status: "PAID", paidAt });
  }
  list(): OrderListRow[] { return [...this.map.values()]; }
}

export interface SalesSummaryReadRepo {
  applyPlaced(total: number): void;
  applyPaid(total: number): void;
  get(): SalesSummary;
}

export class InMemorySalesSummaryReadRepo implements SalesSummaryReadRepo {
  private totalOrders = 0;
  private totalSales = 0;
  private paidOrders = 0;

  applyPlaced(total: number): void {
    this.totalOrders += 1;
    // 「注文総額」は注文時点で足す派（要件次第で変わる！）
    this.totalSales += total;
  }
  applyPaid(_total: number): void {
    this.paidOrders += 1;
  }
  get(): SalesSummary {
    return {
      totalOrders: this.totalOrders,
      totalSales: this.totalSales,
      paidOrders: this.paidOrders,
    };
  }
}

// ------------------------------
// src/projections/syncProjection.ts
// ------------------------------
export class SyncProjection {
  constructor(
    private orderList: OrderListReadRepo,
    private summary: SalesSummaryReadRepo,
  ) {}

  handle(event: DomainEvent): void {
    if (event.type === "OrderPlaced") {
      this.orderList.upsert({
        orderId: event.orderId,
        status: "ORDERED",
        total: event.total,
        orderedAt: event.occurredAt,
      });
      this.summary.applyPlaced(event.total);
      return;
    }
    if (event.type === "OrderPaid") {
      this.orderList.markPaid(event.orderId, event.paidAt);
      // ここでは「支払い済み件数」を増やすだけ
      this.summary.applyPaid(0);
      return;
    }
  }
}

// ------------------------------
// src/commands/placeOrder.ts
// ------------------------------
export type PlaceOrderCommand = {
  orderId: OrderId;
  items: OrderItem[];
};

export class PlaceOrderHandler {
  constructor(
    private writeRepo: OrderWriteRepo,
    private bus: EventBus,
  ) {}

  execute(cmd: PlaceOrderCommand): void {
    const { order, event } = Order.place(cmd.orderId, cmd.items);
    this.writeRepo.save(order);
    this.bus.publish(event); // 同期投影ならこの直後にReadが育つ🌱
  }
}

// ------------------------------
// src/commands/payOrder.ts
// ------------------------------
export type PayOrderCommand = {
  orderId: OrderId;
  paidAt: string;
};

export class PayOrderHandler {
  constructor(
    private writeRepo: OrderWriteRepo,
    private bus: EventBus,
  ) {}

  execute(cmd: PayOrderCommand): void {
    const order = this.writeRepo.findById(cmd.orderId);
    if (!order) throw new Error("Order not found");

    const event = order.pay(cmd.paidAt);
    this.writeRepo.save(order);
    this.bus.publish(event);
  }
}

// ------------------------------
// src/queries/getOrderList.ts
// ------------------------------
export class GetOrderListQueryService {
  constructor(private readRepo: OrderListReadRepo) {}
  execute(): OrderListRow[] {
    return this.readRepo.list();
  }
}

// ------------------------------
// src/queries/getSalesSummary.ts
// ------------------------------
export class GetSalesSummaryQueryService {
  constructor(private readRepo: SalesSummaryReadRepo) {}
  execute(): SalesSummary {
    return this.readRepo.get();
  }
}

// ------------------------------
// src/app.ts（配線して動作確認）
// ------------------------------
const bus = new InMemoryEventBus();

const writeRepo = new InMemoryOrderWriteRepo();
const orderListRead = new InMemoryOrderListReadRepo();
const summaryRead = new InMemorySalesSummaryReadRepo();

const projector = new SyncProjection(orderListRead, summaryRead);
bus.subscribe((e) => projector.handle(e));

const placeOrder = new PlaceOrderHandler(writeRepo, bus);
const payOrder = new PayOrderHandler(writeRepo, bus);

const getOrderList = new GetOrderListQueryService(orderListRead);
const getSummary = new GetSalesSummaryQueryService(summaryRead);

// 実行してみる✨
placeOrder.execute({
  orderId: "O-001",
  items: [
    { menuId: "M-ONIGIRI", qty: 2, unitPrice: 250 },
    { menuId: "M-TEA", qty: 1, unitPrice: 120 },
  ],
});

console.log("LIST after place:", getOrderList.execute());
console.log("SUMMARY after place:", getSummary.execute());

payOrder.execute({ orderId: "O-001", paidAt: new Date().toISOString() });

console.log("LIST after pay:", getOrderList.execute());
console.log("SUMMARY after pay:", getSummary.execute());
```

これで卒業条件の **Command2本・Query2本・投影1本**ぜんぶ満たすよ🎉✨

---

## 7. “卒業チェックリスト”✅（これを見ながら最終確認しよ〜！）

### Command（更新）✅

* [ ] PlaceOrder が作れて、注文できる🍙
* [ ] PayOrder が作れて、ORDERED→PAID にできる💳
* [ ] 変な入力（qty=0 など）で落とせる🛡️

### Query（参照）✅

* [ ] 一覧が「画面で欲しい形」で返る📋
* [ ] 集計が返る（件数・合計など）📊

### 投影（Projection）✅

* [ ] PlaceOrder の後に Readモデルが更新される🌱
* [ ] PayOrder の後に Readモデルも更新される🔄

### ADR✅

* [ ] ADRが3本ある📝
* [ ] 各ADRが「背景/選択肢/決定/結果」入り✅ ([technology.blog.gov.uk][1])
* [ ] 1 ADR = 1決定になってる✅ ([テックターゲット][4])

---

## 8. そのまま貼れるADRテンプレ（MADR風）📝✨

### ADR 0001：卒業制作で“同期投影”を選ぶ（例）

```md
# 0001 - 卒業制作では同期投影（Inline Projection）を採用する

## Status
Accepted

## Context
卒業制作では、Command→Event→Readモデル更新までの一連の流れを、まず確実に動かして理解したい。
非同期投影（キュー・リトライ・冪等性など）まで入れると仕組みが増えて学習が分断されやすい。

## Decision
Write側でイベントを発行し、同一プロセス内でProjectionを即時実行してReadモデルを更新する（同期投影）。

## Consequences
- ✅ 実装がシンプルで、デバッグしやすい
- ✅ 「CQRS + Projection」の基本形を最短で体験できる
- ❗ Write処理がRead更新分だけ重くなる可能性がある
- ❗ 将来的にスケールさせるなら非同期化の検討が必要
```

同期投影は最短で学べるぶん、将来は非同期も検討しやすいっていう“学習としての正解”があるよ🫶
（実運用の再投影・安全な再構築みたいな話も、次の一歩で効いてくる！）([Event-Driven][11])

---

### ADR 0002：Readモデルは“画面都合のDTO”として別管理にする（例）

```md
# 0002 - Readモデルはドメインを直接返さず、画面都合のDTOとして別管理する

## Status
Accepted

## Context
Queryは「表示が欲しい形」が正義であり、ドメインモデルをそのまま返すと変更に弱くなる。
また、集計や一覧などは参照専用に最適化した形で持った方がわかりやすい。

## Decision
Read側は OrderListRow / SalesSummary のような画面向けDTOを定義し、ReadRepositoryからそれを返す。

## Consequences
- ✅ 画面の要求に合わせやすい（一覧・集計が楽）
- ✅ ドメインの変更がUIに直撃しにくい
- ❗ DTOが増える（ただしRead専用と割り切る）
```

---

### ADR 0003：ADRはMADRで docs/adr に置く（例）

```md
# 0003 - ADRはMADR形式でリポジトリ内（docs/adr）に保存する

## Status
Accepted

## Context
アーキテクチャ決定の理由が後から追えないと、将来の修正で迷う。
短く読みやすいテンプレが欲しい。

## Decision
MADRテンプレートを採用し、docs/adr 配下に連番ファイルとして保存する。

## Consequences
- ✅ 決定の背景・選択肢・理由・結果が揃う
- ✅ Markdownなのでレビューしやすい
- ✅ VS Code拡張やCLIで生成・目次化もできる
- ❗ たまに更新（Deprecatedなど）を忘れがち → 運用でカバー
```

MADRやADRのテンプレ＆ツール類は選択肢が豊富で、VS Code拡張やCLIもあるよ〜！([adr.github.io][2])

---

## 9. AI拡張の使いどころ（“卒業制作で効く”やつだけ🤖✨）

### ADRをAIに手伝わせるプロンプト例📝🤖

* 「この決定をADR（MADR形式）で、Context/Options/Decision/Consequencesつきで下書きして」
* 「代替案を3つ出して、それぞれのデメリットも書いて」
* 「このADR、1つの決定に絞れてる？冗長なところ削って」

### コード面で効く使い方🧰✨

* 「Projectionの責務が太くないかレビューして」
* 「Readモデルの項目、画面都合として過不足ないか見て」
* 「境界で返すエラーを Result 形式にしたい。最小の型を提案して」

---

## 10. （おまけ）次の一歩🚪✨

卒業できたら、次はここが伸びしろだよ〜🎯

* 非同期投影にして **冪等性**・**リトライ**・**Outbox** を入れる📨🔁
* Readモデルを **再投影**で作り直せるようにする🧯🧱 ([Event-Driven][11])
* 興味が出たら Saga / イベントソーシングへ…（ここから先は沼だけど楽しい😆🕳️）

---

## ちょい最新メモ（TypeScriptまわり）🧠✨

本日時点の公開情報だと、TypeScriptは **5.9.x が “Latest” としてリリース表示**されてるよ（GitHub Releases基準）。([GitHub][12])
あと、コンパイラの“ネイティブ化”系の動き（TypeScript 7のプレビュー等）も進んでるので、今後ツール体験がさらに速くなる流れはありそう！🚀([Microsoft Developer][13])

---

もしよければ、あなたの卒業制作に合わせて **ADRの中身（タイトル案・選択肢・トレードオフ）を一緒に“あなた仕様”に整える**のもできるよ🫶✨
（例：「同期投影を選んだ理由」を、あなたのアプリ要件に合わせて一段キレイにする💅）

[1]: https://technology.blog.gov.uk/2025/12/08/the-architecture-decision-record-adr-framework-making-better-technology-decisions-across-the-public-sector/?utm_source=chatgpt.com "The Architecture Decision Record (ADR) Framework"
[2]: https://adr.github.io/madr/?utm_source=chatgpt.com "About MADR"
[3]: https://ozimmer.ch/practices/2022/11/22/MADRTemplatePrimer.html?utm_source=chatgpt.com "The Markdown ADR (MADR) Template Explained and Distilled"
[4]: https://www.techtarget.com/searchapparchitecture/tip/4-best-practices-for-creating-architecture-decision-records?utm_source=chatgpt.com "8 best practices for creating architecture decision records"
[5]: https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/?utm_source=chatgpt.com "Master architecture decision records (ADRs): Best ..."
[6]: https://dev.to/wallacefreitas/architecture-decision-records-adr-documenting-your-projects-decisions-5ac8?utm_source=chatgpt.com "Architecture Decision Records (ADR): Documenting Your ..."
[7]: https://marketplace.visualstudio.com/items?itemName=FredericPouyez.adrutilities&utm_source=chatgpt.com "ADR Utilities"
[8]: https://marketplace.visualstudio.com/items?itemName=StevenChen.vscode-adr-manager&utm_source=chatgpt.com "ADR Manager VS Code Extension"
[9]: https://marketplace.visualstudio.com/items?itemName=vincent-ledu.adr-tools&utm_source=chatgpt.com "adr-tools - Architecture Decision Records tool"
[10]: https://zenn.dev/mahiguch/articles/70cb5b9cf04db1?utm_source=chatgpt.com "madr-kit v0 - MADR を簡単に管理するツール"
[11]: https://event-driven.io/pl?utm_source=chatgpt.com "Event-Driven by Oskar Dudycz"
[12]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[13]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
