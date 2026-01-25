# 第21章 Extract Function（長い関数を分割）✂️📦

### ねらい🎯

* 長い関数を「目的ごと」に切り分けて、読みやすくする📖✨
* 変更に強くして、バグの入り込みを減らす🛡️🐛
* VS Codeの「Extract function」を使って安全に分割できるようになる🧑‍💻💡 ([Visual Studio Code][1])

---

### まず最初に覚える合言葉🧠✨

* **1関数 = 1つの仕事**が理想💼🍀
* 「この塊、コメント付けたくなる…」は **切り出しチャンス**📝➡️✂️
* 「ここだけ再利用したい」「ここだけテストしたい」も **切り出しチャンス**🧪💞

---

## 1) 「切り出す場所」の見つけ方🔍👀

### ✅ よくある“切り出しサイン”👃✨

* 同じ関数の中に、**やってることが3種類以上**ある（検証/計算/整形/保存…みたいに）🍱
* 途中から **話題が変わる**（例：金額計算してたのに、急に表示用文字列を作り始める）🌀
* 変数が増えすぎて、**スクロールしないと全体が見えない**📜😵
* 「この5〜10行だけ理解すればいいのに…」って気持ちになる🥺✂️
* `if` や `try` が増えて、流れが見えにくい🌲😵‍💫

---

## 2) 安全に進める“最短ループ”🛟✅

分割は「動作を変えない」改善だから、毎回これで守るよ🧷✨

1. 変更前に **型チェック & テスト & 実行** ✅🧷🧪
2. 小さく切り出す（1か所だけ）👣✂️
3. すぐ **型チェック & テスト** ✅🧷🧪
4. 差分を見て「動きは同じ？」を確認👀🔁

---

## 3) VS Codeで Extract Function を使う💡✂️

やり方はシンプル🎀

1. 切り出したい行をドラッグで選択🖱️
2. **Ctrl + .**（クイックフィックス）を押す⌨️✨
3. **Extract function**（または Extract Method）を選ぶ✂️📦
4. 関数名を付ける🏷️🌸

VS CodeはTypeScriptで **Extract function** をサポートしてるよ🧑‍💻💡 ([Visual Studio Code][1])

---

## 4) 例でやってみよう（Before/After）🧩➡️✨

### お題：注文の合計を作る関数が長い…🛒💸

#### Before（長い関数😵‍💫）

```ts
type CartItem = {
  id: string;
  name: string;
  price: number; // 税抜のつもり
  qty: number;
};

type CheckoutInput = {
  items: CartItem[];
  couponCode?: string;
  prefecture: "tokyo" | "osaka" | "other";
};

type CheckoutResult = {
  subtotal: number;
  discount: number;
  shipping: number;
  tax: number;
  total: number;
  summaryText: string;
};

export function checkout(input: CheckoutInput): CheckoutResult {
  // 1) 入力チェック
  if (input.items.length === 0) {
    throw new Error("カートが空です");
  }
  for (const item of input.items) {
    if (item.qty <= 0) {
      throw new Error(`数量が不正: ${item.name}`);
    }
    if (item.price < 0) {
      throw new Error(`価格が不正: ${item.name}`);
    }
  }

  // 2) 小計
  let subtotal = 0;
  for (const item of input.items) {
    subtotal += item.price * item.qty;
  }

  // 3) 割引（クーポン）
  let discount = 0;
  if (input.couponCode === "OFF10") {
    discount = Math.floor(subtotal * 0.1);
  } else if (input.couponCode === "OFF500") {
    discount = 500;
  }
  if (discount > subtotal) discount = subtotal;

  // 4) 送料（雑な例）
  let shipping = 0;
  const afterDiscount = subtotal - discount;
  if (afterDiscount < 3000) {
    shipping = input.prefecture === "tokyo" ? 350 : 500;
  }

  // 5) 税（10%）
  const tax = Math.floor((afterDiscount + shipping) * 0.1);

  // 6) 合計
  const total = afterDiscount + shipping + tax;

  // 7) 表示用テキスト
  const lines: string[] = [];
  lines.push(`小計: ¥${subtotal.toLocaleString("ja-JP")}`);
  lines.push(`割引: -¥${discount.toLocaleString("ja-JP")}`);
  lines.push(`送料: ¥${shipping.toLocaleString("ja-JP")}`);
  lines.push(`税: ¥${tax.toLocaleString("ja-JP")}`);
  lines.push(`合計: ¥${total.toLocaleString("ja-JP")}`);
  const summaryText = lines.join("\n");

  return { subtotal, discount, shipping, tax, total, summaryText };
}
```

この関数、やってることが **7種類** もあるよね…🍱💦
だから「目的ごと」に切り出して、`checkout()` を“司令塔”にしよう👑✨

---

### After（Extract Functionで分割✨）

ポイントは「①検証」「②計算」「③表示」を分けること🎯🌸

