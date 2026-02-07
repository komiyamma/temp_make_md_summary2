# 第77章：割引計算はどこに置く？🏷️🧠✨

今日は「割引」という、地味に事故りやすい仕様を題材にして、**VO / Entity（集約）/ Domain Service のどこに置くのがキレイ？**を判断できるようになるよ〜！💪💕

---

## 今日のゴール🎯

* 「割引ロジックの置き場所」を**理由つきで**選べるようになる🧠✨
* “DDDっぽいだけ”じゃなくて、**壊れにくい形**で実装できるようになる🏰🔧
* テストも一緒に用意して、変更に強くする🧪🛡️

---

## まず結論：置き場所の判断フローチャート🌳✨

**迷ったらこれ！**👇

* ✅ **「値」そのものの操作（%計算、丸め、上限など）**
  → **VO**（例：DiscountRate、Money）
  ※VOは「値に対する操作」を閉じ込めやすいよ〜💎
  （例：Moneyが「%計算」などを持つのは自然、という話もあるよ）([vaadin.com][1])

* ✅ **「注文（Order）のルール」そのもの（支払い後は割引変更不可、合計の整合性など）**
  → **Entity / Aggregate（Order）**
  ※**不変条件（守るべきルール）**を“城壁”みたいに守る🏯🛡️

* ✅ **「どの割引を適用するか」の判断が、複数の情報にまたがる**
  （会員ランク、キャンペーン、過去の購入履歴、別集約、外部設定…）
  → **Domain Service**（基本：stateless）
  ※「Entity/VOの操作として自然に入らない業務処理」は stateless service を使う、という整理があるよ
  さらに Domain Service は **stateless** で、他の要素に収まらないロジックを担当、という説明もあるよ([vaadin.com][1])

---

## 例題（カフェ注文☕🧾）：割引仕様を3タイプに分けるよ！

割引って、だいたいこの3系統に割れるの👇

1. **計算だけの割引**（例：10%オフ、100円引き、最大300円まで）
2. **注文のルールに絡む割引**（例：支払い後は割引変更不可、割引後合計が0未満は禁止）
3. **適用判定がむずい割引**（例：会員ランク、期間限定、累計購入額、クーポンの併用可否…）

この3つを、DDDの道具でキレイに配置していくよ〜🎀

---

## パターンA：VOに置く（計算の“型安全”担当）💎🧮

### こういう時にVOが勝つ🏆

* 「%計算」「丸め」「上限」「0未満禁止」みたいな**値の計算ルール**
* 他のもの（DBやRepo）に依存しない**純粋計算**
* “割引”自体が、意味ある値（Rate / Amount）として扱える

VOに「値の操作」を入れるのは自然、という説明もあるよ([vaadin.com][1])

### 実装例：Money VO と Discount VO💴✨

```ts
// domain/valueObjects/Money.ts
export class Money {
  private constructor(private readonly yen: number) {
    if (!Number.isInteger(yen)) throw new Error("Money must be integer yen");
    if (yen < 0) throw new Error("Money cannot be negative");
  }

  static ofYen(yen: number): Money {
    return new Money(yen);
  }

  toYen(): number {
    return this.yen;
  }

  add(other: Money): Money {
    return Money.ofYen(this.yen + other.yen);
  }

  sub(other: Money): Money {
    const next = this.yen - other.yen;
    if (next < 0) throw new Error("Money cannot be negative after subtraction");
    return Money.ofYen(next);
  }

  percentOff(rate: DiscountRate): Money {
    // 10%オフ → discount = floor(yen * 0.10)
    const discount = Math.floor(this.yen * rate.toNumber());
    return Money.ofYen(this.yen - discount);
  }
}

// domain/valueObjects/DiscountRate.ts
export class DiscountRate {
  private constructor(private readonly value: number) {
    if (!(value > 0 && value < 1)) throw new Error("rate must be 0 < rate < 1");
  }
  static of(value: number): DiscountRate {
    return new DiscountRate(value);
  }
  toNumber(): number {
    return this.value;
  }
}
```

**ポイント🥰**

* 「金額は必ず整数円」「マイナス禁止」みたいなルールをVOが守る
* Orderが計算を雑にやっても、VO側がガードしてくれる🛡️

---

## パターンB：Entity（Aggregate）に置く（注文の不変条件を守る🏯）

### こういう時にEntity/集約が勝つ🏆

