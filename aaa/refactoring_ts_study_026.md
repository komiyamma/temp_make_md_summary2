# 第26章 重複排除①（同じ知識は1か所へ）🔁🧠

### ねらい🎯

* 「同じことを2回書いてる…😵」を見つけて、**修正漏れゼロ**に近づける✨
* “コピペの安心感”を卒業して、**直しやすい形**にする🧹💕

---

### 今日のキーワード🌟

* **重複（duplication）**：似たコードが複数ある状態🔁
* **同じ知識（same knowledge）**：
  “何をするか”じゃなくて **「なぜそうするか（仕様・ルール）」が同じ** ってこと🧠✨
* **変更理由が同じなら一緒にする**🧩
  変更理由が別なら、似てても分けてOK🙆‍♀️

---

### まず大事なこと（ここがコツ）💡

#### ✅ 重複は「行」じゃなくて「知識」で判断する

同じように見えても…

* Aは「クーポン割引のルール」🎟️
* Bは「会員ランク割引のルール」👑

みたいに **別の知識**なら、無理に一緒にしないでOK👍✨
逆に、**片方を直すとき、もう片方も必ず直す**なら、それは「同じ知識」なので1か所にまとめたい💪

---

### よくある重複パターン👃✨

* 計算ロジックがコピペ（合計、税、割引、送料…）🧾
* バリデーションがコピペ（入力チェック）🧪
* 似たif条件があちこちにある（「有効なユーザー」判定など）🚦
* 同じ文字列・正規表現・エラー文言が散らばる🧷

---

### 手順（安全に小さく刻むよ👣🛟）

1. **今の動作を固定する**🧷

   * 可能ならテスト追加🧪（難しければログでもOK🪵）
2. **重複2か所を“並べて”差分を見る**👀🔍

   * どこが同じ？どこが違う？
3. **「違い」をパラメータにする方針を決める**🧩
4. **共通部分を小さく関数に抽出**✂️📦
5. **片方だけ置き換えて動作確認 → もう片方も置換**🔁✅
6. **名前をちゃんと付ける**🏷️（ここ超大事！）
7. **コミットは小さく**💾（差分が説明できる単位）

---

### コード例（ビフォー/アフター）🧩➡️✨

#### 状況📌

「カートの合計」と「注文の合計」で、ほぼ同じ計算をコピペしちゃってる…🔁😵
こういうの、後から税率や丸めが変わった時に **片方だけ直して事故**が起きがち💥

---

#### Before（重複あり）😵‍💫

```ts
type LineItem = { unitPrice: number; quantity: number };

function calcCartTotal(items: LineItem[], discountRate: number) {
  const subtotal = items.reduce((sum, x) => sum + x.unitPrice * x.quantity, 0);
  const discounted = Math.floor(subtotal * (1 - discountRate));
  const taxed = Math.floor(discounted * 1.1);
  return taxed;
}

type Order = { items: LineItem[]; memberDiscountRate: number };

function calcOrderTotal(order: Order) {
  const subtotal = order.items.reduce((sum, x) => sum + x.unitPrice * x.quantity, 0);
  const discounted = Math.floor(subtotal * (1 - order.memberDiscountRate));
  const taxed = Math.floor(discounted * 1.1);
  return taxed;
}
```

**困るポイント😵**

* 税率が変わったら？丸めが変わったら？➡️ **2か所直す必要**がある
* 片方だけ直してバグりやすい💥

---

#### After（同じ知識を1か所へ）✨

```ts
type LineItem = { unitPrice: number; quantity: number };

function calcSubtotal(items: ReadonlyArray<LineItem>) {
  return items.reduce((sum, x) => sum + x.unitPrice * x.quantity, 0);
}

function calcTotalWithDiscountAndTax(subtotal: number, discountRate: number) {
  const discounted = Math.floor(subtotal * (1 - discountRate));
  const taxed = Math.floor(discounted * 1.1);
  return taxed;
}

function calcCartTotal(items: LineItem[], discountRate: number) {
  const subtotal = calcSubtotal(items);
  return calcTotalWithDiscountAndTax(subtotal, discountRate);
}

type Order = { items: LineItem[]; memberDiscountRate: number };

function calcOrderTotal(order: Order) {
  const subtotal = calcSubtotal(order.items);
  return calcTotalWithDiscountAndTax(subtotal, order.memberDiscountRate);
}
```

