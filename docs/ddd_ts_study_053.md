# 第53章：集約境界の決め方（不変条件ドリブン）🔒🏯✨

今日は「**集約（Aggregate）の境界って、どうやって決めるの？**」を、**不変条件（絶対守るルール）**から逆算して決める練習をするよ〜！🫶🌸
ここが分かると、DDDが一気に“設計の道具”として使えるようになる✨

---

## 1) まず最重要：集約の境界は「ルールを守るための柵」だよ🧱🐣

DDDの定番リファレンスでは、ざっくりこう言ってるのね👇

* Entity/VOを**集約としてまとめて境界を引く**
* **集約の入口（Root）だけ**外に公開する
* **集約全体の不変条件**を定義して、Rootが守る
* **同じ境界でトランザクション（同時に成功/失敗させる範囲）も決める**
* 境界内は**同期的に整合性を守る**、境界をまたぐ更新は**非同期**で扱うのが基本  ([Domain Language][1])

この章の合言葉はこれっ👇✨
**「境界＝不変条件を“同期で守る”最小の範囲」**🔒⚡

---

## 2) 不変条件ドリブンの決め方：5ステップでいこう〜🧭💕

### Step 1：不変条件をぜんぶ書き出す📝🔒

まずは「絶対に破ってはいけないルール」を箇条書き！

例（カフェ注文☕🧾）

* ✅ 支払い後は明細を変更できない
* ✅ 合計金額は明細の合計と一致する
* ✅ 明細の数量は1以上
* ✅ 注文は明細0件では確定できない

👉 **この“守るべきもの”が境界の候補を決める核**だよ💎

---

### Step 2：「同期で守りたいセット」を探す🔍⚡

不変条件は、だいたい「AとBを同時に更新しないと破れる」形をしてるよね。

たとえば…

* 「支払い後は明細変更不可」って、
  **支払い状態**と**明細操作**が“同じルールセット”にいる感じがする👀✨

---

### Step 3：そのセットを“1つの城（Aggregate）”にまとめる🏯🛡️

同期で守りたいものをまとめて、境界を引く！

* 境界の中：**Rootが直接守る**（同期で整合性を保証）
* 境界の外：**いつか整合する**（非同期・イベント・別ユースケース）

「境界内は同期、境界を越えたら非同期」が基本だよ〜 ([Domain Language][1])

---

### Step 4：Root（入口）を1つに決める🚪👑

外から触れるのは **Rootだけ**。
Root以外を外に触らせると、ルールが破られやすくなる…！🥺💦 ([Domain Language][1])

---

### Step 5：トランザクション/分散と噛み合うか最終確認🧾🌍

その境界が「トランザクションや配置（分散）」の単位として自然か？
もし無理があるなら、**モデルの見直し**を疑うのがDDDっぽい✨ ([Domain Language][1])

---

## 3) 例題：カフェ注文で「集約境界」を決めてみる☕🧾🔒

### 候補になる登場人物たち🧩

* Order（注文）
* OrderLine（明細）
* MenuItem（メニュー商品）
* Payment（支払い）

ここで大事なのは
**「DBのテーブル」や「画面」から決めない**ってこと！
**不変条件から決める**んだよ〜🔒💕

---

### パターンA：Order集約に「注文＋明細＋支払い状態」を入れる（王道）🏯✨

**不変条件**

* 支払い後は明細変更不可 ✅
* 合計は明細の合計 ✅
* 確定条件（明細0件NG） ✅

このへんは全部、Orderが持つ状態で守れるよね！
だから…

✅ **Order（Root）**
　└ OrderLine（VO寄りでOK）
　└ status（Draft/Confirmed/Paid…）
　└ total（いつでも再計算できる or キャッシュ）

この形は「境界内同期」が自然でキレイ🫶

---

### パターンB：Paymentを別集約にする（実務寄り・スケール寄り）🔗💳

もし支払いが外部決済で複雑になったら、Paymentを別にしたくなることがあるよね。

このときの考え方はこう👇

* **OrderはOrderの不変条件を守る**
* 「支払い完了」情報は**別集約/外部から来る**
* 境界をまたぐ整合は **非同期**（イベントや後追い更新）  ([Domain Language][1])

ただし注意！⚠️
「支払い完了と注文Paidを絶対同時に更新しないとダメ」なら、
それは **“同一集約に入れたいサイン”** かも。

---

## 4) 迷ったらこれ！境界決めチェックリスト✅🧠✨

* ✅ この不変条件は **どのオブジェクトが責任を持つべき？**
* ✅ そのルールを守るのに **同時更新が必要なもの**はどれ？
* ✅ それらを **Root 1つ**のメソッドで守れる？
* ✅ Root以外を外に出したくなってない？（危険信号）
* ✅ 境界をまたぐなら「非同期でもOKな性質」？ ([Domain Language][1])

---

## 5) TypeScript実装：不変条件で“境界”を固定する💎🧊

