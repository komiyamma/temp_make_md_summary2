# 第29章 ループ整理（map/filterで意図を見せる）🌀🍃

### ねらい🎯

`for` や `forEach` の“やってることゴチャ混ぜ”をほどいて、**「何をしたいか」がパッと読める**形にするよ〜😊✨
`map / filter / reduce / find / some / every` を使い分けて、ループをスッキリさせよう🧹🍃

---

### 今日のゴール✅

次の3つができるようになる💪💖

* ループの目的を **変換 / 絞り込み / 集計 / 検索 / 判定** に分解できる🧠🔍
* `map/filter/reduce/find/some/every` を選んで置き換えできる🧩➡️✨
* 「壊してない？」を **テスト＋型＋差分** で確認できる🛡️🧷✅

---

## 1) ループが読みにくくなる典型パターン👃💦

### よくある“混ぜ込みループ”😵‍💫

1つのループで、こんなことを同時にやってると一気に読みにくくなるよ👇

* 条件判定（if）🚦
* 変換（値を作る）🧪
* 集計（合計・カウント）🧮
* 配列に追加（push）📥
* 途中で止める（break/return）🛑
* ついでの副作用（ログ・DB・API）🌪️

**対策は超シンプル：目的ごとに分けて、目的に合う配列メソッドに置き換える**✨

---

## 2) まずは“目的→メソッド”早見表📌🌸

* **変換したい** → `map` 🧁
* **条件で絞りたい** → `filter` 🥦
* **1つの値にまとめたい（合計など）** → `reduce` 🧮
* **最初に見つかった1件がほしい** → `find` 🔎
* **1つでも条件OKならtrue** → `some` ✅
* **全部条件OKならtrue** → `every` 🧾✅
* **配列を平らにしつつ作りたい** → `flatMap` 🧺
* **並び替えたい（破壊しない版）** → `toSorted`（新しめ）🧊✨ ([MDN Web Docs][1])
* **グループ分けしたい（新しめ）** → `Object.groupBy` / `Map.groupBy` 🧁🧁 ([GitHub][2])

※ TypeScriptも最近は 5.9 まで進んでいて、最新寄りの書き方や型の恩恵が大きいよ🧷✨ ([TypeScript][3])

---

## 3) ビフォー/アフター：定番5パターン🧩➡️✨

### パターンA：`if + push` は `filter + map` へ🍃

#### Before（目的が埋もれがち💦）

```ts
type User = { id: string; name: string; isActive: boolean };

function getActiveUserNames(users: User[]): string[] {
  const result: string[] = [];
  for (let i = 0; i < users.length; i++) {
    const u = users[i];
    if (u.isActive) {
      result.push(u.name);
    }
  }
  return result;
}
```

#### After（目的が見える👀✨）

```ts
type User = { id: string; name: string; isActive: boolean };

function getActiveUserNames(users: User[]): string[] {
  return users
    .filter(u => u.isActive)
    .map(u => u.name);
}
```

✅ ここでのポイント

* `filter` が「残す条件」🥦
* `map` が「変換」🧁
* ループ制御（i, length）を消して、意図だけ残す✨

---

### パターンB：合計・集計は `reduce` へ🧮💖

#### Before（合計なのに、処理が散らばる）

```ts
type Item = { price: number; quantity: number };

function calcTotal(items: Item[]): number {
  let total = 0;
  for (const item of items) {
    total += item.price * item.quantity;
  }
  return total;
}
```

#### After（「集計です！」が一発で伝わる）

```ts
type Item = { price: number; quantity: number };

function calcTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

✅ reduceのコツ🍬

* 初期値（ここだと `0`）は必ず入れるのが安全🛟
* `sum` の名前は “意味がわかる”ものにする（total, count, max など）🏷️

---

### パターンC：探すだけなら `find`、判定なら `some/every` 🔎✅

#### Before（breakやフラグでややこしくなる）

```ts
type Order = { id: string; isPaid: boolean };

