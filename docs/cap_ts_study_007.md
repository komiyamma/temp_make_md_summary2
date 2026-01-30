# 第7章：Partition（分断）を実験で起こす🧪🔌

## 結論1行🧠✨

**分断（P）は「いつか」じゃなくて「いつも起きうる」ので、落ち方を実験で見て“疑わない脳”にするよ！🔌💥**

---

# 1) Partition（分断）ってなに？🤔🌍

分断＝**サービス同士が“生きてるのに繋がらない”状態**のことだよ🧟‍♂️📵
クラッシュ（落ちた）と違って、分断はやっかい…！

* ✅ **プロセスは動いてる**
* ❌ でも **通信だけ失敗**する（タイムアウト、接続拒否、片方向だけ届かない など）

そして分断は「完全に切れる」だけじゃなくて、もっと地味な形でも出るよ👇

* 🐢 片方だけ激遅（タイムアウト多発）
* 🕳️ パケット落ち（たまに成功する）
* 🔀 片方向だけ届かない（Worker→APIだけ死ぬ など）

---

# 2) 今日のミニ実験の構成🧩🛒

この章では、2プロセス（API と Worker）を“わざと分断”して観察するよ👀🕵️‍♀️

* 🧑‍💻 **API**：注文を受け付ける（`http://localhost:4000`）
* 🧰 **Worker**：在庫確保の処理をする（`http://localhost:4001`）
* 📣 Workerは処理後にAPIへ「終わったよ！」を通知（コールバック）する

図にするとこんな感じ👇

* 通常時🙂
  `Client → API → Worker → API(通知)`

* 分断時😱
  `API → Worker` が途切れる / `Worker → API(通知)` が途切れる

---

# 3) まず“観察できる形”にする（ログの型を統一）📝🕵️‍♀️

分断は **ログが弱いと何も分からず詰む**ので、先に“観測できる体”を作るよ💪✨
ポイントはこれ👇

* 🏷️ `service`（api/worker）
* 🧵 `requestId`（同じ流れを追うためのID）
* 🆔 `orderId`
* ⏱️ どこで失敗したか（timeout / connect error / 5xx）

---

# 4) ハンズオン：API / Worker を用意する💻🧪

## 4-1) Worker：在庫確保ジョブを受けて、終わったらAPIへ通知する📦📣

```ts
// apps/worker/src/index.ts
import express from "express";

const app = express();
app.use(express.json());

const PORT = 4001;

function log(level: "INFO" | "WARN" | "ERROR", msg: string, extra: Record<string, unknown> = {}) {
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      service: "worker",
      level,
      msg,
      ...extra,
    })
  );
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

app.post("/jobs/reserve-stock", async (req, res) => {
  const { orderId, requestId } = req.body as { orderId: string; requestId: string };

  log("INFO", "job accepted", { orderId, requestId });

  // 🐢 遅延（分断っぽい状況を作る）
  const slowMs = Number(process.env.SIM_SLOW_WORKER_MS ?? "0");
  if (slowMs > 0) {
    log("WARN", "simulated slow worker", { slowMs, orderId, requestId });
    await sleep(slowMs);
  }

  // ✅ 仕事したことにする（本当は在庫DBを更新する想定）
  log("INFO", "stock reserved", { orderId, requestId });

  // 📣 APIへ通知（コールバック）
  const callbackUrl = process.env.API_CALLBACK_URL ?? "http://localhost:4000/internal/order-events";

  // 🔌 Worker→API の分断（片方向だけ死ぬ例！）
  if (process.env.SIM_PARTITION_WORKER_TO_API === "1") {
    log("ERROR", "simulated partition: worker cannot reach api (callback skipped)", {
      callbackUrl,
      orderId,
      requestId,
    });
    return res.json({ ok: true, note: "callback skipped" });
  }

  try {
    const resp = await fetch(callbackUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ type: "OrderStockReserved", orderId, requestId }),
    });

    log("INFO", "callback sent", { status: resp.status, orderId, requestId });
  } catch (e) {
    log("ERROR", "callback failed", { error: String(e), callbackUrl, orderId, requestId });
  }

  res.json({ ok: true });
});

app.listen(PORT, () => {
  log("INFO", "worker listening", { port: PORT });
});
```

---

