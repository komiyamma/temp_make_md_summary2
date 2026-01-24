## 第3章 リファクタの黄金手順（安全3点セット）🛟✅

### ねらい🎯

リファクタって、やり方を間違えると「どこで壊したか分からない😇」になりがち…！
だからこの章では、**毎回同じ安全手順で進める“型”**を身につけます👣✨
一度この型が入ると、怖さが一気に減ります🧸🫶

---

## リファクタの黄金手順：安全3点セット🛡️🧩✅

### ① 守りを置く（= 壊してない保証を先に作る）🛡️

「変える前に、今の動きを固定」するのが最強です💪✨
守りの例はこんな感じ👇

* **型チェック**（TypeScriptに怒ってもらう🧷）
* **テスト**（“動作は同じ”を機械で確認🧪）
* **Lint/Format**（危ない書き方やブレを減らす👮‍♀️🎀）

> ちなみに TypeScript 5.9 では `tsc --init` が“ミニマルで実用寄り”に改善されていて、最初の土台作りがラクになってます🧱✨ ([TypeScript][1])

---

### ② 小さく変える（= 1回でやるのは1つだけ）👣

1コミット（または1ステップ）でやるのは **「説明できる変更1個」**だけ🧩

例👇

* リネームだけ🏷️
* 関数を1個だけ抽出✂️
* ifのネストを1段だけ減らす🚦
* “同じ処理”を1か所に寄せる🔁

---

### ③ すぐ確認する（= 変えたら即チェック）✅

変えたらすぐ、機械で確認して「OKなら次へ」🏃‍♀️💨
確認が遅れるほど、原因追跡が地獄になります😵‍💫

---

# この章の合言葉🪄

**「守ってから、ちょっと変えて、すぐ確認」**
これを**回転寿司みたいに回す**だけ🍣✨

---

## まず“チェックの形”を作ろう📋✅（例）

プロジェクトにこういう “いつものチェック” があると強いです💪
（名前は何でもOKだよ〜！）

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "test": "vitest",
    "check": "npm run typecheck && npm run lint && npm run test"
  }
}
```

* Vitest は開発中は **watch mode が基本**で、変更に合わせて関連テストを賢く回してくれます🧪⚡ ([Vitest][2])
* ESLint は v9 から **flat config がデフォルト**になっていて、設定の考え方が少しモダン寄りです🧹✨ ([ESLint][3])

---

## コード例（ビフォー/アフター）🧩➡️✨

ここでは「手順の回し方」を体に覚えさせるのが目的だよ💡
題材は“送料ラベル”みたいな小ネタにします📦📮

### Before（ちょいゴチャつき）😵‍💫

```ts
export type Country = "JP" | "US" | "OTHER";

export type Order = {
  totalYen: number;
  country: Country;
  isVip: boolean;
};

export function shippingLabel(order: Order): string {
  let label = "";

  if (order.country === "JP") {
    if (order.totalYen >= 5000) {
      label = "送料無料";
    } else {
      label = "送料 500円";
    }
  } else if (order.country === "US") {
    if (order.totalYen >= 10000) {
      label = "US Free Shipping";
    } else {
      label = "US Shipping $15";
    }
  } else {
    if (order.totalYen >= 12000) {
      label = "Intl Free Shipping";
    } else {
      label = "Intl Shipping $25";
    }
  }

  if (order.isVip) {
    label += " (VIP)";
  }

  return label;
}
```

---

### Step 1：守りを置く（テストで“今の動き”を固定）🛡️🧪

```ts
import { describe, expect, test } from "vitest";
import { shippingLabel } from "../src/shippingLabel";

describe("shippingLabel", () => {
  test("JP", () => {
    expect(shippingLabel({ totalYen: 4999, country: "JP", isVip: false })).toBe("送料 500円");
    expect(shippingLabel({ totalYen: 5000, country: "JP", isVip: false })).toBe("送料無料");
  });

  test("US", () => {
    expect(shippingLabel({ totalYen: 9999, country: "US", isVip: false })).toBe("US Shipping $15");
    expect(shippingLabel({ totalYen: 10000, country: "US", isVip: false })).toBe("US Free Shipping");
  });

  test("VIP suffix", () => {
    expect(shippingLabel({ totalYen: 5000, country: "JP", isVip: true })).toBe("送料無料 (VIP)");
  });
});
```

ここで一回チェック✅

```bash
npm run check
```

---

### Step 2：小さく変える（“送料計算だけ”を関数に分離）👣✂️

狙い：`shippingLabel` から「送料の決定ロジック」を外に出す📤

```ts
export type Country = "JP" | "US" | "OTHER";

