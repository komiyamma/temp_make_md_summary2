# 第69章 アプリ層のアンチパターン（ルールの漏れ）⚠️🧯

## 🎯 この章のねらい

アプリ層が「手順担当」なのに、うっかり **ビジネスルール担当**みたいになってしまう…
その状態（＝ルール漏れ）を見つけて、**ドメインに戻す**練習をするよ🧠✨

## ✅ ゴール

* 「それ、アプリ層に書いちゃダメなやつ…！」を嗅ぎ分けられる🐶💡
* ルールはドメイン（Aggregate/Entity/VO）に閉じ込め、アプリ層はスリムになる💪✨
* 同じチェックが重複しない＆抜け漏れが減る🎉

---

## まず結論：3行ルール📝✨

* **手順（ワークフロー）**はアプリ層🎬
* **不変条件（ビジネスルール）**はドメイン層🔒
* **入出力の形（DTO）**は境界で整える📦

この分離ができると、設計が一気に安定するよ〜😊🌸
（「ビジネスロジックはドメインモデルに載せる」考え方は、ドメインモデルの代表的な説明でも強調されてるよ）([martinfowler.com][1])

---

## 「ルール漏れ」って何がマズいの？😵‍💫

アプリ層にルールが漏れると…

* ✅ **ユースケースAでは守ってるのに、Bでは忘れて破綻**（抜け漏れ）🕳️
* ✅ **同じルールがコピペされて増殖**（重複）🧟‍♀️
* ✅ 仕様変更で **直す場所が多すぎて地獄**（保守コスト爆増）💥
* ✅ 結果、アプリ層が **巨大な手続き（Transaction Script化）**してくる😇
  （これは “手続きを積み上げるパターン” として有名）([martinfowler.com][2])

---

## ルールの種類をサクッと仕分けしよ🍱✨

ここが超重要〜！🧠💕

## 🔒 ドメイン層に置くもの（不変条件）

例：

* 「支払い済みの注文は、明細変更できない」
* 「未払いは提供できない」
* 「確定済みでないと支払いできない」

→ **状態と整合性のルール**はドメインに閉じ込めたい😊

## 🎬 アプリ層に置くもの（手順・調整）

例：

* 入力DTOを受け取る
* リポジトリで取得する
* ドメインのメソッドを呼ぶ
* 保存する
* 例外をユーザー向け結果に変換する

→ **“何をどの順で呼ぶか”**だけやる✨

---

## アプリ層アンチパターン 7選⚠️（全部「ルール漏れ」に繋がる）

「あるある」から行くよ〜😂🧡

## ❶ if が並びすぎる（手続きスクリプト化）🧾🧱

**症状**：Application Service の中が if と status チェックで埋まる
**事故**：別ユースケースで同じチェックを書き忘れる
**治し方**：ドメインに `pay()` / `fulfill()` みたいな “意図メソッド” を作る🛡️

---

## ❷ 同じルールが Pay/Fulfill/Place にコピペされる📎😇

**症状**：どのユースケースも「未払いなら〜」を持ってる
**事故**：文言や条件が微妙にズレて分岐が増える
**治し方**：**1箇所（ドメイン）に集約**して、アプリ層は呼ぶだけ🎯

---

## ❸ Entity が“データ入れ物”になってる（貧血モデル）🩸

**症状**：Entity に setter が生えてて、ロジックは全部サービス側
**事故**：どこからでも状態を壊せる
**治し方**：**状態変更はメソッド経由だけ**にする（setStatus 禁止の延長）🚫🚦

---

## ❹ 配列やオブジェクト参照を外に渡して、外側が勝手にいじる🧨

**症状**：`order.lines.push(...)` が外でできる
**事故**：ドメインの検証をすり抜ける
**治し方**：外に渡すのは **読み取り専用** or **コピー**📦✨

---

## ❺ “ルール”っぽい名前の関数が Application Service にある🧯

