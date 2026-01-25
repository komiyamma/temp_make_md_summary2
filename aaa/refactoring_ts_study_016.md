# 第16章 コードの臭い入門（代表パターン）👃📌

### ねらい🎯

「ここ直したほうが良さそう…👀」を**言語化**できるようになること✨
（まだ大改造はしないよ！“直すサイン”を見つける練習がメイン🧭）

---

## 1. コードの「臭い」ってなに？👃🧠

**コードの臭い（Code Smell）**は、だいたいこんな感じ👇

> 表面に見えている“違和感”で、だいたい奥にもっと深い問題が隠れてることが多いサイン🕵️‍♀️
> ([martinfowler.com][1])

大事ポイント✅

* **バグとは限らない**（動いてても臭いはある😅）
* **見つけたら即直す**…じゃなくて、まずは「どんな臭い？」を言えるのが強い💪
* 臭いは「主観ゼロ」じゃない（でも定番パターンはあるよ📌）([ウィキペディア][2])

---

## 2. 2026年版・周辺ツールの小メモ🔎🧰

“臭い探し”はツールの助けも借りると爆速💨

* TypeScriptは **5.9 系が最新**として案内されていて、たとえば `import defer` みたいな新しめ構文も入ってるよ🧷✨ ([TypeScript][3])
* ESLintは **v9で設定方式（flat config）がデフォルト**になってる流れ（ここ数年の大きな変化ポイント）👮‍♀️📄 ([ESLint][4])
* VS Codeも月次で更新が続いていて、2026年1月のInsidersは 1.109 まで進んでるよ🧑‍💻✨ ([Visual Studio Code][5])

※ここは「覚える」より、「新しめの仕組みに乗ってるんだな〜」くらいでOK😊🌸

---

## 3. 代表4大スメル（まずはこれだけでOK）👃✨

この章では、特に出会いがちな4つに絞るよ📌

### A. 長い関数（Long Function）📏😵‍💫

**サイン👀**

* スクロールが長い🌀
* 途中から「何してるか」忘れる😇
* 途中で何回もコメントが必要になる📝

**ありがちな原因🧩**

* 処理を足し足しで継ぎ足した🍲
* 入力チェック、計算、表示、保存…が1つに混ざってる🎭

**放置すると…😢**

* ちょい修正が怖い（影響範囲が広い）💥
* テストも書きづらい🧪

**最初の一手👣✨**

* まずは**分割の前にリネーム**（変数名・関数名を正しくする）🏷️
* 次に、**まとまりを1個だけ抽出**（Extract Function）✂️📦

---

### B. 重複（Duplication）🔁😬

**サイン👀**

* 似たコードが2回以上ある（コピペ臭）📋
* 片方だけ直して、もう片方がバグる未来が見える😱

**放置すると…😢**

* 修正漏れが起きやすい（地味に一番つらい）🩹

**最初の一手👣✨**

* 「同じ“知識”か？」を確認🧠

  * たとえば “税率10%” が2箇所 → **知識が同じ**（定数や関数へ）
  * たまたま似てるだけ → 無理にまとめない🙅‍♀️

---

### C. 巨大 if / ネスト地獄（Huge if / Deep Nesting）🧱🧨

**サイン👀**

* `if` の中に `if` の中に `if`…（迷路）🌀
* 「この場合だけ違う」が積み重なる📚

**放置すると…😢**

* 条件追加で簡単に壊れる（抜け・漏れ）🕳️
* 読むのが苦行😵

**最初の一手👣✨**

* **ガード節（早期return）**でネストを浅くする🚦
* もしくは「条件に名前をつける」（Extract Function / Variable）🏷️

---

### D. 曖昧な名前（Mysterious Name）😶‍🌫️🏷️

**サイン👀**

* `data`, `tmp`, `info`, `result`, `doIt` みたいな万能ワード🧺
* “これ何？”が頭の中で毎回起きる🤔

**放置すると…😢**

* 理解コストが積み上がる💸
* 新しい人（未来の自分含む）が辛い🥲

