# 第7章 不変条件（Invariants）を先に決めよう🔒✅

## この章のゴール🎯✨

* 「不変条件（Invariants）」＝**ずっと守られるべき業務ルール**を説明できる🙆‍♀️
* ルールを「どこに置くか」を迷わず決められる🧭
* TypeScriptで「無効な状態を作らない」書き方を体験する🧩💙

---

## 7.1 不変条件ってなに？🌱

不変条件は、ざっくり言うと👇
**「この世界では絶対こうでなきゃダメ！」っていうルール**だよ🔒✨

例（ミニEC）🛒

* 注文合計は **0円以上**じゃないとダメ💰
* 支払い済みの注文を **もう一回支払うのはダメ**💳❌
* 未払いの注文を **発送するのはダメ**📦❌

ここで大事なのは、
不変条件は「チェックする項目」じゃなくて **“守るべき状態”** ってこと！🧠✨
（つまり「正しい状態しか存在しない」世界を作りたい🌏💫）

---

## 7.2 なんでイベントより先に不変条件？🧩🔥

ドメインイベントは「起きた事実」だよね（例：`OrderPaid`）⏳📣
でも、もし **ルールがゆるゆる** だと…

* 0円未満の注文が作れちゃう😇
* 未払いなのに発送できちゃう😇
* その結果、「発送した」ってイベントまで出ちゃう😇📣

…ってなって、イベントが**事実じゃなくなる**の🥲💥
だから順番としては👇

1. ルール（不変条件）を決める🔒
2. ルールを破れない形でモデルを作る🏠
3. “正しい変更”が起きたときだけ、イベントが生まれる🌱📣

この順番が超大事〜！✨

---

## 7.3 不変条件の「置き場所」3パターン🗂️✨

不変条件は、だいたいこの3つのどれかに置くと綺麗になるよ🧹💕

### ① Value Object（値オブジェクト）に置く💎

**「値そのものが正しい必要がある」**ルール向き！

* 金額は0以上💰✅
* メールは形式が正しい📧✅
* 住所が空じゃない🏠✅

👉 VOに入れると「変な値がこの世に存在できない」状態になって最強🥳

### ② Entity / Aggregate（集約）に置く🏛️

**「状態遷移・振る舞いの正しさ」**ルール向き！

* 未払い→発送はダメ📦❌
* 支払いは1回だけ💳🔁❌
* キャンセル後は変更できない🙅‍♀️

👉 “操作メソッド” の中で守ると、使う側が楽になるよ😊

### ③ Application（ユースケース）に置く🧭

**「画面や入力の都合」「手続きの順序」**っぽいルール向き！

* クーポンコードの入力必須（UI都合）🎫
* 管理者だけ割引可能（権限）🔑
* 外部APIの結果が必要（インフラ依存）🌐

👉 これはドメインに混ぜるとややこしくなりがち！🚧
（ドメインは“業務の真実”を守る場所✨）

---

## 7.4 まずは「ルールを日本語で3つ」書こう📝💖

ここ超おすすめの手順👇✨

1. ルールを自然文で書く📝
2. 「いつチェックする？」を決める⏰
3. 「どこに置く？」を決める🗂️
4. 失敗したときのエラーを決める🚫💬

例：

* ルール：注文合計は0円以上
* チェック：`Money` を作る瞬間
* 置き場所：`Money`（VO）
* エラー：`AMOUNT_NEGATIVE`

こうすると、あとでイベントを作るときも迷子にならないよ🧭✨

---

## 7.5 TypeScriptで「無効な状態を作らない」基本セット🧰💙

### 7.5.1 Result型（成功/失敗）でやさしく返す🍀

例外（throw）で全部やると、初心者のうちは「どこで落ちた!?😵‍💫」ってなりやすいので、まずは **Result** が便利だよ✨

```ts
// domain/result.ts
export type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });
```

### 7.5.2 ドメインエラーを “型” で決める🚫🧾

```ts
// domain/errors.ts
export type DomainError =
  | { code: "AMOUNT_NEGATIVE"; message: string }
  | { code: "ORDER_ALREADY_PAID"; message: string }
  | { code: "ORDER_NOT_PAID"; message: string };
```

---

## 7.6 コード例：Money（VO）で「0円以上」を守る💰🔒

```ts
// domain/money.ts
import { Result, ok, err } from "./result";
import { DomainError } from "./errors";

export class Money {
  private constructor(public readonly amount: number) {}

  static create(amount: number): Result<Money, DomainError> {
    if (!Number.isFinite(amount)) {
      return err({ code: "AMOUNT_NEGATIVE", message: "金額が不正だよ🥲" });
    }
    if (amount < 0) {
      return err({ code: "AMOUNT_NEGATIVE", message: "金額は0円以上だよ💰✅" });
    }
    return ok(new Money(amount));
  }

  add(other: Money): Money {
    // Money同士の足し算なら、負にはなりにくい（ルール次第でチェック追加してOK）
    return new Money(this.amount + other.amount);
  }
}
```

