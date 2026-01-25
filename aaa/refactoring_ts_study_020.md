# 第20章 リネーム②（関数・ファイル・型名）📁🧩🏷️

### ねらい🎯

* 関数・ファイル・型（type/interface/class/enum）の名前を整えて、プロジェクト全体の読みやすさを爆上げする📈✨
* 「名前＝設計の入口」って感覚を、やさしく体に覚えさせる🧠🌱
* VS Codeのリネーム機能で、安全に一括置換できるようになる🛟🧑‍💻

---

### 今日のゴール🌸

* どんなときに **関数名／ファイル名／型名** を変えるべきか説明できる📣✨
* リネームの“事故ポイント”（外部API・文字列キー・公開APIなど）を避けられる🚧⚠️
* 命名ルールを「1枚」にまとめて、迷いを減らせる📄🎀

---

## 1) まず結論：良い名前は「説明書」📖✨

コードは読まれるもの👀💡
特にリファクタ初学者のうちは、**「正しい処理」より「伝わる名前」**のほうが、バグを減らす近道になりがちだよ🛡️🌷

---

## 2) “変えるべき名前”のサイン集👃✨

### 関数名のサイン🧩

* `doThing`, `process`, `handle`, `exec` みたいに **何してるか不明**😵‍💫
* 返り値が真偽なのに `getX` みたいな名前（例：`getUser` が `boolean` 返す）🙅‍♀️
* `calc` みたいに短すぎて、文脈がないと読めない🫧
* 1つの関数が「複数の仕事」してて、名前が雑になってる（それは分割のサインでもある✂️）

### ファイル名のサイン📁

* `util.ts`, `helper.ts`, `common.ts` が増殖🧟‍♀️
* ファイル名と中身の責務がズレてる（例：`user.ts` に注文処理も混ざってる）🌀
* `index.ts` が便利すぎて “中身がカオス”🧨

### 型名のサイン🏷️

* `Data`, `Info`, `Result`, `Item` だけで世界を回してる🌍💦
* `type A = any` 的な “仮置き” が放置されてる🫠
* `User` が「DBの行」「APIのDTO」「画面表示用」全部を兼ねてる（境界が混ざってる）🎭

---

## 3) 命名の基本ルール（超かんたん版）🧁✨

### (A) 関数名：**動詞＋目的語** が最強💪📝

* ✅ `fetchUserProfile`（プロフィールを取得する）
* ✅ `calculateTotalPrice`（合計金額を計算する）
* ✅ `parseOrderCsv`（注文CSVを解析する）
* ❌ `process` / `doStuff`（何を？どこまで？が不明😇）

#### よく使う動詞テンプレ🧠💡

* 取得：`get` / `fetch` / `load` / `read`
* 変換：`parse` / `format` / `normalize` / `convert`
* 作成：`create` / `build` / `make`
* 検証：`validate` / `assert` / `is`
* 更新：`update` / `set` / `apply`
* 削除：`remove` / `delete` / `clear`

> 使い分けのコツ：
>
> * `get` は “近くにある” から取る感じ🧺
> * `fetch` は “どこかから取りに行く” 感じ（APIとか）🌐
>   ※ これはチームで統一できればOKだよ🎀

---

### (B) ファイル名：**何が入ってるか一目で分かる名札**📛📁

よくある統一例（どれかに寄せよう）👇

* `kebab-case`：`user-profile.ts`（Web系で多い🧁）
* `camelCase`：`userProfile.ts`
* `PascalCase`：`UserProfile.ts`（クラス中心の文化で見る👀）

迷ったら、ファイル名は **kebab-case** が読みやすくておすすめになりやすいよ🧁📁
（ただし既存のプロジェクトが別ルールなら、それに合わせるのが最優先🎀）

---

### (C) 型名：**PascalCase** が基本👑✨

* ✅ `UserId`, `Order`, `OrderStatus`
* ✅ `ApiUserDto`, `DbUserRow`, `UserViewModel`（用途が見える👀✨）
* ❌ `user_type`, `order_status`（型名としては統一しづらいことが多い）

