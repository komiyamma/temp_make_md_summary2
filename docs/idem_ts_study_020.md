# 第20章：HTTPレスポンス設計（200/201/202/409など）📨🔁

## この章のゴール🎯✨

* 「このAPI、次に何すればいいの…？😵」をクライアントに感じさせないレスポンスを作れるようになる💪
* 冪等性（Idempotency）と相性のいい **ステータスコード + ヘッダー + エラー形式** をセットで決められるようになる🔑📦
* ミニ注文API（注文作成＋支払い確定っぽい）で、**レスポンス一覧表**を完成させる📑✅

---

## 1) まず大前提：ステータスコードは「会話の合図」だよ💬🚦

APIは、レスポンスでクライアントにこう伝えてるのと同じ👇

* **200 / 201** → 「OK！結果はこれだよ😊」
* **202** → 「受け取った！でもまだ処理中だよ⏳（あとで確認してね）」
* **409** → 「今の状態とぶつかってるよ⚔️（競合！）」
* **429** → 「今は混みすぎ！ちょっと待って🙏」
* **503** → 「一時的に無理！時間をおいてね🛠️」

この“合図”がブレると、クライアントは
「再送していい？やめた方がいい？同じ結果返る？😇」って迷って事故るの…💥

HTTPの基本の意味（201/202/409/503など）はHTTP仕様（RFC 9110）に基づくよ📘✨ ([rfc-editor.org][1])

---

## 2) 冪等性とレスポンス設計がぶつかるポイント⚡

冪等性が必要になるのは、だいたいこの状況👇

* クライアントが送った
* サーバーは実行した（かもしれない）
* でもクライアントは **返事を受け取れなかった**（タイムアウト/通信切断）📡💔
* だからクライアントが **同じリクエストを再送** 🔁

このとき、サーバーがちゃんと設計されてると…

✅ 同じ `Idempotency-Key` なら、同じ結果（同じレスポンス）を返せる🎁
IETFでも `Idempotency-Key` ヘッダーをPOST/PATCHで“フォールトトレラントにする”ための仕様が策定中だよ🧪 ([IETF Datatracker][2])
実務例としてStripeも `Idempotency-Key` を使い、同じキーは結果をキャッシュして返す運用をしてるよ📦 ([Stripe Docs][3])

---

## 3) まず覚える「勝ちパターン」ステータスセット🏆✨

よく使うのはこのへん（ミニ注文APIで使うのもここ！）👇

### 成功系😊

* **200 OK**：普通に成功。結果も返す📦
* **201 Created**：新しいリソース作った！場所は `Location` で教えるのが定番📍 ([rfc-editor.org][1])
* **204 No Content**：成功だけど返すもの無し（DELETE成功とか）🧼

### 処理中⏳

* **202 Accepted**：受け付けたけど、まだ終わってない（非同期/時間かかる）🌀 ([rfc-editor.org][1])

### 失敗系（クライアント原因）😵

* **400 Bad Request**：形式がダメ（JSON壊れてる等）🧱
* **401 Unauthorized / 403 Forbidden**：認証/権限🔐
* **404 Not Found**：ない🙈
* **409 Conflict**：状態がぶつかった⚔️（冪等キー衝突・二重確定など） ([rfc-editor.org][1])
* **422 Unprocessable Content/Entity**：形式は合ってるけど、内容が処理できない（バリデーションなどで使われがち）🧾
  ※もともとはWebDAVで定義されたコードだよ📘 ([rfc-editor.org][4])
* **429 Too Many Requests**：レート制限。`Retry-After` で待ち時間を伝えられる⏲️ ([IETF Datatracker][5])

### 失敗系（サーバー原因）🔥

* **500**：内部エラー💥
* **503 Service Unavailable**：一時的に無理。`Retry-After` を付けられる🛠️⏳ ([rfc-editor.org][1])

---

## 4) 「エラー本文」は統一フォーマットにしよう📦🧩

ステータスコードだけだと情報が足りないことが多いよね😇
そこで **Problem Details** 形式が便利！

* `application/problem+json` の形で、機械にも人にもわかるエラーを返せる📘✨
* RFC 9457 が現在の仕様（RFC 7807を置き換え）だよ🔁 ([rfc-editor.org][6])

### Problem Details の例（イメージ）🧾

