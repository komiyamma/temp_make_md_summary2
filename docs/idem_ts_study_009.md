# 第9章：APIで「冪等です」を約束する設計（入口の決め方）📜✨

## この章のゴール🎯

* 「このAPI、同じリクエストを何回送っても大丈夫だよ✅」を **仕様として約束する書き方** ができる📝✨
* 「どの操作に冪等性をつける？」「キーはどこに入れる？」を迷わず決められる🔑🧠
* クライアント（フロント/バッチ/別サービス）が **安心してリトライできる契約** を作れる🔁🤝

---

## 9-1. まず大事：冪等性は“実装”だけじゃなく“約束（契約）”🤝📜

冪等性って、サーバー側で「うまくやっとく」だけだと危ないのね😵‍💫
クライアント側がこう思っちゃうから👇

* 「これってリトライしていいの？😰」
* 「二重実行したら課金増える？😱」
* 「同じ結果が返るの？それとも別の注文ができるの？🤔」

だから **APIの仕様（契約）として明文化** するのが超大事📣✨
そして“入口（entry）”＝「どこに、どうやって冪等性を持ち込むか」を決めるよ🚪🔑

---

## 9-2. HTTP標準で“元から冪等”なもの／危ないもの🌐🚦

HTTPの世界では、メソッドに性質があるよ〜って話だったよね🙂
標準的には👇

* **安全（Safe）**：基本「読むだけ」
* **冪等（Idempotent）**：同じリクエストを繰り返しても、意図する結果が同じ

HTTPの標準仕様では、GET/HEAD/OPTIONS/TRACE は安全、PUT/DELETE と安全メソッドは冪等と説明されてるよ📚✨ ([IETF Datatracker][1])
そして、**POSTは基本 “冪等じゃない側”** だから、リトライすると事故りやすい😇💥 ([IETF Datatracker][1])

> ✅つまり
>
> * PUT/DELETE：冪等にしやすい（設計しやすい）
> * POST/PATCH：冪等にしたいなら「追加の仕組み（入口）」が必要🔑

---

## 9-3. 「冪等です」を約束する入口は主に3パターン🎛️✨

### パターンA：リソースIDをクライアントが決める（PUTで作る）🆔✍️

**例**：`PUT /orders/{orderId}`
クライアントが orderId を先に作って、同じIDに同じ内容を“置く”感じ🧺

* 👍 仕様がシンプル（PUTの意味に合う）
* 👍 冪等性が自然に乗る
* 🤔 「IDをクライアントが作っていいの？」って設計判断が必要

---

### パターンB：POST/PATCHに “Idempotency-Key” ヘッダーを入れる🔑📩（王道✨）

IETF（HTTP APIの標準化をしてるところ）が、**Idempotency-Key というリクエストヘッダー**の仕様をInternet-Draftとしてまとめてるよ🧠✨ ([IETF Datatracker][2])
このヘッダーを使うと、POSTやPATCHみたいな「本来冪等じゃない操作」を **“リトライに強い”** 形にできるよ🔁🛡️ ([IETF Datatracker][2])

* 👍 「同じ操作のリトライです！」を明示できる
* 👍 クライアント実装が現実的（UUIDでOK）
* 👍 既に決済系などで実績が多い（StripeやPayPalなど）💳 ([Stripeドキュメント][3])

---

### パターンC：ボディに requestId / operationId を入れる🧾🆔

ヘッダーじゃなくてJSONボディに `requestId` を入れるやり方もあるよ🙂
ただ、HTTP的には「ヘッダーのほうが意図が伝わりやすい」ことが多いかな〜って感じ！

---

## 9-4. 仕様に必ず書くべき“約束セット”📦✅

ここからが本番！
冪等性を「APIの契約」にするなら、最低これを書こう📝✨

### ① どのエンドポイントが対象？（操作単位）🎯

例：

* `POST /orders` は冪等（ただし Idempotency-Key 必須）
* `POST /payments/confirm` も冪等（同上）
* `POST /auth/login` は対象外（例：用途次第）

