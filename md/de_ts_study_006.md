# 第6章 ドメインモデル超入門（Entity/VO）🏠📚

## この章のゴール🎯✨

* 「Entity（エンティティ）🆔」と「Value Object（値オブジェクト）💎」の違いを、ミニECの例で説明できる
* 「イベントが生まれる場所（＝ドメインの中心）🔥」が、どんな“モデル”なのかイメージできる
* 「金額💰」「住所🏠」みたいな“値”を、いい感じに安全に扱えるようになる（＝バグ減る！🙌）

---

## 6.1 まずは“登場人物”をそろえよう🎭🛒

ミニECでよく出てくるのはこんな子たち👇

* 注文（Order）🧾
* 注文ID（OrderId）🆔
* 注文の明細（LineItem）📦
* 金額（Money）💰
* 住所（Address）🏠
* 数量（Quantity）🔢

ここで大事なのは…
**「IDで追いかける存在」**なのか、**「値そのものが大事な存在」**なのか、ってところだよ〜🙂✨

---

## 6.2 Entity と Value Object の違い🆔💎（超重要！）

### Entity（エンティティ）🆔

* **同一性（Identity）がある**

  * たとえば「注文」は、内容が少し変わっても同じ注文だよね？🧾➡️🧾
* つまり、基本は **IDで同一判定**することが多い👍

### Value Object（値オブジェクト）💎

* **同一性はなく、値がすべて**

  * 「1000円」は、どこで出てきても“1000円”だよね💰
* 基本は **値で同一判定（等価）**する👍
* そしてだいたい **不変（immutable）** にするのが気持ちいい✨（勝手に変わらない安心感🫶）

---

## 6.3 “VOにすると嬉しい”の正体💖

VOにすると、何がうれしいの？っていうと👇

* ✅ **バグが減る**（文字列のまま雑に扱わない）
* ✅ **ルール（不変条件）を閉じ込められる**🔒

  * 「金額は0以上」みたいなルールを、VOの中に入れられる
* ✅ **読みやすい**（型で意味が見える）👀✨
* ✅ **イベントにも乗せやすい**📣（必要な値を安全に渡せる）

---

## 6.4 実装してみよう（ミニEC）🧩✨

### フォルダ例🗂️

* `src/domain/order/` … 注文まわり🧾
* `src/domain/shared/` … 共有VO（Moneyなど）💰

---

## 6.5 Value Object：Money 💰（浮動小数の罠を避ける🕳️）

お金は `number` の小数で持つと事故りやすいよ〜😵‍💫
なので、**最小単位（円なら円、ドルならセント）で整数管理**が定番👏

```ts
// src/domain/shared/Money.ts
export class Money {
  private constructor(private readonly yenAmount: number) {
    if (!Number.isInteger(yenAmount)) {
      throw new Error("Moneyは整数（円単位）で持ってね🪙");
    }
    if (yenAmount < 0) {
      throw new Error("Moneyは0以上だよ💰✨");
    }
  }

  static yen(amount: number): Money {
    return new Money(amount);
  }

  get yen(): number {
    return this.yenAmount;
  }

  add(other: Money): Money {
    return new Money(this.yenAmount + other.yenAmount);
  }

  multiply(quantity: number): Money {
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("数量は1以上の整数だよ🔢");
    }
    return new Money(this.yenAmount * quantity);
  }

  equals(other: Money): boolean {
    return this.yenAmount === other.yenAmount;
  }

  toString(): string {
    return `${this.yenAmount.toLocaleString("ja-JP")}円`;
  }

  // イベントpayload用に“素の値”へ変換したいときに便利🧳
  toJSON(): { yen: number } {
    return { yen: this.yenAmount };
  }
}
```

💡ポイント

* **constructorをprivate**にして、`Money.yen()` からしか作れないようにしてるよ🔒
* “変な状態”を入口で弾くのがコツ✅

---

## 6.6 Value Object：Address 🏠（住所は「ひとまとまりの値」）

