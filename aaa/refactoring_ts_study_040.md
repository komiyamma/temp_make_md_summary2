# 第40章 総合演習：段階リファクタで完成させる🎓✅🤖

### ねらい🎯

* 「守りを置く→小さく改善→すぐ確認」を、最初から最後まで1回通して体に覚えさせる👣🛟
* AI提案を“安全に”使うコツ（分割・検証・差分の読み方）を身につける🤖✅
* TypeScriptらしい型の力で、バグりにくい形に整える🧷✨

---

### 最新スナップショット（いまの前提がズレないように）🧭✨

* TypeScript は 5.9 系が「最新」として配布されていて、5.9 のリリースノートも公開済み📌 ([NPM][1])
* Node.js は 24 系が LTS としてリリースされているよ🟢 ([Node.js][2])
* ESLint は v9 で “Flat Config（eslint.config.*）” が中心になってる流れ🧹 ([ESLint][3])
* Vitest は 4.0 が出ていて、テスト環境づくりが軽いのが嬉しい🧪🚀 ([Vitest][4])

---

## 今日のお題：レシート生成ミニアプリ🧾✨

「注文データ（JSON）」から、割引・送料・税・ポイント適用を計算して、レシート文字列を出す小さなアプリを完成させるよ💪😊
わざと“臭いコード”になってるので、段階的に直してピカピカにする✨👃

---

## ゴール🏁（成果物）

* ✅ `npm test` がいつでも通る🧪
* ✅ 型チェックで怪しい値が入りにくい🧷
* ✅ 計算ロジックが “I/O（ファイル読み書き）” から分離されてテストしやすい🚪🧪
* ✅ 変更が「小さいコミット」で説明できる💾📝
* ✅ AI提案を採用しても、必ず検証で安全が担保できる🤖✅

---

## 1) スタート地点（わざと臭いレガシー）👃💥

### ファイル構成（最小）📁

* `src/legacy.ts` … なんでもごちゃ混ぜの計算＋ファイル書き込み😵‍💫
* `src/cli.ts` … コマンドから呼ぶだけ🖥️
* `orders/sample-order.json` … 入力データ📦

### まずはこの“ビフォー”を用意🧩（コピーしてOK）

```ts
// src/legacy.ts
import { readFile, writeFile } from "node:fs/promises";

export async function doStuff(inputPath: string) {
  const txt = await readFile(inputPath, "utf8");
  const o: any = JSON.parse(txt);

  let sum = 0;

  for (let i = 0; i < o.items.length; i++) {
    const it = o.items[i];
    let p = it.price;

    if (it.type === "digital") p = p * 0.9; // 10% off
    if (o.user && o.user.level === "gold") p = p * 0.95; // gold 5% off

    sum += p * it.qty;
  }

  // coupon: "OFF500" or "RATE10"
  if (o.coupon) {
    if (o.coupon.startsWith("OFF")) {
      sum = sum - parseInt(o.coupon.replace("OFF", ""));
    } else if (o.coupon.startsWith("RATE")) {
      const r = parseInt(o.coupon.replace("RATE", "")) / 100;
      sum = sum - sum * r;
    }
  }

  let ship = 0;
  if (o.address && o.address.country === "JP") {
    ship = sum > 5000 ? 0 : 500;
  } else {
    ship = 2500;
  }

  const tax = Math.floor((sum + ship) * 0.1);
  const total = sum + ship + tax;

  const point = o.usePoint ? Math.min(o.usePoint, total * 0.2) : 0;
  const pay = total - point;

  const msg =
    `USER:${(o.user && o.user.name) || "??"}\n` +
    `SUM:${Math.round(sum)}\n` +
    `SHIP:${ship}\n` +
    `TAX:${tax}\n` +
    `POINT:${Math.round(point)}\n` +
    `PAY:${Math.round(pay)}\n`;

  await writeFile("receipt.txt", msg, "utf8");
  return msg;
}
```

