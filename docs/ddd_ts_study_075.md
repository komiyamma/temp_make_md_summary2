# 第75章：Static factory と Factory class の使い分け⚖️🏭✨

この章は「Factoryを使うのは分かったけど、`static`でいいの？クラス作るべき？」って迷子にならないための回だよ〜！🧭💕

（ちなみに今のTypeScript界隈は、安定版は **5.9系**で、**6.0はベータ〜正式が2026年2〜3月に進む予定**、さらに **7.0（ネイティブ化）**の流れが進行中…というタイミングだよ🧠⚡）([TypeScript][1])

---

## この章のゴール🎯💖

* ✅ **Static factory**（例：`Order.create(...)`）が“ちょうどいい”場面を説明できる
* ✅ **Factory class**（例：`new OrderFactory(...).create(...)`）に“育てる”判断ができる
* ✅ 「過剰設計しない」けど「将来詰まらない」落とし所が分かる✨

---

## まず結論：使い分け早見表🧾✨

| こういう時                                 | おすすめ                    | 理由                |
| ------------------------------------- | ----------------------- | ----------------- |
| 生成がシンプル（引数だけで完結）                      | **Static factory** 🧊   | 1ファイルで読める・軽い・迷わない |
| 生成時にルールチェックしたい（不変条件）                  | **Static factory** 🔒   | “生成＝検証”をその場で完結できる |
| 生成に「外部の都合」が絡む（ID生成器・Clock・設定・乱数・採番など） | **Factory class** 🧰    | 依存を注入できてテストも楽     |
| 生成パターンが増えそう（キャンペーン・店舗種別・注文経路…）        | **Factory class** 🌱    | 条件追加でstaticが太りやすい |
| 生成が“手順”になってきた（複数ステップ）                 | **Factory class** 🧑‍🍳 | ドメインを汚さず整理できる     |
| 将来「差し替え」が必要（方針/実装違い）                  | **Factory class** 🔁    | インターフェースで差し替えやすい  |

---

## 重要：名前で混乱しがちポイント😵‍💫🌀

「static factory method」って言葉、よく出るけど…
GoFの **Factory Methodパターン**（継承で生成を差し替えるやつ）とは別物として語られることが多いよ〜！⚠️
“静的メソッドで生成する”のを指して「static factory」と呼ぶのは一般的だけど、パターン名とごっちゃになりやすいので注意ね🧠💦 ([refactoring.guru][2])

---

## 1) Static factory：小さく強くいけるやつ🧊💎

## どんな形？（イメージ）👀✨

* `constructor` を `private` にして
* `static create(...)` だけを入り口にする
* **生成時に不変条件チェック**もできる（＝安全な入口）🔒

### 例：Orderをstaticで作る☕🧾

```ts
// domain/order/Order.ts
import { OrderId } from "./OrderId";
import { Money } from "../shared/Money";
import { OrderLine } from "./OrderLine";

type OrderStatus = "Draft" | "Confirmed" | "Paid" | "Fulfilled" | "Canceled";

export class Order {
  private constructor(
    public readonly id: OrderId,
    private readonly lines: readonly OrderLine[],
    public readonly status: OrderStatus,
    public readonly total: Money
  ) {}

  static create(args: { id: OrderId; lines?: readonly OrderLine[] }): Order {
    const lines = args.lines ?? [];
    if (lines.length === 0) {
      // 例：学習用に「最低1品」ルールがあるならここで守る
      //（ルールがないなら消してOKだよ）
      throw new Error("注文は1品以上が必要です");
    }

    const total = Money.sum(lines.map((l) => l.subtotal()));
    return new Order(args.id, lines, "Draft", total);
  }
}
```

### ここが良いところ😍✨

* 📌 生成の入口が1つ → 「どう作るの？」が迷子にならない
* 🔒 生成時にチェック → “壊れたOrder”が生まれにくい
* 🧪 テストが簡単（引数渡すだけでOK）

---

## 2) Factory class：依存が増えたらこっち🧰🏭✨

Static factoryがしんどくなる瞬間って、だいたいこれ👇

* 「IDは採番したい（生成器が必要）」🪪
* 「今の時刻が必要（Clockが必要）」⏰
* 「設定や方針が必要（税率・丸め・キャンペーン）」🏷️
* 「生成時に別のものを参照したい（でもドメインにRepositoryを入れたくない）」📚🚫

こうなると、static側に依存を“持ち込み”たくなるけど…
それをやると **ドメインが外部事情に汚れやすい** の😭💦
だから **Factory classに寄せる**と気持ちよくなるよ〜✨

## 例：OrderFactoryクラスに育てる🌱🏭

