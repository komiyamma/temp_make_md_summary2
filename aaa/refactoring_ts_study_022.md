# 第22章 Inline / Extract Variable（変数の整理）🧺🪄

## ねらい🎯

* ごちゃっとした式を「名前付きメモ」にして読みやすくする📝✨
* 逆に、意味のない変数は消してスッキリさせる🧹🌿
* 将来の変更が怖くないコードに近づける🛡️💞

---

## まずは2つの魔法🪄✨

### ✅ Extract Variable（変数を取り出す）

長い式や「何してるの？」が分かりにくい計算に、**名前を付ける**やつだよ👀🏷️
→ 目的：**読む人の脳の負担を減らす**🧠💤

### ✅ Inline Variable（変数をインライン化）

「それ、変数にする意味ある？」ってやつを、**式に戻して消す**やつだよ🫧🗑️
→ 目的：**余計な行とノイズを減らす**📉✨

---

## ビフォー/アフター①：Extract Variable（読みにくい式に名前をつける）✍️🧩

### Before（読むのがつらい式😵‍💫）

```ts
type CartItem = { price: number; quantity: number };

function calcCheckoutTotal(items: CartItem[], couponRate: number, isMember: boolean) {
  return Math.floor(
    (items.reduce((sum, item) => sum + item.price * item.quantity, 0) *
      (1 - couponRate) *
      (isMember ? 0.95 : 1) +
      (items.length === 0 ? 0 : 550)) * // 送料っぽい何か
      1.1 // 税っぽい何か
  );
}
```

「何をしてるのか」は分かる…けど、**目が滑る**🥲🌀

---

### After（名前付きメモでスッキリ😌✨）

```ts
type CartItem = { price: number; quantity: number };

function calcCheckoutTotal(items: CartItem[], couponRate: number, isMember: boolean) {
  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const discounted = subtotal * (1 - couponRate);
  const memberDiscounted = discounted * (isMember ? 0.95 : 1);

  const shippingFee = items.length === 0 ? 0 : 550;
  const beforeTax = memberDiscounted + shippingFee;

  const taxRate = 1.1;
  const total = Math.floor(beforeTax * taxRate);

  return total;
}
```

✅ 変数名が「説明」になってるから、読むのがラクになるよ〜🥰📚

---

## 手順（安全に小さく👣🛟）

1. **式のかたまり**を見つける👀

   * 例：`reduce(...)`、`* (1 - couponRate)`、`items.length === 0 ? ...` など
2. そのかたまりに「意味が分かる名前」を付けて `const` にする🏷️✨
3. 置き換える🔁
4. **動作チェック**（テスト/型チェック/実行）✅🧪
5. もう一回読んで、名前が微妙ならリネーム🧠💡

---

## コツ集（ここで差がつく😎✨）

### 1) 「何の値？」が伝わる名前にする🏷️

* `tmp`, `result2`, `value` ← つらい🥲
* `subtotal`, `shippingFee`, `beforeTax` ← やさしい🥰

### 2) 取り出しすぎ注意⚠️

* 1行の単純な式まで全部変数化すると、逆に読みにくくなることも😵
* 目安：**読んだ瞬間に意味が浮かばない式**を優先して抽出しよ🫶

### 3) Inlineするときは「副作用」と「重い処理」に注意🔥

たとえばこういうの👇

```ts
const x = fetchSomething(); // これが重い/副作用ありだと危険かも
return x + x;
```

これを安易に Inline して👇

```ts
return fetchSomething() + fetchSomething();
```

ってすると、**2回呼ばれて挙動が変わる**かも😱💥
👉 Inline は「式が安全（だいたい純粋）」で「回数が増えない」時にね✅

### 4) TypeScriptの型の話：条件を変数にすると、絞り込みが効きにくい時がある🧷⚠️

TypeScript には「条件を別名にしても追跡してくれる」仕組みがあるよ（Control Flow Analysis）📌 ([TypeScript][1])
でも、ケースによっては **うまく絞り込めない**こともある（特にプロパティ絡みなど）😵‍💫 ([Stack Overflow][2])
👉 「if の中に条件を直書きする」ほうが安全な場面もあるよ🛟

---

## ビフォー/アフター②：Inline Variable（邪魔な変数を消す）🧹✨

