# 第18章 変更を分割する設計（作業の道筋）🧩👣

## ねらい🎯

* いきなり大改造しないで、**安全に“少しずつ”直せる**ようになる🛟✨
* 「次に何を変える？」を迷わないための、**分割ロードマップ**を作れる🗺️🖊️
* AIの提案を使いつつ、**壊さずに前へ進む**チェックの型を身につける🤖✅

---

## 1) まず結論：安全に進む“分割の順番”🛟👣

変更を分割するときは、だいたいこの順が強いよ〜！💪✨

1. **観測・守りを置く**（テスト／ログ／型チェック）🛡️🔍
2. **名前を整える**（リネーム・用語統一）🏷️
3. **小さく抜き出す**（変数抽出 → 関数抽出）🧺✂️
4. **責務を分ける**（I/Oとロジック分離）🚪🧠
5. **置き換える**（より良い設計へ差し替え）🔁✨

この順だと、毎回「変更が小さい」＋「差分が読める」＋「戻れる」になりやすいよ😊🧷

---

## 2) 「変更分割ロードマップ」テンプレ🗺️📝

大きい変更ほど、先に“道筋”を紙に描くと勝ちやすい🏆✨
下のテンプレを、そのままコピって埋めてOKだよ〜🧸🖊️

### A. ゴール🎯

* 最終的にどうしたい？（例：巨大関数を分割して読みやすく、テストしやすく）

### B. 変えない約束（守るもの）🛟

* 入出力の意味は同じ
* 例外の出方（いつ投げるか）を変えない
* 性能が落ちそうなら計測する

### C. いまのリスク🔥

* テストがない／副作用が多い／分岐が多い／I/O混ざってる…など

### D. ステップ分割（1ステップ=1目的）👣

各ステップに「終わった判定」を付けるのがコツ✅

* ステップX：やること（例：変数名だけ直す）

  * 終わった判定：テスト✅ 型✅ 動作✅ 差分が小さい✅

---

## 3) 例題：巨大な checkout を安全に分割する🧾🧩

### 3-1. Before（全部入りで怖い😱）

```ts
// checkout.ts（Before）
export async function checkout(
  userId: string,
  items: { id: string; price: number; qty: number }[],
  coupon?: string
) {
  if (!userId) throw new Error("no user");
  if (!items || items.length === 0) return { total: 0, message: "empty" };

  // subtotal
  let subtotal = 0;
  for (const it of items) {
    if (it.qty <= 0) throw new Error("bad qty");
    subtotal += it.price * it.qty;
  }

  // coupon (messy)
  let discount = 0;
  if (coupon) {
    if (coupon.startsWith("OFF")) {
      const p = Number(coupon.slice(3));
      if (!Number.isFinite(p)) throw new Error("bad coupon");
      discount = Math.min(subtotal, p);
    } else if (coupon === "HALF") {
      discount = subtotal * 0.5;
    } else if (coupon === "SHIPFREE") {
      // handled later
    } else {
      throw new Error("unknown coupon");
    }
  }

  // shipping (I/O)
  const shippingBase = await fakeGetShippingBase(userId);
  let shipping = 500 + shippingBase;
  if (subtotal - discount >= 5000) shipping = 0;
  if (coupon === "SHIPFREE") shipping = 0;

  // tax
  const tax = Math.floor((subtotal - discount) * 0.1);
  const total = subtotal - discount + shipping + tax;

  return { total, subtotal, discount, shipping, tax };
}

async function fakeGetShippingBase(userId: string) {
  return userId.length * 10;
}
```

---

### 3-2. このコードの“怖さ”を言語化👃⚠️

* **I/O（非同期）**と**計算ロジック**が混ざってる🚧
* **クーポン**が条件分岐だらけで、追加が怖い😵‍💫
* バリデーションが途中に散らばってる🌀
* “どこを直したら何が壊れるか”が読みにくい📉

---

### 3-3. 分割ロードマップ（コミット単位の道筋）🗺️👣

ここが本章のメイン！✨
**「1コミット＝1目的」**で刻むよ〜💾🧷

