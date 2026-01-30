# 第6章：CAPを日常例で理解する（まずは暗記しない）🍞📦⚖️

## この章の結論1行📝✨

**「通信が切れる（P）瞬間、システムは “一致を守って止まる（C寄り）” か “止まらず返してズレを許す（A寄り）” のどっちかを選ぶ**」です。([Google Cloud][1])

---

## 6.1 CAPって、まず“日常語”にしてみよ〜🍞☕️

CAPの3文字は、こう言い換えるとスッと入ります😊

* **C（Consistency：一致）🧩**
  「どこで見ても、同じ答えが返ってくる（最新 or エラー）」
  ※ここでのCは、いわゆるACIDのCとは別物扱い（“いつ見ても最新”寄りの強い意味）だよ〜⚠️([AWSドキュメント][2])

* **A（Availability：応答）📨**
  「動いてるノードに届いたリクエストには、とにかく返事する（中身が最新とは限らない）」
  ※CAPのAは“100%応答”みたいな強め定義として語られがちで、一般に言う“高可用性”の感覚とズレやすいよ〜😵‍💫

* **P（Partition tolerance：分断耐性）🔌**
  「ネットワークが切れたり遅すぎたり、メッセージが落ちても、システムとして動き続ける前提」
  （“メッセージが落ちる/遅れる”まで含めてPと考えるのが超大事！）([AWSドキュメント][2])

---

## 6.2 “暗記しない”ためのコツ🧠💡

CAPは「3つのうち2つ選べ！」みたいに言われがちだけど、そこから入ると混乱しやすいです🙅‍♀️

覚え方はこれだけ👇

### ✅ ステップ1：まず「Pは起きるもの」とする🔌

分散はネットワーク越しなので、切断や遅延は“起きうる前提”で設計する、が基本です。([Google Cloud][1])

### ✅ ステップ2：Pが起きた“その瞬間”だけ注目する⏱️

普段（分断が起きてない時）は、CっぽくもAっぽくもできる。
**問題は「分断が起きた瞬間に、どっちを捨てる？」** です。

---

## 6.3 日常たとえ話でCAPをつかむ🍞📦🧾

### たとえ①：パン屋さんの“在庫”が2つのレジに分かれてる🍞🧾

* レジAとレジBがあって、本当は在庫を共有したい
* でも突然、レジ同士の通信が切れた（P）🔌

このときの2択👇

#### 🧩 C寄り（正しさ優先）：売らない/止める

「今この在庫が本当に残ってるか分からないなら、売らない（エラー返す）」

* 👍 いいところ：在庫の正しさが守れる
* 👎 つらいところ：お客さんは買えない（応答できない/失敗が増える）

#### 📨 A寄り（応答優先）：とにかく売る

「とりあえず売って、あとで在庫が合わないかも」

* 👍 いいところ：お客さんは買える（返事はする）
* 👎 つらいところ：売りすぎ（在庫マイナス）など“ズレ”が起きうる

> これが **「Pが起きたら C か A どっち？」** の感覚だよ〜⚖️🔥([Google Cloud][1])

---

### たとえ②：グループチャット📱💬

通信が切れても「送信ボタン押したら送れた感」を出す（A寄り）と、
あとで順番が前後したり、既読がズレたりしがち😵‍💫
逆に「通信不安定なので送信できません」（C寄り）なら、矛盾は減るけど使い勝手は落ちる…！

---

### たとえ③：お金の振込💸🏦

「残高」や「二重引き落とし」は事故ると致命的💥
だから多くは **C寄り**（正しさ優先で止める/待たせる）になりやすいです。
（UXは落ちるけど、事故の方がヤバいからね…！）

---

## 6.4 いちばん大事な誤解ポイント⚠️😵‍💫

### ❌「CAPは3つのうち2つを自由に選べる」

実は、**“分断が起きたときに” どっちを優先するかの話**として捉えるとスッキリします。([Google Cloud][1])