## 4-2) API：注文を作って、Workerへジョブを投げて、通知が来たら確定する🛒✅

```ts
// apps/api/src/index.ts
import express from "express";
import crypto from "node:crypto";

const app = express();
app.use(express.json());

const PORT = 4000;

type OrderStatus = "PENDING" | "CONFIRMED";
type Order = {
  orderId: string;
  status: OrderStatus;
  createdAt: string;
  requestId: string;
};

const orders = new Map<string, Order>();

function log(level: "INFO" | "WARN" | "ERROR", msg: string, extra: Record<string, unknown> = {}) {
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      service: "api",
      level,
      msg,
      ...extra,
    })
  );
}

const WORKER_URL = process.env.WORKER_URL ?? "http://localhost:4001";

async function postToWorker(path: string, body: unknown, timeoutMs: number) {
  // 🔌 API→Worker の分断（片方だけ“見えない”状態を再現）
  if (process.env.SIM_PARTITION_API_TO_WORKER === "1") {
    throw new Error("Simulated partition: api cannot reach worker");
  }

  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), timeoutMs);

  try {
    const resp = await fetch(`${WORKER_URL}${path}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
      signal: ac.signal,
    });

    return resp.status;
  } finally {
    clearTimeout(timer);
  }
}

// 注文受付（A寄りにするため、まず受けてPENDINGで返す）
app.post("/orders", async (_req, res) => {
  const orderId = crypto.randomUUID();
  const requestId = crypto.randomUUID();

  const order: Order = { orderId, status: "PENDING", createdAt: new Date().toISOString(), requestId };
  orders.set(orderId, order);

  log("INFO", "order accepted (pending)", { orderId, requestId });

  // Workerへジョブ配送（ここが分断ポイント！）
  try {
    const status = await postToWorker("/jobs/reserve-stock", { orderId, requestId }, 800);
    log("INFO", "job delivered to worker", { orderId, requestId, workerHttpStatus: status });
  } catch (e) {
    // タイムアウトや分断で失敗しても、注文自体は“受けてる”のがポイント
    log("ERROR", "failed to deliver job to worker", { orderId, requestId, error: String(e) });
  }

  res.json({ orderId, status: orders.get(orderId)!.status, requestId });
});

// 注文照会
app.get("/orders/:id", (req, res) => {
  const order = orders.get(req.params.id);
  if (!order) return res.status(404).json({ error: "not found" });
  res.json(order);
});

// Workerからの通知（イベント）
app.post("/internal/order-events", (req, res) => {
  const { type, orderId, requestId } = req.body as { type: string; orderId: string; requestId: string };

  log("INFO", "event received", { type, orderId, requestId });

  const order = orders.get(orderId);
  if (!order) {
    log("WARN", "unknown order id", { orderId, requestId });
    return res.status(404).json({ ok: false });
  }

  if (type === "OrderStockReserved") {
    order.status = "CONFIRMED";
    log("INFO", "order confirmed", { orderId, requestId });
  }

  res.json({ ok: true });
});

app.listen(PORT, () => {
  log("INFO", "api listening", { port: PORT });
});
```

---

# 5) 起動して動作確認🙂✅

ターミナルを2つ開いて起動するよ🖥️🖥️✨

* Terminal A（Worker）

  * `apps/worker` に移動して起動
* Terminal B（API）

  * `apps/api` に移動して起動

注文を投げる（PowerShell例）👇

```powershell
# 注文作成
$o = Invoke-RestMethod -Method Post http://localhost:4000/orders
$o

# すぐ照会（最初はPENDINGのことが多い）
Invoke-RestMethod http://localhost:4000/orders/$($o.orderId)