### Before（ただの中継点🚧）

```ts
function formatUserName(first: string, last: string) {
  const full = `${last} ${first}`;
  const result = full;
  return result;
}
```

`result` いらないよね😆🗑️

### After（スッキリ🌿）

```ts
function formatUserName(first: string, last: string) {
  const full = `${last} ${first}`;
  return full;
}
```

さらに `full` も一回しか使わない＆意味が薄いなら…

```ts
function formatUserName(first: string, last: string) {
  return `${last} ${first}`;
}
```

---

## VS Codeで秒速でやる⚡🧑‍💻

* 式を選択 → 💡（電球）やクイックフィックスから **Extract to constant / variable** を選ぶ✨
* 逆に、変数の上で 💡 から **Inline variable** を選べることもあるよ🪄

あと、VS Code は「ワークスペースの TypeScript」を使う設定にできるよ（プロジェクトの TS と揃えると、型チェックやリファクタの動きが安定しやすい）🔧✨
その場合は **TypeScript: Select TypeScript Version** で切り替える流れになるよ📌 ([Visual Studio Code][3])

---

## ミニ課題✍️🎀（手を動かすと一気に身につく！）

### 課題コード（ビフォー）

```ts
type Item = { price: number; qty: number };
type Order = { items: Item[]; couponRate: number | null; isMember: boolean };

export function calc(order: Order) {
  const a = order.items.reduce((s, it) => s + it.price * it.qty, 0);
  const b = order.couponRate === null ? 0 : order.couponRate;
  const c = a * (1 - b) * (order.isMember ? 0.9 : 1);
  const d = c;
  return Math.round(d);
}
```

### やること✅

1. `a`, `b`, `c` を **意味が分かる名前**にリネームしよう🏷️✨
2. `d` を **Inline Variable** で消そう🧹
3. 「読んだだけで処理が追えるか？」を自分でチェック👀💞

### できたかチェック✅

* 変数名だけで流れが分かる？🧠✨
* 余計な中継変数が消えてる？🗑️
* 動作（計算結果）が変わってない？🔁✅

---

## AI活用ポイント🤖💡（Copilot / Codex でやると爆速）

### ① 変数名の候補を出してもらう🏷️

お願い例📝

* 「この式を Extract Variable したい。意味が伝わる変数名を5個出して。英語で」
* 「この変数名、短すぎるかも。読みやすい命名に直して」

### ② Inline / Extract の安全チェックをさせる🛟

お願い例🧪

* 「この変数をインライン化すると副作用や呼び出し回数が増える危険ある？」
* 「この抽出はやりすぎ？ まとめた方が読みやすい？」

### ③ AIの提案を採用する前のチェック項目✅🤖

* 呼び出し回数が増えてない？（重い処理/副作用）🔥
* 変数名が “説明” になってる？🏷️
* 1つの変数に意味を詰め込みすぎてない？📦⚠️
* 型エラー/警告が増えてない？🧷

---

## ちょいメモ🗞️✨

最近の TypeScript は、エディタや watch モードの体験が良くなる最適化が継続的に入ってるよ（編集→確認が快適になりやすい）🚀 ([Microsoft for Developers][4])
VS Code も 2026年1月に向けた更新が出ていて、リリースノートが定期的に更新されてるよ📌 ([Visual Studio Code][5])

---

## まとめ🌸

* **Extract Variable**：読みにくい式に「名前」をつけて理解を助ける🏷️✨
* **Inline Variable**：意味のない中継変数を消してノイズを減らす🧹🌿
* どっちも「動作を変えない」が大前提！副作用と回数増加だけは要注意だよ🛟💥

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-4.html?utm_source=chatgpt.com "Documentation - TypeScript 4.4"
[2]: https://stackoverflow.com/questions/70244142/why-doesnt-a-type-narrowing-check-of-a-class-property-not-work-when-assigned-to?utm_source=chatgpt.com "Why doesn't a type narrowing check of a class property not ..."
[3]: https://code.visualstudio.com/docs/typescript/typescript-compiling?utm_source=chatgpt.com "Compiling TypeScript"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-8/?utm_source=chatgpt.com "Announcing TypeScript 5.8"
[5]: https://code.visualstudio.com/updates?utm_source=chatgpt.com "December 2025 (version 1.108)"