> ちなみに本日時点で、TypeScriptの最新は **5.9.3** が「latest」として配布されてるよ（npm上）🧡 ([npm][2])
> 5.9の変更点も公式アナウンスで追えるよ〜📰✨ ([Microsoft for Developers][3])
> （Microsoftの公式ブログだよ）

### 💡この章の実装方針（境界を守るため）

* Root（Order）だけが状態変更できる🚪👑
* lines配列は外に生で渡さない（改ざん防止）🧤
* 「支払い後は変更不可」をRootでガード🛡️

---

### サンプルコード（最小）☕🧾

```ts
// domain/errors.ts
export class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DomainError";
  }
}
```

```ts
// domain/valueObjects.ts
import { DomainError } from "./errors";

export class Money {
  private constructor(private readonly cents: number) {}

  static ofYen(yen: number): Money {
    if (!Number.isInteger(yen) || yen < 0) throw new DomainError("金額が不正だよ💦");
    return new Money(yen);
  }

  add(other: Money): Money {
    return new Money(this.cents + other.cents);
  }

  multiply(n: number): Money {
    if (!Number.isInteger(n) || n < 0) throw new DomainError("掛け算が不正だよ💦");
    return new Money(this.cents * n);
  }

  toYen(): number {
    return this.cents;
  }
}

export class Quantity {
  private constructor(public readonly value: number) {}

  static of(n: number): Quantity {
    if (!Number.isInteger(n) || n < 1) throw new DomainError("数量は1以上だよ💦");
    return new Quantity(n);
  }
}

export class OrderId {
  private constructor(public readonly value: string) {}
  static of(value: string): OrderId {
    if (!value) throw new DomainError("OrderIdが空だよ💦");
    return new OrderId(value);
  }
}

export class MenuItemId {
  private constructor(public readonly value: string) {}
  static of(value: string): MenuItemId {
    if (!value) throw new DomainError("MenuItemIdが空だよ💦");
    return new MenuItemId(value);
  }
}
```

```ts
// domain/orderLine.ts
import { DomainError } from "./errors";
import { MenuItemId, Money, Quantity } from "./valueObjects";

// VO寄り：同一性より「値」が大事（menuItemId + unitPrice + quantity）
export class OrderLine {
  private constructor(
    public readonly menuItemId: MenuItemId,
    public readonly unitPrice: Money,
    public readonly quantity: Quantity
  ) {}

  static create(menuItemId: MenuItemId, unitPrice: Money, quantity: Quantity): OrderLine {
    return new OrderLine(menuItemId, unitPrice, quantity);
  }

  changeQuantity(quantity: Quantity): OrderLine {
    return new OrderLine(this.menuItemId, this.unitPrice, quantity);
  }

  subtotal(): Money {
    return this.unitPrice.multiply(this.quantity.value);
  }

  sameMenu(menuItemId: MenuItemId): boolean {
    return this.menuItemId.value === menuItemId.value;
  }

  ensureSamePrice(unitPrice: Money): void {
    if (this.unitPrice.toYen() !== unitPrice.toYen()) {
      throw new DomainError("同じ商品なのに価格が違うよ💦（スナップショット方針を確認してね）");
    }
  }
}
```

```ts
// domain/order.ts
import { DomainError } from "./errors";
import { OrderId, MenuItemId, Money, Quantity } from "./valueObjects";
import { OrderLine } from "./orderLine";

export type OrderStatus = "Draft" | "Confirmed" | "Paid" | "Fulfilled" | "Cancelled";

export class Order {
  private status: OrderStatus = "Draft";
  private lines: OrderLine[] = [];
  private paidAt?: Date;

  private constructor(public readonly id: OrderId) {}

  static create(id: OrderId): Order {
    return new Order(id);
  }

  // 外に配列を渡さない（勝手にpushされるの防止）🧤
  getLinesSnapshot(): ReadonlyArray<OrderLine> {
    return [...this.lines];
  }

  getStatus(): OrderStatus {
    return this.status;
  }

  total(): Money {
    return this.lines.reduce((acc, line) => acc.add(line.subtotal()), Money.ofYen(0));
  }

  addLine(menuItemId: MenuItemId, unitPrice: Money, quantity: Quantity): void {
    this.ensureEditable();

    const existing = this.lines.find(l => l.sameMenu(menuItemId));
    if (existing) {
      // 例：同じ商品は「数量を上書き」ルールにしてみる
      existing.ensureSamePrice(unitPrice);
      const newQty = Quantity.of(existing.quantity.value + quantity.value);
      this.lines = this.lines.map(l => (l.sameMenu(menuItemId) ? l.changeQuantity(newQty) : l));
      return;
    }

    this.lines = [...this.lines, OrderLine.create(menuItemId, unitPrice, quantity)];
  }

  changeQuantity(menuItemId: MenuItemId, quantity: Quantity): void {
    this.ensureEditable();

    const exists = this.lines.some(l => l.sameMenu(menuItemId));
    if (!exists) throw new DomainError("その商品、明細にないよ💦");

    this.lines = this.lines.map(l => (l.sameMenu(menuItemId) ? l.changeQuantity(quantity) : l));
  }

  confirm(): void {
    this.ensureEditable();
    if (this.lines.length === 0) throw new DomainError("明細が0件だと確定できないよ💦");
    this.status = "Confirmed";
  }

  markPaid(now: Date): void {
    if (this.status !== "Confirmed") throw new DomainError("確定してない注文は支払い済みにできないよ💦");
    this.status = "Paid";
    this.paidAt = now;
  }

  private ensureEditable(): void {
    if (this.status === "Paid" || this.status === "Fulfilled") {
      throw new DomainError("支払い後（または提供後）は明細を変更できないよ🔒");
    }
    if (this.status === "Cancelled") {
      throw new DomainError("キャンセル後は変更できないよ💦");
    }
  }
}
```