# ちょい待って再照会（CONFIRMEDになってたらOK）
Start-Sleep -Seconds 1
Invoke-RestMethod http://localhost:4000/orders/$($o.orderId)
```

---

# 6) ここからが本番：分断を起こす😈🔌

## 実験A：API→Worker を分断する（配送できない）📨❌

API側だけ「Workerに繋がらない世界」にするよ！

```powershell
# APIを起動してるターミナルで（そのPowerShellセッションだけ有効）
$env:SIM_PARTITION_API_TO_WORKER = "1"
```

この状態で注文すると…

* APIログ：`failed to deliver job to worker` が出る😱
* 注文：ずっと `PENDING` のままになりやすい🕳️

**分断の怖さポイント🧠⚡**
「Workerに届いたか届いてないか」が**API側だけだと断言できない**（タイムアウトも同じ）！

---

## 実験B：Worker→API（通知）を分断する（片方向だけ死ぬ）📣❌

Worker側だけ「通知できない世界」にするよ！

```powershell
# Workerを起動してるターミナルで
$env:SIM_PARTITION_WORKER_TO_API = "1"
```

この状態で注文すると…

* Workerログ：`callback skipped` が出る😱
* Workerは仕事してるのに、API側の注文は `PENDING` のまま…🫠

**これ、現場でめっちゃ起きるやつ！！**
「処理は終わってるのに画面が更新されない」みたいなやつね😵‍💫📱

---

## 実験C：遅いだけ（落ちてない）🐢⏳

Workerを“激遅”にして、APIが先に諦めるパターンを見るよ！

```powershell
# Worker側
$env:SIM_SLOW_WORKER_MS = "5000"
```

この状態で注文すると…

* API：800msでタイムアウト（失敗ログ）😱
* でもWorker：その後に処理して通知することがある✅📣
* 注文：少し待つと `CONFIRMED` になったりする

**超重要🧠💥**

> **タイムアウト＝失敗確定じゃない**
> 遅いだけで後から成功してることがあるよ…😇

---

# 7) “ガチ分断”をWindowsのFirewallで作る（おまけ）🧱🔥

コードのスイッチよりリアルにやりたい場合は、Windowsのファイアウォールでポートを塞げるよ🔐
`netsh advfirewall firewall add rule ...` の形式が使えるよ。([Microsoft Learn][1])

## Worker(4001) を塞ぐ（API→Worker 分断）

管理者権限のPowerShellで👇

```powershell
netsh advfirewall firewall add rule name="BlockWorker4001" dir=in action=block protocol=TCP localport=4001
```

戻す👇

```powershell
netsh advfirewall firewall delete rule name="BlockWorker4001"
```

※ローカル開発環境だけで使ってね🙏💦（戻し忘れ注意！）

---

# 8) 分断時に“どこをログに出すべき？”チェックリスト✅🕵️‍♀️

最低これが出てると、デバッグが天国になるよ😇✨

* 🧵 requestId（流れ追跡）
* 🆔 orderId（対象特定）
* 🧱 どの境界で失敗？（API→Worker / Worker→API）
* ⏱️ タイムアウトまでのms
* ❌ エラー種別（AbortError / ECONNREFUSED / 5xx など）
* 🔁 何回目の試行？（リトライ回数）

---

# 9) AI（Copilot等）で“分断の観測ポイント”を増やす🤖🕵️‍♀️✨

そのまま貼って使える聞き方だよ💬✨

```text
このAPIとWorkerのコードで、分断・タイムアウト・重複送信を観測するために
ログに必須の項目を10個、理由つきで提案して。
```

```text
AbortError（タイムアウト）とECONNREFUSED（接続拒否）を分けて扱いたい。
Nodeのfetchで例外を分類する実装案を出して。
```

```text
P（分断）が起きたときに「注文が届いたか不明」になる理由を、
初心者向けに例え話で説明して。
```

---

# 10) この章のミニ理解テスト🎓✅

1. 分断は「落ちた」と何が違う？🧟‍♂️📵
2. Workerが遅いだけでも、API側は何を誤解しやすい？🐢⏳
3. Workerが処理完了してても、注文がPENDINGのままになるのはどんな分断？📣❌

---

# 2026-01-30 時点の“最新メモ”🗓️✨（リサーチ済み）

* Node.js は **v24（Krypton）がActive LTS**、v25がCurrentで更新が進んでるよ。([nodejs.org][2])
* TypeScript は **5.9系が最新安定ライン**で、6.0/7.0に向けた大きい転換が公式に案内されてるよ。([typescriptlang.org][3])
* VS Code は 2026年1月時点で 1.108 系のリリースノートが出てるよ。([Visual Studio Code][4])

[1]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/netsh-advfirewall-firewall-control-firewall-behavior?utm_source=chatgpt.com "Use netsh advfirewall firewall context - Windows Server"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://code.visualstudio.com/updates?utm_source=chatgpt.com "December 2025 (version 1.108)"
