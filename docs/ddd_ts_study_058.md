# 第58章：集約のテスト（不変条件が守れるか）🧪🔒✨

この章はひとことで言うと、**集約（Aggregate）が「仕様を守る装置」になってるかを、テストで証明する章**だよ〜！💖
集約は「でっかいクラス」じゃなくて、**ルールを守るための“安全な箱”**だから、テストは超・主役です🏯🛡️

---

## この章のゴール🎯✨

* 集約テストで何を確認するべきか、迷わなくなる🧭
* **不変条件（絶対守るルール）**と**状態遷移**を、テストでガチガチに固められる🔒
* 似たテストを“量産”しないで、**パラメータ化**でキレイに書ける🧷
* 「テストが仕様書になる」感覚をつかむ📘🧪

---

## 2026年2月時点の “テスト環境” の現実（超ざっくり）🧡🧰

* TypeScript は **5.9 系**が最新安定（5.9.2 が stable 扱い）だよ📌 ([GitHub][1])
* Node.js は **v24 が Active LTS**（安定して長く使うならここが無難）🟢 ([Node.js][2])
* テストは **Vitest 4 系**が安定枠（4.0.18 が latest、4.1 は beta が動いてる）🧪 ([Yarn][3])
* Jest は **Jest 30 が stable**（公式が “Current version (Stable)” って言ってる）📌 ([Jest][4])

この章では **「集約テストの考え方」**が本体なので、例は **Vitest** で書くね（Jestでもほぼ同じノリでいけるよ）💕

---

## 集約テストって、何を守るの？🧠🔒

### ✅ 集約テストで守るものトップ3🥇🥈🥉

1. **不変条件（Invariant）**
   例：

* 支払い後は明細を変更できない
* 明細が空の注文は確定できない
* 合計金額は常に「明細の合計」と一致する

2. **状態遷移（State Transition）**
   例：Draft → Confirmed → Paid → Fulfilled

* 飛ばし禁止（Draft から Paid に直行しない）🚫
* 逆戻り禁止（Paid → Confirmed に戻らない）🚫

3. **集約内の整合性（Consistency）**
   例：

* 明細を増減したら total が必ず更新される
* 同じ商品を重複追加したときの扱い（統合する？別行にする？）がブレない

---

## 集約テストの基本方針（これだけ覚えて！）🧪💡

### 1) 「公開メソッドだけ」を叩く👆✨

集約の中の配列を直接いじったり、フィールドを書き換えたりは **テストでも禁止**🙅‍♀️
テストがズルすると、設計が崩れるよ〜💥

### 2) テスト名は “仕様の文章” にする📘✨

おすすめ：

* `it('明細が空の注文は確定できない')`
* `it('支払い後は明細を追加できない')`

これだけで、あとで読み返したとき神です🙏💕

### 3) 正常系より「禁止ルート」を厚めにする🚫🛡️

集約は “壊れないこと” が価値だから、
**「できちゃダメ」をガッツリ**テストするのが強い💪✨

---

## テストの準備：Fixture（テスト用の作りやすい注文）を作ろう🧁🏗️

集約テストは「状態」が大事だから、毎回ゼロから作ると疲れるの…😵‍💫
そこで **Fixture（または Builder）** を作ると超ラク💖

### 🍰 例：Order を作る Fixture イメージ

* `givenDraftOrder()`：下書き注文（明細あり/なしを選べる）
* `givenConfirmedOrder()`：確定済み注文
* `givenPaidOrder()`：支払い済み注文

これがあると、テストが **短く・読みやすく・壊れにくい**✨

---

## 実例：Order 集約テスト（Vitest）🧪☕🧾

> 💡ここでは「Order が Aggregate Root」って前提で、
> `addItem / removeItem / changeQuantity / confirm / pay / cancel / fulfill` みたいなメソッドがある想定にするね✨
> （中身の実装は第56〜57章で作った子たち！）

### ✅ テストコード例（まずは王道：不変条件と遷移）

```ts
import { describe, it, expect } from "vitest";
import { OrderFixture } from "../__fixtures__/OrderFixture";
import { DomainError } from "../../domain/errors/DomainError";

describe("Order Aggregate 🏯", () => {
  it("明細が空の注文は確定できない 😵‍💫", () => {
    const order = OrderFixture.draft({ items: [] });

    expect(() => order.confirm()).toThrowError(DomainError);
  });

  it("下書きの間は明細を追加でき、合計が更新される ✅💴", () => {
    const order = OrderFixture.draft({ items: [] });

    order.addItem(OrderFixture.line({ priceYen: 500, qty: 2 })); // 1000円
    order.addItem(OrderFixture.line({ priceYen: 300, qty: 1 })); // +300円

    expect(order.totalYen()).toBe(1300);
  });

  it("確定後は明細を追加できない 🔒", () => {
    const order = OrderFixture.draft({ items: [OrderFixture.line({ priceYen: 500, qty: 1 })] });
    order.confirm();

    expect(() => order.addItem(OrderFixture.line({ priceYen: 300, qty: 1 }))).toThrowError(DomainError);
  });

  it("支払いは確定済みの注文だけできる 💳", () => {
    const order = OrderFixture.draft({ items: [OrderFixture.line({ priceYen: 500, qty: 1 })] });

    expect(() => order.pay()).toThrowError(DomainError);

    order.confirm();
    order.pay();

    expect(order.status()).toBe("Paid");
  });

  it("支払い後はキャンセルできない 🚫", () => {
    const order = OrderFixture.confirmedWithItems();
    order.pay();

    expect(() => order.cancel()).toThrowError(DomainError);
  });

  it("支払い後に fulfill できる ☕📦", () => {
    const order = OrderFixture.confirmedWithItems();
    order.pay();
    order.fulfill();

    expect(order.status()).toBe("Fulfilled");
  });
});
```

