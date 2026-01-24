# 第25章　投影（Projection）① 同期投影（まずはこれ）🪞⚡

この章は「**Commandで更新したら、その直後にReadモデルも更新して、すぐに画面が新しい状態になる**」っていう、一番わかりやすい投影から入っていくよ〜😊✨
（2026/01/24時点の情報として、TypeScriptは5.9系が最新安定版として配布されてるよ） ([GitHub][1])

---

### この章のゴール🎯✨

読み終わったら、こんな状態になれたら勝ち！🥳

* ✅ 「投影って何？」を日本語で説明できる🗣️
* ✅ 同期投影の“気持ちよさ”と“怖さ”がわかる⚡😱
* ✅ **注文（Command）→ 一覧（Query）**が、投影でちゃんと繋がる🧵✨
* ✅ 「どこに投影コードを置くのがキレイ？」が判断できるようになる🧠

---

## 1) 投影（Projection）ってなに？🪞✨

**投影＝Writeモデルの出来事を、Readモデルの形に“写す”こと**だよ😊

たとえば注文のWriteモデルって、こんな感じで「正しさのルール」を守るのが本業だよね👇

* 注文は items を持つ🍙🍜
* 合計金額は items から計算される💰
* 状態遷移（ORDERED → PAID）にルールがある💳

でも画面の一覧が欲しいのは、たぶんこんな感じ👇

* 注文ID、合計、状態、作成日時、（できればメニュー名も）📋✨

この「画面が欲しい形」に整えたものが **Readモデル** で、
Writeの出来事をReadに反映するのが **投影** ってわけ！🪞💡

---

## 2) 同期投影ってどういう意味？⚡

**同期投影＝Commandが成功した“その流れの中で”Readモデルも更新しちゃう**方法だよ😊

イメージ👇

```txt
[Command] PlaceOrder
   ↓（Writeを更新）
Write DB / Write Repo
   ↓（すぐ投影する🪞⚡）
Read DB / Read Repo
   ↓
[Query] GetOrderList で最新が取れる✨
```

### 同期投影のいいところ🥰

* 画面がすぐ新しくなる！⚡✨
* 「注文したのに一覧に出ない…」みたいな不安が減る🙂
* 作りやすい（最短でCQRSが気持ちよくなる）🚀

### 同期投影の怖いところ😱（超だいじ）

* **Write更新は成功したのに、Read更新が失敗**するとズレる…（いわゆる二重書き問題）⚠️
* DBが別々だと、1回でまとめて守るのが難しい😵‍💫

この“怖さ”をちゃんと知った上で、まずは同期投影で感覚を掴むのがこの章だよ〜😊✨
（次の第26章で非同期投影に進むと、この怖さへの対策が増えていくよ📨⏳）

---

## 3) 投影コード、どこに置くのが正解？🏠🧠

初心者のうちは、次の順で「キレイさ」を上げていくのがおすすめだよ😊

### ① CommandHandlerの中に直書き（最短）✍️

* すぐ動くけど、Handlerが太りやすい😵

### ② Projector（投影専用クラス）を作る（おすすめ）🪞✨

* Handlerは「流れ」、Projectorは「Read更新」に分離できて気持ちいい💕

### ③ イベント経由（このあと出るやつ）📣

* もっと拡張しやすい（非同期投影と相性◎）
* ただし今章では“やりすぎ”になりがちなので、**まず②でOK！**😊

この章は **②Projector方式** でいくよ〜！🪞✨

---

# 4) ハンズオン：注文作成時に、Read一覧も更新する🧩⚡

ここから手を動かすよ〜！🛠️✨
題材はいつもの「学食モバイル注文」🍙📱

---

## 4-1) 今回作る部品（最小セット）📦

* `PlaceOrderHandler`（Command側）🧾✅
* `OrderWriteRepository`（Write保存）🗄️
* `OrderProjector`（投影）🪞⚡
* `OrderListReadRepository`（Read保存）📋
* `GetOrderListQueryService`（Query側）🔎

---

## 4-2) コード一式（例）🧁✨

> ここでは「理解しやすさ優先」で **in-memory** 実装にするよ😊
> （SQLiteにしたい人向けの“小ネタ”は後半に置くね🪄）

---

### `src/domain/order.ts`（超シンプルなドメイン）📦🙂