```ts
type CartItem = {
  id: string;
  name: string;
  price: number;
  qty: number;
};

type CheckoutInput = {
  items: CartItem[];
  couponCode?: string;
  prefecture: "tokyo" | "osaka" | "other";
};

type CheckoutResult = {
  subtotal: number;
  discount: number;
  shipping: number;
  tax: number;
  total: number;
  summaryText: string;
};

export function checkout(input: CheckoutInput): CheckoutResult {
  validateCart(input.items);

  const subtotal = calcSubtotal(input.items);
  const discount = calcDiscount(subtotal, input.couponCode);

  const afterDiscount = subtotal - discount;
  const shipping = calcShipping(afterDiscount, input.prefecture);
  const tax = calcTax(afterDiscount + shipping);

  const total = afterDiscount + shipping + tax;
  const summaryText = buildSummaryText({ subtotal, discount, shipping, tax, total });

  return { subtotal, discount, shipping, tax, total, summaryText };
}

// --- Extracted functions ✂️ ---

function validateCart(items: CartItem[]): void {
  if (items.length === 0) throw new Error("カートが空です");

  for (const item of items) {
    if (item.qty <= 0) throw new Error(`数量が不正: ${item.name}`);
    if (item.price < 0) throw new Error(`価格が不正: ${item.name}`);
  }
}

function calcSubtotal(items: CartItem[]): number {
  let subtotal = 0;
  for (const item of items) subtotal += item.price * item.qty;
  return subtotal;
}

function calcDiscount(subtotal: number, couponCode?: string): number {
  let discount = 0;

  if (couponCode === "OFF10") discount = Math.floor(subtotal * 0.1);
  else if (couponCode === "OFF500") discount = 500;

  return Math.min(discount, subtotal);
}

function calcShipping(afterDiscount: number, prefecture: CheckoutInput["prefecture"]): number {
  if (afterDiscount >= 3000) return 0;
  return prefecture === "tokyo" ? 350 : 500;
}

function calcTax(amount: number): number {
  return Math.floor(amount * 0.1);
}

function yen(n: number): string {
  return `¥${n.toLocaleString("ja-JP")}`;
}

function buildSummaryText(values: Omit<CheckoutResult, "summaryText">): string {
  const { subtotal, discount, shipping, tax, total } = values;
  return [
    `小計: ${yen(subtotal)}`,
    `割引: -${yen(discount)}`,
    `送料: ${yen(shipping)}`,
    `税: ${yen(tax)}`,
    `合計: ${yen(total)}`,
  ].join("\n");
}
```

### どう良くなった？🌸✨

* `checkout()` が **読み物みたいに読める**📖💕
* 割引や送料だけ直したいとき、**見る場所が一発で分かる**🎯
* `calcDiscount()` みたいな小さな関数は **テストしやすい**🧪✨
* 表示用の処理（`buildSummaryText`）が独立して、混ざらない🎀🧼

---

## 5) “いい切り出し”のコツ🏷️✨

### ✅ 関数名は「やってること」をそのまま書く✍️💕

* `calcSubtotal`（小計を計算する）
* `validateCart`（カートを検証する）
* `buildSummaryText`（表示文を組み立てる）

迷ったら、この型が強いよ👇

* `validateXxx` ✅
* `calcXxx` 🧮
* `buildXxx` 🧱
* `formatXxx` 🎀
* `getXxx`（取得だけのとき）📥

---

## 6) Extract Functionの落とし穴⚠️🕳️（ここ大事！）

### ① 依存が多すぎる塊は、まず整地する🌱

切り出したい部分が **周りの変数にべったり** だと、引数が増えがち😵
そのときは先にこれ👇

* その塊が使う値を、直前で変数にまとめる🧺
* 途中で作ってる値を「戻り値」にする（またはオブジェクトで返す）📦

### ② `this` が絡むときは特に注意👀⚡

クラスのメソッド内で切り出すと、`this` の参照が関係してくることがあるよ💦

* 「関数に切り出す」より「メソッドに切り出す」ほうが自然な場合もある🏫
* うまくいかないときは、いったん **引数で渡す** のが安全🛟

### ③ 副作用（外部を変える処理）は分けて考える🧨

* 例：ログ出力、DB更新、HTTP送信、ファイル書き込み…📤
  こういうのは、**計算（純粋）** と **I/O** を分けると超スッキリするよ✨🚪

---

## 7) ミニ課題✍️🎀（30分）

次のどれか1つでOK🌸

### 課題A：30行関数を3〜5個に分割✂️📦

* 目標：`main()` が上から読める文章みたいになる📖✨
* チェック：

  * 1つの切り出しが「1目的」になってる？🎯
  * 関数名だけで何してるか分かる？🏷️

### 課題B：表示処理だけを分離🎀🧼

* 目標：計算ロジックと表示ロジックが混ざらない🍱➡️🍽️

### 課題C：切り出した関数にテストを1本🧪🥚

* 目標：`calcDiscount()` みたいな小さな関数に「安心」を付ける🛡️✨

---

## 8) AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### ① 切り出し候補を見つけてもらう🔍

* 「この関数、目的ごとの塊に分けるなら、どこで区切る？」✂️
* 「切り出した関数名の候補を10個出して（動詞から始めて）」🏷️💨

### ② 引数/戻り値の設計を手伝ってもらう📦

* 「この塊を関数にするとき、必要な引数と戻り値の案を3つ」🧠✨
* 「引数が増えすぎる場合、オブジェクト化する案も出して」🧺📦

### ③ 変更が“動作を変えてないか”チェックさせる✅

* 「Before/Afterの差分を見て、挙動が変わる可能性がある点を列挙して」👀⚠️
* 「境界条件（空配列、0、負数、大きな値）を洗い出して」🧪📋

---

## 9) 2026/01時点メモ🆕🗒️

* TypeScriptの配布情報では、最新系として **5.9系** が案内されていて、npm上の “Latest” も 5.9.3 になってるよ📦✨ ([TypeScript][2])
* TypeScriptは今後の大きな進化として、**TypeScript 6.0/7.0** に向けた計画や進捗も公開されているよ🛤️🚀 ([Microsoft for Developers][3])

---

### まとめ🎀✨

* 長い関数は「目的ごと」に切る✂️📦
* `checkout()` みたいな“司令塔”を作ると、読むのも直すのも楽になる👑📖
* VS Codeの Extract function を使うと安全に進めやすい💡🛟 ([Visual Studio Code][1])

[1]: https://code.visualstudio.com/docs/languages/typescript?utm_source=chatgpt.com "TypeScript in Visual Studio Code"
[2]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