例：`ensureOrderIsPayable(order)` が app に居る
**治し方**：それ、だいたい `order.assertCanPay()` とか `order.pay()` に寄せられる👍

---

## ❻ エラーの意味がバラバラ（文字列Error地獄）🌀

**症状**：`throw new Error("NG")` が乱立
**事故**：UI側が解釈できない / ログも追えない
**治し方**：ドメインは **ドメイン例外（型）**、アプリ層は **結果（DTO）**へ変換📦🧯

---

## ❼ “状態遷移の正しさ”をアプリ層が握っている👮‍♀️

**症状**：`order.status = "PAID"` をアプリ層が直接やる
**事故**：ドメインの中に「守る力」がなくなる
**治し方**：`order.pay()` の中で状態遷移＆ガード節を完結させる🏯🛡️

---

## コードで体感！🙌（悪い例 → 良い例）

題材は PayOrder 💳✨

## ❌ 悪い例：アプリ層にルールが漏れてる

```ts
// PayOrderService.ts（悪い例）
export class PayOrderService {
  constructor(private readonly orderRepo: OrderRepository) {}

  async execute(input: { orderId: string }) {
    const order = await this.orderRepo.findById(input.orderId);
    if (!order) throw new Error("Order not found");

    // 🚨 ルールがアプリ層に漏れてる
    if (order.status !== "CONFIRMED") {
      throw new Error("Only confirmed orders can be paid");
    }

    // 🚨 状態変更も外側が直書き
    order.status = "PAID";
    order.paidAt = new Date();

    await this.orderRepo.save(order);
  }
}
```

この形のままだと、別のユースケースで `status` 書き換えた瞬間に崩れるよ😵‍💫💦

---

## ✅ 良い例：ルールをドメインへ戻す

### 🏯 Order（集約ルート）側に “意図メソッド” を用意

```ts
// Order.ts（良い例）
export class Order {
  private status: "DRAFT" | "CONFIRMED" | "PAID" | "FULFILLED";
  private paidAt: Date | null = null;

  pay(now: Date) {
    if (this.status !== "CONFIRMED") {
      throw new OrderCannotBePaidError(this.status);
    }
    this.status = "PAID";
    this.paidAt = now;
  }
}

export class OrderCannotBePaidError extends Error {
  constructor(public readonly currentStatus: string) {
    super(`Order cannot be paid. status=${currentStatus}`);
  }
}
```

### 🎬 Application Service は “呼ぶだけ”

```ts
// PayOrderService.ts（良い例）
export class PayOrderService {
  constructor(private readonly orderRepo: OrderRepository) {}

  async execute(input: { orderId: string }) {
    const order = await this.orderRepo.findById(input.orderId);
    if (!order) throw new Error("Order not found");

    // ✅ ルール判断はドメインに任せる
    order.pay(new Date());

    await this.orderRepo.save(order);
  }
}
```

この形になると、**どこから pay されても必ずルールが守られる**よ🔒✨
（「集約にロジックを集めて漏れを防ぐ」方向性は、ドメインロジック集中のメリットとしても語られてるよ）([Enterprise Craftsmanship][3])

---

## テストで「漏れない設計」を固定する🧪🛡️

テストは **アプリ層より先にドメインを固める**のが効くよ✨
最近だと Vitest が 4.x 系で進化してる（4.0リリース告知＆4.1 beta が動いてる）([Vitest][4])
Jest も 30 系が “stable” になってるよ([Jest][5])

## 例：Vitestでドメインを直接テスト

```ts
import { describe, it, expect } from "vitest";

describe("Order.pay", () => {
  it("confirmedなら支払いできる", () => {
    const order = createConfirmedOrder(); // テスト用ビルダー想定
    order.pay(new Date("2026-02-07T10:00:00Z"));
    expect(order).toMatchObject({}); // 実際は getter/DTO化した読み取りで確認ね✨
  });

  it("confirmed以外は支払いできない", () => {
    const order = createDraftOrder();
    expect(() => order.pay(new Date())).toThrow();
  });
});
```