ポイント✅

* `constructor` を `private` にして、**create経由でしか作れない**ようにする🔒
* これで「負の金額のMoney」は **存在できない**🎉

---

## 7.7 コード例：Order（集約）で「支払い→発送」の順序を守る📦💳

「状態」と「できる操作」をセットで守るよ💪✨

```ts
// domain/order.ts
import { Result, ok, err } from "./result";
import { DomainError } from "./errors";
import { Money } from "./money";

type OrderStatus = "Draft" | "Paid" | "Shipped";

export class Order {
  private status: OrderStatus = "Draft";

  private constructor(
    public readonly orderId: string,
    private total: Money
  ) {}

  static create(orderId: string, total: Money): Order {
    // totalはMoneyなので「0円以上」が既に保証されてる💰✅
    return new Order(orderId, total);
  }

  pay(): Result<void, DomainError> {
    if (this.status === "Paid") {
      return err({ code: "ORDER_ALREADY_PAID", message: "もう支払い済みだよ💳✅" });
    }
    if (this.status === "Shipped") {
      return err({ code: "ORDER_ALREADY_PAID", message: "発送後は支払い操作できないよ📦❌" });
    }

    this.status = "Paid";
    return ok(undefined);
  }

  ship(): Result<void, DomainError> {
    if (this.status !== "Paid") {
      return err({ code: "ORDER_NOT_PAID", message: "支払い前は発送できないよ📦❌" });
    }

    this.status = "Shipped";
    return ok(undefined);
  }

  getStatus(): OrderStatus {
    return this.status;
  }
}
```

ここが不変条件のキモ🧠✨

* “外側” に `if` を散らさず、**中（集約）で守る**
* すると「使う人が間違えにくい」設計になるよ😊💕

---

## 7.8 よくある落とし穴⚠️😵‍💫

### 落とし穴①：チェックが画面やAPI側に散らばる🌀

* 画面Aではチェックしてるのに、画面Bではしてない…とか起きがち🥲
  👉 ルールは **ドメインの入口** に寄せよう🔒

### 落とし穴②：「とりあえずnullable」で逃げる🫥

* `total?: number` みたいにすると、どこでもnullチェック地獄に…😇
  👉 “存在しないと困るもの” は **作れない** ほうが安全✨

### 落とし穴③：エラーメッセージが毎回バラバラ🗯️

👉 `code` を決めると、ログやUIが整うよ🧾✨

---

## 7.9 演習（ミニEC）📝🛒✨

### 演習1：不変条件を3つ決める🔒

例みたいに、自然文でOKだよ💖

* 例）注文合計は0円以上💰✅
* 例）支払いは1回だけ💳✅
* 例）支払い前の発送は禁止📦❌

### 演習2：置き場所を決める🗂️

3つのルールそれぞれについて👇を埋めてね✨

* 置き場所：VO / 集約 / アプリ層
* 理由：なぜそこが自然？🧠

### 演習3：1つだけ実装する💙

* `Money.create` みたいに「作る瞬間に守る」か、
* `Order.ship` みたいに「操作の瞬間に守る」か、
  どっちか選んで実装してみよう😊✨

---

## 7.10 AI活用プロンプト集🤖💬✨

そのままコピペで使えるよ🪄

### ① 自然文→チェック条件に変換🔁

```text
次の不変条件を、(1)チェック条件 (2)境界値テスト例 (3)エラーコード案 に分解して。
不変条件：『支払い前の注文は発送できない』
TypeScriptで書く想定で、if条件も提案して。
```

### ② 置き場所レビュー🗂️🔍

```text
次のルールは、VO / Entity(集約) / Application のどこに置くべき？
理由も短く3行で。ルール：『注文合計は0円以上』
```

### ③ 抜け穴（破り方）を探す🧯

```text
この不変条件が破られる“抜け穴”を3つ考えて。
それぞれ、どこで防ぐべきかも提案して。
不変条件：『支払いは1回だけ』
```

---

## まとめ🎀✨

* 不変条件は「ずっと守る業務ルール」🔒
* ルールを **VO/集約/アプリ層** のどこに置くか決めると設計がスッキリ🧹
* “無効な状態を作れない” ようにすると、あとでイベントが「本物の事実」になる📣💖

---

## 参考（任意）📚✨

* TypeScript 6.0は5.9系と7.0の間の“橋渡し”リリースとして説明されているよ（6.1は想定しない方針も言及） ([Microsoft for Developers][1])
* TypeScriptの最新リリースはGitHubのReleasesで追えるよ（例：5.9.3がLatestとして表示） ([GitHub][2])
* Branded Types（ブランド型）は「同じstring/numberでも意味を分ける」テクとして定番だよ（型システム上の“印”） ([learningtypescript.com][3])

[1]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/ "Progress on TypeScript 7 - December 2025 - TypeScript"
[2]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[3]: https://www.learningtypescript.com/articles/branded-types "Branded Types | Learning TypeScript"
