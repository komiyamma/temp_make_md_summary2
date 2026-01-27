# 第5章 設計の超入門（SoCと境界）🧱✨

## この章のゴール🎯

* 「混ぜない」だけでコードが読みやすく・直しやすくなる感覚をつかむ🙌✨
* UI / 業務（ドメイン）/ DB / 外部API が **別々の“変更理由”** を持つことを説明できるようになる🧠
* “境界（boundary）” をまたぐときに **データの形を整える（変換する）** 入口を作れるようになる🔁📦

---

## 1) まず結論：混ぜると、将来ぜったい詰む😵‍💫💥

小さいうちは、つい 1つの関数に全部書いちゃいがち👇

* ボタンを押したら…（UI）🖱️
* 入力チェックして…（業務ルール）✅
* DB保存して…（永続化）💾
* メールも送って…（外部連携）📩

これを同じ場所に書くと、**ちょっとした変更が連鎖して**「どこを直すのが正解？」って迷子になりやすいの🥲
SoC（関心の分離）は、こういう “ごちゃ混ぜ地獄” を避けるための基本ルールだよ〜🧹✨ ([ウィキペディア][1])

---

## 2) SoC（関心の分離）ってなに？🧠🚪

SoCは超ざっくり言うと、

* **「同じ種類の悩み（関心）ごとに、場所を分けよう」** という考え方だよ✨ ([ウィキペディア][1])

ここでの「関心」って、たとえば👇

* UIの見た目や入出力（表示・フォーム）🪞
* 業務ルール（注文はこうあるべき、みたいな話）📏
* DBやネットワーク（保存・通信の都合）🌐
* 外部サービス連携（メール、決済など）🔌

ポイントはこれ👇
**関心が違う＝変更理由が違う** から、混ぜると変更が辛い🥵

---

## 3) 「変更理由」で分けると超ラクになる🧩✨

「1つのモジュール（クラス/関数）は、1つの理由で変更されるべき」っていう考え方があって、
これが “混ぜない” の強力なヒントになるよ🧭 ([ウィキペディア][2])

たとえば注文処理で👇

* **税率の計算ルールが変わる**（業務）🧾
* **DBの種類が変わる**（インフラ）💾
* **メール文面が変わる**（通知）📩

この3つは “変わる理由” が別々。
だから、**別々の場所に置く** と安全✨

---

## 4) この教材で使う「4つの箱」📦📦📦📦

ミニECを、いったんこの4つに分けるよ〜🧸🛒

| 箱                      | 何をする？            | 例                              |
| ---------------------- | ---------------- | ------------------------------ |
| Presentation（UI）🪟     | 入力を受ける・結果を表示     | CLI/HTTPの受け口、表示用の文字列           |
| Application（アプリ層）🚚    | 処理の順番を組む（ユースケース） | 「注文作成→保存→イベント配る」みたいな流れ         |
| Domain（ドメイン）🏛️        | 業務ルール・状態変更       | Order, Money, ルールチェック、イベント生成の元 |
| Infrastructure（インフラ）🧱 | DB/外部API/メール送信   | Repository実装、APIクライアント         |

「ドメインは、外の都合を知らない」っていう分け方がキレイ✨
UIやDBの事情にドメインが引っ張られると壊れやすいんだ〜😣 ([martinfowler.com][3])

---

## 5) “境界（boundary）” ってなに？🧱🚪

境界は、**箱と箱のあいだのドア** みたいなもの🚪✨

境界をまたぐときに起きがちな事故👇

* UIの入力がそのままドメインに入って、ドメインがUI都合の型に依存しちゃう😵
* DBの行データがそのままドメインになって、ドメインがDB都合に縛られる😵‍💫

だから境界ではこれをやる👇
✅ **形を整える（変換する）** 🔁

* UIの入力DTO → ドメインの型へ
* ドメインの結果 → 表示用DTOへ
* DBレコード → ドメインへ / ドメイン → DBレコードへ

“業務ロジック” と “外部サービスの都合” を分けるのが大事、って話は実務でもめっちゃ強いよ💪 ([martinfowler.com][4])

---

## 6) 例：ごちゃ混ぜコード（つらい例）😇➡️😵

※これは「こうなりがち」例だよ〜💦