```ts
// domain/order/OrderFactory.ts
import { Order } from "./Order";
import { OrderId } from "./OrderId";
import { OrderLine } from "./OrderLine";

export interface OrderIdGenerator {
  next(): OrderId;
}

export interface Clock {
  nowIso(): string; // 学習用に文字列。実務ならDate系VOでもOK✨
}

export class OrderFactory {
  constructor(
    private readonly idGen: OrderIdGenerator,
    private readonly clock: Clock
  ) {}

  createDraft(args: { lines: readonly OrderLine[] }): Order {
    const id = this.idGen.next();
    const createdAt = this.clock.nowIso(); // 例：イベントやログに使いたくなるやつ
    // createdAt を Order に持たせたいなら、Order の構造に追加してOK！

    // 不変条件は Order 側で守るのが基本（Factoryは“生成の手続き”担当）
    return Order.create({ id, lines: args.lines });
  }
}
```

### ここが良いところ😍✨

* 🧩 依存（ID生成、Clock）が **注入**できる → テストが楽
* 🧼 `Order` 自体は外部を知らない → ドメインが綺麗
* 🔁 実装差し替えが簡単（ID生成をUUID→採番に変更とか）

---

## 3) 「staticで始めて、クラスに育てる」判断ライン🌱➡️🏭

この章のいちばん大事な感覚はこれ👇

## ✅ 最初は static でいい条件🧊

* 生成が **引数だけで完結**してる
* 生成ルートが **1〜2個**くらい
* 依存がない（または “値として渡せる”）
* 仕様がまだ固まってない（学習中は特に！）✨

## ✅ こうなったら Factory class へ🏭

* 「生成に必要なもの」が **サービス化**してきた（`idGen`, `clock`, `policy`）
* `createXXX` が増殖して `Order.createFromWeb`, `Order.createFromKiosk`…みたいに **分岐が増えた**
* 生成が“手順”になってきた（途中で判断・補正・分岐）
* テストで「毎回IDや時刻が違ってつらい」ってなった😇⏰

---

## 4) DDD的に“置き場所”どうする？📦🧠

迷ったらこの2択でOKだよ〜✨

* **ドメイン層のFactory**：

  * 生成に関する“ドメインの都合”（不変条件を満たす形を作る）中心🔒
* **アプリ層のFactory（or ユースケース内の組み立て）**：

  * Repositoryから材料集めたり、外部入力を整えたりする“手順”中心🎬

ポイントは「**ドメインの中にI/O（DBやAPI）を入れない**」だよ🧼✨
（I/Oが絡むならアプリ層で材料を集めて、ドメインのFactoryに渡すのがきれい🙆‍♀️）

---

## 5) よくある事故😂⚠️（これだけ避けて！）

## 🚫 static factoryが太りすぎる

* `static create(...)` の中が `if` だらけ
* 依存が増えて引数が10個…😇

👉 対策：Factory classへ移動して、依存はコンストラクタ注入🏭

## 🚫 Factoryが“ドメインを壊す”

* `new Order(...)` をFactoryが直に呼んで
  不変条件チェックをスキップしちゃうパターン💥

👉 対策：**Order側の安全な入口（create）**は残す🔒

## 🚫 生成＝どこでもOKになって、生成方法が散らかる

* あちこちで `new Order(...)` が登場

👉 対策：`constructor` を隠して入口を統一🧊✨

---

## 6) AI活用（Copilot/Codex）で爆速にするプロンプト例🤖⚡

## ✅ 判断の壁打ち（使い分け）

「いま static で良いか、Factory class にするべきか」を聞くプロンプト👇

* 「`Order.create` が今後太りそうかを判断したい。
  生成に必要な情報はA,B,C。将来増えそうな条件はX,Y。
  static継続/Factory class化の判断と、移行ステップ案を出して」

## ✅ “育てる”移行（最小差分）

* 「今ある `static create` を壊さずに、`OrderFactory` を追加して依存注入できる形にしたい。
  既存コード影響を最小にする差分案（ファイル構成・インターフェース）を提案して」

## ✅ テスト観点追加

* 「OrderFactory導入後に追加すべきテスト観点を列挙して。
  ID/時刻を固定できるスタブ実装も提案して」

---

## 7) ミニ演習🎮✨（手を動かす用）

## 演習A：staticのまま強くする🧊🔒

1. `Order.create` の引数をオブジェクト化（将来の拡張用）
2. 生成時のガード（例：lines空禁止）を1つ入れる
3. テストで「空配列だと失敗」を追加🧪

## 演習B：Factory classに育てる🏭🌱

1. `OrderIdGenerator` と `Clock` を作る（interface）
2. `OrderFactory.createDraft` を作る
3. テストで `FakeClock` と `FixedIdGenerator` を使って “同じ結果になる” を確認🧪⏰

---

## まとめ🌸✨

* **static factory**：シンプルな生成・入口統一・不変条件チェックに強い🧊🔒
* **Factory class**：依存注入・生成手順の整理・差し替え・テストに強い🏭🧰
* 迷ったら **「いま依存がある？将来増える？」**で判断！🌱

次の章（Domain Service）に進むと、「Factoryに押し込めたくなる“ルール”」をどう逃がすかが見えてくるよ🧙‍♀️✨

[1]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[2]: https://refactoring.guru/design-patterns/factory-comparison?utm_source=chatgpt.com "Factory Comparison - Design Patterns"