```json
{
  "type": "https://example.com/problems/idempotency-key-conflict",
  "title": "Idempotency key conflict",
  "status": 409,
  "detail": "Same Idempotency-Key was used with a different request body.",
  "instance": "/orders"
}
```

💡ポイント

* `type`：エラー種類（URLっぽい識別子）🔖
* `title`：短い見出し🪧
* `status`：HTTPステータス（本文にも入れると親切）🧠
* `detail`：人間向け説明📣
* `instance`：起きた場所（リクエストパスなど）📍

---

## 5) ミニ注文API：レスポンス設計の「完成形」サンプル📑✨

ここでは例として👇の2つを考えるね！

* `POST /orders`：注文を作る🧾
* `POST /orders/{orderId}/pay`：支払い確定っぽい処理💳

### A. `POST /orders` のレスポンス候補🧾📨

| 状況                            |            ステータス | 返すもの                              | 補足                                                |
| ----------------------------- | ---------------: | --------------------------------- | ------------------------------------------------- |
| 注文作成成功                        |              201 | 注文JSON + `Location: /orders/{id}` | “作った”ので201が自然📍 ([rfc-editor.org][1])             |
| 同じIdempotency-Keyの再送（すでに成功済み） | **最初と同じ**（例：201） | **最初と同じ本文**                       | 冪等の美しさ✨（同じキー＝同じ結果）                                |
| 同じキーだが本文が違う（危険！）              |      409（または422） | Problem Details                   | 「キー使い回し事故」⚔️                                      |
| バリデーションNG（例：金額がマイナス）          |      422（または400） | Problem Details                   | 422は“内容が処理できない”の意味でよく使われる🧾 ([rfc-editor.org][4]) |
| レート制限                         |              429 | Problem Details + `Retry-After`   | 待ち時間を伝えよう⏲️ ([IETF Datatracker][5])               |
| 一時的に過負荷/メンテ                   |              503 | Problem Details + `Retry-After`   | 一時的なら503が自然🛠️ ([rfc-editor.org][1])              |

---

### B. 「処理中」どう返す？：202の使いどころ⏳🌀

たとえば支払い処理って、外部決済っぽくて時間かかる想定にしたいよね💳🌧️
そのとき便利なのが **202 Accepted**！

* **202**：「受け付けたよ。完了はまだ！」
* 追加で **状態確認URL** を `Location` などで教えると親切📍

`Retry-After` は、503のほか、待ってほしいときに使われるヘッダーとして定義されてるよ⏲️ ([rfc-editor.org][1])

✅ 例：支払い処理が開始されたら…

* `202 Accepted`
* `Location: /operations/{operationId}`（確認先）
* 本文：`{ "operationId": "...", "status": "processing" }`

---

## 6) 「409 Conflict」ってどんなとき？冪等性だと超重要⚔️🔑

409は「今の状態と矛盾して処理できない」って意味で使うよ📘 ([rfc-editor.org][1])

冪等性でありがちな409例👇

### 例1：同じIdempotency-Keyなのに、本文が違う😱

* 1回目：`amount=1000`
* 2回目：`amount=2000`（同じキー）

これは **“別の操作を同じキーでやろうとした”** ってことだから超危険💥
→ 409（or 422）で落とすのが安全⚔️

### 例2：状態遷移の競合（もう支払い済みなのに、再度pay）💳💥

* `paid` なのに `pay` が来た
  → 409（状態がぶつかってる）

---

## 7) TypeScript実装ミニ例：ステータスとProblem Detailsを返す🧑‍💻✨

### Problem Details を返すヘルパー🧩

```ts
import type { Response } from "express";

type ProblemDetails = {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  // 拡張フィールドもOK（例: code, errors など）
  [key: string]: unknown;
};

export function sendProblem(res: Response, problem: ProblemDetails) {
  return res
    .status(problem.status)
    .type("application/problem+json")
    .json(problem);
}
```

### 409（冪等キー衝突）を返す例⚔️