function hasUnpaid(orders: Order[]): boolean {
  let found = false;
  for (const o of orders) {
    if (!o.isPaid) {
      found = true;
      break;
    }
  }
  return found;
}
```

#### After（意図がそのまま関数名に✨）

```ts
type Order = { id: string; isPaid: boolean };

function hasUnpaid(orders: Order[]): boolean {
  return orders.some(o => !o.isPaid);
}
```

* 「全部OK？」→ `every` 🧾✅
* 「1つでもOK？」→ `some` ✅
* 「最初の1件がほしい」→ `find` 🔎

---

### パターンD：`continue` だらけは “前処理で絞る”🥦✨

#### Before（continueが多いと迷子になりやすい😵‍💫）

```ts
type Log = { level: "info" | "warn" | "error"; message: string };

function pickErrorMessages(logs: Log[]): string[] {
  const result: string[] = [];
  for (const log of logs) {
    if (log.level !== "error") continue;
    if (log.message.trim() === "") continue;
    result.push(log.message);
  }
  return result;
}
```

#### After（条件を `filter` に寄せる）

```ts
type Log = { level: "info" | "warn" | "error"; message: string };

function pickErrorMessages(logs: Log[]): string[] {
  return logs
    .filter(l => l.level === "error")
    .map(l => l.message.trim())
    .filter(msg => msg !== "");
}
```

✅ チェーンが長くなってきたら…🧶
途中を変数で切ってOKだよ（読みやすさ優先）😊✨

```ts
function pickErrorMessages(logs: Log[]): string[] {
  const errors = logs.filter(l => l.level === "error");
  const trimmed = errors.map(l => l.message.trim());
  return trimmed.filter(msg => msg !== "");
}
```

---

### パターンE：更新系は “破壊しない” を優先（map / 新しめAPI）🧊✨

配列の中身を更新したいとき、`for` で直接書き換えると副作用で事故りやすい💥
`map` で **新しい配列** を作るのが安全🛟✨

#### Before（元配列を壊すかも…）

```ts
type Product = { id: string; price: number; sale: boolean };

function applyDiscount(products: Product[]): Product[] {
  for (const p of products) {
    if (p.sale) p.price = Math.floor(p.price * 0.9);
  }
  return products;
}
```

#### After（新しい配列を返す✨）

```ts
type Product = { id: string; price: number; sale: boolean };

function applyDiscount(products: Product[]): Product[] {
  return products.map(p =>
    p.sale ? { ...p, price: Math.floor(p.price * 0.9) } : p
  );
}
```

さらに、最近のJSには **破壊しない版** が増えてるよ🧊

* `toSorted()`（破壊しない sort） ([MDN Web Docs][1])

例：

```ts
const sorted = products.toSorted((a, b) => a.price - b.price);
```

---

## 4) TypeScriptで“さらに読みやすく・安全に”する小ワザ🧷✨

### 4-1) `filter` で型を絞る（型ガード風）🔍🧠

「nullを消したい」みたいな時、`filter(Boolean)` は便利だけど型が弱いことがあるよ〜💦
TypeScriptに伝えるならこんな感じ👇

```ts
function notNull<T>(v: T | null | undefined): v is T {
  return v != null;
}

