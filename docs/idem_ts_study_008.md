# 第8章：POSTが危ない理由（作成＝増える問題）😵➕🧾

## この章のゴール🎯✨

* POSTが「二重作成」しやすい理由を、流れで説明できる🙂🔁
* 「成功したのに返事が届かなかった」時に何が起きるか想像できる😇📨
* “安全にする方向性”を、ふんわり先読みできる（次章以降の伏線）🔑✨

---

## 8.1 まず結論：POSTは「増える」から事故りやすい😵📦

POSTはよく「新規作成」に使われます🆕
新規作成って、やるたびに“新しいもの”が増えちゃう操作ですよね？📈

だから、同じ内容を **2回** 送ると…

* 注文が2件できる🧾🧾
* 決済が2回走る💳💳
* 招待メールが2通飛ぶ📩📩

みたいな「増殖事故」が起きがちです😱

ちなみにHTTPの標準的な考え方でも、POSTのような“冪等じゃない（＝同じのを何回もやると同じ結果にならない）”操作は、クライアントが勝手にリトライしないのが基本方針です⚠️ ([rfc-editor.org][1])

---

## 8.2 二重注文が起きる“王道タイムライン”⏱️😇

ここ、めちゃ大事です📌
事故の本体はだいたいこの流れ👇

### パターンA：タイムアウト → ユーザー再送（連打）💥

1. ユーザーが「注文する」ボタンを押す🖱️✨
2. サーバー側では注文が作成される（実は成功）✅
3. でも通信が不安定で、返事（レスポンス）が届かない📡💦
4. 画面は「失敗したっぽい」表示になる🙃
5. ユーザーがもう一回押す（またPOST）🔁
6. サーバーはまた“新規作成”する🧾🧾（二重注文）

### パターンB：クライアント/ミドルの自動リトライ🔁🤖

ユーザーは連打してないのに起きるやつです😇
HTTPクライアント、SDK、プロキシ、リバースプロキシ等が「一時的な失敗だから再送しよ」ってやることがあります（※POSTは危ないので本来慎重に扱うべき）⚠️ ([rfc-editor.org][1])

---

## 8.3 「同じリクエストを2回送る」って、現実では普通に起きる😇🌧️

二重送信って、本人のミスだけじゃないです🙂💦

* モバイル回線やWi-Fiが一瞬切れる📶
* タイムアウトが短めに設定されている⏳
* 画面更新/戻る/再送の挙動で再実行される🔄
* サーバーは処理したけど、返答パケットが落ちる📨💥
* 障害時に「再試行」する仕組みが中間にいる🔁

なので、設計側が「二重でも壊れない」を用意するのが現実的です🛡️✨

---

## 8.4 ミニ実験：POSTを2回送ると2つ増える🧪🧾🧾

「ほんとに増えるの？」を、超ミニで体感します🙂✨
（メモリ保存なので、再起動すると消えるタイプです😇）

### ① サーバー（orders.ts）

```ts
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

type Order = {
  id: string;
  item: string;
  createdAt: string;
};

const orders: Order[] = [];

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", `http://${req.headers.host}`);

  // POST /orders で注文を作る（＝増える）
  if (req.method === "POST" && url.pathname === "/orders") {
    let body = "";
    for await (const chunk of req) body += chunk;

    const json = body ? (JSON.parse(body) as { item?: string }) : {};
    const order: Order = {
      id: randomUUID(),
      item: json.item ?? "unknown",
      createdAt: new Date().toISOString(),
    };

    orders.push(order);

    res.writeHead(201, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ created: order, total: orders.length }));
    return;
  }

  // GET /orders で一覧を見る（確認用）
  if (req.method === "GET" && url.pathname === "/orders") {
    res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ total: orders.length, orders }, null, 2));
    return;
  }

  res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
  res.end("not found");
});

server.listen(3000, () => {
  console.log("http://localhost:3000 で起動したよ✨");
});
```

### ② 2回送るクライアント（client.ts）

```ts
const url = "http://localhost:3000/orders";

async function postOnce() {
  const r = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ item: "coffee" }),
  });
  return r.json();
}

console.log("1回目", await postOnce());
console.log("2回目", await postOnce());