0. **守りを置く**：ゴールデンマスター（スナップショット）テストを作る🧪👑
1. **リネームだけ**：`it`→`item`、`p`→`amountOff` みたいに意味のある名前へ🏷️✨
2. **小さく抽出①**：`calcSubtotal(items)` を作って移す✂️
3. **小さく抽出②**：`calcDiscount(subtotal, coupon)` を作って移す✂️
4. **I/Oと分離**：`getShippingBase(userId)` と `calcShipping(...)` に分ける🚪🧠
5. **税計算も独立**：`calcTax(subtotal, discount)` を作る🧾
6. **最後に整える**：`validateInput(...)` を先頭にまとめる🧹✨

---

## 4) ステップ0：守り（ゴールデンマスター）を置く🛡️👑

テストが薄いときは、**「現状の出力を固定」**が最強だよ〜！🛟✨

例：代表ケースを何個か選んで、戻り値をスナップショットで保持📸
（テストフレームワークは好きなやつでOK。ここではイメージだけ👀）

```ts
// checkout.test.ts（イメージ）
import { checkout } from "./checkout";

test("golden master: normal", async () => {
  const result = await checkout(
    "userA",
    [{ id: "p1", price: 1000, qty: 2 }],
    "OFF300"
  );
  expect(result).toMatchSnapshot();
});

test("golden master: shipfree", async () => {
  const result = await checkout(
    "userA",
    [{ id: "p1", price: 1200, qty: 3 }],
    "SHIPFREE"
  );
  expect(result).toMatchSnapshot();
});
```

✅ これで「動作を変えてない？」が一発で分かるようになるよ〜！😊🧪

---

## 5) ステップ1：リネームだけ🏷️✨（差分を超小さく）

ここは**意味が変わらない変更しかやらない**のがコツ👣
VS Codeならリネームは“参照込み”で安全にできるよ🧑‍💻🔧

例：`it` → `item`、`p` → `amountOff`、`subtotal` → `subTotal` みたいな表記ゆれもついでに統一🎀

✅ 終わった判定：テスト✅ 型✅ 動作✅

---

## 6) ステップ2〜6：抽出→分離→整形（ここで勝つ）🏆✨

### After（最終形のイメージ）🌸

「やってることは同じ、でも読みやすい！」を目指すよ😊

```ts
type Item = { id: string; price: number; qty: number };

type CheckoutOk = {
  total: number;
  subtotal: number;
  discount: number;
  shipping: number;
  tax: number;
};

type CheckoutEmpty = { total: 0; message: "empty" };

export async function checkout(
  userId: string,
  items: Item[],
  coupon?: string
): Promise<CheckoutOk | CheckoutEmpty> {
  validateInput(userId, items);

  if (items.length === 0) return { total: 0, message: "empty" };

  const subtotal = calcSubtotal(items);
  const discount = calcDiscount(subtotal, coupon);

  const shippingBase = await getShippingBase(userId);
  const shipping = calcShipping(subtotal, discount, shippingBase, coupon);

  const tax = calcTax(subtotal, discount);
  const total = subtotal - discount + shipping + tax;

  return { total, subtotal, discount, shipping, tax };
}

function validateInput(userId: string, items: Item[]) {
  if (!userId) throw new Error("no user");
  for (const item of items) {
    if (item.qty <= 0) throw new Error("bad qty");
  }
}

function calcSubtotal(items: Item[]): number {
  let subtotal = 0;
  for (const item of items) subtotal += item.price * item.qty;
  return subtotal;
}

function calcDiscount(subtotal: number, coupon?: string): number {
  if (!coupon) return 0;

  if (coupon.startsWith("OFF")) {
    const amountOff = Number(coupon.slice(3));
    if (!Number.isFinite(amountOff)) throw new Error("bad coupon");
    return Math.min(subtotal, amountOff);
  }

  if (coupon === "HALF") return subtotal * 0.5;
  if (coupon === "SHIPFREE") return 0;

  throw new Error("unknown coupon");
}

function calcShipping(
  subtotal: number,
  discount: number,
  shippingBase: number,
  coupon?: string
): number {
  if (coupon === "SHIPFREE") return 0;

  const afterDiscount = subtotal - discount;
  if (afterDiscount >= 5000) return 0;

  return 500 + shippingBase;
}

function calcTax(subtotal: number, discount: number): number {
  return Math.floor((subtotal - discount) * 0.1);
}

async function getShippingBase(userId: string) {
  return userId.length * 10; // 例
}
```

