# 第30章 null/undefined整理①（発生パターン理解）🫧🧠

## ねらい🎯

「null/undefined が *なぜ* 生まれて、*どう* 伝染して、*どこ* で落ちるのか」を説明できるようになるよ〜🗣️✨
（この章は“直し方”よりも、“見つけ方・理解の仕方”に集中！🔍）

---

## 今日のゴール🏁

* null と undefined の違いを、例付きで言えるようになる🧃
* 「発生パターン」を7つ覚える👀✨
* 自分のコードで「null/undefinedマップ🗺️」を作れるようになる📝

---

## まずは超ざっくり：null と undefined の違い🧃

* **undefined**：値が「まだ無い／渡されてない／存在しない」🫥
  例）オプション引数を渡さなかった、`find` が見つけられなかった、プロパティが無い、など
* **null**：値が「空だと明示されてる」🕳️
  例）DBやAPIが「空」を null で返す、DOM API が「見つからない」を null で返す、など

そして大事なのが👇
**“無い”には種類がある**（未設定／欠損／検索失敗／権限なし…）ので、雑に扱うほどバグりやすい⚠️💥

---

## null/undefined が出る7つの“あるある”パターン👀✨

### ① 未設定（オプション引数・初期化漏れ）🫧

* 関数の引数を省略した
* 変数を宣言したけど代入してない（または分岐で代入されない）

### ② 欠損（オプションプロパティ・存在しないキー）📦

* `user.profile` が無い
* 受け取った JSON にキーが無い
* “あるはず”と思い込んでるだけ、が多い😇

### ③ 検索失敗（見つからない）🔎

* `Array.find()` → **見つからないときがある**
* `Map.get()` → **無いキーがある**
* `querySelector()` → **DOMに無い要素がある**

### ④ インデックスアクセス（配列・辞書の取り出し）🧺

* `arr[i]`（範囲外アクセス）
* `dict[key]`（存在しないキー）

### ⑤ 外部I/O（API・DB・ローカルストレージ・環境変数）🌍

* そもそも外の世界は「信用しちゃダメ」🛡️
* null を返す文化のAPIも普通にある

### ⑥ 型が弱い境界（any/unknown/JSON.parse）🧪

* `JSON.parse()` は「中身が保証されない」
* ライブラリ境界で `any` が混ざると、急に無敵状態になって事故る🤕

### ⑦ 「空」を表現する設計（仕様として空があり得る）🕳️

* “未ログイン”
* “検索結果0件”
* “まだ選択していない”
  → 仕様上「無い」が正しいケースもある🙆‍♀️

---

## コード例（ビフォー/アフター）🧩➡️✨

### 例1：検索失敗（`find`）で落ちる💥

**ビフォー（見つかる前提で書いちゃう）**

```ts
type User = { id: string; name: string };

const users: User[] = [
  { id: "a", name: "Aki" },
  { id: "b", name: "Beni" },
];

export function greet(userId: string) {
  const user = users.find(u => u.id === userId);
  // 🙅‍♀️ user が見つからないと user は undefined
  return `Hello, ${user.name}!`;
}
```

**アフター（“見つからない可能性”を認めてから考える）**

```ts
type User = { id: string; name: string };

const users: User[] = [
  { id: "a", name: "Aki" },
  { id: "b", name: "Beni" },
];

export function greet(userId: string) {
  const user = users.find(u => u.id === userId);

  // ✅ まず「見つからない」を分岐として扱える形にする
  if (!user) {
    return "Hello, guest!";
  }

  return `Hello, ${user.name}!`;
}
```

ポイント：この章では「**見つからないのは仕様として起きる**」をまず受け入れるのが目的だよ🫶✨
（安全な書き方のバリエーションは次章で増やすよ〜🛟）

※ `strictNullChecks` を有効にすると、`null/undefined` を「ある前提」で使うと型エラーで気づけるようになるよ✅ ([TypeScript][1])

---

### 例2：DOM（`querySelector`）は null を返す🧩

**ビフォー（要素ある前提）**

```ts
const button = document.querySelector("#submit");
button.addEventListener("click", () => {
  console.log("submit!");
});
```

**アフター（“無い”が仕様）**

```ts
const button = document.querySelector<HTMLButtonElement>("#submit");

if (!button) {
  // ここに来る可能性がある（DOMに存在しない、IDミスなど）
  console.warn("submit button not found");
} else {
  button.addEventListener("click", () => {
    console.log("submit!");
  });
}
```

---

## 「どこで生まれて、どこで落ちる？」マップ作り🗺️✨

null/undefined は、**1点で生まれて、川みたいに下流へ流れる**🌊
だから、やることはシンプル👇

### ① 発生源（source）を探す🔦

よくいる発生源キーワード🧠✨

* `find(` / `get(` / `querySelector(`
* `JSON.parse`
* `?.`（optional chaining）
* `?.` が多い場所は「無いを前提にしている」サイン👀