const list = await fetch("http://localhost:3000/orders").then((r) => r.json());
console.log("一覧", list);
```

### ③ 見えること👀✨

* 1回目で total が 1
* 2回目で total が 2
* 一覧に注文が2件ある🧾🧾

これが「POSTは増える」＝「同じのが再送されると増殖」って感覚です😵➕

---

## 8.5 「じゃあPOSTは使っちゃダメなの？」→ ダメじゃない🙆‍♀️✨

POSTは便利なので普通に使います🙂
ただし、**“増える系のPOST”は、壊れない工夫が必要**ってだけです🛡️✨

ここから先は次章以降で深掘りするけど、方向性はこんな感じ👇

### 方向性A：Idempotency-Key（冪等キー）で「同じなら同じ結果」を返す🔑🔁

* リクエストに「この操作のキー」を付ける
* サーバーはキーを見て、2回目以降は“前と同じ結果”を返す📦📤

この考え方はIETFでも標準化のドラフトが進んでいて、POSTやPATCHを“故障に強くする”ためのヘッダーとして整理されています📜✨ ([IETF Datatracker][2])
実務でも Stripe などが「Idempotency-Key」を使う設計をドキュメント化しています💳🧾 ([Stripeドキュメント][3])

### 方向性B：PUTっぽく「同じIDに同じものを置く」🧩

* 「新規IDをクライアント側で決める」
* そのIDに“置き換え”する（増殖しにくい）
  （PUTが冪等になりやすい、の続きに繋がります🔁）

### 方向性C：DBのユニーク制約などで「物理的に二重作成できなくする」🗄️🛡️

* “同じ意味の作成”は1回だけ通す
* 2回目は競合として扱う（後の章でやります🙂）

---

## 8.6 事故を防ぐためのミニ判断チェック✅🧠

次の質問に「はい」が多いほど、POST増殖対策が必須です⚠️

* そのPOST、実行するたびに“新しいもの”が増える？📈
* それ、二重になったらお金/在庫/信頼が壊れる？💳📦😱
* タイムアウトや再送が起きてもおかしくない？📡💦
* クライアント側がリトライする可能性ある？🔁🤖
* 「成功したのに返事が届かない」時、同じ操作を再実行してしまうUI？🙃🖱️

---

## 8.7 ミニ演習📝✨

### 演習1：二重注文タイムラインを書こう⏱️🧾

下の穴埋めでOK🙂

* (1) ユーザー操作：＿＿＿＿
* (2) サーバー内部：＿＿＿＿（成功/失敗どっち？）
* (3) ネットワーク：＿＿＿＿（何が落ちた？）
* (4) 画面表示：＿＿＿＿
* (5) 2回目のリクエストで起きたこと：＿＿＿＿

### 演習2：「増えるPOST」を3つ挙げよう📌➕

例：注文作成、決済、招待送信…みたいに、自分で3つ🙂✨

### 演習3：増殖しちゃダメ度を★で付けよう⭐

* ★☆☆：増えても大事故じゃない
* ★★☆：困る
* ★★★：絶対ムリ😱（ここに冪等キー必須になりがち）

---

## 8.8 AI活用コーナー🤖💬（理解が一気にラクになる✨）

### ① 会話形式で事故を説明してもらう💬

AIにこれを投げてみてね👇

* 「POSTの二重作成が起きる流れを、ユーザー・アプリ・サーバー・ネットワークの4人が会話する形式で説明して。最後に“どこで防げるか”も一言」

### ② “あなたのサービス”に置き換えて危険ポイント洗い出し🔍

* 「（あなたのサービス説明）で、POSTが二重実行されたら困る操作を10個挙げて。困る理由も一言ずつ」

### ③ タイムラインを図にする（文章でOK）🖼️

* 「二重注文が起きるタイムラインを、時刻t0〜t6で箇条書きにして」

---

## まとめ🌸

POSTは「作成＝増える」ので、再送・連打・タイムアウトと相性が悪いです😵
現実はリトライだらけだから、**“増えるPOST”には壊れない仕組み**が必要になります🛡️🔑✨
次章では、その“約束の作り方”をAPI仕様として表に出す方向に進みます📜💖

[1]: https://www.rfc-editor.org/rfc/rfc9110.html?utm_source=chatgpt.com "RFC 9110: HTTP Semantics"
[2]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/?utm_source=chatgpt.com "The Idempotency-Key HTTP Header Field - Datatracker - IETF"
[3]: https://docs.stripe.com/api-v2-overview?locale=ja-JP&utm_source=chatgpt.com "API v2 の概要 | Stripe ドキュメント"

