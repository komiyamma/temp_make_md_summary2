# 第2章：互換性が壊れると何が起きる？😱💥

## ねらい🎯✨

「たった1つの変更」で、**どんな事故が起きるのか**を“具体例”でつかむよ〜🧠💡
（怖がらせたいんじゃなくて、**予防できる目👀**を作るのが目的！）

---

## まず結論：壊れ方はだいたい3種類😵‍💫🧨

## ① ビルドが落ちる（コンパイルで止まる）🟥🔨

TypeScriptが怒って、先に進めないやつ。
例：関数名が変わった、引数が増えた、型が厳しくなった…など。

* ✅ 良いところ：**早めに気づける**（本番で死ににくい）
* 😭 つらいところ：修正箇所が多いと「直しても直してもエラー」地獄

> TypeScriptはバージョンアップ時に “Notable Behavioral Changes” として、厳しくなる変更や挙動変更がまとめられることがあるよ📌 ([TypeScript][1])

---

## ② 実行時エラー（動かしてから死ぬ）💣🏃‍♀️

ビルドは通るのに、起動した瞬間（または特定操作で）落ちるやつ。

* 例：`undefined is not a function`
* 例：JSONの形が変わって、`user.id` が `undefined` になって落ちる
* 例：モジュール方式（ESM/CJS）の差で import が死ぬ

> 「型があるから安全」と思いがちだけど、**境界（入力/外部データ）では型だけじゃ守れない**ことがあるよ⚠️

---

## ③ サイレント破壊（落ちないけど、挙動が変わる）😇➡️😱

これがいちばん怖い…！
落ちないから気づきにくいのに、結果が変わって事故るやつ。

* 例：計算結果が微妙に変わる
* 例：日付処理の解釈が変わる
* 例：エラー扱いだったのが成功扱いになる（逆も）

> TypeScriptは “Breaking Changes” をまとめて公開していて、「コンパイルは通るけど意味が変わる」みたいな話も起こりうるよ📚 ([GitHub][2])

---

## 2026-02-04 時点での「アップデート事故が起きやすい現場」あるある🧯📌

## ✅ ランタイム（Node.js）を上げたら壊れる😵‍💫

Node.jsはメジャー間の移行で breaking change がまとまって出ることがあるよ。公式の移行ガイドも用意されてる。 ([Node.js][3])

そして、いまのリリースラインも押さえておくと安心！

* Node.js v25：Current（最新系）
* Node.js v24：Active LTS（長期サポートの安定枠）
* Node.js v22：Maintenance LTS（保守枠）

…みたいに「同時に複数ラインが生きてる」のが普通だよ🧩 ([Node.js][4])

---

## ✅ import まわり（ESM/CJS、exports、解決ルール）で壊れる📦🌀

TypeScriptの `moduleResolution`（import の探し方）や `module` 設定が噛み合ってないと、突然こうなる：

* `Cannot find module 'xxx'`
* `ERR_MODULE_NOT_FOUND`
* `Package subpath is not defined by "exports"`

このへんは TypeScript の公式設定説明があるよ📘 ([TypeScript][5])

---

## ✅ TypeScript 自体のアップデートで「急に型エラーが増える」🟦⚡

「バグ修正＝より正しくなる」ことで、昔たまたま通ってたコードが通らなくなることがあるよ。
だから **リリースノートの“変更点”を見るクセ**が超大事👀✨ ([TypeScript][1])

（ちなみに TypeScript 5.9 は安定版が出ていて、公式リリース一覧でも確認できるよ） ([GitHub][6])
さらに将来の TypeScript 6/7 では大きめの整理が進む方針も出てるから、「アップデート＝何も起きない」とは思わないのが安全🧠 ([Microsoft for Developers][7])

---

## 具体例で体感しよ〜🧪✨（よくある3パターン）

## パターンA：関数の名前変更（ビルド落ち）🟥

### 変更前（利用者のコード）

```ts
import { calcTax } from "my-lib";

const total = calcTax(1000);
```

### 変更後（ライブラリ側が `calcTax` を `calculateTax` に改名）

利用者側はこうなる👇

* `calcTax` が見つからなくてビルド落ち💥
* エラー文が出るので、直す場所は分かりやすい🙆‍♀️

✅ **気づきやすい壊れ方**だね！

---

## パターンB：引数や戻り値の意味変更（サイレント破壊）😇➡️😱

### 変更前

* `discountRate = 0.2` は **20%引き** の意味

### 変更後（内部仕様変更）

* `discountRate = 0.2` は **最終価格の係数（0.8の意味）** に変わった