```ts
export type OrderStatus = "ORDERED" | "PAID";

export type OrderItem = {
  menuId: string;
  name: string;
  unitPrice: number;
  qty: number;
};

export class Order {
  constructor(
    public readonly id: string,
    private status: OrderStatus,
    private readonly items: OrderItem[],
    private readonly createdAt: Date,
    private paidAt: Date | null
  ) {}

  static place(input: { id: string; items: OrderItem[]; now: Date }): Order {
    if (input.items.length === 0) throw new Error("items is empty 😿");
    if (input.items.some((x) => x.qty <= 0)) throw new Error("qty must be > 0 😿");
    if (input.items.some((x) => x.unitPrice < 0)) throw new Error("unitPrice must be >= 0 😿");

    return new Order(input.id, "ORDERED", input.items, input.now, null);
  }

  pay(now: Date) {
    if (this.status !== "ORDERED") throw new Error("only ORDERED can be paid 🙅‍♀️");
    this.status = "PAID";
    this.paidAt = now;
  }

  getStatus(): OrderStatus {
    return this.status;
  }

  getItems(): OrderItem[] {
    return [...this.items];
  }

  totalPrice(): number {
    return this.items.reduce((sum, x) => sum + x.unitPrice * x.qty, 0);
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }

  getPaidAt(): Date | null {
    return this.paidAt;
  }
}
```

---

### `src/write/orderWriteRepository.ts`（Write側リポジトリ）🗄️✨

```ts
import { Order } from "../domain/order.js";

export interface OrderWriteRepository {
  save(order: Order): Promise<void>;
  findById(id: string): Promise<Order | null>;
}

export class InMemoryOrderWriteRepository implements OrderWriteRepository {
  private store = new Map<string, Order>();

  async save(order: Order): Promise<void> {
    this.store.set(order.id, order);
  }

  async findById(id: string): Promise<Order | null> {
    return this.store.get(id) ?? null;
  }
}
```

---

### `src/read/orderListReadModel.ts`（Readモデル：一覧行）📋✨

ここがポイント！🪞
**ドメイン（Order）をそのまま返さない**で、画面向けに割り切るよ😊

```ts
import { OrderStatus } from "../domain/order.js";

export type OrderListRow = {
  id: string;
  totalPrice: number;
  status: OrderStatus;
  createdAtIso: string;

  // 画面で便利な“おまけ”（ドメインに無理に入れないでOK🙆‍♀️）
  itemSummary: string; // 例: "唐揚げ丼×1, 味噌汁×2"
};
```

---

### `src/read/orderListReadRepository.ts`（Read側リポジトリ）📋🗄️

```ts
import { OrderListRow } from "./orderListReadModel.js";

export interface OrderListReadRepository {
  upsert(row: OrderListRow): Promise<void>;
  listLatest(): Promise<OrderListRow[]>;
  findById(id: string): Promise<OrderListRow | null>;
}

export class InMemoryOrderListReadRepository implements OrderListReadRepository {
  private store = new Map<string, OrderListRow>();

  async upsert(row: OrderListRow): Promise<void> {
    this.store.set(row.id, row);
  }

  async findById(id: string): Promise<OrderListRow | null> {
    return this.store.get(id) ?? null;
  }

  async listLatest(): Promise<OrderListRow[]> {
    return [...this.store.values()].sort((a, b) => b.createdAtIso.localeCompare(a.createdAtIso));
  }
}
```

---

## 4-3) ここが本題：Projector（同期投影）🪞⚡

### `src/projection/orderProjector.ts`

「WriteのOrder」→「ReadのOrderListRow」へ変換して保存する係だよ😊✨
この章の主役！🪞⚡

```ts
import { Order } from "../domain/order.js";
import { OrderListReadRepository } from "../read/orderListReadRepository.js";
import { OrderListRow } from "../read/orderListReadModel.js";

export class OrderProjector {
  constructor(private readonly orderListReadRepo: OrderListReadRepository) {}

  async projectPlaced(order: Order): Promise<void> {
    const row: OrderListRow = {
      id: order.id,
      totalPrice: order.totalPrice(),
      status: order.getStatus(),
      createdAtIso: order.getCreatedAt().toISOString(),
      itemSummary: order
        .getItems()
        .map((x) => `${x.name}×${x.qty}`)
        .join(", "),
    };

    await this.orderListReadRepo.upsert(row);
  }

  async projectPaid(order: Order): Promise<void> {
    // 今回は「一覧のstatusを更新する」だけ（最小）🙂
    const current = await this.orderListReadRepo.findById(order.id);
    if (!current) {
      // 同期投影でも、事故ゼロじゃないので保険を入れるのが実務っぽい🧯
      return;
    }

    await this.orderListReadRepo.upsert({
      ...current,
      status: order.getStatus(),
    });
  }
}
```

---

## 4-4) CommandHandler：Write更新 → すぐ投影🧾⚡

### `src/commands/placeOrderHandler.ts`

ここで **「Writeの保存」→「投影」** を順番にやるよ😊

```ts
import { Order, OrderItem } from "../domain/order.js";
import { OrderWriteRepository } from "../write/orderWriteRepository.js";
import { OrderProjector } from "../projection/orderProjector.js";

export type PlaceOrderCommand = {
  orderId: string;
  items: OrderItem[];
};

export class PlaceOrderHandler {
  constructor(
    private readonly writeRepo: OrderWriteRepository,
    private readonly projector: OrderProjector
  ) {}

  async handle(cmd: PlaceOrderCommand): Promise<void> {
    const now = new Date();

    // 1) ドメイン生成（ルールチェック込み）📦🛡️
    const order = Order.place({ id: cmd.orderId, items: cmd.items, now });

    // 2) Write保存🗄️
    await this.writeRepo.save(order);

    // 3) すぐ投影（同期投影）🪞⚡
    await this.projector.projectPlaced(order);
  }
}
```