### ② 伝播（propagation）を追う🧵

「戻り値 → 呼び出し元 → さらに呼び出し元」って辿る

* 関数の戻り値に `| undefined` が入ってないのに、実態は入ってる…が一番こわい😱

### ③ 落ちる場所（sink）を特定する💥

だいたい落ちるのはここ👇

* プロパティアクセス：`x.y`
* 関数呼び出し：`x()`
* 文字列結合・テンプレ：`` `${x}` ``（気づきにくい地味バグもある😵‍💫）

---

## 見つける力が上がる「守りのスイッチ」3つ🔧🧷

“理解”のために、**型が気づかせてくれる状態**に寄せるのがコツだよ✅

### 1) strictNullChecks 🛡️

`null/undefined` を「別の型」として扱い、雑に使うと型エラーで止めてくれる🧷✨ ([TypeScript][1])

### 2) exactOptionalPropertyTypes 🎯

オプションプロパティ（`x?: T`）を「**無い**」として厳密に扱う考え方が強くなる📦
（`undefined を入れる`のと`存在しない`が別物として見えやすくなる） ([TypeScript][2])

### 3) noUncheckedIndexedAccess 🧤

`obj[key]` や `arr[i]` みたいな取り出しに **undefined の可能性**を足してくれる🔍
「たまたま今はある」事故を減らせる✨ ([TypeScript][3])

---

## 手順（小さく刻む）👣✨

1. ✅ 変更前に、動作確認できる状態にする（テストor手動チェック手順）🧪
2. 🔎 `null` / `undefined` / `find` / `get` / `querySelector` を検索して「発生源」候補をリスト化📝
3. 🗺️ 1つ選んで、「どこで生まれてどこに渡るか」矢印で追う（呼び出し元へジャンプ！）🧭
4. 🧩 “無い”の種類を分類する（未設定／欠損／検索失敗／仕様で空）
5. 🧾 最後に「落ちる場所」を特定してメモ（次章の安全化で使う）📌✨

---

## ミニ課題✍️🗺️

次のコードの **null/undefinedマップ** を作ってみよう✨
（発生源→伝播→落ちる場所を1本の線で描くイメージ！）

```ts
type Product = { id: string; price: number };

const priceById: Record<string, number> = { a: 1000 };

function getProductPrice(products: Product[], id: string) {
  const p = products.find(x => x.id === id);
  const base = priceById[id];
  return p.price + base;
}
```

### ヒント💡

* `find` は？
* `priceById[id]` は？
* “落ちる場所” はどこ？

---

## AI活用ポイント🤖✅（お願い方＋チェック観点）

### 1) 発生源の洗い出しをしてもらう🔍

お願い例：

* 「この関数で null/undefined が発生しうる箇所を列挙して。**発生理由（どのAPIが何を返すか）**も書いて」

チェック観点✅

* “なぜそう言えるか” が書かれてる？（根拠なしに断言してない？）
* `find/get/querySelector/index access` を見落としてない？

### 2) 伝播経路を図解してもらう🗺️

お願い例：

* 「null/undefined の“伝播経路”を、`source → 関数 → 呼び出し元 → sink` の形式で箇条書きにして」

チェック観点✅

* sink（落ちる場所）が具体的？（`x.y` / `x()` / `+` など）

### 3) “無い”の種類を分類してもらう🧠

お願い例：

* 「このコードの“無い”を `未設定/欠損/検索失敗/仕様で空` に分類して、どれが混ざってるか教えて」

チェック観点✅

* 仕様で空なのに「例外にしろ」みたいな話になってない？（次章で判断する！）😌

---

## 最新メモ🆕（本章に関係ある範囲だけ）

* 直近の安定版として **TypeScript 5.9 系**が公開されているよ（5.9 の公式アナウンスあり） ([Microsoft for Developers][4])
* さらに **2026年初頭に TypeScript 6.0/7.0（ネイティブ移行の流れ）**が“早期2026”ターゲットとして報じられていて、ツール面の体験が大きく変わる期待があるよ🚀 ([InfoWorld][5])

（でも！ null/undefined の考え方そのものは「型で可能性を表して、分岐で受け止める」なので、この章の内容はそのまま超重要だよ🧷✨）

[1]: https://www.typescriptlang.org/tsconfig/strictNullChecks.html?utm_source=chatgpt.com "TSConfig Option: strictNullChecks"
[2]: https://www.typescriptlang.org/tsconfig/exactOptionalPropertyTypes.html?utm_source=chatgpt.com "TSConfig Option: exactOptionalPropertyTypes"
[3]: https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html?utm_source=chatgpt.com "TSConfig Option: noUncheckedIndexedAccess"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[5]: https://www.infoworld.com/article/4100582/microsoft-steers-native-port-of-typescript-to-early-2026-release.html?utm_source=chatgpt.com "Microsoft steers native port of TypeScript to early 2026 ..."