---

## 7) VS Codeでの“分割が捗る”操作🧑‍💻🧰

* **リネーム**：シンボル上でリネーム（参照ごと安全）🏷️
* **抽出**：範囲選択 → リファクタ（Extract）✂️
* **参照を追う**：定義へ移動／参照の検索で影響範囲を見る👀
* **差分を小さく保つ**：1コミットごとにテスト＆型チェック✅🧷🧪

（VS Codeは2026年1月のリリース情報が継続更新されてるよ📌）([Visual Studio Code][1])

---

## 8) よくある失敗あるある😵‍💫💥 → 回避策🛟

### 失敗1：最初に“理想形”へ一気に作り替える💣

✅ 回避：**手順カード**で「名前→抽出→分離→置換」を守る👣

### 失敗2：途中で目的が混ざる（リネーム＋仕様変更＋バグ修正）🍲

✅ 回避：**コミットに目的を1個だけ**（「税計算を関数化」だけ、みたいに）💾

### 失敗3：抽出した関数の引数が増えすぎて地獄😇

✅ 回避：いったんOK！
その後「責務の分離」段階で、データ構造を整える（次の章で強くなるやつ✨）

---

## 9) ミニ課題✍️🗺️

### 課題A：ロードマップを作ろう🧩

次の条件で「分割ロードマップ（6〜10ステップ）」を書いてみてね😊

* 関数が長い
* if/switchが多い
* I/Oが混ざってる
* テストが少ない

✅ ゴール：**ステップごとに“終わった判定”が付いてること**✅✅✅

### 課題B：コミットメッセージ案を付けよう💾

例：

* `test: add golden master snapshots for checkout`
* `refactor: rename variables for readability`
* `refactor: extract calcSubtotal`
  みたいに、短く目的が分かる形にしてね🧷✨

---

## 10) AI活用ポイント🤖💡（お願い方＋チェック観点✅）

### お願い方テンプレ①：ロードマップ作成🗺️

```txt
このTypeScript関数を「動作を変えずに」段階的に分割したいです。
1コミット=1目的で、6〜10ステップのロードマップを作ってください。
各ステップに「目的」「作業内容」「終わった判定（型/テスト/動作/差分）」を付けてください。
```

### お願い方テンプレ②：差分レビュー（危険検知）👮‍♀️

```txt
この差分はリファクタです。動作変更の可能性がある箇所を指摘して、
「確認すべきテストケース」を列挙してください。
```

### チェック観点✅（AIの提案を採用する前に）

* “同じ入力→同じ出力”が守れてる？🧪
* 例外のタイミング変わってない？⚠️
* I/Oとロジックの境界が分かれた？🚪
* 命名が「読める日本語」になった？🏷️
* 1コミットの差分が小さい？👣

---

## ちょい最新メモ📌（2026年時点）

* TypeScriptは **5.9** のリリースノートが更新されてるよ（2026年1月時点）🧷✨([TypeScript][2])
* OpenAIの **Codex（VS Code拡張）** は「IDEで並走」や「タスク委任」みたいな使い方が案内されてるよ🤖🧑‍💻([OpenAI Developers][3])
* GitHub Copilot も、IDE上のチャットなど機能が整理されてる📚🤖([docs.github.com][4])

[1]: https://code.visualstudio.com/updates?utm_source=chatgpt.com "December 2025 (version 1.108)"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://developers.openai.com/codex/ide/?utm_source=chatgpt.com "Codex IDE extension"
[4]: https://docs.github.com/en/copilot/get-started/features?utm_source=chatgpt.com "GitHub Copilot features"
