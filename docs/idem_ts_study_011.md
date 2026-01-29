# 第11章：冪等キーは誰が作る？（クライアント生成 vs サーバー生成）🙋‍♀️🆚🖥️

## この章のゴール🎯

* 「冪等キーを **クライアントで作る** / **サーバーで作る**」の違いを、メリデメ付きで説明できる🙂✨
* 自分のミニ注文APIならどっちにするか、理由付きで決められる✅
* “再送なのにキーが変わって二重実行”みたいな事故を避けられる🚫😱

---

## 11.1 まず超大事：冪等キーは「再送でも同じ値」が命🔁❤️

冪等キー（`Idempotency-Key`）は **「この操作は同じものをもう一回送ってます！」** をサーバーに伝えるための合言葉だよ🗝️✨
だから、通信失敗やタイムアウトで再送するときも **必ず同じキー** を使う必要があるよ🔁

ちなみに `Idempotency-Key` ヘッダーは IETF で標準化が進んでいて、「キーはクライアントが生成するユニーク値」で、UUIDなどのランダムIDが推奨されてるよ🧩📜 ([IETF Datatracker][1])

---

## 11.2 方式A：クライアント生成🙋‍♀️（王道✨）

### どう動く？🧠

1. クライアントが操作開始時にキーを1回だけ作る🔑
2. `Idempotency-Key` と一緒に `POST /orders` する📨
3. もし失敗っぽかったら **同じキーで再送** 🔁
4. サーバーは「同じキー＝同じ操作」とみなして、結果を使い回す📦

Stripe みたいな実運用でも「クライアントがキーを生成」して、「最初のレスポンス（成功/失敗のステータスとボディ）を保存して、同じキーには同じ結果を返す」方式が採用されてるよ💳🧾 ([Stripeドキュメント][2])

### メリット👍

* **再送に強い**：ネットワークが荒れても同じキーで粘れる🔁🌧️
* **クライアント側でコントロールできる**：タイムアウト時の再送ロジックと相性が良い🧠
* **実装が単純**：サーバーは「キーを見て保存/返す」でOK🧰

### デメリット・落とし穴😵

* **“再送のたびに新しいキーを作っちゃう”事故**が起きがち😱

  * これやると「別操作」扱いになって二重作成しやすい💥
* UIでページ更新するとキーが消えることがある（保持の工夫が必要）🌀

---

## 11.3 方式B：サーバー生成🖥️（2ステップになりがち）

### どう動く？🧠

「キーを先にもらう」流れになることが多いよ👇

1. `POST /orders/prepare` → サーバーがキー（またはトークン）を発行🎫
2. クライアントはそのキーを持って `POST /orders` を実行📨
3. 再送時もそのキーを使い続ける🔁

### メリット👍

* **キー発行ルールをサーバーで統制できる**（TTLや形式など）⏳🔒
* “キーの取り扱い”を仕様として揃えやすい📜✨
* クライアント実装が弱い/多様（外部パートナー等）でも、運用ルールを押し付けやすい🤝

### デメリット・落とし穴😵

* **APIが増える**（prepareが必要）＝設計が重くなる🧱
* prepare自体が失敗すると…？みたいに、考えることが増える😇
* 生成したキーをクライアントが保持できないと結局つらい（だから2ステップにしても“保持”が要る）🌀

---

## 11.4 どっちを選ぶ？決め方のコツ🧭✨

### まずはこの結論でOK🙆‍♀️

* **基本は「クライアント生成」**（王道・シンプル・再送と相性◎）🔑✨
* **外部連携が多い / ルール統制したい / クライアントが信用できない**なら「サーバー生成（2ステップ）」も検討🖥️🎫

### 早見チェック✅

* 通信が不安定で再送が多い？ → クライアント生成がラク🔁
* 多種類のクライアント（提携先/古いSDK/ノーコード）を相手にする？ → サーバー生成が安定🤝
* 「どのくらいの期間キーを有効にするか」を厳密に管理したい？ → サーバー主導がやりやすい⏳
* まず教材ミニアプリとして作る？ → クライアント生成で十分✨

---

## 11.5 実装例（TypeScript）🧑‍💻✨

### 例A：クライアント生成で `Idempotency-Key` を付ける（おすすめ）🔑📨

ポイントは **「1回生成→再送でも同じ値」** だよ🔁❤️
`crypto.randomUUID()` は暗号学的に強い乱数で v4 UUID を作れるよ🔐✨ ([MDNウェブドキュメント][3])

```ts
// client.ts（擬似クライアント）
// 「注文確定ボタンを押した瞬間」に1回だけ作って、再送でも同じ値を使うイメージ🙂

type CreateOrderBody = { userId: string; items: Array<{ sku: string; qty: number }> };

export async function createOrderWithRetry(body: CreateOrderBody) {
  const idempotencyKey = crypto.randomUUID(); // ここは「最初の1回だけ」生成！🔑

  const request = () =>
    fetch("http://localhost:3000/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify(body),
    });

  // 例：最大2回リトライ（雑に書いてるよ🫶）
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await request();
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      if (attempt === 3) throw e;
      // ここで「同じ idempotencyKey のまま」再送するのが大事🔁
      await new Promise((r) => setTimeout(r, 300 * attempt));
    }
  }
}
```