```ts
// ❌ UI・業務・DB・通知が全部まざってる例（つらい）
async function placeOrder(reqBody: any) {
  // UI入力チェックっぽい
  if (!reqBody.userId) throw new Error("userId required");

  // 業務ルールっぽい
  if (reqBody.items.length === 0) throw new Error("items required");

  // DB保存っぽい
  const orderId = crypto.randomUUID();
  await db.insert("orders", { id: orderId, userId: reqBody.userId, itemsJson: JSON.stringify(reqBody.items) });

  // 通知っぽい（外部）
  await emailClient.send({
    to: reqBody.email,
    subject: "注文ありがとう！",
    body: `注文ID: ${orderId}`,
  });

  return { orderId };
}
```

この関数、変更理由が多すぎるよね🥲

* フォームの項目が変わったら？
* ルールが増えたら？
* DBが変わったら？
* メールが変わったら？
  全部ここが壊れる可能性…😱

---

## 7) 例：分けたコード（ラクになる例）✨🧩

「アプリ層が流れを組む」「ドメインはルールと状態」「外は差し替え」って分けるよ🪄

### (1) Domain：注文を作る（ルールと状態）🏛️

```ts
// domain/order.ts
export type OrderId = string;

export type OrderItem = Readonly<{
  productId: string;
  quantity: number;
}>;

export class Order {
  private constructor(
    public readonly id: OrderId,
    public readonly userId: string,
    private readonly items: ReadonlyArray<OrderItem>,
  ) {}

  static place(params: { id: OrderId; userId: string; items: ReadonlyArray<OrderItem> }): Order {
    if (!params.userId) throw new Error("userId is required");
    if (params.items.length === 0) throw new Error("items are required");

    // ここに業務ルールを集めていく💡
    return new Order(params.id, params.userId, params.items);
  }
}
```

### (2) Infrastructure：保存と通知（外部I/O）🧱📩

```ts
// infrastructure/orderRepository.ts
import { Order } from "../domain/order";

export interface OrderRepository {
  save(order: Order): Promise<void>;
}
```

```ts
// infrastructure/notifier.ts
export interface Notifier {
  orderPlaced(input: { userId: string; orderId: string }): Promise<void>;
}
```

### (3) Application：処理の順番を組む（ユースケース）🚚

```ts
// application/placeOrderUseCase.ts
import { Order } from "../domain/order";
import type { OrderRepository } from "../infrastructure/orderRepository";
import type { Notifier } from "../infrastructure/notifier";

export class PlaceOrderUseCase {
  constructor(
    private readonly repo: OrderRepository,
    private readonly notifier: Notifier,
  ) {}

  async execute(input: { userId: string; items: { productId: string; quantity: number }[] }) {
    const orderId = crypto.randomUUID();

    const order = Order.place({
      id: orderId,
      userId: input.userId,
      items: input.items,
    });

    await this.repo.save(order);
    await this.notifier.orderPlaced({ userId: input.userId, orderId });

    return { orderId };
  }
}
```

この分け方だと👇

* ルール変更 → domain を中心に直す🧠
* DB変更 → repository実装を差し替える💾
* 通知変更 → notifier実装を差し替える📩
  って感じで「変更が局所化」するよ✨ ([ウィキペディア][1])

---

## 8) “境界で変換する” をちゃんとやる（超重要）🔁🧾

ここが設計の気持ちいいポイント〜！✨
UIから来る入力は、だいたい “ゆるい” ので、**境界で整える**💄

### UI入力DTO → アプリ入力へ（例）🪟➡️🚚

```ts
// presentation/placeOrderRoute.ts（例：HTTPのつもり）
import { z } from "zod";
import { PlaceOrderUseCase } from "../application/placeOrderUseCase";

const schema = z.object({
  userId: z.string().min(1),
  items: z.array(z.object({
    productId: z.string().min(1),
    quantity: z.number().int().positive(),
  })).min(1),
});

export async function handler(reqBody: unknown, useCase: PlaceOrderUseCase) {
  // ✅ 境界で整える（ここから内側は信じていい）
  const input = schema.parse(reqBody);

  const result = await useCase.execute(input);
  return { status: 200, body: result };
}
```

