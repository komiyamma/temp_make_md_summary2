# 第67章 提供ユースケース FulfillOrder ☕📦✨

カフェの現実って、だいたいこうだよね👇
「注文は作った！💳支払いも済んだ！…でも☕まだ渡してない！」
この“最後の一手”が **FulfillOrder（提供）** だよ〜！🎀

---

## この章でできるようになること 🎯💖

1. **提供ユースケース**を「アプリ層の手順」として実装できる 🧑‍🍳🧾
2. 「支払い済みじゃないと提供できない」みたいな **不変条件**を、ちゃんと **ドメイン側**に閉じ込められる 🔒✨
3. **テスト**で「提供できる/できない」をガチガチに固められる 🧪💪

---

## ちょい最新メモ 2026 🗞️✨（実装の前に気持ちを揃える）

* **TypeScript の安定最新版は 5.9.3（npm の latest）**だよ 📌([npm][1])
* **TypeScript 6.0**は、GitHubの公式スケジュールだと **2026-02-10 に Beta**、**2026-03-17 に Final**予定（※今日は 2026-02-07）📅([GitHub][2])
* **Node.js は v24 が Active LTS（2026-01-12 更新）**って整理されてるよ 🟩([Node.js][3])
* テストは **Vitest 4 系**が主流で、**4.1 では Test Tags**も入ってきてる（便利！）🏷️([Vitest][4])

この章のコードは **TS 5.9.x 前提で普通にOK**、あとで TS6 が来ても設計の芯は変わらないよ〜😊🫶

---

## まず仕様を固めよう Given When Then ✅🍩

提供（Fulfill）の最小ルールはこんな感じにすると分かりやすいよ👇

### ✅ 正常系

* **Given** 支払い済み（Paid）の注文がある 💳
* **When** FulfillOrder を実行する ☕
* **Then** 注文が提供済み（Fulfilled）になる 📦✨

### ❌ 異常系（これが超大事！）

* 支払い前（Draft / Confirmed）なら提供できない 😵‍💫
* キャンセル済みなら提供できない 🛑
* すでに提供済みなら提供できない（or 冪等にOKにする）🔁

---

## 状態遷移を 1枚で掴む 🚦🧠

「Fulfill はどこからどこへ？」がブレると、実装が事故るよ〜💥
最小の遷移はこう👇

```
Draft ──confirm──▶ Confirmed ──pay──▶ Paid ──fulfill──▶ Fulfilled
   └────────────cancel──────────────▶ Cancelled
Confirmed └────────────cancel────────▶ Cancelled
Paid └────────────────cancel?────────▶（※今回は無しでもOK）
Fulfilled ──（もう変更不可）──▶
```

ここでの主役はこれ👇
**「Paid じゃないと Fulfill できない」**🔒✨

---

## 設計の方針 🧱✨

### ✅ 役割分担（DDDの美味しいところ🍰）

* **アプリ層（Application Service）**：手順を書く（取得→操作→保存）🧾
* **ドメイン層（Order 集約）**：ルールを守る（提供できる条件チェック）🔒
* **インフラ層（Repository 実装）**：保存する（InMemory/DB）💾

「提供できるかどうか」の判断を、アプリ層に書き始めるとすぐ崩れるよ〜⚠️
**判断は Order のメソッドに寄せる**のが勝ち✨👑

---

## 追加するもの一覧 🧺✨

この章で増えるファイル（例）👇

* `domain/order/Order.ts`（もしくは既存に追記）
* `app/fulfillOrder/FulfillOrderService.ts`
* `app/fulfillOrder/dto.ts`
* `test/...`（ドメイン＋アプリのテスト）

---

## 実装していこう〜！☕💨

## 1 提供の入力と出力 DTO を作る 📦💖

「ユースケースの入り口」は、まず DTO を置くのが安定だよ〜！

```ts
// app/fulfillOrder/dto.ts

export type FulfillOrderInputDto = Readonly<{
  orderId: string;
  fulfilledBy: string; // バリスタID的なもの（今は文字列でOK）
}>;

export type FulfillOrderOutputDto = Readonly<{
  orderId: string;
  status: 'FULFILLED';
}>;
```

