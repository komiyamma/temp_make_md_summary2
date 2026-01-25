# 第25章 マジックナンバー・文字列の退治🔢🪄

### ねらい🎯

* 「なんでこの数字？この文字列？」を **意味が伝わる定数** にして、読みやすさ＆安全性を上げる✨
* TypeScriptの型も使って、**タイポ（打ち間違い）や仕様ブレ** を減らす🧷✅

---

### マジックナンバー／マジック文字列って？👻

コードの中に突然出てくる、**意味が分からない数字や文字列**のことだよ🌀

* `0.08`（…税率？割引？なに？）
* `"paid"`（…支払い済み？ `"PAID"` と何が違うの？）
* `86400000`（…1日？ミリ秒？だれか説明して〜😵）

---

### なんで困るの？😣

* **読む人が迷子**になる🧭💦
* **修正漏れ**が起きやすい（同じ数字が複数箇所に散らばる）🔁😱
* **タイポで壊れる**（`"paied"` とか…）⌨️💥
* 仕様変更（税率変更など）が来たときに **地獄**🔥

---

## まずはビフォー→アフターで体感🧩➡️✨

### ビフォー（マジックだらけ😵）

```ts
type Order = {
  price: number;
  status: string; // "pending" | "paid" | "canceled" のつもり…
};

export function calcTotal(order: Order, now: Date) {
  const tax = order.price * 0.1;
  const shipping = order.price >= 5000 ? 0 : 550;

  // 「支払い済み」なら当日中はキャンセル不可…のつもり
  if (order.status === "paid") {
    const diffMs = now.getTime() - new Date("2026-01-01").getTime();
    if (diffMs < 86400000) return order.price + tax + shipping;
  }

  return order.price + tax + shipping;
}
```

どこがツラい？😭

* `0.1` は税率っぽいけど、確信がない
* `5000` は送料無料ライン？それとも別の意味？
* `550` は送料？通貨は？円？
* `"paid"` は打ち間違えたら終わり
* `86400000` は “1日” っぽいけど、ミリ秒って分かりにくい

---

### アフター（意味が読める✨＋型で守る🧷）

```ts
type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];
const OrderStatus = {
  Pending: "pending",
  Paid: "paid",
  Canceled: "canceled",
} as const;

type Order = {
  priceYen: number;      // 単位を名前で出す✨
  status: OrderStatus;   // ここが超大事🧷
};

const TAX_RATE = 0.10;
const FREE_SHIPPING_THRESHOLD_YEN = 5000;
const SHIPPING_FEE_YEN = 550;

const MS_PER_SECOND = 1000;
const SECONDS_PER_DAY = 60 * 60 * 24;
const MS_PER_DAY = MS_PER_SECOND * SECONDS_PER_DAY;

const CANCEL_LIMIT_MS_AFTER_PAID = MS_PER_DAY;

export function calcTotal(order: Order, now: Date) {
  const taxYen = order.priceYen * TAX_RATE;
  const shippingYen =
    order.priceYen >= FREE_SHIPPING_THRESHOLD_YEN ? 0 : SHIPPING_FEE_YEN;

  if (order.status === OrderStatus.Paid) {
    const paidAt = new Date("2026-01-01"); // 例：本当は注文の支払い日時を使う
    const diffMs = now.getTime() - paidAt.getTime();
    if (diffMs < CANCEL_LIMIT_MS_AFTER_PAID) {
      return order.priceYen + taxYen + shippingYen;
    }
  }

  return order.priceYen + taxYen + shippingYen;
}
```

ポイント💡

* **定数名に意味＋単位**（`_YEN`, `_MS`）を入れると事故が減る🛟
* `"paid"` を **`OrderStatus.Paid`** にして、タイポを型で防ぐ🧷✅（`as const` の定番パターンだよ） ([TypeScript][1])
* `MS_PER_DAY` みたいに **分解して書く**と読みやすい🔍✨

ちなみに `as const` は「値をできるだけリテラル型として固定する」仕組みで、enumっぽいパターンも作れるよ🧷 ([TypeScript][1])

---

## 手順（安全に小さく直す👣🛟）

### 1) まず「意味のあるやつ」を探す🔍👃

次の条件なら、定数化候補だよ✅

* 同じ数字/文字列が **複数回** 出る
* 仕様っぽい（税率、上限、閾値、ステータス、URL、キー名…）
* 単位が絡む（円、ms、px、回数…）

---

### 2) いきなり全部置換しない（まず“名前”を置く）🏷️✨

* まず **定数を作る**（まだ1箇所だけ置換でもOK）
* 動くのを確認してから、少しずつ置換範囲を広げる👣

---

### 3) 定数の置き場所は「近く」が基本📍

