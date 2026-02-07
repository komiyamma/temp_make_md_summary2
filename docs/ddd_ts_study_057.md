# 第57章：Order集約を実装②：遷移とガード節🚦🛡️☕🧾

この章は「**不正操作を完全ブロックする**」回だよ〜！✨
Order集約（Orderが集約ルート🏯👑）に、**confirm/pay/cancel/fulfill** を実装して、**状態遷移のルール**と**ガード節（早期チェック）**でガチガチに守ります💪💞

※最新動向メモ：現時点（2026-02-07）では TypeScript は 5.9 系が安定版で、6.0 は 2026-02-10 にBeta、2026-03-17 にFinal予定…という計画が公開されています📅✨ ([GitHub][1])
（なので、この章のサンプルは **TS 5.9 前提でOK**だよ〜！）

---

## 1) ゴール（この章の到達点）🎯✨

* ✅ `setStatus()` みたいな “雑な変更” を **不可能**にする🚫
* ✅ `confirm()` / `pay()` / `cancel()` / `fulfill()` が **唯一の状態変更ルート**になる🚪
* ✅ どの操作も、先に **ガード節**で「やっちゃダメ」を即ブロック🛡️
* ✅ 例外（ドメインエラー）メッセージが、後でUIに出せるくらい “人間にやさしい”👩‍🍳💬

---

## 2) まずは状態遷移を「仕様」として固定する🚦📌

カフェ注文ドメインの例だと、こんな感じが分かりやすいよ〜☕🧾

| 現在の状態          | できること                   | 次の状態                 |
| -------------- | ----------------------- | -------------------- |
| Draft（下書き）     | confirm / cancel / 明細編集 | Confirmed / Canceled |
| Confirmed（確定）  | pay / cancel            | Paid / Canceled      |
| Paid（支払い済）     | fulfill                 | Fulfilled            |
| Canceled（取消）   | 何もできない                  | -                    |
| Fulfilled（提供済） | 何もできない                  | -                    |

ここがDDDで超大事💡
**「状態が違うと、できる操作が違う」＝ドメインルール**だから、UIやDBじゃなく **ドメイン（集約）で守る**よ🛡️✨

---

## 3) ガード節ってなに？🛡️（超ざっくり）

ガード節はこれ👇

* 「条件がダメなら、**最速で止める**」
* 深いifネストを作らない
* “違反” を **その場で発見**できる

たとえば、支払い済みの注文に `pay()` しようとしたら…
「え、二重払いじゃん😱」ってなるよね。
だから `pay()` の最初でこうする👇

```ts
if (this.status !== 'Confirmed') {
  throw new DomainError('支払いできません（注文が未確定です）');
}
```

この「最初に止める」がガード節🛡️✨

---

## 4) 実装方針：2つのやり方（おすすめは②）🧠✨

### ① 素直に `if` を書く（初心者に優しい）😊

* 分かりやすい
* でも、増えるとコピペ地獄になりやすい😂

### ② 遷移表（ルール表）をコードにする（おすすめ）📋✨

* ルールが1か所にまとまる
* 状態が増えても壊れにくい
* テストもしやすい🧪

この章は **②** で行くよ〜！🚀

---

## 5) コード：Order集約に「遷移」と「ガード節」を入れる🏯🛡️

ここでは、**Order集約ルート**だけ載せるね（VOやOrderLineは前章までである前提の形）✍️

### 5-1) ドメインエラー（例外）を用意する🧯

```ts
// domain/errors.ts
export abstract class DomainError extends Error {
  override readonly name: string = 'DomainError';
}

export class InvalidOrderOperationError extends DomainError {
  constructor(message: string) {
    super(message);
  }
}
```

> メッセージは「人間が読める」ほうが後で幸せ💞
> （ログ向けの詳細は後半章でやるよ〜👀）

---

### 5-2) OrderStatus と 遷移表（ルール）を作る🚦📋

```ts
// domain/order/Order.ts
import { InvalidOrderOperationError } from '../errors';

export type OrderStatus =
  | 'Draft'
  | 'Confirmed'
  | 'Paid'
  | 'Canceled'
  | 'Fulfilled';

const allowedTransitions = {
  Draft: ['Confirmed', 'Canceled'],
  Confirmed: ['Paid', 'Canceled'],
  Paid: ['Fulfilled'],
  Canceled: [],
  Fulfilled: [],
} as const satisfies Record<OrderStatus, readonly OrderStatus[]>;
```

`satisfies` を使うと「表が壊れてないか」を型でチェックできて安心だよ🧡
（TypeScriptは5.9系でモジュール周りの設定も整理が進んでるので、最新のルールに寄せやすいよ〜📦✨）([TypeScript][2])

---

### 5-3) ガード用の共通メソッドを作る🛡️✨

