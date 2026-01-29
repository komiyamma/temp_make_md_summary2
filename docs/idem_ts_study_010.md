# 第10章：冪等キー（Idempotency-Key）ってなに？🔑🔁

## 🎯この章のゴール

* 「冪等キーって何？」を**自分の言葉で説明**できる🙂✨
* **同じキー＝同じ処理**として扱う流れ（保存→再利用）がわかる📦🔁
* `POST /orders` みたいな「増える操作」を**安全にリトライ**できるイメージがつかめる🧯💕

---

## 1) まず結論：冪等キーは「この1回の操作」を表す“整理券”🎫🔑

冪等キー（`Idempotency-Key`）は、クライアントがリクエストに付ける **一意な文字列**です。

* 1回目：サーバーが「この整理券の結果」を保存📦
* 2回目以降：**同じ整理券なら、保存した結果をそのまま返す**📤🔁

これで、通信エラーやタイムアウトで「届いたか不明…もう一回押しちゃえ！」が起きても、**二重作成・二重決済**みたいな事故を防げます😇🌧️

実際に `Idempotency-Key` は、IETF の仕様ドラフトでも「POST/PATCH など非冪等メソッドをフォールトトレラントにするためのヘッダー」として整理されています。([IETF Datatracker][1])

---

## 2) どんな時に効くの？（いちばんよくある事故）😵‍💫📱

例：スマホで注文ボタンを押す → 通信が不安定 → 画面が固まる → もう一回押す😇

* 冪等キーなし：注文が **2件作られる** 😱
* 冪等キーあり：2回目は **1回目と同じ結果が返る** 🙂✨

---

## 3) 公式っぽい“推奨”も押さえよう（最新の動き）🧠📌

### ✅キーは「UUIDみたいなランダム」が王道

IETFドラフトでは「UUIDなどのランダム識別子を推奨」と書かれています。([IETF Datatracker][1])
Stripeも「UUID v4 など十分なエントロピーを推奨」と明記しています。([Stripeドキュメント][2])

### ✅同じキーを“別の内容”に使い回しちゃダメ🙅‍♀️

* IETFドラフト：**別 payload に再利用しちゃダメ**、もしやったら `422` を返す例まで載っています([IETF Datatracker][3])
* Stripe：1回目と**エンドポイントやパラメータが違う**のに同じキーを使うと `idempotency_error` になる、と説明しています([Stripeドキュメント][4])

### ✅同じキーが「処理中」に同時に来たら？（並行）⚔️

IETFドラフトは「処理中の同キー再送なら `409 Conflict` を返す」例を示しています。([IETF Datatracker][3])
Stripeでも同様に、同時実行で同キーが使われると `idempotency_key_in_use` というエラーコードが案内されています。([Stripeドキュメント][5])

---

## 4) 具体例：ミニ注文APIでイメージしよ🍰🧾

### 🧾やりたいこと

* `POST /orders` で注文を作る（本来は“増える”から危険😵）

### ✅クライアント → サーバー：ヘッダーに付ける

リクエストの雰囲気👇

```http
POST /orders
Idempotency-Key: 8e03978e-40d5-43e8-bc93-6894a57f9324
Content-Type: application/json

{"itemId":"cake-001","qty":1}
```

IETFドラフトにも `Idempotency-Key` の例として UUID が載っています。([IETF Datatracker][1])

---

## 5) Windowsで叩く例（curl / PowerShell）🪟💻✨

### A) `curl.exe`（PowerShellでも確実）

※PowerShellの `curl` は別物（エイリアス）になることがあるので `curl.exe` が安心🙆‍♀️

```bash
curl.exe -X POST "http://localhost:3000/orders" ^
  -H "Content-Type: application/json" ^
  -H "Idempotency-Key: 8e03978e-40d5-43e8-bc93-6894a57f9324" ^
  -d "{\"itemId\":\"cake-001\",\"qty\":1}"
```

### B) PowerShell `Invoke-RestMethod`（読みやすい）

```powershell
$headers = @{
  "Content-Type" = "application/json"
  "Idempotency-Key" = "8e03978e-40d5-43e8-bc93-6894a57f9324"
}

$body = @{
  itemId = "cake-001"
  qty = 1
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://localhost:3000/orders" -Headers $headers -Body $body
```

---

## 6) サーバー側の「超ざっくりアルゴリズム」🔁📦

サーバーはざっくりこう動きます👇

1. リクエストから `Idempotency-Key` を取り出す🔑
2. そのキーの記録があるか見る👀
3. なければ「初回」→ 処理して結果を保存📦
4. あれば「再送」→ 保存した結果を返す📤
5. ただし「同じキーなのに内容が違う」ならエラー🙅‍♀️

   * IETFドラフトは `422` 例を提示([IETF Datatracker][3])
6. 「処理中の同キー再送」なら `409` などで“待ってね”返し⏳

   * IETFドラフトは `409` 例を提示([IETF Datatracker][3])

---

## 7) TypeScriptでミニ実装（メモリ版）🧑‍💻🔑✨

※ここでは「仕組み理解」が目的なので、保存先はメモリ（Map）にします🙂
（永続化やTTLは後の章でガッツリやるよ！⏳🗄️）