const xs = [1, null, 2, undefined, 3];
const ys = xs.filter(notNull); // number[]
```

---

### 4-2) `forEach` と `async` の罠⚠️😱（超大事）

`forEach(async () => ...)` は **awaitしてくれない** から、順番や完了待ちが崩れやすいよ💦

❌やりがち：

```ts
items.forEach(async item => {
  await save(item);
});
```

✅順番にやるなら（素直に `for...of`）：

```ts
for (const item of items) {
  await save(item);
}
```

✅並列にやって待つなら（`Promise.all`）：

```ts
await Promise.all(items.map(item => save(item)));
```

---

## 5) ループ整理の手順（小さく刻む）👣🛟

1. **そのループの目的を1行で書く**📝
   例：「アクティブユーザーの名前一覧を作る」
2. ループの中身を色分けイメージで分解🎨

   * 絞り込み条件🚦
   * 変換🧁
   * 集計🧮
   * 副作用🌪️
3. **副作用があるなら、まず外に追い出す**📤
   例：ログ出力、API呼び出し、外部変数の更新など
4. 目的に合うメソッドへ置換🧩➡️✨

   * 絞り込み → `filter`
   * 変換 → `map`
   * 集計 → `reduce`
   * 検索 → `find`
   * 判定 → `some/every`
5. **動作確認**✅
   テスト／型チェック／実行で「同じ結果？」を確認🛡️🧷
6. 読みにくくなったら変数で区切る🧶
   「短い＝正義」じゃなくて「読める＝正義」💖

---

## 6) ミニ課題✍️🌼

### 課題1：`if + push` を卒業🥦🧁

次を `filter + map` にしてね👇

```ts
type Post = { title: string; likes: number };

function pickPopularTitles(posts: Post[]): string[] {
  const result: string[] = [];
  for (const p of posts) {
    if (p.likes >= 100) {
      result.push(p.title);
    }
  }
  return result;
}
```

---

### 課題2：合計を `reduce` に🧮

次を `reduce` にしてね👇

```ts
type CartItem = { price: number };

function sumPrices(items: CartItem[]): number {
  let sum = 0;
  for (const it of items) {
    sum += it.price;
  }
  return sum;
}
```

---

### 課題3：判定は `some/every` ✅🧾

次の「条件を満たす要素が1つでもあるか」を `some` にしてね👇

```ts
type User = { name: string; banned: boolean };

function hasBannedUser(users: User[]): boolean {
  for (const u of users) {
    if (u.banned) return true;
  }
  return false;
}
```

---

## 7) AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### 7-1) 目的の言語化を手伝ってもらう📝

* 「このfor文がやっていることを、**1文**で説明して」
* 「変換・絞り込み・集計・検索・判定のどれ？」

### 7-2) 置換案を複数出させて比較🔁

* 「`map/filter/reduce` を使った案を3つ。読みやすさ順に並べて理由も」
* 「チェーンが長い場合の“変数で区切る版”も出して」

### 7-3) “壊してない？”をテストで守る🧪

* 「この関数のテストケースを境界値込みで列挙して」
* 「Before/After が同じ結果になるテストを作って」

### 7-4) よくある落とし穴チェック⚠️

* 「並び順は変わらない？」
* 「重複は増えてない？」
* 「`undefined/null` の扱いは同じ？」
* 「途中終了（break/return）の意味が消えてない？」

---

## 8) 仕上げチェックリスト🧿✅

* ループの目的が **1行で言える**？📝
* `i` や `push` が消えて、**意図が前に出た**？👀✨
* 途中終了の意味（break/return）を、`some/find` などで **正しく再現**できてる？🛑
* 元の配列やオブジェクトを **壊してない**？🧊
* 型エラーなし🧷、テストOK🧪、実行結果OK✅？

---

### おまけ：最近の“新しめ配列機能”の存在だけ知っておく📎✨

* `toSorted()` は **破壊しない sort** で、並び替えの事故を減らせるよ🧊 ([MDN Web Docs][1])
* `Object.groupBy / Map.groupBy` は **グループ分け** がスッキリ書ける（新しめ）🧁🧁 ([GitHub][2])
* TypeScriptも 5.9 まで来ていて、モジュール周り含め改善が続いてるよ🧷✨ ([TypeScript][3])

[1]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/toSorted?utm_source=chatgpt.com "Array.prototype.toSorted() - JavaScript - MDN Web Docs"
[2]: https://github.com/asciidwango/js-primer/discussions/1765?utm_source=chatgpt.com "v6.0.0: ES2024の対応/Node.jsの大幅更新 #1765"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