✅ ここでのポイントはね：

* 「支払い後は変更不可」みたいな**集約の不変条件**が、Orderの中だけで完結して守れてること！🔒🏯
* だからこの範囲が **集約境界として自然**って判断できる✨

---

## 6) テスト：境界が正しいとテストが超ラク！🧪💕（例：Vitest）

```ts
import { describe, it, expect } from "vitest";
import { Order } from "../domain/order";
import { MenuItemId, Money, OrderId, Quantity } from "../domain/valueObjects";

describe("Order Aggregate 🔒", () => {
  it("支払い後は明細変更できない", () => {
    const order = Order.create(OrderId.of("o1"));
    order.addLine(MenuItemId.of("coffee"), Money.ofYen(500), Quantity.of(1));
    order.confirm();
    order.markPaid(new Date());

    expect(() =>
      order.addLine(MenuItemId.of("cake"), Money.ofYen(450), Quantity.of(1))
    ).toThrow("支払い後");
  });

  it("合計は明細の合計と一致する", () => {
    const order = Order.create(OrderId.of("o2"));
    order.addLine(MenuItemId.of("coffee"), Money.ofYen(500), Quantity.of(2)); // 1000
    order.addLine(MenuItemId.of("cake"), Money.ofYen(450), Quantity.of(1));   //  450

    expect(order.total().toYen()).toBe(1450);
  });
});
```

---

## 7) AI（壁打ち）プロンプト：境界をレビューしてもらおう🤖💬✨

### 🎯プロンプト1：不変条件を抽出してもらう

```text
以下の仕様から「不変条件（絶対守るルール）」を箇条書きで抽出して。
そのあと、それぞれが「どの状態・どの操作」に関係するかもセットで書いて。

仕様：
- （ここにGiven/When/Thenや文章を貼る）
制約：
- DBや画面は考えず、業務ルールだけを見る
```

### 🎯プロンプト2：集約境界案のメリデメ比較

```text
Order / Payment / MenuItem について、集約境界の案を2つ作って。
各案について「守れる不変条件」「同期が必要な範囲」「非同期に逃がす範囲」
「実装が辛くなるポイント」を表で出して。
```

### 🎯プロンプト3：いまのコードの臭い診断

```text
このOrder集約コードを読んで、
- 集約境界が広すぎる/狭すぎるサイン
- Root以外が外に漏れているサイン
- 不変条件が漏れているサイン
を指摘して。改善案も3つ出して。
```

（AIは“答え”じゃなくて、**観点を増やす相棒**ね🫶✨）
（OpenAIやGitHub系のツールでやるイメージ！）

---

## 8) ミニ演習🎓🌸（この章のゴール確認）

### 演習A：不変条件→境界を1回で決める！

次のルールが増えたとするよ👇

* 「クーポンは注文全体に1枚だけ使える」
* 「クーポン適用後の合計が0円未満にならない」

👉 これ、Order集約の中に入れる？外に出す？
**理由を“不変条件”で説明**してみてね🧠✨

---

### 演習B：境界をまたぐなら“非同期でOK？”を判断！

* 「支払い完了したら、レシートを発行する（別システム）」

👉 これは **同一トランザクションで絶対必要？**
それとも **非同期（イベント）でOK？**
「なぜ？」を一言で！📣✨

---

## 9) 今日のまとめ🎀✨

* 集約境界は **不変条件（守るべきルール）**から決める🔒
* **境界内は同期で整合性を守る**、境界をまたぐ更新は**非同期**が基本 ([Domain Language][1])
* Rootだけを入口にして、不変条件を**1か所に閉じ込める**🏯👑
* もし境界がトランザクション/分散と噛み合わないなら、**モデルの再考**も視野 ([Domain Language][1])

次の第54章（他集約参照：ID参照が基本🔗🪪）に行くと、今日の「境界をまたぐときの作法」がめっちゃ気持ちよく繋がるよ〜！🫶✨

[1]: https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf "Microsoft Word - pdf version of final doc - Mar 2015.docx"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[3]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