型は `number` のままだから、**ビルドも通る**。
でも値の意味が変わったから、売上計算がズレて大事故〜😇💥

✅ 対策の考え方：

* 「型」だけじゃなくて **意味（セマンティクス）も契約**だよ🧾✨

---

## パターンC：JSONの形が変わった（実行時エラー or サイレント破壊）🧾💥

たとえば API がこう変わる：

* 変更前：`{ userId: "A123" }`
* 変更後：`{ id: "A123" }`

利用者のコードがこうだと👇

```ts
// どこかで any になってたり、型を付けずに扱ってると…
const userId = response.userId.toUpperCase();
```

* `response.userId` が `undefined` になって **実行時エラー**🔥
* あるいは、分岐次第で「変な値で進んで」**静かに壊れる**😇

✅ よくある原因：

* 外部データ（API/DB/ファイル）を **“型だけで信用した”**
* “境界”にチェックがない（ここは第19章で深掘りするやつ！）

---

## 症状別：「今、何が起きてる？」の見分け方👀🔎

## 🟥 ビルド落ちのサイン

* エラーが **大量に出る**
* CI で止まる
* import / 型 / 引数 / 戻り値あたりが多い

→ **互換性が壊れた可能性 高め**🧨

---

## 💣 実行時エラーのサイン

* 起動直後に落ちる
* 特定の画面/操作でだけ落ちる
* ログに `undefined` / `not a function` / `Cannot read properties of ...` がいる

→ **境界データか import 解決**をまず疑う📦🧾

---

## 😇➡️😱 サイレント破壊のサイン

* 失敗はしないが「結果が変」
* 問い合わせが来て初めて発覚
* A/B の数字がズレる
* テストがないと気づきにくい

→ **“意味変更”が混ざってないか**疑うのがコツ🧠✨

---

## ミニ演習📝✨「変更1つで困る人、3タイプ想像」👥👥👥

次の変更を想像して、困る人を3タイプ書いてみよ〜✍️

> 変更：`getUser(id: string)` が `getUser(userId: string)` に名称変更された

例の書き方テンプレ👇

* タイプ1：〇〇（例：別チームのフロント担当）→ 困る理由：〇〇😵‍💫
* タイプ2：〇〇（例：自動テスト/CI担当）→ 困る理由：〇〇💥
* タイプ3：〇〇（例：過去バージョン固定の顧客）→ 困る理由：〇〇🧊

ポイントは「**自分以外の誰か**」を入れることだよ〜🌸

---

## AI活用🤖💡（Copilot / Codex で“影響調査”を爆速にする）

そのまま貼って使えるプロンプト例だよ🪄✨
（相手がコードも読める前提のAI拡張向け）

## ① 影響範囲チェック🔍

```text
この変更（diff）で、利用者が壊れる可能性がある箇所を
「ビルド落ち」「実行時エラー」「サイレント破壊」に分類して列挙して。
各項目に、具体的な壊れ方の例も1つずつつけて。
```

## ② “契約としての意味”の確認🧾

```text
この関数/レスポンスの「意味（セマンティクス）」として
利用者に約束している前提を箇条書きにして。
破った可能性があるものに ⚠️ を付けて。
```

## ③ “破壊変更かどうか”判定🧨

```text
この変更は破壊変更（breaking change）？
そうなら「何が契約で」「どこが破られたか」を短く説明して。
破壊変更じゃない形に寄せる代案も2つ出して。
```

---

## 最後に：この章のまとめ🌟

* 互換性が壊れると、だいたい **①ビルド落ち ②実行時エラー ③サイレント破壊** のどれかで来る😱
* いちばん怖いのは **落ちないのに結果が変わる**タイプ😇➡️😱
* Node.js や TypeScript のアップデート、import 解決の変更は “壊れポイント”になりやすい📦🌀 ([Node.js][3])
* 影響調査は AI 拡張に投げると速い🤖⚡（ただし最終判断は人間の目👀✨）

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-5.html?utm_source=chatgpt.com "Documentation - TypeScript 5.5"
[2]: https://github.com/microsoft/TypeScript/wiki/Breaking-Changes?utm_source=chatgpt.com "Breaking Changes · microsoft/TypeScript Wiki"
[3]: https://nodejs.org/en/blog/migrations/v22-to-v24?utm_source=chatgpt.com "Node.js v22 to v24"
[4]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[5]: https://www.typescriptlang.org/tsconfig/moduleResolution.html?utm_source=chatgpt.com "TSConfig Option: moduleResolution"
[6]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[7]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
