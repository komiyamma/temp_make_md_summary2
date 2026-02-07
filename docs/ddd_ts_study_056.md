# 第56章：Order集約を実装①「構造を固める」🏯🛡️✨

この章はね、**Order集約を“安全な城🏯”として成立させるための骨組み作り**だよ〜！😊
（次の第57章で、状態遷移やガード節をガチガチにして“城壁”を完成させる感じ🧱✨）

---

## 0) 今日のゴール🎯💖

この章が終わったら、こうなってるのが理想だよ〜！✨

* Order集約が「入口ひとつ（集約ルート）」になってる🚪👑
* 外部から **明細配列を直接いじれない**（= 城の中に勝手に侵入できない）🙅‍♀️
* 合計金額が **常に明細の合計と一致**する（ズレない）🧾🧮
* どのファイルに何を書くか迷わない（構造が固い）📁✨
* テストで「構造が壊れてない」をサクッと確認できる🧪✅

※本日時点（2026-02-07）の最新安定版 TypeScript は GitHub Releases 上で **v5.9.3** が最新として表示されてるよ📌 ([GitHub][1])
（TypeScript は Beta → RC → final → patch というリリース段階があるのも公式Wikiで確認できるよ🔁 ([GitHub][2])）

---

## 1) 「集約が城🏯」ってどういう意味？🧠✨

### ✅ 集約ルート（Order）は「城の門番👑」

外から触っていいのは **Orderだけ**。

* 外部：`order.addItem(...)` はOK🙆‍♀️
* 外部：`order.lines.push(...)` はNG🙅‍♀️（勝手に城内改造）

### ✅ 集約の中（明細や合計）は「城の中🏰」

中は Order が責任もって整合性を保つ！

* 合計は Order が計算する🧮
* 明細の追加・削除・変更は Order のメソッド経由だけ🕹️

---

## 2) この章で作る“構造”の設計図🗺️✨

イメージはこんな感じ👇

* `Order`（集約ルート👑）

  * `OrderId`（VO💎）
  * `OrderStatus`（状態🚦）
  * `OrderLine[]`（明細🧾）
  * `total()`（合計🧮 = 明細合計の派生）
* `OrderLine`（明細：VO寄り🧾💎）

  * `MenuItemId`（VO💎）
  * `Quantity`（VO💎）
  * `Money`（VO💎）

---

## 3) ファイル構成（この章ぶん）📁✨

例：こんな配置だと迷子になりにくいよ〜😊

* `src/domain/shared/`

  * `Money.ts`
  * `Quantity.ts`
  * `DomainError.ts`
* `src/domain/order/`

  * `OrderId.ts`
  * `MenuItemId.ts`
  * `OrderStatus.ts`
  * `OrderLine.ts`
  * `Order.ts`
* `src/test/domain/order/`

  * `Order.test.ts`

---

## 4) 実装①：shared（小さいVOたち）💎✨

### `DomainError.ts`（ドメインの怒り💢を型にする）

```ts
export class DomainError extends Error {
  override name = "DomainError";
}
```

### `Quantity.ts`（数量：1以上の整数だけ！📏）

```ts
import { DomainError } from "./DomainError";

export class Quantity {
  private constructor(public readonly value: number) {}

  static of(value: number): Quantity {
    if (!Number.isInteger(value)) throw new DomainError("数量は整数でね🙂");
    if (value <= 0) throw new DomainError("数量は1以上だよ🙂");
    return new Quantity(value);
  }

  add(other: Quantity): Quantity {
    return Quantity.of(this.value + other.value);
  }
}
```

### `Money.ts`（お金：float禁止〜！💴🧯）