### ここでのポイント🧡✨

* **「できないこと」をテストしてる**（confirm できない、追加できない、pay できない、cancel できない）🔒
* 例外の型は `DomainError` でまとめると、テストも読みやすいよ🧯
* `totalYen()` みたいな “観測メソッド” があるとテストがスッキリ✨
  （ドメインの内部配列を覗かないで済む👀🚫）

---

## 状態遷移は “パラメータ化” で一気に固める🧷🚦✨

Vitest は `test.each` / `it.each` が使えるよ（Jest互換）🧪 ([Vitest][5])
これを使うと、遷移の「禁止表」をそのままテストにできるのが気持ちいい〜💕

### ✅ 例：禁止遷移をまとめてテスト

```ts
import { describe, it, expect } from "vitest";
import { OrderFixture } from "../__fixtures__/OrderFixture";
import { DomainError } from "../../domain/errors/DomainError";

describe("Order state transitions 🚦", () => {
  it.each([
    ["Draft", "pay", () => OrderFixture.draftWithItems()],
    ["Draft", "fulfill", () => OrderFixture.draftWithItems()],
    ["Confirmed", "fulfill", () => OrderFixture.confirmedWithItems()],
    ["Paid", "confirm", () => OrderFixture.paidWithItems()],
    ["Paid", "cancel", () => OrderFixture.paidWithItems()],
  ] as const)(
    "%s 状態のとき %s はできない 🚫",
    (_status, action, factory) => {
      const order = factory();

      expect(() => {
        // action を呼ぶ
        if (action === "pay") order.pay();
        if (action === "fulfill") order.fulfill();
        if (action === "confirm") order.confirm();
        if (action === "cancel") order.cancel();
      }).toThrowError(DomainError);
    }
  );
});
```

### これの良さ😍

* 遷移が増えても **配列を増やすだけ**
* テスト名が **仕様の一覧**になる
* 「抜け」が見つけやすい（禁止表に穴があると気づく）🕳️👀

---

## “時間” が絡むなら：fake timers / Date 操作⏰🧪

もし集約に「期限」「締切」「キャンセル可能時間」みたいなルールが入るなら、
テストでは **時間を固定**して安定させよ〜！✨

Vitest は `vi.useFakeTimers` や `vi.setSystemTime` が用意されてるよ⏰🧊 ([Vitest][6])

（このロードマップだと第86章の Clock 注入につながってくるやつだね💖）

---

## 🤖 AI活用（Copilot / Codex）で “テスト観点の漏れ” を潰すテンプレ✨

AIはコード生成より、**観点チェック**が強いよ〜！👀🧠

### ① 観点を増やしてもらうプロンプト📝✨

* 「この集約の公開メソッド一覧」と「不変条件一覧」を貼って
* こう聞く：

> 「この集約の不変条件が破れる “禁止操作の順序” を、テストケースとして20個提案して。
> それぞれ Given/When/Then で書いて。重複はまとめて。」

### ② パラメータ化候補を作らせる🧷

> 「下の遷移表を、Vitest の it.each に落とし込む配列（ケース一覧）にして。
> できればテスト名も読みやすくして。」

### ③ 例外メッセージの品質🧯

> 「DomainError のメッセージを、利用者向けと開発者向け（ログ向け）に分けたい。
> 例を5パターン作って。」

---

## よくある失敗（集約テストあるある）😂⚠️

* ❌ **内部配列を直接触るテスト**（集約ルールを回避してしまう）
* ❌ **“最終状態だけ” 見て安心する**（途中の禁止ルートが穴になる）
* ❌ **テストデータ生成がつらくて、ケース数が増えない**（Fixture不足）
* ❌ **例外が雑で、何がダメなのか分からない**（DomainError設計が弱い）

---

## 仕上げ：この章のチェックリスト✅💖

テストが揃ったら、これ全部 YES なら勝ち〜！🎉✨

* ✅ 不変条件は「守れる」だけじゃなく「破れない」を確認してる？🔒
* ✅ 遷移は “できる” と “できない” が両方テストされてる？🚦
* ✅ 代表的な順序違い（confirm 前に pay 等）を潰してる？🧯
* ✅ テストが公開メソッドだけで書けてる？👆
* ✅ Fixture があって、ケース追加がラク？🧁

---

## ミニ演習🎓☕✨（次の章に効くやつ）

1. 「禁止遷移表」をあなたの Order 集約で作ってみてね🚦📝
2. それを `it.each` でテストにしてみてね🧷🧪
3. AIに「抜けてる禁止操作の順序」を10個出させて、追加してみてね🤖✨

---

必要なら、あなたの第56〜57章の `Order` 実装（メソッド名や状態名）が分かる形で貼ってくれたら、**そのコードにピッタリ一致する “第58章完成版のテスト一式”**（Fixture込み）に整えて出すよ〜！🧪💖

[1]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://classic.yarnpkg.com/en/package/vitest?utm_source=chatgpt.com "vitest"
[4]: https://jestjs.io/versions?utm_source=chatgpt.com "Jest Versions"
[5]: https://vitest.dev/api/?utm_source=chatgpt.com "Test API Reference"
[6]: https://vitest.dev/guide/mocking/timers?utm_source=chatgpt.com "Timers"