> 💡 fulfilledAt（提供時刻）も本当は欲しいけど、時間注入（Clock）は後半でやるから、今回は「まず動く最小」に寄せてOK〜！⏰✨

---

## 2 アプリ層の Result 型を用意する（あるならそれを使う）📦🧯

第65章で「異常系とメッセージ」をやってるので、この形が相性いいよ👇

```ts
// app/shared/Result.ts（すでにあるなら不要）

export type Ok<T> = Readonly<{ ok: true; value: T }>;
export type Err<E> = Readonly<{ ok: false; error: E }>;
export type Result<T, E> = Ok<T> | Err<E>;

export const ok = <T>(value: T): Ok<T> => ({ ok: true, value });
export const err = <E>(error: E): Err<E> => ({ ok: false, error });
```

エラーDTOも最小で👇

```ts
// app/shared/AppErrorDto.ts

export type AppErrorDto = Readonly<{
  code:
    | 'ORDER_NOT_FOUND'
    | 'ORDER_NOT_PAYED'
    | 'ORDER_ALREADY_FULFILLED'
    | 'ORDER_CANCELLED';
  userMessage: string;
}>;
```

---

## 3 ドメイン側に Fulfill のルールを閉じ込める 🔒🏯

### 3-1 OrderStatus を想定（既存なら合わせてね）

```ts
// domain/order/OrderStatus.ts（例）

export type OrderStatus =
  | 'DRAFT'
  | 'CONFIRMED'
  | 'PAID'
  | 'FULFILLED'
  | 'CANCELLED';
```

### 3-2 ドメイン例外（既存の流儀があれば寄せてOK）

```ts
// domain/order/OrderErrors.ts

export class OrderNotPayedError extends Error {
  constructor() {
    super('Order is not paid.');
  }
}

export class OrderAlreadyFulfilledError extends Error {
  constructor() {
    super('Order is already fulfilled.');
  }
}

export class OrderCancelledError extends Error {
  constructor() {
    super('Order is cancelled.');
  }
}
```

### 3-3 Order に fulfill メソッドを追加 ☕✨

ポイントはこれ👇
**「status を直接 set させない」**
**「fulfill() だけが状態を変えられる」**💪

```ts
// domain/order/Order.ts（例：一部だけ）

import {
  OrderNotPayedError,
  OrderAlreadyFulfilledError,
  OrderCancelledError,
} from './OrderErrors';
import { OrderStatus } from './OrderStatus';

export class Order {
  private status: OrderStatus;
  private fulfilledBy: string | null;

  private constructor(status: OrderStatus) {
    this.status = status;
    this.fulfilledBy = null;
  }

  // 例：ファクトリ（既存に合わせてね）
  static createDraft(): Order {
    return new Order('DRAFT');
  }

  // 例：状態参照
  getStatus(): OrderStatus {
    return this.status;
  }

  fulfill(by: string): void {
    if (this.status === 'CANCELLED') throw new OrderCancelledError();
    if (this.status === 'FULFILLED') throw new OrderAlreadyFulfilledError();
    if (this.status !== 'PAID') throw new OrderNotPayedError();

    this.status = 'FULFILLED';
    this.fulfilledBy = by;
  }
}
```

> ✅ これで「提供できる条件」が **Order 自身の責務**になったよ〜！えらい！🎉💖

---

## 4 Application Service を作る 🎬☕

FulfillOrder は「更新系」だから、アプリ層の手順はテンプレでOK👇

1. 取得する
2. ドメイン操作する
3. 保存する
4. DTOで返す