命名規約を強制したいときは、`typescript-eslint` の `naming-convention` ルールでスタイルを揃えられるよ👮‍♀️✨ ([TypeScript ESLint][1])

---

## 4) VS Codeで安全にリネームする（超重要）🛟🧑‍💻

### 4-1) シンボルを一括リネーム（関数・型・変数など）🏷️✨

1. 変えたい名前にカーソルを置く👆
2. `F2`（Rename Symbol）🔁
3. 新しい名前を入力してEnter✅
4. 参照箇所もまとめて変わる（言語対応していれば）🎯 ([Visual Studio Code][2])

> ポイント💡
> “検索置換”と違って、意味のある参照を追ってくれるのが強い✨
> （だから誤爆が減る🧯）

---

### 4-2) ファイル移動・リネーム時に import を自動更新する📦🔁

TypeScriptのプロジェクトでは、ファイル名を変えると import パスが壊れがち😵‍💫
VS Codeは **移動/リネーム時に import パスを更新**できるよ🛠️✨ ([Visual Studio Code][3])

設定キー（覚えなくてOK、検索できればOK🔍）

* `typescript.updateImportsOnFileMove.enabled`（TypeScript用）([Visual Studio Code][3])
* 値は `"prompt"`（確認する/デフォルト）、`"always"`（常に更新）、`"never"`（更新しない） ([Visual Studio Code][3])

おすすめはこう👇🎀

* 普段：`"prompt"`（安全に確認できる）🛟
* 小さい学習プロジェクト：`"always"`（気持ちよく進む）🚀
* 大規模で怖い時：いったん `"prompt"` に戻す👀

---

### 4-3) リネーム後の“安全チェック”✅🛡️

リネームは基本的に挙動を変えないけど、**外部との境界**で事故りやすいよ🚧💥

リネーム後に必ずやること👇

* 型チェック🧷（`tsc` / VS Codeのエラー0）
* テスト🧪（あれば最優先！）
* 実行確認▶️（最低1回）
* 差分チェック👀（想定外に変えてない？）

---

## 5) 事故りやすいリネームTOP5🚧⚠️（ここ超大事）

1. **JSONのキー名**（例：`{ user_id: ... }`）を変えちゃう🫠

   * これは挙動変わる！API互換が崩れる！
2. **公開APIのexport名**（外から使われてる関数/型）📦
3. **文字列で参照してる名前**（ルーティング名、イベント名、ログの識別子など）🧵
4. **DBのカラム名・テーブル名**🗄️
5. **設定ファイルのキー**（例：`"featureXEnabled"`）⚙️

合言葉：
**「コード上の参照」じゃなくて「文字列や外部契約」なら、リネーム＝仕様変更** になりやすい📜⚠️

---

## 6) ビフォー/アフター：関数名を“責務が伝わる形”へ🧩➡️✨

### Before（何してるか薄い😵‍💫）

```ts
export function process(items: { price: number; qty: number }[]) {
  let sum = 0;
  for (const item of items) {
    sum += item.price * item.qty;
  }
  return sum;
}
```

### After（読むだけで分かる😍）

```ts
type LineItem = { price: number; quantity: number };

export function calculateTotalPrice(items: LineItem[]): number {
  let total = 0;
  for (const item of items) {
    total += item.price * item.quantity;
  }
  return total;
}
```

良くなったところ💖

* `process` → `calculateTotalPrice`（何をする関数か一発👀）
* `qty` → `quantity`（略語はチームが許す範囲で！迷ったら素直に✨）
* `sum` → `total`（意味が合ってる）

---

## 7) ビフォー/アフター：型名で“用途の境界”を見せる🏷️🧱

### Before（全部Userで混ざる😇）

```ts
export type User = {
  id: string;
  name: string;
  createdAt: string;
};
```

### After（境界が見える✨）

```ts
// APIから来る形
export type ApiUserDto = {
  id: string;
  name: string;
  createdAt: string; // ISO文字列
};

// 画面で使う形（必要なら）
export type UserViewModel = {
  id: string;
  displayName: string;
  createdAtLabel: string;
};
```