* 割引が **Orderの整合性**そのものに関わる
  例：

  * 支払い済みの注文には割引を適用し直せない🚫
  * 割引の結果、合計が0未満は禁止🙅‍♀️
  * 「割引適用後合計」を常に正しい状態で保持したい✅

### 実装例：Orderが“適用”を支配する☕🧾

```ts
// domain/order/Order.ts
import { Money } from "../valueObjects/Money";
import { DiscountRate } from "../valueObjects/DiscountRate";

type OrderStatus = "Draft" | "Confirmed" | "Paid" | "Fulfilled" | "Cancelled";

export class Order {
  private status: OrderStatus = "Draft";
  private discountRate: DiscountRate | null = null;

  constructor(private readonly lines: { price: Money; qty: number }[]) {
    if (lines.length === 0) throw new Error("Order must have at least one line");
  }

  confirm(): void {
    if (this.status !== "Draft") throw new Error("Only Draft can be confirmed");
    this.status = "Confirmed";
  }

  pay(): void {
    if (this.status !== "Confirmed") throw new Error("Only Confirmed can be paid");
    this.status = "Paid";
  }

  applyDiscount(rate: DiscountRate): void {
    // ✅ 不変条件：支払い後は割引変更不可
    if (this.status === "Paid" || this.status === "Fulfilled") {
      throw new Error("Cannot apply discount after payment");
    }
    this.discountRate = rate;
  }

  totalBeforeDiscount(): Money {
    return this.lines.reduce((sum, line) => {
      const lineTotal = Money.ofYen(line.price.toYen() * line.qty);
      return sum.add(lineTotal);
    }, Money.ofYen(0));
  }

  totalAfterDiscount(): Money {
    const total = this.totalBeforeDiscount();
    return this.discountRate ? total.percentOff(this.discountRate) : total;
  }
}
```

**ポイント🥳**

* 「割引を適用していい状態か？」は、**Order自身が判断**する
* 割引の計算はVO（Money/DiscountRate）が担当しつつ、
  “いつ適用できるか”はEntityが守る（役割分担がキレイ✨）

---

## パターンC：Domain Serviceに置く（“どの割引を選ぶ？”担当）🧙‍♀️🎟️

### こういう時にDomain Serviceが勝つ🏆

* 「割引適用の判断」が**1つのEntity/VOの責務として自然じゃない**
* **複数の情報**にまたがる（会員、期間、キャンペーン、履歴…）
* ルールが増える未来が濃厚（季節、イベント、クーポン併用…）

Domain Serviceは **stateless** で、Entity/VOに自然に入らない業務ロジックを担当する、という整理があるよ

### 実装例：DiscountService（判断だけする）🧠

```ts
// domain/discount/DiscountService.ts
import { DiscountRate } from "../valueObjects/DiscountRate";
import { Order } from "../order/Order";

export type DiscountContext = {
  isStudent: boolean;
  todayIsoDate: string; // "2026-02-07" みたいなやつ
  monthlyTotalYen: number; // 累計購入額（別集約/履歴から来る値）
};

export class DiscountService {
  // stateless（フィールドを持たない）でOK
  decideRate(order: Order, ctx: DiscountContext): DiscountRate | null {
    // 例1：学生なら 10% オフ
    if (ctx.isStudent) return DiscountRate.of(0.10);

    // 例2：月の累計が1万円以上なら 5% オフ
    if (ctx.monthlyTotalYen >= 10_000) return DiscountRate.of(0.05);

    // 例3：合計が2000円以上なら 3% オフ
    if (order.totalBeforeDiscount().toYen() >= 2_000) return DiscountRate.of(0.03);

    return null;
  }
}
```

**ここ大事💡**

* この service は「どの割引にする？」だけ決める
* 「適用していいか？」の最終判断は **Order.applyDiscount** が握る（安全🏯）

---

## ありがちなダメ例（やっちゃダメ〜！😵‍💫⚠️）

### ❌ アプリ層やUIが合計を書き換える

* Orderの整合性が壊れる
* “いつでも割引変更できる”事故が起きる
* テストしづらい＆仕様が散らばる🌀

**対策✅**

* UI/アプリ層：**手順（オーケストレーション）だけ**
* ドメイン：**ルール（不変条件）と判断**を握る

（Domain Service と Application Service を混同しない整理もあるよ）([vaadin.com][1])

---

## テスト（Vitest）で守りを固めよ〜🧪🛡️

