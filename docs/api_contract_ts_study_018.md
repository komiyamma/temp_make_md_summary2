# 第18章：データ契約①：JSONの約束（形・必須・任意）🧾🤝

## この章でできるようになること🎯✨

* JSONの「契約（約束）」を、**形だけじゃなく言葉でも説明**できる🙂📝
* **必須 / 任意 / nullable / デフォルト値**を、混乱せずに使い分けられる🧠💡
* 変更するときに「これは安全？危険？」をざっくり判断できる⚖️🧯

---

## 1) JSONの“契約”ってなに？🤔📦

JSONは、作る側（Producer）と使う側（Consumer）の間で渡される「データの手紙」💌
この手紙には “約束” が必要だよね。

たとえば、こんな約束👇

* どんなキーが来るの？（形）🧩
* それは必須？任意？（ルール）✅
* nullは来る？来ない？（空の意味）🫥
* 値の意味は？単位は？（意味）📖

JSON自体の基本ルール（型や構文）は標準で決まってるよ。([datatracker.ietf.org][1])

---

## 2) まずは超重要ワード4つ✨（ここが沼ポイント😵‍💫）

### ✅ 必須（required）

「このキーが無いと成立しない」
例：ユーザーIDが無いと、誰のデータか分からない😇

### ☑️ 任意（optional）

「あるかもしれないし、無いかもしれない」
例：ニックネームは未設定の人もいる🙂

### 🫥 nullable（null許容）

「キーはあるけど値が null の可能性がある」
例：email は “未登録” を null で表す、みたいなケース📭

### 🎁 デフォルト値（default）

「省略されたとき、こう扱うよ」
例：language が無ければ `"ja"` とみなす、など🇯🇵

---

## 3) いちばん間違えやすい：「無い」「null」「空文字」🌀😵‍💫

ここ、ちゃんと区別すると超つよい💪✨

* **キーが無い**：そもそも情報が提供されてない

  * 例：`{}`
* **null**：提供されたけど「値が空（不在）」という意味

  * 例：`{"email": null}`
* **空文字 `""`**：値はある（ただし中身が空）

  * 例：`{"email": ""}`

💡ポイント：
「未入力」を `""` で表すのか `null` で表すのか、**契約として統一**しないと後で地獄になりがち🔥👹
（バリデーション、検索、DB、UI表示がズレる…）

---

## 4) “伝わるJSON契約”の書き方：3点セット🧰✨

JSON契約は、だいたいこの3つを揃えると強いよ💪

1. **サンプルJSON**（まず直感で伝える）👀
2. **文章の仕様**（人間向けに誤解を潰す）📝
3. **機械が読める仕様**（JSON Schema / OpenAPIなど）🤖✅

JSON Schema は「JSONの構造を定義するための標準仕様」だよ。([json-schema.org][2])
OpenAPI 3.1 のスキーマは **JSON Schema 2020-12 をベース**にしてる（しかも拡張もある）よ。([swagger.io][3])

---

## 5) 例でやってみよ💡：プロフィールJSON🧁

### 5-1) サンプルJSON（例）👀✨

```json
{
  "id": "u_123",
  "name": "Aoi",
  "nickname": "あおちゃん",
  "email": null,
  "createdAt": "2026-02-01T10:00:00Z"
}
```

### 5-2) 文章の仕様（この形にすると読みやすい📝🌸）

**UserProfile（ユーザープロフィール）**

* `id`（string）✅必須

  * 形式：`u_` で始まる識別子（例：`u_123`）
  * 意味：ユーザーを一意に識別するID
* `name`（string）✅必須

  * 意味：表示名（空文字はNG）
* `nickname`（string）☑️任意

  * 意味：任意のニックネーム（無ければ未設定）
* `email`（string または null）☑️任意 / 🫥null可

  * 意味：メールアドレス。未登録の場合は `null`
* `createdAt`（string）✅必須

  * 形式：RFC 3339/ISO 8601 形式の日時文字列（例：`2026-02-01T10:00:00Z`）

👉 ここで大事なのは **「任意」と「null可」を同時に書く**こと！

* `email` は「無い」もあり得るし（任意）、あっても null かもしれない（null可）…みたいに、現実は複雑なんだよね😵‍💫💦

---

## 6) JSON Schemaで“機械が読める契約”にする🤖✅

JSON Schema は「何が来てOKか」を宣言できるよ（2020-12 が現行の中心）([json-schema.org][4])