---

### 例B：サーバー生成（2ステップ）🎫🖥️

```ts
// client_server_generated.ts（擬似クライアント）
type PrepareResponse = { idempotencyKey: string };
type CreateOrderBody = { userId: string; items: Array<{ sku: string; qty: number }> };

export async function createOrderServerIssuedKey(body: CreateOrderBody) {
  // 1) 先にキーをもらう🎫
  const prep = await fetch("http://localhost:3000/orders/prepare", { method: "POST" });
  const { idempotencyKey } = (await prep.json()) as PrepareResponse;

  // 2) そのキーで作成📨
  const res = await fetch("http://localhost:3000/orders", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": idempotencyKey,
    },
    body: JSON.stringify(body),
  });

  return await res.json();
}
```

---

## 11.6 サーバー側の“安全装置”もセットで覚える🛡️✨

### (1) 「同じキーなのに中身が違う」を拒否する🚫🧾

同じ `Idempotency-Key` を **別内容のリクエストに使い回す** と、事故の匂いがプンプン😱
IETFのドラフトでは「同じキーを別payloadで再利用したら 422 を返す」案が書かれてるよ🧯 ([IETF Datatracker][1])
Stripeも「最初とパラメータが違うとエラーにする」方針を明記してるよ🧷 ([Stripeドキュメント][2])

### (2) 「キーが無いと困る操作」は、足りない時にエラーにする📛

IETFのドラフトでは、必須なのに `Idempotency-Key` が無いなら 400 を返す案も書かれてるよ📨 ([IETF Datatracker][1])

---

## 11.7 よくある事故あるある😱 → こう直す🔧✨

### 事故1：再送のたびにキーを作り直してる🔁💥

* 原因：リトライ関数の中で `crypto.randomUUID()` を呼んじゃう
* 対策：**操作開始時に1回だけ作って、再送では使い回す**（この章の例Aみたいに！）🔑❤️

### 事故2：同じキーを別注文に使い回した😇

* 原因：「キー＝ユーザーの固定ID」みたいな誤解
* 対策：キーは **“操作単位”でユニーク**。同じキーは同じ操作だけ！🚫

### 事故3：ブラウザで `crypto.randomUUID()` が動かない🥲

* 原因：安全なコンテキスト（HTTPS等）じゃないと使えない場合があるよ🔐
* 対策：HTTPS（または開発時はlocalhost）で動かす／代替でUUIDライブラリを使う🧰 ([MDNウェブドキュメント][3])

---

## 11.8 ミニ演習✍️🧪（答えは1行でOK）

### 問1：どっち派？🙋‍♀️🆚🖥️

次のケースで「クライアント生成」or「サーバー生成」どっちが良さそう？理由も1つ書こう🙂

1. 決済っぽい処理（失敗したらすぐ再送したい）💳
2. 外部パートナーが叩くAPI（実装品質がバラバラ）🤝
3. 管理画面のボタン（押し間違い連打が多い）🖱️💥

### 問2：事故を見抜こう👀

「同じ `Idempotency-Key` で、bodyが違う注文」が来た。サーバーはどうする？🧯
（ヒント：422） ([IETF Datatracker][1])

---

## 11.9 AI活用テンプレ🤖✨（コピペOK）

### ① 比較表を作らせる📋

「冪等キーのクライアント生成とサーバー生成を、メリット/デメリット/向いてる場面/落とし穴で表にして」

### ② “自分の案”をレビューさせる🔍

「私は（ケースを書く）なので（方式）にします。想定事故を3つ挙げて、対策も添えて」

### ③ リトライ実装の地雷を潰す💣

「TypeScriptのfetchリトライ実装で、冪等キーが変わってしまう典型ミスを具体例で教えて」

---

## まとめチェック✅✨

* 冪等キーは **再送でも同じ値** が絶対ルール🔁❤️
* 基本は **クライアント生成が王道**（再送と相性◎）🙋‍♀️✨
* サーバー生成は **統制したい/外部連携が多い** ときに強い🖥️🎫
* 同じキーで内容が違うのは危険！**422などで拒否**が定番🧯 ([IETF Datatracker][1])

[1]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/ "
            
    
        draft-ietf-httpapi-idempotency-key-header-07 - The Idempotency-Key HTTP Header Field
    

        "
[2]: https://docs.stripe.com/api/idempotent_requests "docs.stripe.com"
[3]: https://developer.mozilla.org/en-US/docs/Web/API/Crypto/randomUUID?utm_source=chatgpt.com "Crypto: randomUUID() method - Web APIs | MDN"

