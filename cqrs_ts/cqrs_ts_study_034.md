# 第34章　API設計（CommandとQueryの出入口）🌐🚪✨

（学食モバイル注文アプリ題材🍙📱）

この章は「**APIの入口を決めるだけで、CQRSが一気に“迷子にならない”**」って体験をしてもらう回だよ〜😊💖
ここを雑にすると、あとで **フロントが詰まる😵‍💫 / エラーが地獄👹 / ドキュメントが破綻💥** しがち…なので、やさしく丁寧に型を作るね🧁✨

---

## 0) この章のゴール🎯✨

読み終わったら、こんな状態になってればOKだよ😊🙌

* ✅ Command と Query の **URL設計ができる**（迷わない）
* ✅ **POST=更新 / GET=参照** を軸に、エンドポイントを一覧化できる
* ✅ エラーを **Problem Details（RFC 9457）** で統一できる⚠️🧰 ([RFC エディタ][1])
* ✅ OpenAPI で **“仕様を固定”** して、あとから増えても壊れない設計にできる📘✨ ([Swagger][2])

---

## 1) CQRS を HTTP に落とす基本ルール🧠✨

まずはこれだけ覚えると超ラク😊

* **Command（更新）** 👉 だいたい **POST**
* **Query（参照）** 👉 だいたい **GET**
* Query は **副作用ゼロ（読むだけ）** を絶対に守る🧼🚫

これが「POST=Command、GET=Query」の基本だよ🌱✨

---

## 2) API設計で一番大事なこと💎

それはね… **「フロントが迷わない入口」** を作ること😊🖥️✨

APIって、バックエンドの都合で作るとこうなりがち👇😇

* `/doOrder`
* `/orderUpdate`
* `/orderSearchNew`

…うん、未来の自分が泣くやつ😭💔

だからこの章では、**迷子にならない“型”** を使うよ🧁✨

---

## 3) まずはエンドポイントを一覧化しよう🧾✨

「学食モバイル注文」の最低限の API はこうなるよ〜😊🍙

### ✅ Command 側（更新）💥

* **注文する**：`POST /orders`
* **支払う**：`POST /orders/{orderId}/payments`

> 「支払う」を `POST /orders/{id}/pay` みたいに“動詞”にしたくなるけど、
> ここでは **支払い(payment)という“モノ”を作る** って考えるとキレイだよ💳✨
> （サブリソース設計ってやつ😊）

### ✅ Query 側（参照）🔎

* **注文一覧**：`GET /orders?status=ORDERED`
* **売上集計**：`GET /sales/summary?date=2026-01-24`

---

## 4) 入口の設計テンプレ（迷子防止）🧭✨

### 4-1) Command のレスポンスは “軽く” 🪶

Command のレスポンスで **Readモデル（画面用DTO）を返したくなる**んだけど、最初はグッと我慢😊✋
理由はシンプル👇

* Command は「更新の結果」を返す場所
* 表示用の形（Read DTO）は Query の仕事

なので基本はこう👇

* `POST /orders` → `{ orderId }` を返す（+必要なら version）
* 画面は `GET /orders/{orderId}` みたいな Query を叩く…でもいいし、一覧再取得でもOK🔄✨

### 4-2) 同期/非同期でステータスが変わる📮⏳

* **すぐ処理が終わる** 👉 `201 Created`（作成） or `200 OK`
* **キューに積んで後で処理** 👉 `202 Accepted`（受付だけ）

この “202” は CQRS と相性いいよ〜😊✨

---

## 5) HTTPメソッドの使い分け（迷いポイント潰し）🔀✅

### よく使うのはこの3つだけでOK😊

* `GET`：読むだけ
* `POST`：Command（更新の依頼）
* `PATCH`：部分更新（ただし CQRS では乱用注意⚠️）

`PATCH` は「部分変更」のためのメソッドとして定義されてるよ🩹✨ ([MDN Web Docs][3])
でも CQRS 学習では、最初は **“PayOrder みたいな明示Command”** の方が安全😊🛡️
（ドメインのルールを守りやすいから！）

