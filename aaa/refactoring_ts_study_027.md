# 第27章 重複排除②（ユーティリティ地獄を避ける）🧯🧰

### ねらい🎯

重複をまとめたい気持ちは正しいんだけど…
まとめ方を間違えると **`utils/` がなんでも入るゴミ箱** になって、逆に読みにくくなるの🥲🗑️
この章では「共通化したコードの置き場所」を迷わないルールで決められるようになるよ✨📁

---

### 今日できるようになること🌸

* 「共通化するのはOK、でも置き場は“責務”で決める」感覚がわかる🧠✨
* `utils地獄` の典型パターンを避けられる🚫🧨
* **近く → 機能内共有 → 全体共有** の順で安全に育てられる🌱➡️🌳
* AI提案（Copilot / Codex）を“鵜呑みにせず”置き場判断できる🤖✅

---

## 1. ユーティリティ地獄ってなに？😱🧰

### よくある症状🩹

* `src/utils.ts`（または `src/utils/`）が巨大化📈
* 便利そうだから何でも入れてしまう🧺
* どれが「本当に共通」かわからない😵‍💫
* 結果：**探せない・直せない・壊れる** の三重苦💥

### なぜ起きるの？🤔

共通化の判断が「同じ形」だけになって、
本当は大事な **“同じ理由で変わるか？”（＝同じ責務か？）** を見てないからだよ🧠💡

---

## 2. 置き場を決める超シンプルルール📁✨

### ルールA：まずは“近く”に置く🏠

「共通化したい！」と思っても、最初は **使ってる場所の近く** に置くのが安全👣🛟
（いきなり `shared` に置くと、あとで地獄になりやすい）

✅ 目安

* 1ファイル内の重複 → **同じファイルの下に private helper**
* 同じフォルダ内の数ファイルで共通 → **同じフォルダに `xxx.helpers.ts` じゃなく、意味のある名前のファイル**

### ルールB：機能（feature）内共有 → 機能フォルダの中で完結🎁

例：`checkout` の中だけで使うなら、**checkout の中**に置く📦
「将来他でも使いそう」はだいたい罠🙈（未来予測で shared を増やすと散らかる）

### ルールC：全体共有は“名前で縛る”🔒

全体共有にするなら、フォルダ名を **ドメイン or 技術の意味が伝わる** ものにするのが大事✨

* ❌ `utils/`, `common/`, `helpers/`（何でも入る）
* ✅ `money/`, `date/`, `http/`, `id/`, `format/`（入れられる物が限定される）

---

## 3. 具体例で体感しよ〜🧩➡️✨（ビフォー/アフター）

### お題：金額表示があちこちで重複してる💴😵

#### Before（各所にベタ書き）🫠

```ts
// src/features/checkout/ui/OrderSummary.ts
export function formatYen(amount: number) {
  return new Intl.NumberFormat("ja-JP", { style: "currency", currency: "JPY" }).format(amount);
}

// src/features/cart/ui/CartRow.ts
export function formatYen(amount: number) {
  return new Intl.NumberFormat("ja-JP", { style: "currency", currency: "JPY" }).format(amount);
}
```

「同じじゃん！utilsに入れよ！」ってなるけど…ちょっと待って🫷😇

---

### よくある失敗例（`utils` に投げる）🚫🗑️

```ts
// src/utils.ts  ← こういうのが増えていく…
export function formatYen(amount: number) { /* ... */ }
export function calcTax(amount: number) { /* ... */ }   // え、税計算まで…？
export function buildOrderTitle(o: Order) { /* ... */ } // それドメイン…
```

税計算とか注文タイトルは、**ビジネス都合で変わる**やつだよね？
それを `utils` に入れると「変更理由がバラバラ」になって崩壊する💥🧨

---

### After（“意味で分けて”置く）✨📁

✅ 金額の「表示」は技術寄り（UIで使う共通表現）
→ `shared/money` に置くのが自然💴✨

```ts
// src/shared/money/formatJPY.ts
const formatter = new Intl.NumberFormat("ja-JP", { style: "currency", currency: "JPY" });

export function formatJPY(amount: number): string {
  return formatter.format(amount);
}
```

```ts
// src/features/checkout/ui/OrderSummary.ts
import { formatJPY } from "@/shared/money/formatJPY";

export function renderTotal(total: number) {
  return formatJPY(total);
}
```

---

### じゃあ「税計算」はどこ？🧾🤔

税率や端数処理が「仕様」で変わるなら、これは **ドメイン寄り**🌱
→ checkout の domain に閉じ込めるのが安全🔐