```ts
import express from "express";
import crypto from "node:crypto";

const app = express();
app.use(express.json());

type StoredResult =
  | { state: "processing"; requestHash: string; startedAt: number }
  | { state: "done"; requestHash: string; status: number; body: unknown };

const store = new Map<string, StoredResult>();

function hashRequest(method: string, path: string, body: unknown) {
  // “同じ内容か？”を判定するための指紋（fingerprint）🫶
  const raw = JSON.stringify({ method, path, body });
  return crypto.createHash("sha256").update(raw).digest("hex");
}

app.post("/orders", async (req, res) => {
  const key = req.header("Idempotency-Key");
  if (!key) {
    // IETFドラフトでも「必須の操作なら 400」を推奨してるイメージ🧾:contentReference[oaicite:10]{index=10}
    return res.status(400).json({ message: "Idempotency-Key is required" });
  }

  const requestHash = hashRequest("POST", "/orders", req.body);
  const existing = store.get(key);

  // ✅ すでに同じキーの記録がある場合
  if (existing) {
    // “同じキーなのに中身が違う”は危険なので弾く🙅‍♀️
    if (existing.requestHash !== requestHash) {
      // IETFドラフトでは 422 の例があるよ🧾:contentReference[oaicite:11]{index=11}
      return res.status(422).json({
        message: "Idempotency-Key was reused with a different payload",
      });
    }

    // まだ処理中なら 409（“今やってるよ”）⏳
    if (existing.state === "processing") {
      // IETFドラフトも“処理中の再送は 409”を例示🧾:contentReference[oaicite:12]{index=12}
      return res.status(409).json({
        message: "A request is outstanding for this Idempotency-Key",
      });
    }

    // done なら保存済みの結果をそのまま返す📤🔁
    return res.status(existing.status).json(existing.body);
  }

  // ✅ 初回：processing として先に置く（同時実行対策の第一歩）🔒
  store.set(key, { state: "processing", requestHash, startedAt: Date.now() });

  try {
    // ここが本来の注文作成処理（仮）🍰
    const orderId = crypto.randomUUID();
    const resultBody = {
      orderId,
      itemId: req.body?.itemId,
      qty: req.body?.qty,
      createdAt: new Date().toISOString(),
    };

    const status = 201;

    // ✅ 結果を保存しておく（次回は同じ結果を返す）📦
    store.set(key, { state: "done", requestHash, status, body: resultBody });

    return res.status(status).json(resultBody);
  } catch (e) {
    // “失敗も保存する？”は設計判断がある（後の章で詳しく！）🧠
    store.delete(key);
    return res.status(500).json({ message: "Internal error" });
  }
});

app.listen(3000, () => {
  console.log("listening on http://localhost:3000");
});
```

### ✅これでどうなる？

* 同じ `Idempotency-Key` で2回叩く
  → 2回目は **同じ orderId が返る** 🎉🔁
* 同じキーで body を変えて叩く
  → `422`（危険な使い回しをブロック）🙅‍♀️

Stripeも「最初の結果（ステータスコードとボディ）を保存して、同じキーなら同じ結果を返す」方式を説明しています。([Stripeドキュメント][2])

---

## 8) よくある落とし穴あるある😇⚠️

### 🧨落とし穴1：リトライなのに“毎回違うキー”を作っちゃう

→ それ、冪等にならない！😵
**同じ操作のやり直し**なら、**同じキー**を使うのがポイント🔁

### 🧨落とし穴2：「同じキーで別内容」事故

→ サーバーは“同じ操作”だと思って前の結果を返しちゃうかも…
だから **内容違いは弾く**（指紋チェック）が大事💡
IETFドラフトも「別payloadに再利用NG」を明確にしています。([IETF Datatracker][1])

### 🧨落とし穴3：同じキーが同時に飛んでくる（連打＋自動リトライ）⚔️

→ 「処理中」を区別して `409` などで返す設計が必要
IETFドラフトは `409` の例を示し、Stripeでも同時実行時の `idempotency_key_in_use` を案内しています。([IETF Datatracker][3])

---

## 9) 📝ミニ演習（手を動かすやつ）✍️✨

### 演習1：リクエスト例を書こう🧾

* `POST /orders` に `Idempotency-Key` を付けたリクエストを、**自分の言葉**で書いてみてね🙂

### 演習2：2回叩いて“同じ結果”を確認🔁

1. 同じキーで2回 `POST /orders` を送る
2. 返ってくる `orderId` が同じかチェック👀✅

### 演習3：わざと壊す（キー使い回し）😈

* 同じキーのまま `qty` を変えて送る
* `422` っぽいエラーになるのを確認🙅‍♀️

---

## 10) 🤖AI活用（この章向けテンプレ）✨

### ①curl / PowerShellコマンドを作らせる🪄

* 「このAPIに `Idempotency-Key` を付けた `curl.exe` を作って」って頼む
* **ただし** そのままコピペせず、ヘッダー名・JSONが合ってるか自分でチェック✅

### ②“同じキーで別payload”が危険な理由を1分で説明させる🎤

* AIに説明させて、**自分の言葉で言い直す**と理解が固まるよ🙂🧠

### ③サーバー側の分岐（初回/再送/処理中/内容違い）を図にさせる🧩

* フローチャートの文章版を作らせて、あとで自分で清書すると最強✍️✨

---

## ✅まとめ（ここだけ覚えてればOK）🎉

* `Idempotency-Key` は「この1回の操作」の整理券🎫🔑
* サーバーは「最初の結果」を保存して、同じキーなら同じ結果を返す📦📤🔁
* **同じキーの別内容**はNG（弾くのが安全）🙅‍♀️
* **処理中の同時再送**は `409` などで制御が必要⏳⚔️ ([IETF Datatracker][3])

[1]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/ "
            
    
        draft-ietf-httpapi-idempotency-key-header-07 - The Idempotency-Key HTTP Header Field
    

        "
[2]: https://docs.stripe.com/api/idempotent_requests "docs.stripe.com"
[3]: https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-idempotency-key-header-07 "
            
                draft-ietf-httpapi-idempotency-key-header-07
            
        "
[4]: https://docs.stripe.com/api/errors "docs.stripe.com"
[5]: https://docs.stripe.com/error-codes "docs.stripe.com"