---

## 6) エラーは RFC 9457（Problem Details）で統一しよう⚠️🧰✨

ここ、地味に“幸福度”めちゃ上がるよ😊💖
RFC 9457 は HTTP API のエラー表現を標準化する仕様だよ〜 ([RFC エディタ][1])

### 6-1) エラーの返し方（おすすめ形）🧱✨

返却Content-Type：`application/problem+json`

例：未注文の支払いをしようとした（ドメインエラー）👇

```json
{
  "type": "https://example.com/problems/order-not-found",
  "title": "Order not found",
  "status": 404,
  "detail": "The specified order does not exist.",
  "instance": "/orders/ord_123/payments",
  "traceId": "9f1c2a..."
}
```

ポイント😊👇

* `status`：HTTPステータス
* `title/detail`：人間向け
* `type`：機械向け（エラー種別のキー）
* `traceId`：ログ追跡（第36章にもつながる🧭✨）

---

## 7) リトライ前提！Command には Idempotency-Key を付けよう🔁🛡️

ネットワークは普通にコケる😇📶
だから **「同じ注文が2回入っちゃった😭」** を防ぐために、Command にはこれを付けるのが超おすすめ👇

* `Idempotency-Key: <uuid>`

サーバー側は「このキーで処理済みなら、同じ結果を返す」ってやる感じ😊
（第30章の冪等性と、API入口がここで繋がるよ🔗✨）

---

## 8) OpenAPI（仕様書）を“先に固定”すると強い📘✨

OpenAPI は HTTP API の仕様を機械可読にする標準だよ😊
OpenAPI 3.1 が仕様として公開されてるよ〜 ([Swagger][2])

そして OpenAPI があると👇

* ドキュメント自動生成📚
* クライアントSDK生成🛠️（openapi-generator など） ([GitHub][4])
* フロントとバックの認識ズレが激減😇✨

