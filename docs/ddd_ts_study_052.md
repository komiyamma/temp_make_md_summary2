# 第52章 Aggregate Root：外部の入口は1つ🚪👑

この章はね、「集約（Aggregate）というお城🏯」を**“ちゃんと守れる形”**にする回だよ〜！✨
結論から言うと…

* ✅ **外部（アプリ層やUI）は、集約ルート（Root）だけを触る**
* ✅ 集約の中の子（OrderLineとか）を **外から直接いじらせない**
* ✅ そうすると **不変条件（守るべきルール）** が壊れない🎉

---

## 1) 今日のゴール🎯✨

この章のゴールはこれ！

* 🧠 「なんで入口を1つにするの？」が腹落ちする
* 🏗️ TypeScriptで「外から壊せないOrder集約」を実装できる
* 🧪 テストで「不正操作ができない」ことを確認できる

---

## 2) 入口が1つじゃないと何が起きるの？😱🧨

例：Order（注文）が集約だとして…

* Orderには、明細（OrderLine）がぶら下がってるよね🧾
* ここで、外部がOrderLineを直接いじれると…

### 💥事故のパターン（ありがち）

* 🧾 明細を勝手に追加 → 合計金額の整合が崩れる
* 🚦 支払い済みなのに、明細を勝手に変更 → 仕様違反
* 🔒 「同じ商品は1行にまとめる」ルールを無視して二重行が増える

つまり…
**「集約で守るはずのルール」が、入口が複数あるせいで守れなくなる**の🥲

---

## 3) “やっちゃダメ設計”の例🚫😂

「Orderの中身を外に丸見えで渡しちゃう」パターンね。

```ts
// ❌ ダメな例：外部が lines を直接いじれる
class OrderBad {
  public lines: { menuItemId: string; quantity: number; unitPrice: number }[] = [];
}

// 外部コード
const order = new OrderBad();
order.lines.push({ menuItemId: "coffee", quantity: 1, unitPrice: 500 }); // 勝手に追加できる😱
order.lines[0].quantity = 999; // 勝手に変更できる😱
```

これだと、Orderが「守りたいルール」を持ってても、**横から殴られて終わり**です🫠

---

## 4) Aggregate Rootのコツ🧠🔑（ここが本題！）

### ✅ ルール1：外部に公開する“窓口”はRootだけ🚪👑

* 外から触れるのは `Order` のメソッドだけ
* `OrderLine` は外から生成・変更させない（or させにくくする）

### ✅ ルール2：配列やオブジェクトを“生で返さない”🧤

* `lines` をそのまま返すと、外で `push()` される
* 返すなら **readonly** や **コピー** を返す

### ✅ ルール3：変更は「意図のあるメソッド」でだけ許可🕹️

* `setStatus()` とか `line.quantity = ...` を禁止寄りにして
* `addItem() / changeQuantity() / removeItem() / pay()` みたいにする✨

---

## 5) 実装してみよう：Order集約（Rootが門番する）🏯🛡️

ここでは **Order = Aggregate Root**、**OrderLine = 集約内部の値（VO寄り）** で作るよ🧡
（OrderLineをEntityにする場合でも「外部から直接触らせない」は同じ！）

### 5-1) 下ごしらえ：ドメイン用のエラー🧯

```ts
export class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DomainError";
  }
}
```

### 5-2) 最小VOたち（Quantity / Money）💎

```ts
import { DomainError } from "./DomainError";

export class Quantity {
  private constructor(private readonly value: number) {}

  static of(value: number): Quantity {
    if (!Number.isInteger(value)) throw new DomainError("数量は整数でね🧾");
    if (value <= 0) throw new DomainError("数量は1以上だよ🧾");
    if (value > 99) throw new DomainError("数量が多すぎるよ🧾");
    return new Quantity(value);
  }

  get asNumber(): number {
    return this.value;
  }
}

export class Money {
  private constructor(private readonly yen: number) {}

  static yen(value: number): Money {
    if (!Number.isInteger(value)) throw new DomainError("金額は整数(円)でね💴");
    if (value < 0) throw new DomainError("金額がマイナスはNG💴");
    return new Money(value);
  }

  add(other: Money): Money {
    return Money.yen(this.yen + other.yen);
  }

  multiply(n: number): Money {
    return Money.yen(this.yen * n);
  }

  get asYen(): number {
    return this.yen;
  }
}
```

### 5-3) OrderLine（集約内部の“変更不可パーツ”）🧾🧊

ポイント：**外から quantity を書き換えられない**ようにするよ✨