```ts
// app/fulfillOrder/FulfillOrderService.ts

import { Result, ok, err } from '../shared/Result';
import { AppErrorDto } from '../shared/AppErrorDto';
import { FulfillOrderInputDto, FulfillOrderOutputDto } from './dto';
import { OrderNotPayedError, OrderAlreadyFulfilledError, OrderCancelledError } from '../../domain/order/OrderErrors';

// domain側にある前提（第71章で整えるけど、今は最小でOK）
export interface OrderRepository {
  findById(orderId: string): Promise<any | null>; // 既存の型に合わせてね
  save(order: any): Promise<void>;
}

export class FulfillOrderService {
  constructor(private readonly orderRepo: OrderRepository) {}

  async execute(
    input: FulfillOrderInputDto
  ): Promise<Result<FulfillOrderOutputDto, AppErrorDto>> {
    const order = await this.orderRepo.findById(input.orderId);

    if (!order) {
      return err({
        code: 'ORDER_NOT_FOUND',
        userMessage: '注文が見つかりませんでした 🥲',
      });
    }

    try {
      order.fulfill(input.fulfilledBy);
    } catch (e: unknown) {
      if (e instanceof OrderNotPayedError) {
        return err({
          code: 'ORDER_NOT_PAYED',
          userMessage: '支払いが完了していない注文は提供できません 💳❗',
        });
      }
      if (e instanceof OrderAlreadyFulfilledError) {
        return err({
          code: 'ORDER_ALREADY_FULFILLED',
          userMessage: 'この注文はすでに提供済みです ☕✅',
        });
      }
      if (e instanceof OrderCancelledError) {
        return err({
          code: 'ORDER_CANCELLED',
          userMessage: 'キャンセル済みの注文は提供できません 🛑',
        });
      }
      throw e; // 想定外は上に投げる（ログは第89章で✨）
    }

    await this.orderRepo.save(order);

    return ok({
      orderId: input.orderId,
      status: 'FULFILLED',
    });
  }
}
```

---

## テストで “提供の硬さ” を作る 🧪🔒✨

## 5 ドメインテストが主役 🏯🧪

Vitest の環境設定などは公式にまとまってるよ（node/jsdom切替とか）🧰([Vitest][5])
ここではシンプルに unit テスト！

```ts
// test/domain/order.fulfill.test.ts
import { describe, it, expect } from 'vitest';
import { Order } from '../../src/domain/order/Order';
import { OrderNotPayedError, OrderAlreadyFulfilledError } from '../../src/domain/order/OrderErrors';

describe('Order.fulfill', () => {
  it('PAID のときだけ FULFILLED にできる ☕✅', () => {
    const order = Order.createDraft();

    // ここは既存の pay() / confirm() に合わせてね（例として直接いじらないのが理想）
    // 今回は説明用に status を作れるファクトリがある体で進めるのもアリ
    // 例：order.confirm(); order.pay();
    // もし無いなら「paid状態の生成」をテスト用Factoryで作るのがオススメ✨

    // 仮：paid状態を作るためのテスト専用ヘルパを使う前提
    // (本番コードにテスト都合の穴を開けないこと！)
  });

  it('支払い前は提供できない 💳❌', () => {
    const order = Order.createDraft();
    expect(() => order.fulfill('barista-1')).toThrow(OrderNotPayedError);
  });

  it('二重提供はできない 🔁❌', () => {
    // 例：paid状態の order を作った体
    const order = Order.createDraft();
    // order.confirm(); order.pay();
    // order.fulfill('barista-1');
    // expect(() => order.fulfill('barista-1')).toThrow(OrderAlreadyFulfilledError);
  });
});
```

> 🥺 ここで「paid状態をどう作る？」が気になったら超いい感覚！
> 理想は **confirm()/pay() のメソッド経由で状態を作る**ことだよ〜（テストが仕様書になる📖✨）

---

## 6 アプリ層テストで “手順の正しさ” を確認 🎬🧪

InMemory Repository を使うと爆速でいけるよ〜🏎️💨

