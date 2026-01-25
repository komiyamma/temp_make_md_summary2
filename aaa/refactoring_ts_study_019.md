# 第19章 リネーム①（変数名が世界を救う）🏷️🌍

### ねらい🎯

* **変数名だけで「何が入ってるか」「何のためか」が伝わる**ようにするよ😊✨
* リファクタ初学者でも、**安全に・小さく・確実に**読みやすさを上げられる最強手段が「リネーム」だよ💪🛟

---

## 1. リネームが効く理由🧠✨

コードって、読む時間のほうが圧倒的に長いのに、読者は未来の自分かもしれない…！😇
だから **「名前＝説明書」** なんだよ📘💡

* 変数名が良いと

  * コメントが減る✍️➡️🧼
  * バグが減る（勘違いが減る）🐛⬇️
  * 変更が怖くなくなる😌🛟

> 「新しい読者に伝わる、説明的な名前にする」って方針は、TypeScriptの代表的なスタイルガイドでも強く推されてるよ📌 ([Google GitHub][1])

---

## 2. まずは“臭い名前”を知ろう👃⚠️

次の名前が出たら、だいたい「リネームどき」だよ🧯✨

### 2.1 意味が薄い・何でも入る系🫥

* `data`, `info`, `obj`, `value`, `result`, `temp`, `tmp`
* `flag`, `status`（中身が具体的じゃない）
* `list`（何のリスト？）

✅ 例：

* `data` ❌ → `userProfile` ✅
* `result` ❌ → `validatedEmail` ✅

### 2.2 省略が強すぎる🧩

* `usr`, `prc`, `cfg`, `req`, `res`（チーム外の人が読めない😵）

スタイルガイドでも「よく分からない省略は避けよう」って言われがちだよ📌 ([Google GitHub][1])

### 2.3 単位や意味が不明🔢🌀

* `time`, `size`, `count`, `limit`
  → **ms？秒？KB？件数？最大値？** が分からないやつ😇

✅ 例：

* `timeout` ❌ → `timeoutMs` ✅
* `size` ❌ → `fileSizeBytes` ✅
* `count` ❌ → `retryCount` ✅

### 2.4 “似た者同士”が並ぶ🧍🧍‍♀️🧍‍♂️

* `user`, `user2`, `userData`, `userInfo`
  → 違いが曖昧で事故る💥

✅ 例：

* `user` と `user2` ❌
  → `authorUser` / `viewerUser` ✅

---

## 3. 命名の基本ルール（変数編）🧷✨

TypeScript界隈の一般的な命名はだいたいこれ👇

* 変数・ローカル・プロパティ：**camelCase**
* 型・クラス：**PascalCase**
* 定数（不変で共有されるもの）：**UPPER_CASE**
  こういう方針はTypeScript公式リポジトリのコーディングガイドにも載ってるよ📌 ([GitHub][2])

---

## 4. “伝わる名前”の作り方レシピ🍳✨

### 4.1 変数は「名詞」📦

* 中身がモノなら名詞でいこう！
* `userName`, `orderTotal`, `discountRate`

### 4.2 boolean は “質問形” にする❓✅

true/false を読むときに気持ちいい形にするよ😊

* `isActive`, `hasPermission`, `canRetry`, `shouldSendEmail`

❌ `activeFlag`（読みにくい）
✅ `isActive`

### 4.3 コレクションは複数形・中身がわかる🍱

* `users`, `orderItems`, `errorMessages`

❌ `list`
✅ `userIds`

### 4.4 “何のために存在するか”を入れる🎯

* `cacheKey`（キャッシュ用のキー）
* `displayName`（表示用の名前）
* `requestTimeoutMs`（リクエストのタイムアウト）

### 4.5 短い名前が許される場面もあるよ👌

たとえば **10行以内の狭いスコープ**なら、`i` みたいな短い名前が許されるケースもあるよ（読み手が迷子になりにくいから）📌 ([Google GitHub][1])

---

## 5. “安全にリネームする手順”👣🛟

リネームは簡単そうで、手作業だと事故りがち😱
だから **ツールにやらせる**のが鉄則だよ🧰✨

### 手順（1コミットでやるならこれ）✅

1. **VS Code の Rename Symbol（F2）** で変更🏷️
2. 影響範囲をプレビューで確認👀
3. 型チェック＆テストを実行🧷🧪
4. 差分を見て「意味が変わってない」こと確認🔍
5. コミット💾✨（「Rename: 〇〇 → 〇〇」みたいに書くと気持ちいい）

---

## 6. ビフォー/アフター（超あるある）🧩➡️✨

### 6.1 “何の数字？”をやめる🔢🛑

```ts
// Before 😵
function calc(a: number, b: number, c: number) {
  return a * (1 - b) + c;
}
```

```ts
// After 😊
function calculateDiscountedPrice(
  basePrice: number,
  discountRate: number,
  shippingFee: number
) {
  return basePrice * (1 - discountRate) + shippingFee;
}
```

ポイント🎯

* `a/b/c` は読者に「推理」を強いる🕵️‍♀️💦
* **単語＋役割**にすると、説明ゼロでも読める📖✨

---

### 6.2 boolean を“読める英語”にする✅📣

```ts
// Before 😵
const send = user.mail && user.ok;
```