ポイント🎀
「同じ人」でも、**層によって“必要な形”が違う**ことが多いよ🌷
名前で分けると、混乱がグッと減る🧠✨

---

## 8) ファイル名リネームの例（importが壊れない流れ）📁🛟

### 例：`user.ts` → `user-profile.ts` にしたい

やることはシンプル👇

* ファイル名を変更（Explorer上でリネーム）✏️
* import更新を VS Code に任せる（設定が `"prompt"` なら確認が出る）🔁 ([Visual Studio Code][3])
* 型チェック＆テストでOK✅

---

## 9) 命名ポリシー「1枚シート」テンプレ📄🎀

プロジェクトで迷いを減らすために、これだけ決めよう💡

* ファイル名：`kebab-case`（例：`user-profile.ts`）📁
* 関数名：`動詞 + 目的語`（例：`fetchUserProfile`）🧩
* 型名：`PascalCase`（例：`UserProfile`）🏷️
* DTO/DB/画面：用途を接尾辞で区別（`Dto`, `Row`, `ViewModel` など）🧱
* 略語：原則しない（例外：`id`, `url` など “一般常識レベル” のものだけ）🔤
* boolean：`is/has/can/should` で始める（例：`isValid`, `hasPermission`）✅

---

## 10) ミニ課題✍️🌷

### 課題A：関数名を10個直す🏷️✨

次の “薄い名前” を、意図が伝わる名前に直してみよう👇

* `processUser`
* `doLogin`
* `handle`
* `calc`
* `makeData`

ルール：**動詞＋目的語**にする🧠✨

---

### 課題B：型名を「用途」で分ける🏷️🧱

`User` を次の3つに分けて命名してみよう👇

* APIから来る形
* DBに保存する形
* 画面表示用の形

---

### 課題C：命名ポリシー1枚を完成させる📄🎀

上のテンプレを自分のプロジェクト用に埋めて、`docs/naming.md` に置く（つもりでOK）🗂️✨

---

## 11) AI活用ポイント🤖✅（お願い方＋チェック観点）

### お願い方（コピペOK）📝✨

* 「この関数がやってることを **日本語1文** で説明して。その説明に合う関数名を **英語で10個** 出して」🤖
* 「この型は **API DTO / DB / UI** のどれ？理由も。分けるなら型名案を出して」🤖
* 「このファイル名、責務に合ってる？合ってないなら新しい名前とフォルダ配置案を出して」🤖📁

### チェック観点✅

* 名前が“やること”を言ってる？（`process` みたいに逃げてない？）👀
* 似た概念の名前と整合してる？（`fetch` と `get` が混ざってない？）🎀
* 長すぎて読めない？（長いなら分割のサインかも✂️）🧩
* 外部契約（JSONキー/公開API）を変えてない？🚧⚠️

---

## 12) 最新メモ🗞️✨（2026年初の現状）

* TypeScript は npm 上で **5.9.3** が “Latest” として公開されているよ🧷✨ ([npm][4])
* VS Code の `F2` リネームは公式のリファクタ機能として案内されているよ🛠️✨ ([Visual Studio Code][2])
* ファイル移動/リネーム時の import 更新は `typescript.updateImportsOnFileMove.enabled` で制御できるよ📦🔁 ([Visual Studio Code][3])

---

### まとめ🧁✨

* 関数名＝「動詞＋目的語」🧩
* ファイル名＝「中身の名札」📁
* 型名＝「用途の境界を見せる」🏷️🧱
* VS Code のリネーム機能で、安全に一括変更🛟✨
* 事故るのは “外部契約（文字列・公開API）”🚧⚠️

[1]: https://typescript-eslint.io/rules/naming-convention/?utm_source=chatgpt.com "naming-convention"
[2]: https://code.visualstudio.com/docs/editing/refactoring?utm_source=chatgpt.com "Refactoring"
[3]: https://code.visualstudio.com/docs/typescript/typescript-refactoring?utm_source=chatgpt.com "Refactoring TypeScript"
[4]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