```ts
import { DomainError } from "./DomainError";

type Currency = "JPY"; // 例題はJPY固定（後で増やしてもOK）

export class Money {
  private constructor(
    private readonly minor: number, // JPYなら「円」をそのまま最小単位として扱う
    public readonly currency: Currency
  ) {}

  static jpy(yen: number): Money {
    if (!Number.isInteger(yen)) throw new DomainError("金額は整数（円）でね🙂");
    return new Money(yen, "JPY");
  }

  get yen(): number {
    return this.minor;
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.minor + other.minor, this.currency);
  }

  multiply(quantity: number): Money {
    if (!Number.isInteger(quantity)) throw new DomainError("掛ける数は整数でね🙂");
    return new Money(this.minor * quantity, this.currency);
  }

  equals(other: Money): boolean {
    return this.currency === other.currency && this.minor === other.minor;
  }

  private assertSameCurrency(other: Money) {
    if (this.currency !== other.currency) {
      throw new DomainError("通貨が違うお金は足せないよ🙂");
    }
  }
}
```

---

## 5) 実装②：Order側のVO（IDたち）🪪💎

### `OrderId.ts`

```ts
import { DomainError } from "../shared/DomainError";

export class OrderId {
  private constructor(public readonly value: string) {}

  static of(value: string): OrderId {
    if (!value || value.trim().length === 0) throw new DomainError("OrderIdが空だよ🙂");
    return new OrderId(value.trim());
  }
}
```

### `MenuItemId.ts`

```ts
import { DomainError } from "../shared/DomainError";

export class MenuItemId {
  private constructor(public readonly value: string) {}

  static of(value: string): MenuItemId {
    if (!value || value.trim().length === 0) throw new DomainError("MenuItemIdが空だよ🙂");
    return new MenuItemId(value.trim());
  }

  equals(other: MenuItemId): boolean {
    return this.value === other.value;
  }
}
```

---

## 6) 実装③：OrderStatus（状態の箱）🚦✨

第57章で本格的に遷移を閉じ込めるけど、まずは“型”を固めるよ〜😊

### `OrderStatus.ts`

```ts
export type OrderStatus = "Draft" | "Confirmed" | "Paid" | "Canceled" | "Fulfilled";
```

---

## 7) 実装④：OrderLine（明細）🧾💎

明細は **不変**にしておくと、集約がめっちゃ守りやすいよ🧊✨
（数量変更＝“新しいOrderLineを作る”って感じ）

### `OrderLine.ts`

```ts
import { MenuItemId } from "./MenuItemId";
import { Money } from "../shared/Money";
import { Quantity } from "../shared/Quantity";

export class OrderLine {
  private constructor(
    public readonly menuItemId: MenuItemId,
    public readonly unitPrice: Money,
    public readonly quantity: Quantity
  ) {}

  static create(params: {
    menuItemId: MenuItemId;
    unitPrice: Money;
    quantity: Quantity;
  }): OrderLine {
    return new OrderLine(params.menuItemId, params.unitPrice, params.quantity);
  }

  lineTotal(): Money {
    return this.unitPrice.multiply(this.quantity.value);
  }

  withAddedQuantity(additional: Quantity): OrderLine {
    return new OrderLine(this.menuItemId, this.unitPrice, this.quantity.add(additional));
  }

  withQuantity(quantity: Quantity): OrderLine {
    return new OrderLine(this.menuItemId, this.unitPrice, quantity);
  }
}
```

---

## 8) 実装⑤：Order（集約ルート）👑🏯

### ✅ この章の超大事ポイント3つ🧱✨

1. **配列は外に渡さない（渡すならコピー＆freeze）**🧊
2. **合計は保持しない（派生値として計算）**🧮
3. **変更はOrderのメソッド経由だけ**🚪👑

### `Order.ts`