```ts
import { Money, Quantity } from "./ValueObjects";

export class OrderLine {
  private constructor(
    public readonly menuItemId: string,
    public readonly unitPrice: Money,
    public readonly quantity: Quantity
  ) {}

  static create(menuItemId: string, unitPrice: Money, quantity: Quantity): OrderLine {
    return new OrderLine(menuItemId, unitPrice, quantity);
  }

  withQuantity(quantity: Quantity): OrderLine {
    // ✅ “変更”じゃなくて“新しいのを作る”🧊
    return new OrderLine(this.menuItemId, this.unitPrice, quantity);
  }

  subtotal(): Money {
    return this.unitPrice.multiply(this.quantity.asNumber);
  }
}
```

### 5-4) Order（Aggregate Root）🚪👑

ここが超重要！🌟

* `#lines` は **private**（外から触れない）
* `lines` は **ReadonlyArray** として返す
* 明細変更は **Orderのメソッド経由** だけ

```ts
import { DomainError } from "./DomainError";
import { Money, Quantity } from "./ValueObjects";
import { OrderLine } from "./OrderLine";

type OrderStatus = "draft" | "confirmed" | "paid" | "cancelled";

export class Order {
  readonly id: string;
  #status: OrderStatus;
  #lines: OrderLine[];

  private constructor(id: string) {
    this.id = id;
    this.#status = "draft";
    this.#lines = [];
  }

  static start(id: string): Order {
    return new Order(id);
  }

  // ✅ 外部に公開するのは「読み取り用」だけ
  get status(): OrderStatus {
    return this.#status;
  }

  // ✅ 配列は「readonly」として渡す（pushできない！）
  get lines(): ReadonlyArray<OrderLine> {
    return this.#lines.slice(); // コピーを返すのが安心🧤
  }

  total(): Money {
    return this.#lines.reduce((acc, line) => acc.add(line.subtotal()), Money.yen(0));
  }

  addItem(menuItemId: string, unitPriceYen: number, quantityValue: number): void {
    this.#assertEditable();

    const unitPrice = Money.yen(unitPriceYen);
    const quantity = Quantity.of(quantityValue);

    const idx = this.#lines.findIndex(l => l.menuItemId === menuItemId);

    if (idx >= 0) {
      // ✅ 同じ商品は1行にまとめる（例ルール）
      const current = this.#lines[idx];
      const newQty = Quantity.of(current.quantity.asNumber + quantity.asNumber);
      this.#lines[idx] = current.withQuantity(newQty);
      return;
    }

    this.#lines.push(OrderLine.create(menuItemId, unitPrice, quantity));
  }

  changeQuantity(menuItemId: string, quantityValue: number): void {
    this.#assertEditable();

    const quantity = Quantity.of(quantityValue);
    const idx = this.#lines.findIndex(l => l.menuItemId === menuItemId);
    if (idx < 0) throw new DomainError("その商品は明細にないよ🧾");

    this.#lines[idx] = this.#lines[idx].withQuantity(quantity);
  }

  removeItem(menuItemId: string): void {
    this.#assertEditable();

    const before = this.#lines.length;
    this.#lines = this.#lines.filter(l => l.menuItemId !== menuItemId);
    if (this.#lines.length === before) throw new DomainError("その商品は明細にないよ🧾");
  }

  confirm(): void {
    if (this.#status !== "draft") throw new DomainError("確定できるのは下書きだけだよ🚦");
    if (this.#lines.length === 0) throw new DomainError("明細が空だと確定できないよ🧾");
    this.#status = "confirmed";
  }

  pay(): void {
    if (this.#status !== "confirmed") throw new DomainError("支払いできるのは確定後だけ💳");
    this.#status = "paid";
  }

  cancel(): void {
    if (this.#status === "paid") throw new DomainError("支払い後はキャンセル不可だよ🔒");
    this.#status = "cancelled";
  }

  #assertEditable(): void {
    if (this.#status === "paid") throw new DomainError("支払い後は明細を変更できないよ🔒");
    if (this.#status === "cancelled") throw new DomainError("キャンセル後は触れないよ🧯");
  }
}
```

---

## 6) “入口が1つ”って、実際どこが嬉しいの？🎁✨

### ✅ 不変条件が1箇所で守れる🔒

「支払い後は明細変更不可」みたいなルールを
**Orderの中だけ**で守ればOKになる👍

### ✅ 変更のルールが読みやすい📖

外から見えるのが

* `addItem`
* `changeQuantity`
* `confirm`
* `pay`