```ts
// src/cli.ts
import { doStuff } from "./legacy";

const input = process.argv[2] ?? "orders/sample-order.json";
doStuff(input).then((msg) => console.log(msg));
```

```json
// orders/sample-order.json
{
  "user": { "name": "Mina", "level": "gold" },
  "address": { "country": "JP" },
  "coupon": "OFF500",
  "usePoint": 300,
  "items": [
    { "name": "Ebook", "type": "digital", "price": 1200, "qty": 1 },
    { "name": "Sticker", "type": "physical", "price": 400, "qty": 2 }
  ]
}
```

### このコードの“臭い”チェック👃📝

* `any` で何でも通る（事故りやすい）🧨
* 計算とファイル書き込みが一緒（テストしづらい）😵
* マジックナンバー（0.9 / 0.95 / 5000 / 0.1 / 0.2 …）🔢
* 文字列クーポンのパースが直書き（壊れやすい）🧵
* お金を `number` で雑に扱う（小数・丸めが混ざる）💸

---

## 2) 段階リファクタの全手順（この順でやる）🗺️👣

### ステップ0：作業を小さく刻む準備💾🌿

* ブランチ作る🌿
* 「1コミット＝1説明」を守る👣📌
  例）
* `test: add golden master`
* `refactor: extract calculation`
* `refactor: introduce types`
* `refactor: split IO from domain`

---

## 3) 守り①：ゴールデンマスター（現状出力を固定）👑🛟

「動作を変えてない」を証明する最短ルート✨
まずは `doStuff()` の戻り値（レシート文字列）を固定しよう🧾✅

### テスト例（Vitest）🧪

```ts
// test/legacy.test.ts
import { describe, it, expect } from "vitest";
import { doStuff } from "../src/legacy";
import { writeFile } from "node:fs/promises";

describe("golden master", () => {
  it("sample order receipt stays same", async () => {
    // ついでに毎回同じ入力になるように、テスト内でサンプルを書いてもOK👌
    await writeFile(
      "orders/__tmp.json",
      JSON.stringify({
        user: { name: "Mina", level: "gold" },
        address: { country: "JP" },
        coupon: "OFF500",
        usePoint: 300,
        items: [
          { name: "Ebook", type: "digital", price: 1200, qty: 1 },
          { name: "Sticker", type: "physical", price: 400, qty: 2 }
        ]
      }),
      "utf8"
    );

    const receipt = await doStuff("orders/__tmp.json");
    expect(receipt).toMatchInlineSnapshot(`
"USER:Mina
SUM:1301
SHIP:500
TAX:180
POINT:300
PAY:1681
"
`);
  });
});
```

> 💡まずはこのテストが通ればOK！数字が「え、なにこれ？」でも気にしないでね。
> 今は“固定する”だけが目的👑🛟（理解はあとでOK）

### AI活用ポイント🤖✅

**お願い例🗣️**

* 「この関数の入出力を変えずに、テストを書きたい。Vitestで最小のゴールデンマスターテストを書いて」
  **チェック観点✅**
* 生成されたスナップショットが“今の出力”と一致してる？
* 余計なリファクタを混ぜてない？（テスト追加だけになってる？）

---

## 4) 守り②：フォーマット＆Lint（差分を読みやすく）🎀👮‍♀️

ここは“見た目の安定”で、後の差分レビューが楽になる✨

### VS Codeのリファクタ操作も使うよ🧑‍💻🪄

* **Rename Symbol（F2）** で安全に名前変更できる🏷️ ([Visual Studio Code][5])
* **Copilot Chat** で「小さく直す提案」を出させる🤖💬 ([Visual Studio Code][6])

### ESLint（Flat Config）最小セット例🧹

typescript-eslint の Quickstart は、Flat Config 前提でこういう構成になってるよ📌 ([TypeScript ESLint][7])

```js
// eslint.config.mjs
import eslint from "@eslint/js";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig(
  eslint.configs.recommended,
  tseslint.configs.recommended
);
```

