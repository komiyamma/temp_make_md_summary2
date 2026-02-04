# 第22章：HTTP API契約①：骨格（入力/出力/ステータス）🌐🦴

## 22.1 この章でできるようになること 🎯💖

* HTTP APIの「最低限の契約セット」を、迷わず書けるようになる 📝✨
* 1つのAPIについて「入力（Request）」「出力（Response）」「ステータスコード」をセットで決められる 🧩🌈
* “あとから壊れない”ために、最初に固定すべきポイントが分かる 🧱🔒

---

## 22.2 まず覚える！HTTP API契約の「骨格」5点セット 🦴✨

HTTP APIの契約って、まずはこれだけ決めればOKだよ〜！😊🌸

1. **エンドポイント**（例：`/memos`）🛣️
2. **メソッド**（GET/POST/PUT/PATCH/DELETE）🖱️
3. **入力**（path/query/header/body）📥
4. **出力**（成功レスポンスの形）📤
5. **ステータスコード**（成功/失敗の意味づけ）🔢

この5点が固まると、仕様が一気にブレにくくなるよ✨
（OpenAPIでも「ステータスコードで結果を表す」前提になってるよ）([Swagger][1])

---

## 22.3 入力（Request）を「どこに・何を・どう入れるか」決めよう 📥🧾✨

### A) 入力の置き場所は4種類 🧺🌼

* **Path**：リソースの場所（例：`/memos/{memoId}`）🧭
* **Query**：絞り込み・ページング（例：`?limit=20&cursor=...`）🔎
* **Header**：認証・言語・トレースIDなど（例：`Authorization`）🏷️
* **Body**：作成/更新の中身（JSONなど）📦

ポイント：

* **GETは基本Bodyなし**にしておくと混乱しにくいよ（道具や中間機器の相性も安定しやすい）🧠✨
* **BodyはContent-Type**とセット（だいたいJSON）📮

### B) 入力仕様の「テンプレ」🧾✨

APIの入力は、これだけ書けば最低限の契約になるよ👇

* **どこに入る？**（path/query/header/body）
* **項目名**
* **型**（string/number/boolean/配列/オブジェクト）
* **必須？任意？**
* **制約**（最小最大、文字数、正規表現、列挙など）
* **例**（Good/Badがあると神✨）
* **エラー時どうなる？**（どのステータス？エラー形式は？）

---

## 22.4 出力（Response）を「成功の形」で固定しよう 📤🎁✨

### A) まずは成功レスポンスの基本パターン3つ 🌟

* **200 OK**：取得・更新結果を返す（Bodyあり）📦
* **201 Created**：新規作成できた（新しいリソースができた）🎉
* **204 No Content**：成功したけど返すBodyなし（削除など）🧹

ステータスコードは「結果の意味」を運ぶものだよ。HTTPの意味はRFCで定義されてるから、迷ったらここに寄せるのが一番安全✨（成功/失敗クラスなど）([IETF Datatracker][2])

### B) レスポンスの形は「揃える」と運用がラク 🧠💗

初心者のうちは、成功レスポンスを **だいたい同じ形** に揃えるのが超おすすめ！
（クライアント側の実装が楽＆壊れにくい✨）

例：

* 単体取得：`{ data: {...} }`
* 一覧：`{ data: [...], page: {...} }`
* ただし「小規模なら素直にそのまま返す」でもOK（やりすぎないの大事）🌿

---

## 22.5 ステータスコードの選び方：最小ルールだけ覚えよっ 🔢🧠✨

### A) まずは「3分類」でOK！🍡

* **2xx**：成功 🎉
* **4xx**：クライアント側が直せる可能性が高い（入力ミスなど）🧩
* **5xx**：サーバ側の問題（落ちてる/不具合など）🛠️

この「クラス分け」自体がHTTPの基本の考え方だよ([IETF Datatracker][2])

### B) よく使う定番セット（最初はこれで戦える）🔥