---

## 4-5) QueryService：Readモデルを返すだけ🔎🧼

### `src/queries/getOrderListQueryService.ts`

```ts
import { OrderListReadRepository } from "../read/orderListReadRepository.js";
import { OrderListRow } from "../read/orderListReadModel.js";

export class GetOrderListQueryService {
  constructor(private readonly readRepo: OrderListReadRepository) {}

  async execute(): Promise<OrderListRow[]> {
    return await this.readRepo.listLatest();
  }
}
```

---

## 4-6) 動作確認：CommandのあとにQueryしてみる✨

### `src/main.ts`

```ts
import { InMemoryOrderWriteRepository } from "./write/orderWriteRepository.js";
import { InMemoryOrderListReadRepository } from "./read/orderListReadRepository.js";
import { OrderProjector } from "./projection/orderProjector.js";
import { PlaceOrderHandler } from "./commands/placeOrderHandler.js";
import { GetOrderListQueryService } from "./queries/getOrderListQueryService.js";

async function main() {
  const writeRepo = new InMemoryOrderWriteRepository();
  const readRepo = new InMemoryOrderListReadRepository();
  const projector = new OrderProjector(readRepo);

  const placeOrder = new PlaceOrderHandler(writeRepo, projector);
  const getOrderList = new GetOrderListQueryService(readRepo);

  // ✅ Command（更新）
  await placeOrder.handle({
    orderId: "O-001",
    items: [
      { menuId: "M-01", name: "唐揚げ丼", unitPrice: 650, qty: 1 },
      { menuId: "M-99", name: "味噌汁", unitPrice: 120, qty: 2 },
    ],
  });

  // ✅ Query（参照）→ 投影されてるから最新が取れる！
  const list = await getOrderList.execute();
  console.log(list);
}

main().catch(console.error);
```

ここまで動けば、**同期投影の勝ちパターン**できたよ〜！🎉🪞⚡

---

# 5) ミニ演習（超大事）🧠⚠️

### Q1：もし「Write保存は成功」したのに「Read更新が失敗」したら？😱

起きることを3つ、箇条書きしてみて〜📝✨

ヒント👇

* 画面に出ない
* 集計がズレる
* 後から直すのがつらい

---

# 6) よくある落とし穴あるある😵‍💫🕳️（同期投影編）

### 🕳️ あるある1：Handlerが太っていく🍔

投影ロジックをHandlerに直書きすると、更新が増えるほど地獄…😇
✅ 対策：**Projectorに逃がす**（今やったやつ！）🪞✨

### 🕳️ あるある2：Readモデルを“ドメインのコピー”にしちゃう📦➡️📦

Readは画面のための形でOK！
✅ 対策：Read DTOは割り切る（第18章の復習だね🎁🙂）

### 🕳️ あるある3：「二重書き問題」から目をそらす🙈

同期投影はシンプルだけど、**ズレの可能性**はある⚠️
✅ 対策の方向性（次でやる！）

* 非同期投影（第26章）📨⏳
* Outbox（第31章）📮✅
* 再投影（第36章）🔁🧰

---

# 7) AI活用プロンプト例🤖💬（コピペOK）

* 「`OrderProjector` の責務が重すぎないかレビューして。太ってるなら分割案も出して🙏」🪞🍔
* 「Readモデル（`OrderListRow`）の項目が“画面の言葉”になってるか、改善案ちょうだい📋✨」
* 「同期投影で二重書き問題が起きるパターンを、今回のコードを前提に3つ挙げて！対策も！」⚠️🧠
* 「`projectPaid` がReadに存在しない時の扱い、実務ならどうする？選択肢とメリデメ！」🧯🙂

---

# 8) 最新ちょいメモ（2026）🗒️✨

* Node.js は **v24がLTS**として案内されてるよ（2026/01時点）。 ([Node.js][2])
* TypeScript 5.9 では `--module node20` みたいな **安定したNode向けモジュール設定**も用意されてるよ（tsconfigを整える時に便利！） ([TypeScript][3])
* Nodeには `node:sqlite` という **組み込みSQLite** もあるけど、現時点では “Active development（安定化途中）” 扱いだよ（使うなら理解して使う感じ！） ([Node.js][4])

---

## 次章予告📨⏳

次の第26章は、いよいよ **非同期投影**！
「Commandのあとすぐじゃなくて、イベント経由でReadを育てる」感じになって、CQRSが一気に“それっぽく”なるよ〜！📣🌱✨

[1]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://nodejs.org/api/sqlite.html?utm_source=chatgpt.com "SQLite | Node.js v25.4.0 Documentation"