> ポイント：**アプリ層の if をテストする**んじゃなくて、
> **ドメインのメソッドが守ってる**ことをテストする🛡️✨

---

## 直し方レシピ🍳（迷ったらこの順！）

1. **アプリ層の if を眺めて「ルールっぽい文」を抜き出す**📝
2. それを **ドメインの言葉**にする（`pay`, `fulfill`, `confirm`…）🗣️
3. ドメインに **メソッド＋ガード節**を作る🔒
4. アプリ層から if を消して、**ドメインを呼ぶだけ**にする🎬
5. ルールが **1箇所**になったら勝ち🏆✨

---

## 2026の “ちょい最新” TypeScriptメモ🧡🆕

* TypeScript 5.9 のリリースノートでは、`tsc --init` がより「実戦向け」の tsconfig を吐くように調整されてるよ（`module: nodenext` / `target: esnext` / `strict` など）([typescriptlang.org][6])
* Node.js は v24 が Active LTS、v25 が Current（奇数系）という扱いになってるので、普通は LTS を軸に考えるのが安心だよ🟢([Node.js][7])

---

## 🤖 AIの使いどころ（この章向けテンプレ）🧠✨

アプリ層のコードを貼って、こんな感じで聞くと強いよ〜！

## 🪄 テンプレ1：ルール漏れ検出

* 「この `PayOrderService` の中から **ビジネスルール**っぽい行を全部列挙して、**ドメインに移す候補**を提案して」

## 🪄 テンプレ2：置き場所判定

* 「この条件は **ドメイン不変条件 / アプリ手順 / UI入力補助** のどれ？理由もつけて」

## 🪄 テンプレ3：リファクタ手順

* 「if を消して `Order.pay()` に寄せたい。**最小差分**の手順をステップで出して」

（Copilot でも、GitHub のAI拡張でも、OpenAI 系でも、この聞き方が効くよ🤖💡）

---

## 理解チェック✅💡（サクッと10問）

1. 「支払い後は明細変更不可」はどの層に置く？
2. Application Service が太る一番ありがちな原因は？
3. `order.status = "PAID"` を外でやると何が起きる？
4. ルールが Pay と Fulfill にコピペされると何が辛い？
5. “手順” と “不変条件” の違いを一言で言うと？
6. 「入力の空文字チェック」はだいたいどこ？
7. 「状態遷移の可否判定」はだいたいどこ？
8. ドメインに移したら、アプリ層のコードはどうなるのが理想？
9. ルール移動の最初の一歩は？
10. テストをアプリ層じゃなくドメインに寄せるメリットは？

---

## まとめ🎀✨

* アプリ層にルールが漏れると、**重複・抜け漏れ・変更地獄**が起きる⚠️
* **ドメインに「守る力」**を持たせる（意図メソッド＋ガード節）🏯🛡️
* アプリ層は **薄く・読みやすく・手順だけ**🎬✨

---

次の第70章は、ここまでのユースケース（Place/Pay/Fulfill/Get）を **ぜんぶ繋いで動かす回**だよ🎉
その前に、今のコードの `if` 密度を見て「漏れてるルール」を1個だけでもドメインに戻しておくと、気持ちよく進めるよ〜😊🌸

[1]: https://martinfowler.com/eaaCatalog/domainModel.html?utm_source=chatgpt.com "Domain Model"
[2]: https://martinfowler.com/eaaCatalog/transactionScript.html?utm_source=chatgpt.com "Transaction Script"
[3]: https://enterprisecraftsmanship.com/posts/validation-and-ddd/?utm_source=chatgpt.com "Validation and DDD"
[4]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[5]: https://jestjs.io/versions?utm_source=chatgpt.com "Jest Versions"
[6]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html "TypeScript: Documentation - TypeScript 5.9"
[7]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