* **200 OK**：GET成功 / 更新結果返す
* **201 Created**：POSTで新規作成成功
* **204 No Content**：DELETE成功（Bodyなし）
* **400 Bad Request**：形式がおかしい（JSON壊れてる、型が変、必須欠け等）
* **401 Unauthorized**：認証できてない（ログイン情報ない/無効）🔐
* **403 Forbidden**：認証はできたけど権限がない 🙅‍♀️
* **404 Not Found**：対象がない（ID違いなど）🕳️
* **409 Conflict**：競合（重複、同時更新の衝突など）⚔️
* **422 Unprocessable Content**：形式はOKだけど内容がダメ（ルール違反）📏
* **429 Too Many Requests**：叩きすぎ（レート制限）🚦
* **500 Internal Server Error**：サーバで想定外 💥

ステータスコードは標準の登録済みコードから選ぶのが基本で、OpenAPIもその前提で書くよ([Swagger][1])

---

## 22.6 失敗レスポンスも「骨格だけ」決めよう（超重要）🚨🧱

「エラー時に何が返るか」も契約だよ！
最近は、HTTP APIのエラー形式として **Problem Details** が強い味方✨

* 規格：**RFC 9457**（RFC 7807を置き換え）
* Content-Type：`application/problem+json` が基本 ([RFCエディタ][3])

### Problem Details の最小形（例）🧾✨

（この章では“骨格”として、まずこれを採用候補にしておく感じでOK！）

```json
{
  "type": "https://example.com/problems/invalid-parameter",
  "title": "Invalid parameter",
  "status": 400,
  "detail": "title is required",
  "instance": "/memos"
}
```

RFC 9457で定義されている基本フィールド（type/title/status/detail/instance）に寄せると、クライアントも処理しやすくなるよ🫶([RFCエディタ][3])

---

## 22.7 仕様を書いてみよう：1本のAPIをテンプレで固める 🧾🛠️✨

### A) 仕様テンプレ（文章版）📄🌸

まずはこれをコピペして埋めてね👇

* **目的**：何をするAPI？
* **Method / Path**：`POST /memos` みたいに
* **入力**

  * path：なし/あり（項目・型・必須）
  * query：なし/あり
  * header：必要なら
  * body：JSONスキーマ（必須/任意、制約、例）
* **成功レスポンス**

  * status：200/201/204 のどれ？
  * body：返すなら形（例）
* **失敗レスポンス**

  * 400/401/403/404/409/422…のどれが起きる？
  * エラー形式：Problem Details（最小形）
* **例（curl的なやつ）**：リクエスト例とレスポンス例（Good/Bad）

### B) OpenAPIで「契約をファイル化」する（入口だけ）📘✨

OpenAPIはHTTP APIの標準的な記述形式だよ（人も機械も理解しやすい）([Swagger][4])
バージョンは3.1系だけじゃなく、3.2.0の仕様ページも公開されてるよ([OpenAPI Initiative Publications][5])
（3.1.1は3.1.0の要求を変えずに改善が入った、というリリースノートもあるよ）([GitHub][6])

ここでは「pathsの骨格」だけ例ね👇

```yaml
openapi: 3.1.0
info:
  title: Memo API
  version: 1.0.0
paths:
  /memos:
    post:
      summary: Create a memo
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [title]
              properties:
                title:
                  type: string
                  minLength: 1
                body:
                  type: string
      responses:
        "201":
          description: Created
        "400":
          description: Bad Request (Problem Details)
          content:
            application/problem+json:
              schema:
                type: object
                properties:
                  type: { type: string }
                  title: { type: string }
                  status: { type: integer }
                  detail: { type: string }
                  instance: { type: string }
```

OpenAPIではステータスコードもレスポンス定義の中心になるよ([Swagger][1])
Problem DetailsのContent-Type（`application/problem+json`）もRFCで定義されてるよ([RFCエディタ][3])

---

## 22.8 例題：メモ作成APIを「契約の骨格」で完成させる 📝🧠✨