さらに、**「CPデータベース」「APデータベース」って雑にラベリングするのも危険**って話もよく出ます（状況や設定で挙動が変わるから）。([martin.kleppmann.com][3])

---

## 6.5 ハンズオン：分断中の挙動を2パターン作る（拒否 vs 受付）🧪🔌

ここでは“超ミニ分散”を、Windows上でサクッと再現します😊
**同じ「購入API」なのに、分断（P）中の設計方針で体験が変わる**のがゴール！

### 🎯 作るもの

* Node A（ポート 4001）🅰️
* Node B（ポート 4002）🅱️
* 在庫 `stock` を持ってて、購入すると減る📦
* A↔Bで「購入ログ」を送り合って同期っぽくする📨
* 通信を切るスイッチで“分断”を作る🔌

---

### 6.5.1 AIに“たたき台”を作らせるプロンプト例🤖📝

Copilot / Codex にこう投げると早いよ〜✨

* 「TypeScriptで、2つのHTTPサーバー（4001/4002）を起動して、/buyで在庫を減らすミニ例を作って。peerへPOSTして同期する。通信を切るフラグも入れて。」
* 「CAPの観点で、分断中に“拒否(C寄り)”と“受付(A寄り)”の2モードを切り替えられるようにして。」

出てきたコードは、そのまま使わずに👇をチェック✅

* 例外処理ちゃんとある？😵‍💫
* タイムアウト入ってる？⏱️
* ログ見れば挙動が追える？🕵️‍♀️

---

### 6.5.2 サンプル実装（最小構成）💻✨

#### 📁 ファイル：`src/node.ts`