---

## 5) 改善①：名前を直す（読めるようにする）🏷️✨

まずは“意味が伝わる名前”にするだけで、脳みそが楽になる🧠💕

### 例（小さなリネーム）👣

* `doStuff` → `generateReceiptFromFile`
* `o` → `order`
* `sum` → `subtotal`

⚠️この時点ではロジックは変えない！
「名前だけ」コミットにする💾✅

### AI活用ポイント🤖✅

**お願い例🗣️**

* 「このコード、意味が伝わる命名にしたい。関数名・変数名の候補を“変更量少なめ”で提案して」
  **チェック観点✅**
* 参照先も全部更新されてる？（F2が強い💪）
* “命名以外”の変更が混ざってない？（混ざったら分割👣）

---

## 6) 改善②：計算を“純粋関数”に抜き出す🚪🧪

ここが本章の山場⛰️✨
「計算（ドメイン）」と「ファイル（I/O）」を分離すると、テストが一気に楽になるよ🧪🥳

### やること👣

1. `calculateReceipt(order)` を作る（中身は legacy からコピーでOK）📦
2. `generateReceiptFromFile` は「読む→parse→calculate→書く」だけに薄くする🪶
3. 追加で “計算だけのユニットテスト” を作る🧪✨

---

## 7) 改善③：型でバグを封じる🧷🛡️

### まず “型の骨格” を作る🦴✨

```ts
// src/domain.ts
export type MemberLevel = "regular" | "gold";

export type ItemType = "digital" | "physical";

export type Coupon =
  | { kind: "none" }
  | { kind: "fixed"; amountYen: number }
  | { kind: "rate"; percent: number };

export type Order = {
  userName: string;
  level: MemberLevel;
  country: "JP" | "OTHER";
  coupon: Coupon;
  usePointYen: number;
  items: Array<{
    name: string;
    type: ItemType;
    priceYen: number;
    qty: number;
  }>;
};

export type Receipt = {
  userName: string;
  subtotalYen: number;
  shippingYen: number;
  taxYen: number;
  pointUsedYen: number;
  payYen: number;
};
```

### 文字列クーポンを “安全にパース” する（unknown→narrowing）🔍🧷

```ts
// src/parse.ts
import type { Coupon } from "./domain";

export function parseCoupon(raw: unknown): Coupon {
  if (typeof raw !== "string" || raw.length === 0) return { kind: "none" };

  if (raw.startsWith("OFF")) {
    const n = Number(raw.slice(3));
    return Number.isFinite(n) ? { kind: "fixed", amountYen: Math.max(0, Math.trunc(n)) } : { kind: "none" };
  }

  if (raw.startsWith("RATE")) {
    const p = Number(raw.slice(4));
    const percent = Number.isFinite(p) ? Math.max(0, Math.min(100, Math.trunc(p))) : 0;
    return { kind: "rate", percent };
  }

  return { kind: "none" };
}
```

---

## 8) アフター例（完成形のイメージ）✨🧾

「計算」と「I/O」が分かれてるのがポイントだよ👍