### 6-1) JSON Schema（例）🧾✨

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.com/schemas/user-profile.json",
  "title": "UserProfile",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^u_[0-9]+$"
    },
    "name": {
      "type": "string",
      "minLength": 1
    },
    "nickname": {
      "type": "string",
      "minLength": 1
    },
    "email": {
      "type": ["string", "null"],
      "format": "email"
    },
    "createdAt": {
      "type": "string",
      "format": "date-time"
    }
  },
  "required": ["id", "name", "createdAt"]
}
```

### 6-2) このSchemaの読み方（ここだけ押さえればOK✨）

* `required` に書かれたキーが **必須** ✅
* `properties` にあるけど `required` に無いキーは **任意** ☑️
* `type: ["string", "null"]` で **null許容** 🫥

  * OpenAPI 3.1 でも「nullは type に含める」流れが基本になってるよ。([swagger.io][3])
* `additionalProperties: false` は「知らないキーは拒否」🚫

  * 便利だけど、後方互換の観点では“厳しめ”になることもある（後で解説するね）⚠️

---

## 7) 互換性の観点：JSON変更の「安全/注意/危険」⚖️🧨

“データ契約”は変更で壊れやすい💥
ざっくり基準👇

### 🟢 比較的安全（壊れにくい）

* **任意のキーを追加**する（例：`nickname` を追加）➕🙂
* **制約をゆるくする**（例：文字数上限を広げる）🪶

### 🟡 注意（相手の実装次第で壊れる）

* **enum（許可値）の追加**

  * 使う側が「知らない値でも無視」できればOK
  * でも「知らない値はエラー！」だと壊れる😱
* **additionalProperties: false** を使ってる契約で、サーバが新キーを出し始める

  * “厳格クライアント”だと落ちる💣

### 🔴 危険（破壊変更になりやすい）

* **必須キーを追加**（古いクライアントが送れない/受け取れない）😵
* **キー削除**（使う側が参照してたら即死）💀
* **型変更**（string → number など）🧨
* **意味変更**（同じ値でも意味が変わるのが一番怖い😱）

---

## 8) ミニ演習📝🌸：JSON仕様を“文章”にしてみよう

### お題🎀

次のJSONの仕様を、人間が読んで誤解しない文章にしてね🙂✨

```json
{
  "productId": "p_001",
  "name": "Strawberry Cake",
  "price": 520,
  "salePrice": null,
  "tags": ["sweet", "seasonal"]
}
```

### ルール（テンプレ）🧾

各フィールドをこの5点で書こう👇

* 型（string/number/array/object…）
* 必須/任意
* null可/不可
* 制約（例：最小値、文字数、形式）
* 意味（何を表すか）

✨できたら最後に「無い vs null」の扱いも一言で！

---

## 9) AI活用コーナー🤖💞（レビュー係にしてラクしよ）

### 9-1) 仕様を読みやすく整理してもらう🧠✨

コピペしてお願い👇

* 「このJSON仕様を、**必須/任意/null可**が一目で分かるように整理して。曖昧な点があれば質問も出して」🧾🔍🤖

### 9-2) “破壊変更になりそう”を指摘してもらう⚠️

* 「この変更案は後方互換的に安全？危険？理由も3つ」🧯🤖

### 9-3) JSON Schemaに起こしてもらう🧾➡️🤖

* 「このサンプルJSONから JSON Schema（2020-12）を作って。`required` と `null` の扱いも丁寧に」([json-schema.org][4])

---

## 10) よくある事故あるある😇💥（先に踏み抜きを回避！）

* 「任意」なのに、実装では **必須扱い**してた（UIが落ちる）😵
* `null` を許可したつもりが、実は「キー無し」と混同してた🌀
* 仕様に「単位」が書いてなくて、円とドルが混ざった💸😱
* “意味変更”を軽くやってしまって、数字は正しいのに結果がズレた🧨

---

## まとめ🎓✨

* JSON契約は「形」だけじゃなく「必須/任意/null/意味」までがセット🧾💗
* 文章仕様 + 機械仕様（JSON Schema / OpenAPI）で、ブレと事故を減らせる🤖✅ ([json-schema.org][2])
* 変更は「必須追加・型変更・意味変更」が特に危険⚠️🔥

次の章では、**型だけじゃ守れない**ところを「実行時バリデーション」でどう守るかに進むよ🚫✅✨

[1]: https://datatracker.ietf.org/doc/html/rfc8259?utm_source=chatgpt.com "RFC 8259 - The JavaScript Object Notation (JSON) Data ..."
[2]: https://json-schema.org/draft/2020-12/json-schema-core?utm_source=chatgpt.com "JSON Schema: A Media Type for Describing JSON Documents"
[3]: https://swagger.io/specification/?utm_source=chatgpt.com "OpenAPI Specification - Version 3.1.0"
[4]: https://json-schema.org/draft/2020-12?utm_source=chatgpt.com "Draft 2020-12"