住所って、`city` とか `postalCode` とかパーツはあるけど…
ドメイン的には **“住所”という1つの値**だよね🏠✨

```ts
// src/domain/shared/Address.ts
export class Address {
  constructor(
    public readonly postalCode: string,
    public readonly prefecture: string,
    public readonly city: string,
    public readonly line1: string,
    public readonly line2?: string
  ) {
    if (!postalCode.match(/^\d{3}-\d{4}$/)) {
      throw new Error("郵便番号は 123-4567 形式だよ📮");
    }
    if (!prefecture || !city || !line1) {
      throw new Error("住所の必須項目が空だよ🏠💦");
    }
  }

  equals(other: Address): boolean {
    return (
      this.postalCode === other.postalCode &&
      this.prefecture === other.prefecture &&
      this.city === other.city &&
      this.line1 === other.line1 &&
      this.line2 === other.line2
    );
  }

  toString(): string {
    return `${this.postalCode} ${this.prefecture}${this.city}${this.line1}${this.line2 ?? ""}`;
  }

  toJSON(): {
    postalCode: string;
    prefecture: string;
    city: string;
    line1: string;
    line2?: string;
  } {
    return {
      postalCode: this.postalCode,
      prefecture: this.prefecture,
      city: this.city,
      line1: this.line1,
      line2: this.line2,
    };
  }
}
```

---

## 6.7 Entity：Order 🧾（IDで追いかける存在）

注文は「同じ注文」として追跡したいから **Entity** だよ〜🆔✨

まず、注文IDも“意味のある値”だから、雑な `string` のままにしないのが気持ちいい🫶
（`OrderId` を VO っぽく扱う感じ✨）

```ts
// src/domain/order/OrderId.ts
export type OrderId = string & { readonly __brand: "OrderId" };

export const OrderId = {
  new(): OrderId {
    // Node/ブラウザの crypto.randomUUID() を使うよ🧬
    return crypto.randomUUID() as OrderId;
  },

  from(value: string): OrderId {
    if (!value || value.length < 10) {
      throw new Error("OrderIdが短すぎるよ🆔💦");
    }
    return value as OrderId;
  },
} as const;
```

次に明細（LineItem）📦
これは「値の組み合わせ」なので VO にしやすいよ👍

```ts
// src/domain/order/LineItem.ts
import { Money } from "../shared/Money";

export class LineItem {
  constructor(
    public readonly productId: string,
    public readonly unitPrice: Money,
    public readonly quantity: number
  ) {
    if (!productId) throw new Error("productIdが空だよ📦");
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("quantityは1以上の整数だよ🔢");
    }
  }

  subtotal(): Money {
    return this.unitPrice.multiply(this.quantity);
  }

  equals(other: LineItem): boolean {
    return (
      this.productId === other.productId &&
      this.unitPrice.equals(other.unitPrice) &&
      this.quantity === other.quantity
    );
  }

  toJSON(): { productId: string; unitPriceYen: number; quantity: number } {
    return {
      productId: this.productId,
      unitPriceYen: this.unitPrice.yen,
      quantity: this.quantity,
    };
  }
}
```

最後に注文本体🧾✨

```ts
// src/domain/order/Order.ts
import { OrderId } from "./OrderId";
import { LineItem } from "./LineItem";
import { Money } from "../shared/Money";

type OrderStatus = "Created" | "Paid" | "Shipped";

export class Order {
  private status: OrderStatus = "Created";
  private readonly items: LineItem[] = [];

  constructor(public readonly id: OrderId) {}

  addItem(item: LineItem): void {
    if (this.status !== "Created") {
      throw new Error("支払い後は明細を追加できないよ💳❌");
    }
    this.items.push(item);
  }

  total(): Money {
    return this.items.reduce((sum, item) => sum.add(item.subtotal()), Money.yen(0));
  }

  pay(): void {
    if (this.status !== "Created") {
      throw new Error("二重支払いはできないよ💳💦");
    }
    if (this.items.length === 0) {
      throw new Error("明細ゼロは支払えないよ🧾💦");
    }
    this.status = "Paid";
    // 🔥イベントは次の章以降で「ここで生む」ようになるよ（今は準備だけ）
  }

  getStatus(): OrderStatus {
    return this.status;
  }

  // Entityの同一判定はだいたいIDでOK🆔✨
  equals(other: Order): boolean {
    return this.id === other.id;
  }

  snapshot(): {
    id: string;
    status: OrderStatus;
    items: ReturnType<LineItem["toJSON"]>[];
    totalYen: number;
  } {
    return {
      id: this.id,
      status: this.status,
      items: this.items.map((x) => x.toJSON()),
      totalYen: this.total().yen,
    };
  }
}
```