「境界でチェックして整える」→ 内側（アプリ/ドメイン）はシンプルになって最高🥳

---

## 9) 演習①：ミニECの“関心”を3つに分けよう📝✨

次の3つに分けて、箇条書きしてみてね👇（5分）⏱️

* 🏛️ 業務（ドメイン）：注文のルール、状態、計算
* 📩 通知：メール、プッシュ、ログ通知
* 💾 永続化：DB、ファイル、API保存

例（ちょい見本）👇

* 業務：注文は1件以上のアイテムが必要、合計は0円以上…
* 通知：注文完了メール、管理者通知…
* 永続化：ordersテーブルに保存、itemsも保存…

---

## 10) 演習②：“混ざりポイント”探し🔍😵‍💫

今あるコード（なければ想像でもOK）で、次のにおいを探してチェック✅

* [ ] 1つの関数に「保存」「通知」「ルール」が混ざってる
* [ ] DBのカラム名がドメイン型に直接出てきてる
* [ ] UIの入力形式（文字列とか）がドメインまで侵入してる
* [ ] try/catch が何層にも入り組んでる（責務が混ざりがち）

見つけたら、どれが **Domain / Application / Infrastructure / UI** かメモしてね📝✨

---

## 11) 演習③：“境界の変換関数”を1つ作ろう🔁🧩

たとえばこれ👇

* UIの `quantity` が文字列で来ちゃう世界線を想像して…😇
* **境界で number に変換して**、内側へ渡す！

```ts
type PlaceOrderUiInput = {
  userId: string;
  items: { productId: string; quantity: string }[]; // UIは文字列で来がち😇
};

type PlaceOrderAppInput = {
  userId: string;
  items: { productId: string; quantity: number }[];
};

export function toAppInput(ui: PlaceOrderUiInput): PlaceOrderAppInput {
  return {
    userId: ui.userId,
    items: ui.items.map(i => ({
      productId: i.productId,
      quantity: Number(i.quantity),
    })),
  };
}
```

✅ “変換は境界で” ができると、内側がキレイに保てるよ〜✨

---

## 12) AI活用（Copilot / Codex向け）🤖💬✨

AIは「混ぜない設計」の相談相手として超優秀だよ🫶
そのまま貼って使えるプロンプト例👇

### 混ざりを指摘してもらう🔍

* 「この関数の責務（関心）を列挙して、SoCの観点で分割案を3つ出して。分割後のファイル名案もほしい」

### 境界（変換）を作ってもらう🔁

* 「UI入力DTO→アプリ入力の変換関数を作って。型安全にして、変換ミスの扱い方も提案して」

### ドメインに入れていい情報か判定してもらう🧭

* 「この値はドメインに置くべき？それともUI/インフラ都合？理由も添えて」

※注意：業務ルール（何が正しいか）は、AIより “仕様” を優先だよ📌（AIは推測しがち）🙅‍♀️

---

## 13) 章末チェックリスト✅🌟

* [ ] UI / 業務 / DB / 外部API が “別の関心” ってわかった
* [ ] 「変更理由」で分けるとラク、を説明できる ([ウィキペディア][2])
* [ ] 境界でデータを整える（変換する）イメージが持てた
* [ ] アプリ層は「手順」、ドメインは「ルール」、インフラは「外の都合」って言える ([martinfowler.com][3])

---

## ミニまとめ🍬✨

* SoCは「ごちゃ混ぜをやめる」基本ルール🧹 ([ウィキペディア][1])
* 「変更理由」が違うものは、場所を分けると未来が助かる🛟 ([ウィキペディア][2])
* 境界では、データの形を整えて内側を守る🔁🛡️
* この土台ができると、次の章以降のドメインイベント設計がスッと入るよ🌱✨

[1]: https://en.wikipedia.org/wiki/Separation_of_concerns?utm_source=chatgpt.com "Separation of concerns"
[2]: https://en.wikipedia.org/wiki/Single-responsibility_principle?utm_source=chatgpt.com "Single-responsibility principle"
[3]: https://martinfowler.com/eaaDev/SeparatedPresentation.html?utm_source=chatgpt.com "Separated Presentation"
[4]: https://martinfowler.com/articles/refactoring-external-service.html?utm_source=chatgpt.com "Refactoring code that accesses external services"