```ts
// src/features/checkout/domain/calcTax.ts
export function calcTax(amount: number): number {
  // 例：切り捨て仕様（仕様なので変わり得る）
  return Math.floor(amount * 0.1);
}
```

こうすると、

* 表示の共通（format）＝ shared
* 仕様の共通（税計算）＝ feature/domain
  で責務が混ざらない✨🎯

---

## 4. “置き場”判断チェックリスト✅🧠

共通化したくなったら、この順で質問してね💡

### Q1：そのコード、ビジネス用語が入ってる？🏷️

* ✅ 入ってる → feature の中（domain / usecase寄り）📦
* ❌ 入ってない → shared 候補🌍

### Q2：変更理由は1つ？🎯

* ✅ 仕様が変わる時だけ → domain
* ✅ 技術都合（表示・通信・変換）だけ → shared
* ❌ 理由が複数 → 分ける（混ぜない）🧨

### Q3：依存が重い？🏋️‍♀️

* UI（React）に依存してるのに shared に置くと、他で使えなくて微妙…🥲
  → **UI依存は基本 feature/ui に寄せる** のが無難🎀

---

## 5. 安全な進め方（小さく刻む）👣🛟

1. **重複してる関数を1つに決める**（片方を“正”にする）👑
2. もう片方を **import に置き換える**🔁
3. 型チェック & テスト & 実行で確認✅🧷🧪
4. 置き場が微妙なら、まずは **近くに置いてから育てる**🌱
5. “共有先”を広げるのは、必要が出た時だけ📈

---

## 6. VS Codeでラクする小技🧑‍💻✨

* 参照検索（Find All References）で「本当にどこで使われてるか」確認👀
* Rename Symbol で安全に命名変更🏷️
* Move to a new file（拡張や機能による）で切り出し補助📦
* import が増えたら、パスを整理して読みやすく📌

---

## 7. ミニ課題✍️🌼（15〜25分）

### 課題A：分類ゲーム🃏✨

次の “共通化候補” を、どこに置くか決めてね📁

* `formatJPY(amount)`
* `calcTax(amount)`
* `buildOrderTitle(order)`
* `retryFetch(url)`

👉 置き場所を **「近く / feature内 / shared」** のどれかで書いてみよう✍️😊

### 課題B：置き場ルールを3つ作る📜✨

あなたのプロジェクト用に、次の形で3つルールを書いてみてね💡

* 「〇〇なら feature/domain」
* 「〇〇なら shared/xxx」
* 「迷ったら〇〇」

---

## 8. AI活用ポイント🤖✅（お願い方＋チェック観点）

### AIへのお願いテンプレ📝

「置き場を提案して」だけだと、AIは雑に `utils` を作りがち😇🧯
なので、制約をつけて頼むのがコツ✨

```text
次の重複コードを共通化したいです。
- “変更理由（仕様/技術）” を推測して分類してください
- 置き場所を「近く / feature内 / shared」に分けて3案ください
- utils/common/helpers という名前は禁止
- それぞれの案のメリット/デメリットも書いてください
```

### AIの答えをチェックする観点✅

* 「将来使うかも」で shared を増やしてない？🔮❌
* ドメイン（仕様）を shared に混ぜてない？🧾❌
* shared の名前が “意味で縛られてる”？（money/date/http…）🔒✅
* import が変に循環しそうじゃない？🔁⚠️

※ lint周りは最近のESLintは **flat config が標準** になって移行期の落とし穴もあるから、AIが古い `.eslintrc` 前提の提案をしてたら注意してね🧯（ESLint v9でflat configがデフォルト化）([ESLint][1])
TypeScript向けのLint連携（typescript-eslint）も継続更新されてるよ📈([GitHub][2])

---

## まとめ🎀✨

* 共通化はOK！でも **置き場は“責務（同じ理由で変わるか）”で決める**🧠🎯
* 迷ったら **近くに置いて育てる**🌱
* 全体共有は **意味で縛る名前（money/date/http…）** にして、`utils地獄` を防ぐ🧯📁
* AIは便利だけど、置き場判断は **チェックリストで人間が最終決定**🤖✅

[1]: https://eslint.org/blog/2025/03/flat-config-extends-define-config-global-ignores/?utm_source=chatgpt.com "Evolving flat config with extends"
[2]: https://github.com/typescript-eslint/typescript-eslint/releases?utm_source=chatgpt.com "Releases · typescript-eslint/typescript-eslint"