```ts
import { DomainError } from "../shared/DomainError";
import { Money } from "../shared/Money";
import { Quantity } from "../shared/Quantity";
import { MenuItemId } from "./MenuItemId";
import { OrderId } from "./OrderId";
import { OrderLine } from "./OrderLine";
import { OrderStatus } from "./OrderStatus";

export class Order {
  #lines: OrderLine[] = [];
  #status: OrderStatus;

  private constructor(public readonly id: OrderId) {
    this.#status = "Draft";
  }

  static createDraft(id: OrderId): Order {
    return new Order(id);
  }

  get status(): OrderStatus {
    return this.#status;
  }

  /**
   * 外に配列そのものを渡さない🧊
   * ReadonlyArray + freeze で「うっかり破壊」を防ぐ
   */
  getLines(): ReadonlyArray<OrderLine> {
    return Object.freeze([...this.#lines]);
  }

  /**
   * 合計は「常に明細から計算」🧮
   * これでズレ事故が激減するよ✨
   */
  total(): Money {
    return this.#lines.reduce((acc, line) => acc.add(line.lineTotal()), Money.jpy(0));
  }

  /**
   * この章では “構造” を見せたいので、最低限の操作だけ用意するよ😊
   * ルール（状態遷移ガード等）は第57章で本気出す🔥
   */
  addItem(params: { menuItemId: MenuItemId; unitPrice: Money; quantity: Quantity }): void {
    // 例：同じ商品があれば数量を足す（シンプル運用）🧾➕
    const index = this.#lines.findIndex(l => l.menuItemId.equals(params.menuItemId));
    if (index >= 0) {
      const current = this.#lines[index]!;
      // 価格が違う同一商品…みたいなケースは運用次第なので、とりあえず弾く🚫
      if (!current.unitPrice.equals(params.unitPrice)) {
        throw new DomainError("同じ商品なのに単価が違うよ🙂（運用ルール決めよ）");
      }
      this.#lines[index] = current.withAddedQuantity(params.quantity);
      return;
    }

    this.#lines = [...this.#lines, OrderLine.create(params)];
  }

  removeItem(menuItemId: MenuItemId): void {
    const before = this.#lines.length;
    this.#lines = this.#lines.filter(l => !l.menuItemId.equals(menuItemId));
    if (this.#lines.length === before) {
      throw new DomainError("消したい商品が見つからないよ🙂");
    }
  }

  changeQuantity(menuItemId: MenuItemId, quantity: Quantity): void {
    const index = this.#lines.findIndex(l => l.menuItemId.equals(menuItemId));
    if (index < 0) throw new DomainError("数量を変えたい商品が見つからないよ🙂");
    const current = this.#lines[index]!;
    this.#lines[index] = current.withQuantity(quantity);
  }

  /**
   * 外へ出すなら「スナップショット」形式が安心📸
   * （DTOは第63章でやるけど、今は構造守る練習ね✨）
   */
  snapshot(): {
    id: string;
    status: OrderStatus;
    lines: { menuItemId: string; unitPriceYen: number; quantity: number }[];
    totalYen: number;
  } {
    return {
      id: this.id.value,
      status: this.#status,
      lines: this.#lines.map(l => ({
        menuItemId: l.menuItemId.value,
        unitPriceYen: l.unitPrice.yen,
        quantity: l.quantity.value,
      })),
      totalYen: this.total().yen,
    };
  }

  // 第57章でここに confirm()/pay()/cancel() を足して「状態遷移の城壁」を作るよ🏯🧱
}
```

---

## 9) 最小テスト：構造が壊れてないか確認🧪✅

本日時点で Vitest は npm 上で **v4.0.18** が最新として表示されてるよ🧪✨ ([npm][3])
（Vitest 4.0 のアナウンスも公式ブログにあるよ📣 ([Vitest][4])）

### `Order.test.ts`