```ts
export class Order {
  private status: OrderStatus;
  // private readonly id: OrderId;
  // private lineItems: OrderLine[];

  private constructor(/* ... */) {
    this.status = 'Draft';
  }

  getStatus(): OrderStatus {
    return this.status;
  }

  // ✅ ガード：条件がダメなら即停止
  private ensure(condition: unknown, message: string): asserts condition {
    if (!condition) throw new InvalidOrderOperationError(message);
  }

  // ✅ 遷移表に従っているかを一括チェック
  private ensureCanTransitionTo(next: OrderStatus) {
    const allowed = allowedTransitions[this.status];
    this.ensure(
      allowed.includes(next),
      `この操作はできません（${this.status} → ${next} は禁止です）`
    );
  }

  private transitionTo(next: OrderStatus) {
    this.ensureCanTransitionTo(next);
    this.status = next;
  }

  // ここからユースケース操作（外部に公開する入り口）🚪👑
```

ポイントはこれ👇😍

* `status` は **private**（外から触れない）🔒
* `transitionTo()` が “内部の唯一の変更” になる🧊
* 遷移が増えても、表と `ensureCanTransitionTo()` を直せばOK✨

---

### 5-4) confirm / pay / cancel / fulfill を実装する☕💳🚫📦

ここで「状態だけ」じゃなく、**その操作に必要なルール**も一緒にガードするよ🛡️

```ts
  confirm() {
    // 例：明細ゼロで確定は禁止（ありがち！）
    // this.ensure(this.lineItems.length > 0, '注文を確定できません（商品が0件です）');

    this.transitionTo('Confirmed');
  }

  pay() {
    // 状態遷移のルールは transitionTo が守ってくれる✨
    // 追加で「合計金額が0なら支払いできない」みたいなルールを足してもOK
    this.transitionTo('Paid');
  }

  cancel(reason?: string) {
    // 「提供済はキャンセル不可」などは遷移表でブロックされる🛡️
    // reasonを持たせたいなら、ここでVO化したり、履歴に残したり（後で拡張OK）
    this.transitionTo('Canceled');
  }

  fulfill() {
    this.transitionTo('Fulfilled');
  }
}
```

> ここが「DDDっぽいだけ」を卒業する分かれ道🎓✨
> **アプリ層が if で守るんじゃなく、集約が自分で守る**のが大事だよ〜🏯🛡️

---

## 6) 使い方イメージ（ミニ例）☕✨

```ts
const order = /* Order.create(...) */;

// OK
order.confirm();
order.pay();
order.fulfill();

// NG（例：提供済に pay しようとする）
order.pay(); // ここで例外🧯
```

この「NGをちゃんと止める」のが今回の勝ち🏆✨

---

## 7) よくあるミス集😂⚠️（ここ超大事！）

### ❌ setStatus を public にする

* 一発で城が崩壊🏯💥
* ルールを回避できちゃう

### ❌ アプリ層で if して “通しちゃう”

* 画面やAPIが増えるほど、ルールが散らばる🌀
* 「片方だけチェックしてた😇」が起きる

### ❌ 遷移表がない（各メソッドにバラバラにif）

* ルールの見通しが悪くなる
* 状態が増えた時に事故る🚑

---

## 8) AI活用（例外メッセージを “ユーザー向け” に整える🤖💬✨）

この章のAIパートはここが最高に相性いいよ〜！😍

### 使えるプロンプト例🪄

```text
あなたはUXライターです。
次のドメインエラー文言を、ユーザー向けに短く分かりやすくしてください。
条件：
- 責めない口調
- 次に何をすればいいかが分かる
- 30文字前後

元の文言：
「この操作はできません（Paid → Paid は禁止です）」
```

さらに開発者向けの情報も欲しいときは👇

```text
同じ内容で、
(1) ユーザー表示用（短い）
(2) ログ用（原因が追える。status/next/operation を含む）
の2種類を提案して。
```

（エラー設計は後半章で本格的にやるけど、今のうちから “2種類に分ける発想” を入れると強いよ💪✨）

---

## 9) 理解チェック（ミニクイズ）📝💡

1. `confirm()` の中で **ガード節**はどこに置くのが気持ちいい？🛡️
2. 遷移表があると、状態が1個増えたとき何がラク？🚦
3. 「支払い済の注文は明細変更不可」ってルールは、どこで守る？🏯

答えられたらかなり良い感じ〜！🎉✨

---

## 10) 次章の予告🔜🧪

次（第58章）は、今日作った “城” が崩れないかを **テストで証明**するよ〜！🧪🔒
特に、**順番違い**（confirmしないでpay等）を大量に叩いて「絶対壊れない」を作るよ🔥

ちなみに最近のテスト界隈だと Vitest 4.0 が出ていて、4.1 beta の動きもあるよ〜📈（高速で気持ちいいやつ！） ([Vitest][3])

---

必要なら、この章のコードを「ファイル分割（domain/order/…）」した完全版もそのまま出せるよ📁✨

[1]: https://github.com/microsoft/TypeScript/issues/63085?utm_source=chatgpt.com "TypeScript 6.0 Iteration Plan · Issue #63085"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