```ts
import type { Request, Response } from "express";
import { sendProblem } from "./sendProblem";

export function createOrder(req: Request, res: Response) {
  const key = req.header("Idempotency-Key");
  if (!key) {
    return sendProblem(res, {
      type: "https://example.com/problems/idempotency-key-required",
      title: "Idempotency-Key is required",
      status: 400,
      detail: "Please send Idempotency-Key header for POST /orders."
    });
  }

  // ここでは例として「同じキーが別payloadで来た」扱いにする
  const conflict = false; // ←本当は保存済みリクエストと比較する
  if (conflict) {
    return sendProblem(res, {
      type: "https://example.com/problems/idempotency-key-conflict",
      title: "Idempotency key conflict",
      status: 409,
      detail: "Same Idempotency-Key was used with a different request body.",
      instance: "/orders"
    });
  }

  // 成功（201）
  const orderId = "ord_123";
  return res
    .status(201)
    .location(`/orders/${orderId}`)
    .json({ orderId, status: "created" });
}
```

---

## 8) 演習📝✨（ミニ注文APIのレスポンス表を作ろう！）

### 演習1：レスポンス一覧を完成させよう📑✅

次を埋めてみてね👇（あなたの正解が“APIの契約”になるよ！）

* `POST /orders`

  * 成功：___（200/201/202どれ？）
  * 冪等リトライで成功済み：___（同じ？変える？）
  * 同じキー本文違い：___（409/422/400…どれ？）
  * バリデーションNG：___（422/400…どっち？）

* `POST /orders/{id}/pay`

  * 処理がすぐ終わる成功：___
  * 時間がかかる（外部決済想定）：___（202？）
  * すでに支払い済み：___（409？）

🎀コツ：クライアントが「次に何するか」を迷わない答えを選ぶのが勝ち！

---

### 演習2：Retry-Afterを付けるのはどれ？⏲️

次のうち「Retry-Afterが特に相性いい」のを選ぼう👇

* A) 401
* B) 429
* C) 503

（ヒント：429はRFC 6585でRetry-Afterを付けられるって書かれてるよ📘 ([IETF Datatracker][5])）

---

## 9) AI活用プロンプト🤖💡（コピペOK）

### ① ステータス表のたたき台を作らせる📋

```text
ミニ注文APIのレスポンス設計をしたいです。
エンドポイントは POST /orders と POST /orders/{id}/pay です。
冪等性のため Idempotency-Key を使います。
成功/処理中/競合/バリデーション/レート制限/過負荷 のケースごとに
推奨ステータスコードと、返すJSONの例（Problem Details形式も）を表で出してください。
```

### ② あなたの案を“ツッコミ役”にレビューさせる🔍

```text
以下が私のレスポンス設計案です。
「クライアントが迷う点」「冪等性と相性が悪い点」「ステータスがブレている点」を指摘して、
改善案を出してください。

（ここにあなたのレスポンス表を貼る）
```

---

## 10) まとめ🌸（この章の必勝ルール）

* **同じIdempotency-Keyなら、原則“同じレスポンス”を返す**のが一番わかりやすい🔁✨（実務でも採用例あり）([Stripe Docs][3])
* **201は「作った」合図**。`Location` を付けると親切📍 ([rfc-editor.org][1])
* **202は「受け付けた、まだ」**。確認先（状態URL）を用意すると迷わせない⏳🌀 ([rfc-editor.org][1])
* **409は「状態がぶつかった」**（冪等キー衝突、二重確定など）⚔️ ([rfc-editor.org][1])
* **429/503はRetry-Afterで“待ち時間”を言える**⏲️ ([IETF Datatracker][5])
* エラー本文は **Problem Details（RFC 9457）** に寄せると、整って強い📦✨ ([rfc-editor.org][6])

[1]: https://www.rfc-editor.org/rfc/rfc9110.html?utm_source=chatgpt.com "RFC 9110: HTTP Semantics"
[2]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/?utm_source=chatgpt.com "The Idempotency-Key HTTP Header Field - Datatracker - IETF"
[3]: https://docs.stripe.com/error-low-level?locale=ja-JP&utm_source=chatgpt.com "高度なエラー処理 | Stripe ドキュメント"
[4]: https://www.rfc-editor.org/rfc/rfc4918.html?utm_source=chatgpt.com "RFC 4918: HTTP Extensions for Web Distributed Authoring ..."
[5]: https://datatracker.ietf.org/doc/html/rfc6585?utm_source=chatgpt.com "RFC 6585 - Additional HTTP Status Codes - Datatracker - IETF"
[6]: https://www.rfc-editor.org/rfc/rfc9457.html?utm_source=chatgpt.com "RFC 9457: Problem Details for HTTP APIs"