```ts
// After 😊
const hasEmail = user.email != null;
const isVerified = user.isVerified === true;
const shouldSendEmail = hasEmail && isVerified;
```

ポイント🎯

* `send` は「送るの？送らないの？」が曖昧😇
* boolean は `is/has/can/should` で整えると最強💪✨

---

### 6.3 “似た名前”を役割で分ける🎭

```ts
// Before 😵
const user = getUser();
const user2 = getUserFromCache();
```

```ts
// After 😊
const fetchedUser = getUser();
const cachedUser = getUserFromCache();
```

ポイント🎯

* 「どっちがどっち？」が消える🧼✨

---

## 7. ありがちな落とし穴（リネームの事故）💥🧯

### 7.1 “意味を変えちゃうリネーム”😱

* `limit` → `max` にしたら

  * 「上限」なのか「最大値」なのかニュアンスがズレることがあるよ⚠️
    ✅ **元の意図（ドメインの言葉）**を優先しよう📌

### 7.2 名前に型情報を埋め込みすぎる🧊

* `userNameString` みたいなやつ
  TypeScriptは型が別にあるから、基本は冗長になりやすいよ🧷💡（例外は `id`, `ms`, `bytes` みたいな“単位”）

### 7.3 “短いけど有名じゃない略語”🤐

* `cfg`, `prm`, `usr` みたいなのは、初見殺しになりがち😵
  「略して良いのは、誰でも知ってるやつだけ」くらいが安心だよ😊 ([MDNウェブドキュメント][3])

---

## 8. ミニ課題✍️（曖昧名を10個、改善しよう）🎯✨

### お題（Before）😵

次の変数名を、意味が伝わる名前にしてみてね🏷️💡

1. `data`（ユーザーの住所）
2. `info`（商品の価格と通貨）
3. `flag`（ログイン済みか）
4. `list`（注文IDの配列）
5. `tmp`（検証済みメール）
6. `count`（リトライ回数）
7. `time`（APIタイムアウトms）
8. `value`（割引率）
9. `obj`（カートの中身）
10. `result`（バリデーション結果）

### 例（Afterの一案）😊

* `data` → `shippingAddress`
* `info` → `priceWithCurrency`
* `flag` → `isLoggedIn`
* `list` → `orderIds`
* `tmp` → `validatedEmail`
* `count` → `retryCount`
* `time` → `apiTimeoutMs`
* `value` → `discountRate`
* `obj` → `cartItems`
* `result` → `validationResult`

---

## 9. AI活用ポイント🤖✨（候補出し→人が決める）

AIは **候補を増やす**のが得意だよ😊
でも最終決定は、プロジェクトの言葉（ドメイン）を知ってる人がやるのが安全✅

### 9.1 依頼テンプレ（そのままコピペOK）📋

* 「この変数名の改善案を10個。短すぎる略語は禁止。booleanなら is/has/can/should を使って」
* 「単位を明示して（ms/bytes/percentなど）。名前だけで誤読しない案にして」
* 「ドメイン用語を優先して。一般的すぎる言葉（data/info/value）は避けて」

### 9.2 追加のチェック依頼（強い）🛡️

* 「このリネームで“意味が変わって見える”危険がないか指摘して」
* 「似てる名前が混ざってないか（user/userInfo/userDataみたいな）レビューして」

---

## 10. 命名規則を“仕組みで守る”🧰✅

「良い名前にしよう！」って気合いより、**ルールで支える**ほうが続くよ😊✨
たとえば ESLint の `@typescript-eslint/naming-convention` で命名の形を固定できるよ🏷️📌 ([TypeScript ESLint][4])

```ts
// 例：命名の形だけをざっくり統一するイメージ✨
{
  "@typescript-eslint/naming-convention": [
    "error",
    { "selector": "variable", "format": ["camelCase", "UPPER_CASE", "PascalCase"] },
    { "selector": "function", "format": ["camelCase"] },
    { "selector": "typeLike", "format": ["PascalCase"] }
  ]
}
```

※ここでは「第19章」なので深入りしないけど、**“名前の形”の統一**はリネーム効果をさらに上げるよ📈✨

---

## 11. お守りチェックリスト🧿✨（リネーム版）

リネームしたら、最後にここだけ見てね👀✅

* 名前だけで「中身」と「目的」が分かる？📦🎯
* 省略しすぎてない？（チーム外の人も読める？）🧩
* boolean は `is/has/can/should` になってる？✅
* 単位が必要なら入ってる？（`Ms`, `Bytes`, `Percent`…）🔢
* 似た名前が並んで混乱しない？（役割で分けた？）🎭
* 変更は名前だけ？（意味・挙動は同じ？）🛟
* 型チェック＆テスト通った？🧷🧪

---

[1]: https://google.github.io/styleguide/tsguide.html?utm_source=chatgpt.com "Google TypeScript Style Guide"
[2]: https://github.com/microsoft/TypeScript/wiki/Coding-guidelines?utm_source=chatgpt.com "Coding guidelines · microsoft/TypeScript Wiki"
[3]: https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Code_style_guide/JavaScript?utm_source=chatgpt.com "Guidelines for writing JavaScript code examples"
[4]: https://typescript-eslint.io/rules/naming-convention/?utm_source=chatgpt.com "naming-convention"