```ts
import { describe, it, expect } from "vitest";
import { Money } from "../domain/valueObjects/Money";
import { DiscountRate } from "../domain/valueObjects/DiscountRate";
import { Order } from "../domain/order/Order";
import { DiscountService } from "../domain/discount/DiscountService";

describe("discount placement", () => {
  it("Money percentOff works", () => {
    const total = Money.ofYen(1000);
    const after = total.percentOff(DiscountRate.of(0.10));
    expect(after.toYen()).toBe(900);
  });

  it("Order forbids discount after payment", () => {
    const order = new Order([{ price: Money.ofYen(500), qty: 2 }]); // 1000
    order.confirm();
    order.pay();

    expect(() => order.applyDiscount(DiscountRate.of(0.10))).toThrow();
  });

  it("Domain service decides discount, Order applies it", () => {
    const order = new Order([{ price: Money.ofYen(800), qty: 3 }]); // 2400
    const svc = new DiscountService();

    const rate = svc.decideRate(order, {
      isStudent: false,
      todayIsoDate: "2026-02-07",
      monthlyTotalYen: 0,
    });

    expect(rate?.toNumber()).toBe(0.03);

    order.applyDiscount(rate!);
    expect(order.totalAfterDiscount().toYen()).toBe(2328); // floor(2400*0.03)=72 → 2400-72
  });
});
```

---

## 判断力アップ練習（4問）✍️💖

### Q1：単純に「10%オフ」だけ（上限なし）

* VO / Entity / Domain Service どれ？

### Q2：「支払い後は割引を変えられない」

* VO / Entity / Domain Service どれ？

### Q3：「会員ランク（別集約）× キャンペーン期間（カレンダー）で割引が変わる」

* VO / Entity / Domain Service どれ？

### Q4：「割引後の合計が0未満は禁止」

* VO / Entity / Domain Service どれ？

---

## 解答🎀✅

* **A1：VO**（計算そのもの）💎
* **A2：Entity/集約**（状態と不変条件）🏯
* **A3：Domain Service**（複数情報の判断）🧙‍♀️
* **A4：VO か Entity（両方で守れる）**

  * Moneyがマイナス禁止で守る（VO）🧊
  * Orderが「割引適用の結果を制約」する（Entity）🏯
    → “二重に守る”のはアリだよ（安全側）🛡️✨

---

## AI活用テンプレ（コピペOK）🤖🪄

### 1) 置き場所相談

「次の割引仕様を **VO/Entity/Domain Service** のどこに置くべきか、理由を3つずつ。
仕様：〇〇（ここに仕様）
制約：支払い後は変更不可、併用不可、上限あり…」

### 2) テストケース増やし

「この割引ロジックの **境界値テスト** を10個。
“起きやすい事故”を優先して、期待結果も書いて。」

### 3) 将来の複雑化の見立て

「この割引仕様が半年後に複雑化するとしたら、どう増える？
増えた時に破綻しない設計の“先回りポイント”を提案して。」

---

## まとめ🎉✨

* **VO**：計算・丸め・上限・型安全（値のルール）💎
* **Entity/集約**：状態と不変条件（いつ適用できる？何が禁止？）🏯
* **Domain Service**：複数情報にまたがる“判断”（基本 stateless）🧙‍♀️
* “判断”と“適用”を分けると、設計が一気に壊れにくくなるよ〜🛡️💕

---

## 2026メモ（最新動向ちょい足し）🗓️✨

* TypeScriptは 5.9 のリリースノートが公開されていて、`import defer` など新しいモジュール関連の話題があるよ([TypeScript][2])
* TypeScriptのコンパイラをネイティブ化する「TypeScript 7 native preview」の話も出てる（ビルド高速化系）([Microsoft Developer][3])
* Node.js のリリース/サポート状況は公式ページで追えるよ（Current / LTS）([Node.js][4])
* テストは Vitest 4 の公式アナウンスも出ていて、モダンTS開発での選択肢として強いよ([vitest.dev][5])

---

次の章に進む前に、「じゃあ**“割引が増えたらどうする？”**」って未来を想像できるとめちゃ強いよ〜！🌸🧠
必要なら、この章の内容をベースに「あなたのカフェ注文ドメインで、割引仕様を3つ増やして設計する演習」も作るね🥰💪

[1]: https://vaadin.com/blog/ddd-part-2-tactical-domain-driven-design "DDD Part 2: Tactical Domain-Driven Design | Vaadin"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[5]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