* その関数だけで使う → **関数の近く**（同ファイル内）
* モジュールで共有 → **そのモジュールの上部**
* プロジェクト全体で共有 → **ドメイン別の定数モジュール**

※なんでも `constants.ts` に投げると、逆に迷子になりがち😵📦

---

## 定数の作り方：どれ使う？🧰✨

### A. ただの `const`（まずはこれでOK）👍

* 数字・文字列・正規表現・閾値など
* 迷ったらこれ！

---

### B. `as const` オブジェクト（マジック文字列退治に強い🧷）

* ステータス・種別・イベント名など
* `type` とセットにすると、**補完が効く＆タイポが死ぬ**💀➡️✅ ([TypeScript][1])

---

### C. `enum`（使ってもOKだけど特徴を知ろう）🧩

TypeScriptの `enum` は「名前付き定数セット」を作れる機能だよ🧷 ([TypeScript][2])
ただし **JS出力にオブジェクトが出る**ので、プロジェクトの方針で好みが分かれることもあるよ🤔

---

### D. `const enum`（玄人寄り⚠️）

`const enum` は参照が **数値/文字列にインライン化**されやすくて軽い反面、設定やビルド方式によって注意点があるよ（例：`preserveConstEnums` など）🧯 ([TypeScript][3])
この教材では、まずは **`as const` パターン**を推しにしておくと安全🍀

---

## よくある落とし穴まとめ🕳️😵

### ❌ 定数名がふわふわ

* `VALUE1`, `TMP`, `NUM` とかはダメ〜🙅‍♀️
  ✅ **意味＋単位＋条件**を入れる
  例：`FREE_SHIPPING_THRESHOLD_YEN`, `MAX_RETRY_COUNT`

### ❌ 0 や 1 まで全部定数化

* `0` が「初期値」って分かる場所なら、そのままでもOK👌
* でも `-1` が「見つからない」みたいな意味なら、`includes` に変えるなど設計で消せることもあるよ✨

### ❌ “同じ数字”でも意味が違うのに共通化

* たまたま `5000` が同じでも

  * 「送料無料ライン」
  * 「ポイント付与ライン」
    みたいに意味が違うなら、**別定数**にするのが正解✅

---

## ミニ課題✍️🌸（やってみよう）

### お題：マジックを定数にして、型で守る🧷

```ts
export function getBadge(status: string, score: number) {
  if (status === "gold" && score >= 80) return "★";
  if (status === "silver" && score >= 60) return "☆";
  if (status === "bronze" && score >= 40) return "△";
  return "-";
}
```

### やること✅

1. `"gold" / "silver" / "bronze"` を **`as const` パターン**で型にする🏷️
2. `80 / 60 / 40` を **意味のある定数**にする🔢
3. ついでに、戻り値の `"★" "☆" "△" "-"` も定数にして読みやすくする✨（余裕があれば）

### 期待する完成イメージ（一例）🌷

* `Status.Gold` みたいに書ける
* `GOLD_MIN_SCORE` みたいな名前がある
* `status: Status` になってて、変な文字列が入らない🧷✅

---

## AI活用ポイント🤖✅（お願い方＋チェック観点）

### 使えるお願い方🪄

* 「この関数のマジックナンバー／文字列を列挙して、**意味の推測**と **定数名候補（単位つき）**を10個出して」
* 「`as const` を使って、タイポを防ぐ型定義に直して。**before/after** で差分も説明して」
* 「定数名が読みやすいかレビューして。**より良い命名案**を3パターン（保守的/ふつう/攻め）で」

### チェック観点✅👀

* 定数名に **単位**が入ってる？（YEN / MS / PX / COUNT など）
* 似た数字を **うっかり同じ定数にしてない？**
* `status: string` が残ってない？（残ってたらタイポ地獄👻）
* 置き場所が変じゃない？（遠すぎる定数は読みにくい🧭）

---

## お守りチェックリスト🧿✨

* 「この数字・文字列、**意味が言える？**」🗣️
* 「**単位**が分かる？」📏
* 「型で守れるところ、守った？」🧷✅
* 「同じ意味は1か所？」🔁
* 「名前を見ただけで仕様が読める？」📖✨

---

### 参考（TypeScript最新＆関連ドキュメント）📚✨

この章の型テクは `as const`（const assertion）や enum の性質がベースだよ🧷 ([TypeScript][4])

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-4.html?utm_source=chatgpt.com "Documentation - TypeScript 3.4"
[2]: https://www.typescriptlang.org/docs/handbook/enums.html?utm_source=chatgpt.com "TypeScript: Handbook - Enums"
[3]: https://www.typescriptlang.org/ja/tsconfig/?utm_source=chatgpt.com "すべてのTSConfigのオプションのドキュメント"
[4]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