---

### ② キーはどこに入れる？（入口）🔑🚪

おすすめ：**Idempotency-Key ヘッダー**
この仕様では、Idempotency-Key は「文字列として送る」とされてるよ（Structured Headerの文字列）📨 ([IETF Datatracker][2])

---

### ③ キーのルール（超重要⚠️）

IETFのdraftでは特にここが強調されてるよ👇

* **キーはユニークであること**
* **違うリクエスト内容（payload）に同じキーを使っちゃダメ** 🚫 ([IETF Datatracker][2])
* UUIDなどのランダムID推奨🎲 ([IETF Datatracker][2])

---

### ④ “同じキー” だったら何が返る？（最強の安心）🧠📤

ここは **できれば強く約束** したい✨

* 同じキーの **リトライ（処理完了後）** → **初回と同じ結果（成功でも失敗でも）を返す** 🔁 ([IETF Datatracker][2])
  （Stripeも「最初のステータスコードとボディを保存して同じものを返す」方式を説明してるよ） ([Stripeドキュメント][3])

---

### ⑤ “同時に来た”ときどうする？（競合の約束）⚔️🧵

IETFのdraftでは「まだ初回が終わってないのに同じキーが来たら競合エラーを返す」が推奨されてるよ📌 ([IETF Datatracker][2])
よくある約束：**409 Conflict** を返す🧯

---

### ⑥ キーがない／間違ってるときどうする？🧯

IETFのdraftでは例として👇が出てるよ（めっちゃ参考になる✨） ([IETF Datatracker][2])

* 仕様で必須なのに **Idempotency-Key がない** → 400 Bad Request
* **同じキーを別payloadで再利用** → 422 Unprocessable Content
* **同じキーの処理が進行中** → 409 Conflict

---

## 9-5. ミニ注文APIに“冪等の約束”を入れてみよう🍰🧾✨

### 対象エンドポイント（例）

* `POST /orders`（注文作成）🧁
  → **Idempotency-Key 必須** にして「二重注文」を防ぐ💥

---

### 仕様文（そのままコピペOKな例）📝✨

> この操作は冪等です。クライアントは Idempotency-Key ヘッダーに一意な文字列（UUID推奨）を指定してください。同一キーかつ同一内容のリクエストを再送した場合、サーバーは初回と同一のレスポンス（ステータスコードとボディ）を返します。処理が進行中の状態で同一キーのリクエストが到着した場合は 409 Conflict を返します。キーが未指定の場合は 400 を返します。異なる内容で同一キーを再利用した場合は 422 を返します。 ([IETF Datatracker][2])

いい感じに「約束」が全部入ってるでしょ😆✨

---

## 9-6. 具体例：リクエスト/レスポンス（イメージ）📨📩

```http
POST /orders HTTP/1.1
Content-Type: application/json
Idempotency-Key: 7b9d5d6a-7f0a-4a73-9b74-5d8dfb3d0d8d

{
  "userId": "u_123",
  "items": [{ "sku": "cake", "qty": 1 }]
}
```

初回（例：201 Created）👇

```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "orderId": "o_999",
  "status": "created"
}
```

同じキーで再送（成功済みのリトライ）👇
→ **同じ 201 と同じボディを返す** のが一番わかりやすい🔁✨

---

## 9-7. TypeScript側：リトライでもキーを“使い回す”例🔁💻

ポイントはこれだけ👇

* 「同じ操作」＝ **同じ Idempotency-Key を固定**
* 「別の新規操作」＝ **新しい Idempotency-Key を作る**

```ts
type CreateOrderRequest = {
  userId: string;
  items: { sku: string; qty: number }[];
};

async function createOrderWithRetry(payload: CreateOrderRequest) {
  const idempotencyKey = crypto.randomUUID(); // 1回の“操作”で固定！

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch("http://localhost:3000/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Idempotency-Key": idempotencyKey,
        },
        body: JSON.stringify(payload),
      });

      // 409(処理中) なら少し待って再試行…みたいな戦略もアリ
      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      return await res.json();
    } catch (e) {
      if (attempt === 3) throw e;
      await new Promise((r) => setTimeout(r, 400));
    }
  }
}
```