### API：`POST /memos` 🧡

**目的**：メモを1件作る ✍️

**Request Body（JSON）**

* `title`：string、必須、1文字以上
* `body`：string、任意

**成功**

* **201 Created**
* 返すなら例：`{ "id": "m_123", "title": "...", "body": "...", "createdAt": "..." }`

  * 返す/返さないはチーム方針でOK（どっちでも契約として固定が大事）🔒✨

**失敗（例）**

* **400**：JSON壊れてる / 必須がない / 型が変
* **422**：形式はOKだけど内容ルール違反（例：titleが空文字）
* エラーはProblem Detailsで返す（骨格は22.6参照）📛

---

## 22.9 ミニ演習（手を動かすやつ）💪🌸🧪

### 演習1：テンプレを埋めて「1本」仕様を書こう 🧾✨

次のどれかを選んで、22.7Aのテンプレを埋めてみてね😊

* `GET /memos`（一覧）📚
* `GET /memos/{memoId}`（単体取得）🔎
* `DELETE /memos/{memoId}`（削除）🧹

**チェックポイント** ✅

* 入力の置き場所（path/query/body）が自然？
* 成功ステータスが200/201/204のどれかで説明できる？
* 400/404/422の出し分けができてる？

### 演習2：ステータスコード当てクイズ 🎮🔢

次を、どのステータスにするか決めて理由も1行で✨

* 存在しない `memoId` を取りにいった
* `title` が空文字で作成しようとした
* 同じタイトルは禁止、すでに存在した
* 1分間に1000回叩いてきた

（ヒントは22.5Bだよ〜💡）

---

## 22.10 AI活用（“契約の叩き台”を秒速で作る）🤖🛠️✨

### そのままコピペで使えるプロンプト集 🧠💗

* *「`POST /memos` のAPI契約を、入力（path/query/body）・成功レスポンス・失敗レスポンス（400/422/404など）・ステータスコード理由つきで、箇条書きにして」* 📝🤖
* *「次のJSON仕様（title必須、body任意）に対して、400と422の境界例を5つずつ出して」* 📛🤖
* *「Problem Details（RFC 9457）で、入力エラー用のtype設計案（URL例）を3つ提案して」* 🧾🤖
* *「OpenAPI 3.1 形式で `/memos` の `post` と `get` のpathsだけ作って」* 📘🤖

AIが出した案は“そのまま採用”じゃなくて、**22.5の定番セットに照らして違和感がないか**だけ最後に見ると失敗しにくいよ✅✨

---

## 22.11 まとめ：この章で固めた「骨格」が、互換性の土台になる 🧱🌈✨

* APIの契約はまず **入力・出力・ステータス** の3点セットで骨格ができるよ🦴
* ステータスコードはHTTPの意味（RFC）に寄せると迷子になりにくいよ🔢([IETF Datatracker][2])
* エラー形式は **Problem Details（RFC 9457）** を骨格にしておくと、統一しやすいよ📛([RFCエディタ][3])
* OpenAPIで契約をファイル化すると、人もツールも扱いやすくなるよ📘([Swagger][4])

[1]: https://swagger.io/specification/?utm_source=chatgpt.com "OpenAPI Specification - Version 3.1.0"
[2]: https://datatracker.ietf.org/doc/html/rfc9110?utm_source=chatgpt.com "RFC 9110 - HTTP Semantics"
[3]: https://www.rfc-editor.org/rfc/rfc9457.html?utm_source=chatgpt.com "RFC 9457: Problem Details for HTTP APIs"
[4]: https://swagger.io/specification/v3/?utm_source=chatgpt.com "OpenAPI Specification - Version 3.1.0"
[5]: https://spec.openapis.org/oas/v3.2.0.html?utm_source=chatgpt.com "OpenAPI Specification v3.2.0"
[6]: https://github.com/OAI/OpenAPI-Specification/releases?utm_source=chatgpt.com "Releases · OAI/OpenAPI-Specification"