**うれしいこと🥰**

* 税率や丸めルールが変わっても **1か所直せばOK**✅
* “合計計算の知識”がまとまって、読みやすい📚✨

---

### ここでの“見極め”ポイント🧠✨

#### ✅ まとめたのは「同じ知識」だから

* どっちも「小計 → 割引 → 税 → 丸め」という **同じルール**🧾
* 変更されるときは **一緒に変わる**可能性が高い🔁

#### ⚠️ まとめすぎ注意（やりがち）🧯

* `calc(x, y, z, a, b, c...)` みたいに **引数だらけ**になる
* 名前が `util`, `helper` で “何の知識？” ってなる
  ➡️ それは次章の「ユーティリティ地獄」への入口😇🧯

---

### テストで「動作同じ」を守る🧪✅

最近のテスト環境だと、Vitest は TypeScript/ESM を“そのまま”扱えるのが売りだよ〜🧪⚡（設定が軽めで始めやすい） ([Vitest][1])

例（超ミニ）👇

```ts
import { describe, it, expect } from "vitest";

describe("合計計算", () => {
  it("同じ入力なら同じ結果になる", () => {
    const items = [{ unitPrice: 100, quantity: 2 }, { unitPrice: 50, quantity: 1 }];
    expect(calcCartTotal(items, 0.1)).toBe( (Math.floor(Math.floor(250 * 0.9) * 1.1)) );
  });
});
```

---

### ミニ課題✍️🌸

次のどっちかをやってみてね👇（両方できたら最強💪✨）

#### 課題A（重複発見👀🔍）

自分のコード（または練習用コード）で、次を1つ探す🕵️‍♀️

* 同じ計算
* 同じ入力チェック
* 同じ条件分岐
  見つけたら「これって同じ知識？それとも似てるだけ？」を1行でメモ📝

#### 課題B（共通化実践✂️📦）

Before例のような重複を、**抽出関数2つまで**で共通化してみる🧩
（`calcSubtotal` みたいな “名詞の関数” が作れるとキレイ💕）

---

### AI活用ポイント🤖✅（お願い方＋チェック観点）

#### お願い方（コピペOK）📝✨

*「この2つの関数の重複を、**“同じ知識を1か所にする”**方針でリファクタして。
ただし **汎用utility化しすぎない**で、ドメインが伝わる名前にして。
手順は“安全に小さく刻む”形で、コミット単位の提案もつけて。」*

#### AIの提案を採用する前のチェック✅

* 片方の仕様変更で、もう片方も変わる？（同じ知識？）🧠
* 関数名を読んで、何のルールかわかる？🏷️
* 引数が増えすぎてない？（3つ超えたら黄色信号🚦）
* テスト/型チェックで「動作同じ」を確認できた？🧪🧷

---

### 2026アップデートメモ🗞️✨

* TypeScript は npm 上で **5.9.3 が最新**として案内されてるよ📦✨ ([npm][2])
* ESLint は Flat Config 周りが進化していて、`defineConfig()` や `extends` が整備されてきてるよ🧹（設定も型安全にしやすい） ([ESLint][3])

---

### まとめ🧸✨

* 重複排除は「同じ行」じゃなくて **同じ知識**を1か所へ🔁🧠
* 手順は「守る→並べる→小さく抽出→置換→確認」👣✅
* まとめすぎるとユーティリティ地獄⚠️（名前と引数の数で見張ろう👀）

[1]: https://vitest.dev/?utm_source=chatgpt.com "Vitest | Next Generation testing framework"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[3]: https://eslint.org/blog/2025/03/eslint-v9.22.0-released/?utm_source=chatgpt.com "ESLint v9.22.0 released"