```ts
import http from "node:http";

type Mode = "cp" | "ap";

const NODE_ID = process.env.NODE_ID ?? "A";
const PORT = Number(process.env.PORT ?? (NODE_ID === "A" ? 4001 : 4002));
const PEER_URL = process.env.PEER_URL ?? (NODE_ID === "A" ? "http://localhost:4002" : "http://localhost:4001");
const MODE = (process.env.MODE ?? "cp") as Mode;

// 分断スイッチ（trueなら通信OK、falseなら“分断中”）
const LINK_UP = (process.env.LINK_UP ?? "true") === "true";

// 状態（超ミニなのでインメモリ）
let stock = 5;
const applied = new Set<string>();        // どの購入イベントを適用したか（重複防止の超入門）
const outbox: any[] = [];                 // APモードの“あとで送る”用（簡易）

function json(res: http.ServerResponse, status: number, body: unknown) {
  const text = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  res.end(text);
}

async function readBody(req: http.IncomingMessage): Promise<any> {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(Buffer.from(c));
  const text = Buffer.concat(chunks).toString("utf-8");
  return text ? JSON.parse(text) : {};
}

async function postWithTimeout(url: string, body: any, timeoutMs: number) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    return { ok: r.ok, status: r.status, text: await r.text() };
  } finally {
    clearTimeout(t);
  }
}

function applyEvent(ev: { eventId: string; qty: number; from: string }) {
  if (applied.has(ev.eventId)) return; // 重複は無視（この章では“雰囲気”でOK）
  applied.add(ev.eventId);
  stock -= ev.qty;
}

const server = http.createServer(async (req, res) => {
  try {
    if (!req.url) return json(res, 404, { error: "no url" });

    // ヘルス
    if (req.method === "GET" && req.url === "/health") {
      return json(res, 200, { node: NODE_ID, ok: true, mode: MODE, linkUp: LINK_UP });
    }

    // 在庫を見る
    if (req.method === "GET" && req.url === "/stock") {
      return json(res, 200, { node: NODE_ID, stock, applied: applied.size, outbox: outbox.length });
    }

    // peerからの同期イベント受信
    if (req.method === "POST" && req.url === "/sync") {
      const ev = await readBody(req);
      applyEvent(ev);
      console.log(`[${NODE_ID}] sync <-`, ev);
      return json(res, 200, { ok: true });
    }

    // 購入（qtyだけ減らす）
    if (req.method === "POST" && req.url === "/buy") {
      const { qty = 1 } = await readBody(req);
      const eventId = `${Date.now()}-${Math.random().toString(16).slice(2)}-${NODE_ID}`;
      const ev = { eventId, qty: Number(qty), from: NODE_ID };

      // ここがCAPの分かれ道⚖️
      if (MODE === "cp") {
        // C寄り：peerにも反映できないなら“失敗”で返す（Aを捨てる）
        if (!LINK_UP) {
          console.log(`[${NODE_ID}] CP: partition -> reject`);
          return json(res, 503, { ok: false, reason: "partition: reject to keep consistency-ish" });
        }
        const r = await postWithTimeout(`${PEER_URL}/sync`, ev, 200);
        if (!r.ok) {
          console.log(`[${NODE_ID}] CP: peer failed -> reject`, r.status);
          return json(res, 503, { ok: false, reason: "peer unavailable: reject" });
        }
        // peerがOKなら自分も適用
        applyEvent(ev);
        console.log(`[${NODE_ID}] CP: commit`, ev);
        return json(res, 200, { ok: true, mode: "cp", eventId, stock });
      }

      if (MODE === "ap") {
        // A寄り：とにかく受付して返事する（Cはあとで崩れるかも）
        applyEvent(ev);
        console.log(`[${NODE_ID}] AP: accept`, ev);

        if (!LINK_UP) {
          outbox.push(ev);
          console.log(`[${NODE_ID}] AP: queued (partition)`, ev.eventId);
          return json(res, 200, { ok: true, mode: "ap", note: "queued due to partition", eventId, stock });
        }

        const r = await postWithTimeout(`${PEER_URL}/sync`, ev, 200);
        if (!r.ok) {
          outbox.push(ev);
          console.log(`[${NODE_ID}] AP: queued (peer fail)`, ev.eventId);
          return json(res, 200, { ok: true, mode: "ap", note: "queued due to peer fail", eventId, stock });
        }

        return json(res, 200, { ok: true, mode: "ap", note: "synced", eventId, stock });
      }
    }

    // outbox再送（APモード用）
    if (req.method === "POST" && req.url === "/retry") {
      if (!LINK_UP) return json(res, 200, { ok: true, note: "still partition", outbox: outbox.length });

      let sent = 0;
      const rest: any[] = [];
      for (const ev of outbox) {
        const r = await postWithTimeout(`${PEER_URL}/sync`, ev, 200);
        if (r.ok) sent++;
        else rest.push(ev);
      }
      outbox.length = 0;
      outbox.push(...rest);
      return json(res, 200, { ok: true, sent, remain: outbox.length });
    }

    return json(res, 404, { error: "not found" });
  } catch (e: any) {
    return json(res, 500, { error: e?.message ?? String(e) });
  }
});

server.listen(PORT, () => {
  console.log(`[${NODE_ID}] listening on http://localhost:${PORT} mode=${MODE} linkUp=${LINK_UP} peer=${PEER_URL}`);
});
```

---

### 6.5.3 起動（PowerShell例）▶️💨

#### 🅰️ ターミナル1：Node A（CPモード）

```powershell
$env:NODE_ID="A"
$env:PORT="4001"
$env:PEER_URL="http://localhost:4002"
$env:MODE="cp"
$env:LINK_UP="true"
node .\dist\node.js
```

#### 🅱️ ターミナル2：Node B（CPモード）

```powershell
$env:NODE_ID="B"
$env:PORT="4002"
$env:PEER_URL="http://localhost:4001"
$env:MODE="cp"
$env:LINK_UP="true"
node .\dist\node.js
```

> ※TypeScriptのビルド（`dist/node.js`生成）は、手元のいつものTS手順でOKだよ〜🧰✨
> （この章の主役はCAPなので、ここはサクッと！）

---

## 6.6 実験シナリオ：分断（P）を起こして比べる🔌🧪

### 6.6.1 まずは分断なし（LINK_UP=true）で買ってみる🍞

* Aに購入リクエスト → AもBも在庫が減る（同期できてる）😊

例（別ターミナルから）：

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:4001/buy -ContentType "application/json" -Body '{"qty":1}'
Invoke-RestMethod -Method Get  -Uri http://localhost:4002/stock
```