---

## 6.8 “Entity/VO”の見分けクイズ🧠💡

次のうち、Entityっぽいのはどれ？ VOっぽいのはどれ？（理由もセットで✨）

1. Order（注文）🧾
2. Money（金額）💰
3. Address（住所）🏠
4. Coupon（クーポン）🎫
5. EmailAddress（メールアドレス）📧
6. User（ユーザー）👤

✅ ヒント

* 「IDで追いかける？」→ Entity 🆔
* 「値が同じなら同じ？」→ VO 💎

---

## 6.9 演習：VOにすると何が嬉しい？📝💖

### 演習1：VO候補を3つ出す🧺✨

ミニECで VO にしたら良さそうなものを3つ書こう👇
例：`Money` / `Address` / `EmailAddress` / `Quantity` / `PhoneNumber` 📞 など

### 演習2：「文字列のまま」の危険を1つ書く⚠️

例：住所が空でも通っちゃう、金額がマイナスでも通っちゃう、など😵‍💫

### 演習3：`Quantity` を VO にしてみよう🔢💎

* ルール：1以上の整数
* メソッド：`add()` と `toNumber()` くらいでOK🙆‍♀️

---

## 6.10 テストで安心しよう🧪✨（ミニ例）

Moneyの挙動が壊れてないかチェック✅

```ts
// src/domain/shared/Money.test.ts
import { describe, it, expect } from "vitest";
import { Money } from "./Money";

describe("Money", () => {
  it("足し算できる💰", () => {
    const a = Money.yen(100);
    const b = Money.yen(250);
    expect(a.add(b).yen).toBe(350);
  });

  it("マイナスは作れない🚫", () => {
    expect(() => Money.yen(-1)).toThrow();
  });
});
```

---

## 6.11 AI活用（この章で便利な使い方）🤖🫶

### ① VO候補を洗い出す🧺

* 「ミニECで Value Object にした方が良い概念を10個、理由つきで出して。金額・住所以外もお願い🙏」

### ② ルールを “チェック条件” に落とす🔒

* 「“数量は1以上の整数”を、TypeScriptのconstructorで守る実装例を3パターン出して🔢✨」

### ③ Entity/VOの境界で迷ったとき🧭

* 「この概念は Entity と Value Object のどっちが良い？ ‘同一性’ の観点で判断して理由を教えて🙂」

---

## 6.12 よくある落とし穴まとめ🕳️💥

* `string` が何でも入っちゃって、意味が消える（IDも住所も全部string…）🫥
* VOが可変で、どこかで勝手に値が変わる😱
* 金額を小数で持って誤差が出る（`0.1 + 0.2`系）🫠
* ルールがあちこちに散らばって、直し忘れる🌀

---

## 参考（2026年の“今”の周辺情報）📌

* TypeScript 5.9 リリース（公式） ([Microsoft for Developers][1])
* TypeScript 5.9 リリースノート（公式） ([TypeScript][2])
* TypeScript “Native Previews” の告知（公式） ([Microsoft for Developers][3])
* TypeScript 7 進捗（2025年12月の公式アップデート） ([Microsoft for Developers][4])
* Vitest 4.0 のアナウンス（公式） ([vitest.dev][5])

[1]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://devblogs.microsoft.com/typescript/announcing-typescript-native-previews/?utm_source=chatgpt.com "Announcing TypeScript Native Previews"
[4]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[5]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