```ts
// src/calculate.ts
import type { Coupon, ItemType, Order, Receipt } from "./domain";

const TAX_RATE = 0.1;
const DIGITAL_DISCOUNT = 0.9;
const GOLD_DISCOUNT = 0.95;
const FREE_SHIPPING_THRESHOLD_YEN = 5000;
const JP_SHIPPING_YEN = 500;
const OVERSEAS_SHIPPING_YEN = 2500;
const MAX_POINT_RATE = 0.2;

function itemDiscountRate(type: ItemType): number {
  return type === "digital" ? DIGITAL_DISCOUNT : 1;
}

function memberDiscountRate(level: Order["level"]): number {
  return level === "gold" ? GOLD_DISCOUNT : 1;
}

function applyCoupon(subtotalYen: number, coupon: Coupon): number {
  if (coupon.kind === "none") return subtotalYen;
  if (coupon.kind === "fixed") return Math.max(0, subtotalYen - coupon.amountYen);
  // rate
  const off = Math.floor((subtotalYen * coupon.percent) / 100);
  return Math.max(0, subtotalYen - off);
}

function calcShippingYen(afterDiscountYen: number, country: Order["country"]): number {
  if (country === "JP") return afterDiscountYen > FREE_SHIPPING_THRESHOLD_YEN ? 0 : JP_SHIPPING_YEN;
  return OVERSEAS_SHIPPING_YEN;
}

export function calculateReceipt(order: Order): Receipt {
  const subtotalYen = order.items.reduce((acc, it) => {
    const base = it.priceYen * it.qty;
    const rate = itemDiscountRate(it.type) * memberDiscountRate(order.level);
    return acc + Math.round(base * rate);
  }, 0);

  const discountedYen = applyCoupon(subtotalYen, order.coupon);
  const shippingYen = calcShippingYen(discountedYen, order.country);

  const taxBase = discountedYen + shippingYen;
  const taxYen = Math.floor(taxBase * TAX_RATE);

  const totalYen = taxBase + taxYen;

  const maxPoint = Math.floor(totalYen * MAX_POINT_RATE);
  const pointUsedYen = Math.max(0, Math.min(order.usePointYen, maxPoint));
  const payYen = totalYen - pointUsedYen;

  return {
    userName: order.userName,
    subtotalYen: discountedYen,
    shippingYen,
    taxYen,
    pointUsedYen,
    payYen
  };
}
```

---

## 9) 仕上げ：AIを“レビュワー”として使う🤖🔍

AIは便利だけど、**採用の責任は人間**だよ✋🙂
だから、お願いの仕方を“安全寄り”にするのがコツ！

### 鉄板プロンプト（コピペOK）📋🤖

* 「変更を1コミット分に収めたい。今回の目的は “計算を純粋関数に分けるだけ”。それ以外は触らない手順を箇条書きで」
* 「この差分、振る舞いが変わってないか“疑う視点”でレビューして。特に丸め・境界値・null系」
* 「テストケースを増やしたい。過不足なく、境界値（0 / 1 / 4999 / 5000 / 5001 など）を提案して」

---

## 10) 最終チェック（お守りチェックリスト）🧿✨

* 変更は小さい？👣
* テストは常に通る？🧪✅
* 型チェックで守れてる？🧷
* I/O と計算が分かれてる？🚪
* 差分を説明できる？📝
* AIの提案を“そのまま採用”してない？🤖⚠️

---

## ミニ課題✍️🌸（仕上げの3問）

1. **境界値テスト**を追加しよう🧪

* JP・OTHER、送料境界（5000前後）、ポイント上限（20%）の3つを必ず入れる✅

2. **クーポン拡張**を“安全に”やろう🎟️

* `BOGO`（1個買うと1個無料）みたいな新ルールを追加したい！
* まずは `Coupon` を判別可能 Union で増やして、`switch` の取りこぼしがコンパイルで出る形にしてみてね🧷✅

3. **I/O差し替え**🔌

* ファイル読み書きじゃなくて「メモリ上の配列」から注文を取る実装に変えても、計算テストが壊れないことを確認しよう📦🧪

---

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[2]: https://nodejs.org/en/blog/release/v24.13.0?utm_source=chatgpt.com "Node.js 24.13.0 (LTS)"
[3]: https://eslint.org/blog/2024/04/eslint-v9.0.0-released/?utm_source=chatgpt.com "ESLint v9.0.0 released - ESLint - Pluggable JavaScript Linter"
[4]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[5]: https://code.visualstudio.com/docs/typescript/typescript-refactoring?utm_source=chatgpt.com "Refactoring TypeScript"
[6]: https://code.visualstudio.com/docs/copilot/chat/copilot-chat?utm_source=chatgpt.com "Get started with chat in VS Code"
[7]: https://typescript-eslint.io/getting-started/ "Getting Started | typescript-eslint"