**最初の一手👣✨**

* **意味＋単位＋範囲**で名前を作る🧠

  * `total` → `totalPriceYen` 💴
  * `flag` → `isStudentDiscountEligible` 🎓

---

## 4. まずは「臭いを言葉にする」練習🗣️👃

ここ超大事✅
臭いを見つけたら、いきなり直さずにまずこう言えると強い💪✨

* どの臭い？（長い関数？重複？巨大if？曖昧名？）👃
* 何が困ってる？（読みづらい？変更が怖い？テストできない？）😵
* “最初の一手”は何？（リネーム？抽出？ガード？定数化？）👣

---

## 5. コード例（ビフォー/アフター）🧩➡️✨

### ビフォー：臭い盛り合わせ🍱😇

```ts
type User = { id: string; age: number; isStudent?: boolean };
type CartItem = { name: string; price: number; qty: number };

export function calc(u: User, items: CartItem[], c?: string) {
  let x = 0;

  // 合計計算（その1）
  for (let i = 0; i < items.length; i++) {
    x += items[i].price * items[i].qty;
  }

  // 合計計算（その2）← 似た処理が別の場所にも…
  let y = 0;
  for (const it of items) {
    y += it.price * it.qty;
  }

  // 条件が増えすぎた巨大if
  if (c) {
    if (c === "NEW10") {
      x = x * 0.9;
    } else {
      if (c === "STUDENT" && u.isStudent) {
        x = x * 0.85;
      } else {
        if (c === "SENIOR" && u.age >= 65) {
          x = x * 0.8;
        } else {
          // 何もしない
        }
      }
    }
  }

  // 送料もここで決めちゃう（責務が混ざりがち）
  if (x >= 5000) return { total: Math.round(x), shipping: 0 };
  return { total: Math.round(x), shipping: 600 };
}
```

このコードの臭い（例）👃📌

* `calc` が**長い**＆いろいろ混ざってる🎭
* 合計計算が**重複**してる🔁
* クーポン判定が**巨大if/深いネスト**🧱
* `x`, `y`, `c` みたいな**曖昧名**😶‍🌫️

---

### アフター：まず“読める”ところまで（小さめ改善）✨👣

※この章では「完全な設計」より、**臭いの除去の入口**までね😊

```ts
type User = { id: string; age: number; isStudent?: boolean };
type CartItem = { name: string; price: number; qty: number };

type CouponCode = "NEW10" | "STUDENT" | "SENIOR";

export function calculateCheckout(
  user: User,
  items: CartItem[],
  couponCode?: CouponCode
) {
  const subtotalYen = calculateSubtotal(items);
  const discountedSubtotalYen = applyCoupon(user, subtotalYen, couponCode);
  const shippingYen = calculateShipping(discountedSubtotalYen);

  return { total: Math.round(discountedSubtotalYen), shipping: shippingYen };
}

function calculateSubtotal(items: CartItem[]) {
  return items.reduce((sum, it) => sum + it.price * it.qty, 0);
}

function applyCoupon(user: User, subtotalYen: number, couponCode?: CouponCode) {
  if (!couponCode) return subtotalYen; // ガード節でネスト減らす🚦

  if (couponCode === "NEW10") return subtotalYen * 0.9;
  if (couponCode === "STUDENT" && user.isStudent) return subtotalYen * 0.85;
  if (couponCode === "SENIOR" && user.age >= 65) return subtotalYen * 0.8;

  return subtotalYen;
}

function calculateShipping(totalYen: number) {
  return totalYen >= 5000 ? 0 : 600;
}
```

どこが良くなった？👀✨

* 1つの関数が「何をするか」が読める📖
* 重複が消えた🔁🧹
* 巨大ifが浅くなった🚦
* 名前で意味が伝わる🏷️🌸

---

## 6. 進め方（臭いを見つけたらこの順番）👣✅

いきなり大工事しないのがコツだよ🪚😌