export type Order = {
  totalYen: number;
  country: Country;
  isVip: boolean;
};

function baseShippingLabel(country: Country, totalYen: number): string {
  if (country === "JP") return totalYen >= 5000 ? "送料無料" : "送料 500円";
  if (country === "US") return totalYen >= 10000 ? "US Free Shipping" : "US Shipping $15";
  return totalYen >= 12000 ? "Intl Free Shipping" : "Intl Shipping $25";
}

export function shippingLabel(order: Order): string {
  let label = baseShippingLabel(order.country, order.totalYen);

  if (order.isVip) label += " (VIP)";

  return label;
}
```

---

### Step 3：すぐ確認する✅

```bash
npm run check
```

通ったらOK🎉
この**1サイクル**ができたら、次の改善（命名、定数化、分岐整理…）に進めます👣✨

---

## “小さく刻む”コツ集🍀

### ✅ 1回の変更でやっていいのはこれくらい

* 1関数を1個だけ抽出✂️
* 変数名を数個だけ改善🏷️
* ifの否定を1か所だけ直す🚦
* 重複を1か所だけ寄せる🔁

### ❌ やりがちだけど危険⚠️

* テスト無しで大改造🧨
* AIの提案を一気に貼る📎😇
* “ついで修正”を混ぜる🔀（リファクタじゃなくなる！）

---

## 手順（小さく刻む）👣🗺️：毎回これ！

1. **守りを置く**（型/テスト/Lintのどれか1つでもいい）🛡️
2. **変更を1つだけ**入れる👣
3. **チェックを回す**（typecheck/test/lint/run）✅
4. **差分を見る**（意図どおり？余計な変更ない？）👀
5. **コミット**（説明できる単位）💾

---

## ミニ課題✍️：手順カードを並べ替えよう🃏✨

次のカードを、正しい順番にしてみてね👇（答えは自分で並べ替え！🧠）

* A：チェックを回す✅
* B：守りを置く🛡️
* C：小さく変える👣
* D：差分を見る👀
* E：コミットする💾

---

## ミニ課題✍️：あなたのコードで1サイクル回してみよう🧸🧑‍💻

1. 直したい関数を1つ選ぶ（20〜60行くらいがちょうどいい）🎯
2. “今の動き”が分かるテストを1本だけ作る🧪
3. 変更は **1つだけ**（リネーム or 抽出など）👣
4. `npm run check` を回す✅
5. 差分を見て、コミット💾

---

## AI活用ポイント🤖✅（お願い方＋チェック観点）

### お願い方テンプレ✍️🤖

コピペして使ってOK〜！

```text
この関数をリファクタしたいです。
条件：
- 挙動は変えない（重要）
- 変更は「1ステップ分」だけ提案して
- そのステップで追加/修正すべきテストも提案して
- 変更後に確認するチェック項目（typecheck/test/lint/run）も出して
対象コード：
（ここに貼る）
```

### AIの提案を採用する前のチェック✅🕵️‍♀️

* 差分が「小さい」？👣
* “ついで修正”混ざってない？🔀
* 型チェック通る？🧷
* テスト通る？🧪
* 変更の説明ができる？📝

---

## ちょい最新メモ🗞️✨（安心材料）

TypeScript は今後、ネイティブ実装（高速化）に向けた流れが進んでいて、**6.0 は 5.9 と次世代の橋渡し（bridge）**という位置づけが公式に説明されています🏗️✨ ([Microsoft for Developers][4])
だからこそ、今のうちから「安全に直せる手順」を持ってると、将来の更新にも強いよ〜🛡️💪

---

## まとめ🌸

* リファクタは **手順が9割**🛟
* **守り → 小さく → すぐ確認** を回すだけ🍣✨
* AIは便利だけど、**チェックしてから採用**が鉄則🤖✅

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[2]: https://vitest.dev/guide/features?utm_source=chatgpt.com "Features | Guide"
[3]: https://eslint.org/docs/latest/use/configure/migration-guide?utm_source=chatgpt.com "Configuration Migration Guide"
[4]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