みたいな「意図のあるメソッド」だけになるから、
**コードが仕様書っぽく読める**の🧡

### ✅ テストが強くなる🧪

「入口が1つ」＝「テストすべき場所が少ない」🎉

---

## 7) テスト（Vitestで確認する想定）🧪✨

最近のVitestは v4.0 が出ていて、v4.1 はベータが動いてるよ〜！([vitest.dev][1])
（この教材の方針でも、ドメインはサクッと速いテストが相性いい😊）

### 7-1) “支払い後は変更不可”をテストする🔒

```ts
import { describe, it, expect } from "vitest";
import { Order } from "../domain/Order";

describe("Order Aggregate Root", () => {
  it("支払い後は明細変更できない🔒", () => {
    const order = Order.start("order-1");
    order.addItem("coffee", 500, 1);
    order.confirm();
    order.pay();

    expect(() => order.addItem("tea", 400, 1)).toThrow();
    expect(() => order.changeQuantity("coffee", 2)).toThrow();
    expect(() => order.removeItem("coffee")).toThrow();
  });

  it("同じ商品は1行にまとまる🧾", () => {
    const order = Order.start("order-2");
    order.addItem("coffee", 500, 1);
    order.addItem("coffee", 500, 2);

    expect(order.lines.length).toBe(1);
    expect(order.lines[0].quantity.asNumber).toBe(3);
  });
});
```

---

## 8) よくある落とし穴あるある😂⚠️

### 落とし穴1：`get lines()` で生配列を返す🍋

* `return this.#lines;` ← これやると外から壊される💥
* ✅ `slice()` / readonly / DTO化 が安全🧤

### 落とし穴2：OrderLineを外から new できちゃう🍋

* ✅ `constructor` を `private` にして `create()` 経由にするのが強い✨

### 落とし穴3：「Rootなのにsetter祭り」🍋

* `setStatus()` とか `setLines()` があると、結局入口が増える😵‍💫
* ✅ “意図のあるメソッド” だけを公開しよ〜！

---

## 9) ミニ演習🎮✨（手を動かすと一気に身につく！）

### 演習A：割引を入れてみよ🏷️

仕様：

* `applyDiscountPercent(%)` をOrderに追加（0〜30%）
* 支払い後は適用できない🔒
* 合計の整合性が崩れないようにする

ヒント💡

* 「割引後合計」をOrderが計算して返す
* 明細のunitPriceを直接いじるより「計算の結果」を返す方が安全なこと多いよ😊

### 演習B：外からOrderLineを壊せないことを確認👀

* `order.lines.push(...)` を書いてみて（型エラーになるのが理想✨）
* もしpushできたら、`lines` の返し方を見直そう🧤

---

## 10) AIの使い方（この章向け）🤖💞

### 使い方1：公開メソッドの候補を出させる🧠

お願い例👇

* 「Orderが守る不変条件はこれで、外部から触りたい操作はこれ。公開メソッド案を出して、危ないAPIを指摘して」

### 使い方2：“漏れてる入口”を検出させる🔍

お願い例👇

* 「このOrder実装で、外部から集約内部を破壊できる可能性がある箇所を列挙して。特に配列・参照渡し・setterに注目して」

---

## 11) 2026のTypeScript周りの最新メモ🗞️✨

* npmの `typescript` は **Latest が 5.9.3** と表示されてるよ([npm][2])
* そして **TypeScript 6.0 は“橋渡し版”で、TypeScript 7.0（ネイティブ実装）へ繋ぐ**という方針が公式に語られてるよ([Microsoft for Developers][3])
* TypeScript 7のネイティブプレビュー（Go移植）も案内されていて、大規模コードでの高速化が期待されてる✨（公式ブログでも触れられてるよ）([Microsoft Developer][4])

この章の実装（入口を1つにする）は、**TypeScriptのバージョンが進んでもずっと強い設計**だから安心してOK🧡

---

## まとめ🎀✨（超だいじ！）

* 🏯 集約は「ルールを守る城」
* 🚪👑 外部の入口は「Rootだけ」にする
* 🧤 配列・参照を生で渡さない（readonly / copy）
* 🧊 内部パーツは不変に寄せるとさらに安全
* 🧪 テストは「仕様違反が起きない」を守る

---

次の第53章は「集約境界の決め方（不変条件ドリブン）🔒」だよね！
第52章で作った“城の入口”があると、**境界の議論がめちゃやりやすくなる**よ〜！🎉

[1]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[4]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