---

## 9-8. OpenAPIに書くときの“最低ライン”🧾✨

```yaml
paths:
  /orders:
    post:
      summary: Create order (idempotent)
      parameters:
        - in: header
          name: Idempotency-Key
          required: true
          schema:
            type: string
          description: Unique key for safely retrying the same operation (UUID recommended).
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateOrderRequest"
      responses:
        "201":
          description: Created (or replay of the same request)
        "400":
          description: Missing Idempotency-Key
        "409":
          description: Request with same key is still processing
        "422":
          description: Same key reused with different payload
```

---

## 9-9. よくある事故パターン集😇💥（ここ超大事）

* ❌ リトライのたびに新しいキーを作る
  → 冪等にならない（毎回“新規”扱い）😵‍💫
* ❌ 1秒単位のタイムスタンプをキーにする
  → 同時実行で衝突しがち🧨
* ❌ 別の内容（別カート内容）なのに同じキーを使う
  → 仕様違反＆危険。422にして止めたい🚫 ([IETF Datatracker][2])
* ❌ 「冪等です」って言ってるのに、2回目で違うレスポンスを返す
  → クライアントが混乱してバグる😇

---

## 9-10. ミニ演習📝🌸

### 演習1：仕様文を書こう✍️✨

`POST /orders` を冪等にする仕様文を **3〜5行** で書いてみよう🙂
最低入れたい単語：

* Idempotency-Key
* 同じキーの再送
* 同じレスポンス
* 400 / 409 / 422 のどれか

---

### 演習2：「入口」を選ぼう🚪🔑

次のどれで冪等を約束する？理由も1行で✍️

1. PUTで orderId をクライアント生成
2. POST + Idempotency-Key ヘッダー
3. JSONボディに requestId

---

### 演習3：APIレスポンス表を作ろう📋✨

`POST /orders` のレスポンスを表にしてみよう🙂
（201 / 400 / 409 / 422 だけでもOK）

---

## 9-11. AI活用（この章向け）🤖💬✨

### ① 仕様文の整形（読みやすく）📝

**プロンプト例：**
「次の文章を、API仕様として読みやすい日本語に整えて。曖昧な表現をなくして、400/409/422の条件を明確にして：（仕様文ペースト）」

チェック✅：

* “同じキー”の条件がブレてない？
* “同じレスポンス”が約束されてる？

---

### ② OpenAPIのたたき台を作る🧾

**プロンプト例：**
「/orders のPOSTに Idempotency-Key 必須、400/409/422 を含む OpenAPI YAML を生成して。余計なエンドポイントは増やさないで。」

チェック✅：

* required: true になってる？
* header の in が "header" になってる？

---

### ③ “事故りそうポイント”の洗い出し🔍

**プロンプト例：**
「このAPI仕様で、冪等性が破れやすい落とし穴を10個出して。クライアント実装とサーバ実装の両方から。」

チェック✅：

* 「キー再利用」「同時実行」「レスポンス不一致」は入ってる？

---

## まとめ🏁✨

* 冪等性は **実装だけじゃなく“仕様で約束”** すると一気に強くなる💪📜
* POST/PATCHを冪等にしたいなら、入口として **Idempotency-Key ヘッダー**が王道🔑✨ ([IETF Datatracker][2])
* 仕様には「同じキーの再送は同じ結果」「同時なら409」「違うpayloadで同じキーは422」「必須なら400」を書くと迷いが消える🧠💡 ([IETF Datatracker][2])

[1]: https://datatracker.ietf.org/doc/rfc9110/ "
            
        RFC 9110 - HTTP Semantics

        "
[2]: https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-idempotency-key-header-07 "
            
                draft-ietf-httpapi-idempotency-key-header-07
            
        "
[3]: https://docs.stripe.com/api/idempotent_requests?utm_source=chatgpt.com "Idempotent requests | Stripe API Reference"