1. **臭いにラベルを貼る**（長い/重複/巨大if/曖昧名）🏷️👃
2. **リネームだけ**を先にやる（挙動変えない）🏷️✨
3. “まとまり”を**1個だけ抽出**✂️📦
4. ネストを**1段だけ浅く**（ガード節など）🚦
5. そのたびに **型チェック＆テスト＆実行**✅🧷🧪

---

## 7. ミニ課題✍️🎯

### ミニ課題①：臭い探しビンゴ🎯👃

下の25マス、1つのファイルを見て**当てはまるところに印**をつけてね✅
（いっぱい当てはまるほど“改善チャンスの宝庫”だよ💎✨）

|              |                   |                |               |               |
| ------------ | ----------------- | -------------- | ------------- | ------------- |
| 関数が30行超📏    | `data` が多い😶‍🌫️  | `if` が3段🧱     | コメントで補足だらけ📝  | 同じ式が2回🔁      |
| `else` が長い😵 | 例外/returnが最後に集中🚧 | 役割が混ざる🎭       | 数字が直書き🔢      | 同名っぽい変数が複数🧩  |
| 引数が多い🧳      | ネストが深い🌀          | `switch` が巨大🧱 | “この場合だけ”が増殖🧫 | TODOが増える📌    |
| 1行が長い📜      | 途中で関数名とズレる🤥      | 型が `any` だらけ🎓 | `tmp` がいる🫥   | 似た関数が別ファイルに👀 |
| 変更が怖い😱      | 影響範囲が読めない🌫️      | テストしづらい🧪      | 条件が読めない🧾     | “何をしたい？”が不明😵 |

---

### ミニ課題②：臭いを1個だけ減らす（安全に）👣✨

上の「ビフォー」コードをコピって、次のどれか1個だけやってみてね👇

* `calc` → `calculateCheckout` にリネーム🏷️
* `x` → `subtotalYen` にリネーム💴
* 合計計算の重複を消す（片方だけ残す）🔁🧹
* `if (!couponCode) return ...` を入れてネストを1段減らす🚦

ゴール🏁：**挙動は同じ**のまま、差分が説明できること📝✨

---

## 8. AI活用ポイント🤖✅（お願い方＋チェック観点）

### ① 臭いの指摘をしてもらうプロンプト🔍

```txt
次のTypeScriptコードの「コードスメル」を最大10個、分類（長い関数/重複/巨大if/曖昧な名前など）つきで挙げてください。
それぞれ「困る理由」と「最初の一手（挙動を変えない小さな変更）」もセットで。
```

### ② “小さく刻む案”を出してもらうプロンプト👣

```txt
このコードをリファクタしたいです。
1コミットでできる小さな変更案を5つ、順番つきで提案してください。
各ステップで「挙動が変わってない確認方法」も書いてください。
```

### ③ AI提案を採用する前のチェック✅🧷🧪

* 変更が**1テーマ**になってる？（リネームだけ、抽出だけ…）👣
* 返り値・例外・境界条件が変わってない？🚧
* 条件分岐の**網羅性**が落ちてない？（抜けが増えてない？）🕳️
* 差分が説明できる？📝

---

## まとめ🌸

* コードの臭いは「奥に問題があるかも」のサイン👃 ([martinfowler.com][1])
* まずは **代表4つ（長い/重複/巨大if/曖昧名）** を見つけられればOK📌✨
* 直すときは **リネーム→小さな抽出→ネスト1段減らす** みたいに小さく👣✅
* AIは“指摘”と“手順の分割”が得意。でも採用判断はチェック付きでね🤖✅

[1]: https://martinfowler.com/bliki/CodeSmell.html?utm_source=chatgpt.com "Code Smell"
[2]: https://en.wikipedia.org/wiki/Code_smell?utm_source=chatgpt.com "Code smell"
[3]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[4]: https://eslint.org/blog/2024/04/eslint-v9.0.0-released/?utm_source=chatgpt.com "ESLint v9.0.0 released - ESLint - Pluggable JavaScript Linter"
[5]: https://code.visualstudio.com/updates/v1_109?utm_source=chatgpt.com "January 2026 Insiders (version 1.109)"