```ts
import { describe, it, expect } from "vitest";
import { Order } from "../../../src/domain/order/Order";
import { OrderId } from "../../../src/domain/order/OrderId";
import { MenuItemId } from "../../../src/domain/order/MenuItemId";
import { Money } from "../../../src/domain/shared/Money";
import { Quantity } from "../../../src/domain/shared/Quantity";

describe("Order aggregate structure 🏯", () => {
  it("合計は明細合計と一致する🧮", () => {
    const order = Order.createDraft(OrderId.of("order-1"));

    order.addItem({
      menuItemId: MenuItemId.of("latte"),
      unitPrice: Money.jpy(500),
      quantity: Quantity.of(2),
    }); // 1000円

    order.addItem({
      menuItemId: MenuItemId.of("cookie"),
      unitPrice: Money.jpy(300),
      quantity: Quantity.of(1),
    }); // 300円

    expect(order.total().yen).toBe(1300);
  });

  it("同じ商品は数量が加算される🧾➕", () => {
    const order = Order.createDraft(OrderId.of("order-2"));

    order.addItem({
      menuItemId: MenuItemId.of("latte"),
      unitPrice: Money.jpy(500),
      quantity: Quantity.of(1),
    });
    order.addItem({
      menuItemId: MenuItemId.of("latte"),
      unitPrice: Money.jpy(500),
      quantity: Quantity.of(2),
    });

    const lines = order.getLines();
    expect(lines.length).toBe(1);
    expect(lines[0]!.quantity.value).toBe(3);
    expect(order.total().yen).toBe(1500);
  });

  it("getLines() は外部から破壊されにくい🧊", () => {
    const order = Order.createDraft(OrderId.of("order-3"));
    order.addItem({
      menuItemId: MenuItemId.of("latte"),
      unitPrice: Money.jpy(500),
      quantity: Quantity.of(1),
    });

    const lines = order.getLines();
    // @ts-expect-error ReadonlyArrayなのでpushできない（型で防ぐ）
    // lines.push("x");

    // runtimeでもfreezeしてるので、雑に壊そうとしても落ちて気づける（環境により例外）
    expect(() => (lines as any).push("x")).toThrow();

    // 本体は無事✨
    expect(order.getLines().length).toBe(1);
  });
});
```

---

## 10) AIに頼むなら、この3つが超効く🤖✨（コピペOK）

### ① 骨組み生成（でもロジックは自分で入れる🧠）

* 「Order集約のクラス設計を TypeScript で、`lines` を外部からいじれないようにして。`total()` は派生で計算して。publicフィールドは禁止。」

### ② “穴あきレビュー”依頼（超おすすめ🔍）

* 「このコード、外から配列や内部状態をいじれる抜け道ない？ `lines` の露出・ミュータブル参照・合計の二重管理があれば指摘して。」

### ③ テスト観点を増やす（漏れ防止🧪）

* 「Order集約の構造テスト観点を追加して。特に“合計ズレ”“同一商品追加”“削除失敗”“数量変更”“不変性”を重点で。」

---

## 11) よくある事故😂⚠️（この章で潰せる！）

* `public lines: OrderLine[]` にしてしまう → 外から `push` されて崩壊💥
* `total` をフィールドに持つ → 明細更新と同期ズレる🧟‍♀️
* `Money` を `number` の小数で扱う → 0.1 + 0.2 の世界へようこそ🫠
* 明細を返す時に `return this.lines` → 参照漏れで死亡😇

---

## 12) ミニ課題🎒✨（次章がラクになるやつ）

1. `removeItem` のあと、**明細0件を許すか**決めてみてね（許すならOK、許さないならDomainError）🤔
2. `changeQuantity` を「0になったら削除扱い」にする案を実装してみよ（運用ルール次第）🧾🗑️
3. `snapshot()` に `linesTotalYen` を入れて「totalとの一致テスト」を追加してみよ🧪✅

---

## 13) 理解チェック✅💖（サクッと5問）

1. 集約ルートを1つにする理由は？🚪👑
2. `total` をフィールドに持たず `total()` で計算するメリットは？🧮
3. `getLines()` が `ReadonlyArray` を返すだけだと足りない場面は？🧊
4. 明細（OrderLine）を“不変寄り”にすると何が楽？🧾✨
5. 「同一商品追加で数量加算」ルールの弱点は何？（現実あるある）🫠

---

### 次（第57章）予告💌🚦

次はついに **confirm/pay/cancel の状態遷移**と、**ガード節で完全ブロック🛡️**を作るよ〜！
「Draft以外ではaddItem禁止！」みたいなのを、城壁としてガチガチにしていく✨🏯🧱

必要なら、この章のコードをベースに **“第57章用の状態遷移表🚦（許可/禁止）”**も一緒に作っていこ〜😊

[1]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[2]: https://github.com/microsoft/TypeScript/wiki/TypeScript%27s-Release-Process?utm_source=chatgpt.com "TypeScript's Release Process"
[3]: https://www.npmjs.com/package/vitest?utm_source=chatgpt.com "vitest"
[4]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