---

### 6.6.2 分断を起こす（片側のLINK_UP=false）🔌💥

たとえば **Aだけ分断中**にする：

* Aの環境変数を `LINK_UP="false"` にして再起動（またはB側でもOK）

#### ✅ CPモード（C寄り）だとどうなる？🧩

* Aに /buy → **503で拒否**（返事はするけど成功しない）
* Bの在庫も壊れない
  👉 **Cを守るために、Aを捨てた** って体験！([Google Cloud][1])

#### ✅ APモード（A寄り）に変えると？📨

* MODE="ap" で再起動して同じことをやると…
* Aに /buy → **200で受付**（在庫が減る）
* でもBの在庫は減ってない（ズレる）😵‍💫
  👉 **Aを守るために、Cを捨てた** って体験！([Google Cloud][1])

---

### 6.6.3 分断が直ったら（LINK_UP=true）🔧✨

APモードなら、/retry を叩くと outbox が送られて、Bが追いつく（“収束っぽい”）になります📮💨

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:4001/retry
Invoke-RestMethod -Method Get  -Uri http://localhost:4002/stock
```

---

## 6.7 まとめ：CAPを“言葉で説明”できるようにする🎤✨

### 💬 口で言うテンプレ（超おすすめ）

* **「分断（P）が起きたら、正しさ（C）を守るために止めるか、応答（A）を守るためにズレを許すかを決める」**([Google Cloud][1])

### ✅ 1分チェック（YES/NO）🧠✅

* 「分断中に“受付だけはしたい”」→ **A寄り**📨
* 「分断中に“間違った結果は絶対ダメ”」→ **C寄り**🧩
* 「分断はまあ起きうる」→ **P前提**🔌([Google Cloud][1])

---

## 6.8 ミニ問題（3問）✍️😆

### Q1 🛒💳 決済（課金）

分断中に「二重課金」しうるなら、基本どっち寄り？

* A寄り📨 / C寄り🧩

### Q2 💬 SNSの“いいね”

分断中に一瞬ズレても、あとで直ればOKなら？

* A寄り📨 / C寄り🧩

### Q3 📦 在庫が1個しかない限定商品

分断中に売りすぎたら炎上🔥 どっち寄り？

* A寄り📨 / C寄り🧩

（答えのコツ：**事故コストが高いほどC寄り**、UX優先ならA寄り😊）

---

## この章で覚える最小ワード集📖✨

* **分断（Partition）🔌**：切断だけじゃなく、遅延・落ちも含む
* **C（一致）🧩**：どこでも同じ答え（最新 or エラー）
* **A（応答）📨**：生きてるノードは必ず返事（最新じゃないかも）
* **CAPの本質⚖️**：「Pが起きた瞬間に、CかAのどっちを優先する？」([AWSドキュメント][2])

[1]: https://cloud.google.com/blog/products/databases/inside-cloud-spanner-and-the-cap-theorem?utm_source=chatgpt.com "Inside Cloud Spanner and the CAP Theorem"
[2]: https://docs.aws.amazon.com/whitepapers/latest/availability-and-beyond-improving-resilience/cap-theorem.html?utm_source=chatgpt.com "CAP theorem - Availability and Beyond"
[3]: https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html?utm_source=chatgpt.com "Please stop calling databases CP or AP"