さらに、OpenAPI 3.1 対応のドキュメントUIとして **Scalar** みたいなツールも人気だよ😊🧁 ([APIs You Won't Hate][5])

---

## 9) ハンズオン：API入口を実装する（超ミニ構成）🧩✨

ここでは **“ルーティング層だけ”** を作って、アプリ層（Handler/QueryService）につなぐよ😊🔌

### 9-1) フォルダ案📁✨

* `src/api/commands/...`（Command の入口）
* `src/api/queries/...`（Query の入口）
* `src/application/...`（Handler/QueryService）

「入口は入口、処理は処理」で分けるのがコツ🧠✨

### 9-2) Command：注文する `POST /orders` 🍙✅

```ts
// src/api/commands/orders.ts
import type { Request, Response } from "express";

export async function postOrders(req: Request, res: Response) {
  // 1) 入力（DTO）を取り出す
  const input = req.body as {
    userId: string;
    items: Array<{ menuId: string; qty: number }>;
  };

  // 2) CommandHandler を呼ぶ（ここは第10〜13章で作った想定）
  // const result = await placeOrderHandler.handle(input);

  // 仮：今は雰囲気だけ
  const result = { orderId: "ord_dummy_001" };

  // 3) 返す（作成なので 201）
  res.status(201).json(result);
}
```

### 9-3) Command：支払う `POST /orders/:orderId/payments` 💳✨

```ts
// src/api/commands/payments.ts
import type { Request, Response } from "express";

export async function postPayments(req: Request, res: Response) {
  const orderId = req.params.orderId;

  // const result = await payOrderHandler.handle({ orderId });

  // 仮：雰囲気
  const result = { paymentId: "pay_dummy_001", orderId };

  res.status(201).json(result);
}
```

### 9-4) Query：一覧 `GET /orders` 🔎📋

```ts
// src/api/queries/orders.ts
import type { Request, Response } from "express";

export async function getOrders(req: Request, res: Response) {
  const status = (req.query.status as string | undefined) ?? "ALL";

  // const dto = await getOrderListQueryService.execute({ status });

  // 仮：雰囲気
  const dto = [
    { orderId: "ord_dummy_001", status, total: 850, createdAt: "2026-01-24" }
  ];

  res.status(200).json(dto);
}
```

### 9-5) Query：集計 `GET /sales/summary` 📊✨

```ts
// src/api/queries/sales.ts
import type { Request, Response } from "express";

export async function getSalesSummary(req: Request, res: Response) {
  const date = (req.query.date as string | undefined) ?? "today";

  // const dto = await getSalesSummaryQueryService.execute({ date });

  const dto = { date, totalSales: 12345, topMenu: [{ menuId: "m01", count: 42 }] };

  res.status(200).json(dto);
}
```

### 9-6) ルーティングをまとめる🚦✨

```ts
// src/app.ts
import express from "express";
import { postOrders } from "./api/commands/orders";
import { postPayments } from "./api/commands/payments";
import { getOrders } from "./api/queries/orders";
import { getSalesSummary } from "./api/queries/sales";

const app = express();
app.use(express.json());

// Commands
app.post("/orders", postOrders);
app.post("/orders/:orderId/payments", postPayments);

// Queries
app.get("/orders", getOrders);
app.get("/sales/summary", getSalesSummary);

export default app;
```

---

## 10) ミニ演習（3問）📝✨

### Q1：キャンセルはどのURLが良さそう？🙋‍♀️

候補👇

1. `POST /orders/{id}/cancel`
2. `POST /orders/{id}/cancellations`
3. `PATCH /orders/{id}` で status を CANCELLED にする

おすすめは **2)** 😊
「キャンセルという出来事（モノ）を作る」って考えると読みやすい✨
（1も現場では全然あるけど、増えると動詞が散らかりがち😇）

### Q2：非同期で処理するCommandは、成功ステータス何が良い？⏳

→ **202 Accepted** が王道だよ😊✨

### Q3：エラーの共通フォーマットは？⚠️

→ `application/problem+json`（RFC 9457）だね🧰✨ ([RFC エディタ][1])

---

## 11) AI活用プロンプト（そのまま使ってOK）🤖💖

### API一覧を作らせる🧾

* 「学食注文アプリの Command / Query を、POST/GET でURL設計して一覧にして。動詞URLは避けて、サブリソース優先で🙏」

### レスポンス設計レビューしてもらう👀

* 「この API の Command レスポンスが重すぎないか見て。Query に寄せるならどう直す？」

### エラー設計を揃える⚠️

* 「このエラー一覧を RFC9457 (problem+json) で統一したい。type の命名案も出して」

---

## まとめ🎉✨

* Command/Query の入口を **POST/GET** で整理すると、CQRS が一気にスッキリ😊
* エンドポイントは **先に一覧化** すると迷子ゼロ🧭
* エラーは **RFC 9457 problem+json** で統一すると強い🧰✨ ([RFC エディタ][1])
* OpenAPI を置くと、仕様がブレなくてチームが幸せ📘✨ ([Swagger][2])

---

## 次章予告（第35章）👀✨

次は **フロント側の気持ち** に寄り添う回だよ〜🖥️💞
Command のあと、画面はどう更新する？

* 再取得🔄
* 楽観更新😎
* 通知📣
  この3択を、学食アプリで選べるようにするよ🎯✨

[1]: https://www.rfc-editor.org/rfc/rfc9457.html?utm_source=chatgpt.com "RFC 9457: Problem Details for HTTP APIs"
[2]: https://swagger.io/specification/?utm_source=chatgpt.com "OpenAPI Specification - Version 3.1.0"
[3]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/PATCH?utm_source=chatgpt.com "PATCH request method - HTTP - MDN Web Docs"
[4]: https://github.com/OpenAPITools/openapi-generator?utm_source=chatgpt.com "OpenAPITools/openapi-generator"
[5]: https://apisyouwonthate.com/blog/top-5-best-api-docs-tools/?utm_source=chatgpt.com "The 5 Best API Docs Tools in 2025"