```ts
// test/app/fulfillOrder.service.test.ts
import { describe, it, expect } from 'vitest';
import { FulfillOrderService } from '../../src/app/fulfillOrder/FulfillOrderService';

class InMemoryOrderRepo {
  private store = new Map<string, any>();

  async findById(orderId: string) {
    return this.store.get(orderId) ?? null;
  }

  async save(order: any) {
    this.store.set(order.id ?? 'order-1', order); // 既存のID設計に合わせてね
  }

  seed(orderId: string, order: any) {
    this.store.set(orderId, order);
  }
}

describe('FulfillOrderService', () => {
  it('注文が存在しないときは NOT_FOUND 🥲', async () => {
    const repo = new InMemoryOrderRepo();
    const service = new FulfillOrderService(repo as any);

    const result = await service.execute({ orderId: 'nope', fulfilledBy: 'barista-1' });

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe('ORDER_NOT_FOUND');
  });

  it('支払い済みなら提供できる ☕✅', async () => {
    const repo = new InMemoryOrderRepo();
    const service = new FulfillOrderService(repo as any);

    // paid状態の注文を seed（ここも既存実装に合わせてね）
    // repo.seed('order-1', paidOrder);

    // const result = await service.execute({ orderId: 'order-1', fulfilledBy: 'barista-1' });
    // expect(result.ok).toBe(true);
  });
});
```

---

## AI の使いどころ 🤖💞（この章に最適）

## 便利プロンプト例 ✨📝

### 1️⃣ 状態遷移テーブルを作る

```text
注文の状態が DRAFT/CONFIRMED/PAID/FULFILLED/CANCELLED のとき、
Fulfill（提供）を実行してよい条件と、実行後の状態を表にして。
禁止の場合は理由も1行で。
```

### 2️⃣ テスト観点を増やす

```text
FulfillOrder の異常系テスト観点を10個出して。
「現場で起きがちなミス」っぽい観点を多めにして。
```

### 3️⃣ userMessage をやさしく整える

```text
以下のエラー文を、女子大学生にも分かるやさしい文章にして。絵文字も付けて。
- 支払いが完了していない注文は提供できません
- 注文が見つかりません
- すでに提供済みです
- キャンセル済みです
```

---

## よくある事故ポイント 😂⚠️

## ❌ アプリ層で status 判定して status を書き換える

「if (order.status === 'PAID') order.status = 'FULFILLED'」みたいなやつ！
これやると、どこからでもルール破られる世界になるよ〜😱

✅ **正解**：`order.fulfill()` だけが状態を変える ☕👑

---

## ❌ “提供済み” の判断がUI側だけ

UIでボタン無効化しても、API叩かれたら終わりだよ〜💥
✅ **ドメインで止める**のが本丸！🏯🔒

---

## ちょい背伸び オプション課題 🌱✨

## 🌟 課題A 「準備中」状態を増やしてリアルにする

Paid → Preparing → Fulfilled にすると、現場っぽさUP☕🔥
（ただし状態が増える＝テストも増える！🧪）

## 🌟 課題B “二重提供” を冪等にする

現実はリトライがあるから、
「すでに提供済みなら成功扱い」って設計もあるよ🔁✨
（冪等性は第96章でめちゃくちゃ効く〜！🛡️）

---

## 理解チェック ミニクイズ 🎀🧠

1. Fulfill の「提供できる条件」は、どこに書くのが一番いい？（アプリ層？ドメイン層？）🏯
2. `status` を public にして直接変更できると、何が起きる？😱
3. FulfillOrderService がやるべき “手順” を 4 つで言える？🧾✨

---

## この章のゴール ✅🎉

* `FulfillOrderService.execute()` が書けた ☕📦
* `order.fulfill()` にルールが閉じ込められた 🔒
* 「提供できる/できない」がテストで守られた 🧪💖

---

次の第68章は **GetOrder（読み取り）🔎** だよ〜！
更新系と参照系を分けると、設計がスッ…と美しくなるから楽しみにしててね🥰✨

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://github.com/microsoft/TypeScript/issues/63085?utm_source=chatgpt.com "TypeScript 6.0 Iteration Plan · Issue #63085"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[5]: https://vitest.dev/guide/environment?utm_source=chatgpt.com "Test Environment | Guide"
