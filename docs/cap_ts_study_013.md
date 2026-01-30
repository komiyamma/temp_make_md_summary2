# 第13章：レプリケーション入門（Leader-Follower）🪞👑

## 0. この章でできるようになること 🎯✨

* 「レプリケーション＝複製」って何のため？を説明できる 🗣️💡
* Leader（Primary）に書いて、Follower（Replica）が“遅れて追いかける”感覚がつかめる 🏃‍♀️💨
* 「Followerから読むと古いかも」を、実験でちゃんと目で見て体感できる 👀⏳
* その結果、CAPの「速さ(A)を取りに行くと、ズレ(C)が出るかも」を肌で理解できる ⚖️🔥

---

## 1. レプリケーションってなに？🪞✨（超ざっくり）

レプリケーションは、**同じデータを複数台にコピーして持つ**ことだよ〜📦📦📦

よくある狙いはこんな感じ👇

* **読み取りを速くする / たくさん捌く**（読める場所が増える）⚡📖
* **障害に強くする**（片方が倒れても、もう片方がいる）🧯💪
* **バックアップや分析**に回す（本番を邪魔しにくい）🧪📊

そして、その代表パターンが **Leader-Follower（Primary-Replica）** だよ！👑🪞
公式ドキュメントでも “leader follower（primary-replica）” みたいに並列表現されることが多いよ〜📚✨ ([valkey.io][1])

---

## 2. Leader-Follower（Single-Leader）の基本構造 🧠🗺️

### 2-1. 役割のイメージ 👑🪞

* **Leader（Primary）**：書き込み（更新）を受け付ける中心人物👑✍️
* **Follower（Replica）**：Leaderの変更を受け取って、**少し遅れて反映**する写し🪞⏳

「全部の書き込みがLeaderに集まる」ので、更新の順番が揃いやすいのが強い✨
（書き込みが分散すると、同時更新の衝突が起きやすいからね…💥）
この「Leaderが順序を決める」説明は、Leader-Followerのキモとしてよく語られるよ📌 ([Ivan Fedianin][2])

### 2-2. 文章だけ図解（脳内イメージ用）🗺️🤖

* 書く流れ（Write path）✍️
  ユーザー → Leader に書き込み → Leader が「変更ログ」を流す → Follower が追従

* 読む流れ（Read path）👀
  読み取りは **LeaderでもFollowerでも**できる（設計次第）
  ただし **Followerは遅れてることがある** ←ここが今日の主役！🌟

---

## 3. “遅れて追従”ってどれくらい怖いの？😵‍💫⏳

Followerはだいたい **非同期（async）** で追従することが多いよ。
つまりこう👇

### 3-1. 時系列のミニ例 🕰️

1. 12:00:00　Leaderに「注文確定！」って書き込む ✅
2. 12:00:00　Leaderはすぐ「OK返すよ！」って返せる（速い！）⚡
3. 12:00:02　Followerがやっと追従して「注文確定」を反映 ✅（2秒遅れ）

この間（12:00:00〜12:00:02）にFollowerから読むと…
**「え、注文まだ処理中なんだけど？」** みたいな“古い読み取り”が起きるよ😇📉

---

## 4. ハンズオン：Followerを遅延させて“古い読み取り”を再現する 🧪🐢💥

### 4-0. できあがるもの（完成図）📦✨

* apps/api（Leader）：注文を受け付けて状態を持つ👑
* apps/worker（Follower）：Leaderのイベントをポーリングで取りに行って、遅延つきで反映🪞🐢
* どっちもHTTPで状態を見れるようにする👀

---

## 4-1. API（Leader）を作る 👑✍️

### ① apps/api/src/server.ts

```ts
import express from "express";

type OrderStatus = "PENDING" | "CONFIRMED" | "CANCELED";
type Order = { id: string; status: OrderStatus; updatedAt: number };

type Event =
  | { offset: number; type: "OrderCreated"; orderId: string; at: number }
  | { offset: number; type: "OrderConfirmed"; orderId: string; at: number }
  | { offset: number; type: "OrderCanceled"; orderId: string; at: number };

const app = express();
app.use(express.json());

// Leaderが持つ“正本の状態”
const orders = new Map<string, Order>();

// LeaderがFollowerへ流す“変更ログ”（イベント）
const events: Event[] = [];
let offset = 0;

function pushEvent(e: Omit<Event, "offset">) {
  const ev = { ...e, offset: offset++ } as Event;
  events.push(ev);
  return ev;
}

app.get("/health", (_req, res) => res.json({ ok: true }));

app.post("/orders", (req, res) => {
  const id = String(req.body?.id ?? "");
  if (!id) return res.status(400).json({ error: "id is required" });

  const now = Date.now();
  orders.set(id, { id, status: "PENDING", updatedAt: now });
  const ev = pushEvent({ type: "OrderCreated", orderId: id, at: now });

  res.json({ ok: true, leader: true, order: orders.get(id), event: ev });
});

app.post("/orders/:id/confirm", (req, res) => {
  const id = req.params.id;
  const existing = orders.get(id);
  if (!existing) return res.status(404).json({ error: "not found" });

  const now = Date.now();
  const updated: Order = { ...existing, status: "CONFIRMED", updatedAt: now };
  orders.set(id, updated);
  const ev = pushEvent({ type: "OrderConfirmed", orderId: id, at: now });

  res.json({ ok: true, leader: true, order: updated, event: ev });
});

app.get("/orders/:id", (req, res) => {
  const id = req.params.id;
  const order = orders.get(id);
  if (!order) return res.status(404).json({ error: "not found" });

  res.json({ ok: true, leader: true, order });
});

// Followerが取りに来る“イベント取得API”
app.get("/events", (req, res) => {
  const from = Number(req.query.from ?? 0);
  const slice = events.filter((e) => e.offset >= from);
  res.json({
    ok: true,
    leader: true,
    from,
    nextFrom: slice.length ? slice[slice.length - 1].offset + 1 : from,
    events: slice,
  });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  console.log(`[leader] listening on http://localhost:${port}`);
});
```

---

## 4-2. Worker（Follower）を作る 🪞🐢

Followerは「Leaderの/eventsを定期的に取りに行って、遅延つきで反映」するよ〜⏳✨

### ① apps/worker/src/server.ts

```ts
import express from "express";

type OrderStatus = "PENDING" | "CONFIRMED" | "CANCELED";
type Order = { id: string; status: OrderStatus; updatedAt: number };

type Event =
  | { offset: number; type: "OrderCreated"; orderId: string; at: number }
  | { offset: number; type: "OrderConfirmed"; orderId: string; at: number }
  | { offset: number; type: "OrderCanceled"; orderId: string; at: number };

const app = express();

const followerOrders = new Map<string, Order>();

const leaderBaseUrl = process.env.LEADER_URL ?? "http://localhost:3000";
const pollIntervalMs = Number(process.env.POLL_INTERVAL_MS ?? 300);
const applyLagMs = Number(process.env.APPLY_LAG_MS ?? 1500); // ←ここが“遅延”🐢
let nextFrom = 0;

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

async function applyEvent(ev: Event) {
  // 「わざと遅らせる」ことでレプリカのラグを再現🐢
  await sleep(applyLagMs);

  const now = Date.now();
  const existing = followerOrders.get(ev.orderId);

  if (ev.type === "OrderCreated") {
    followerOrders.set(ev.orderId, {
      id: ev.orderId,
      status: "PENDING",
      updatedAt: ev.at,
    });
  }

  if (ev.type === "OrderConfirmed") {
    if (!existing) {
      followerOrders.set(ev.orderId, { id: ev.orderId, status: "CONFIRMED", updatedAt: ev.at });
    } else {
      followerOrders.set(ev.orderId, { ...existing, status: "CONFIRMED", updatedAt: ev.at });
    }
  }

  if (ev.type === "OrderCanceled") {
    if (!existing) {
      followerOrders.set(ev.orderId, { id: ev.orderId, status: "CANCELED", updatedAt: ev.at });
    } else {
      followerOrders.set(ev.orderId, { ...existing, status: "CANCELED", updatedAt: ev.at });
    }
  }

  console.log(
    `[follower] applied offset=${ev.offset} type=${ev.type} orderId=${ev.orderId} lag=${Date.now() - ev.at}ms (now=${now})`
  );
}

async function pollLoop() {
  while (true) {
    try {
      const url = `${leaderBaseUrl}/events?from=${nextFrom}`;
      const res = await fetch(url);
      const json = (await res.json()) as {
        ok: boolean;
        nextFrom: number;
        events: Event[];
      };

      for (const ev of json.events) {
        // ここは直列にして「遅延が積み上がる」感覚を出すよ🐢🐢🐢
        await applyEvent(ev);
      }
      nextFrom = json.nextFrom;
    } catch (e) {
      console.log("[follower] poll error", e);
      // ちょい待って再挑戦（雑に）🔁
      await sleep(500);
    }

    await sleep(pollIntervalMs);
  }
}

app.get("/health", (_req, res) => res.json({ ok: true }));

app.get("/orders/:id", (req, res) => {
  const id = req.params.id;
  const order = followerOrders.get(id);
  if (!order) return res.status(404).json({ error: "not found (maybe not replicated yet)" });

  res.json({
    ok: true,
    follower: true,
    nextFrom,
    applyLagMs,
    order,
  });
});

const port = Number(process.env.PORT ?? 3001);
app.listen(port, () => {
  console.log(`[follower] listening on http://localhost:${port}`);
  console.log(`[follower] leaderBaseUrl=${leaderBaseUrl} pollIntervalMs=${pollIntervalMs} applyLagMs=${applyLagMs}`);
});

pollLoop();
```

---

## 4-3. 動かして観察する 👀🧪

### ① 起動（ターミナル2つで）

* ターミナルA：Leader

```txt
cd apps/api
npm run dev
```

* ターミナルB：Follower

```txt
cd apps/worker
set LEADER_URL=http://localhost:3000
set APPLY_LAG_MS=3000
npm run dev
```

### ② 注文を作る（Leaderへ書く）🛒✍️

```txt
curl -X POST http://localhost:3000/orders -H "Content-Type: application/json" -d "{\"id\":\"o-1\"}"
```

### ③ すぐFollowerから読む（古い/無い を見る）🪞🐢

```txt
curl http://localhost:3001/orders/o-1
```

ここで起きやすいのは👇

* 404（まだ複製されてない）😇
* もしくは PENDING のまま（更新が追いついてない）⏳

### ④ 少し待って、もう一回読む ⏳✨

```txt
curl http://localhost:3001/orders/o-1
```

だんだん “追いつく” はず！🏃‍♀️💨
Follower側ログに「applied … lag=xxxxms」って出るのも見てね👀📜

---

## 5. ここで起きてることを言葉にすると…🧠✨

### 5-1. “古い読み取り”の正体 🧟‍♀️📖

Followerは **Leaderの変更を後追い**してるから、次のどれかが起きるよ👇

* **まだ存在しない**（作成イベントが未反映）🫥
* **状態が古い**（確定したのにPENDINGのまま）🕰️
* **複数回更新があると、さらにズレる**（遅延が積み上がる）🐢🐢🐢

### 5-2. CAPの肌感覚につながるところ ⚖️🔥

Followerから読めば、分断や遅延があっても「とりあえず返せる」＝**A寄り**になりやすい。
でもその代わり「最新と一致してる保証（C）」は弱くなりがち。
このトレードオフが、今後ずっと出てくるよ〜！🌋✨

---

## 6. “本物のDB”だと何が流れてるの？📦📚（雰囲気だけ）

実際のDBだと、だいたい「変更ログ」を流してるよ。
たとえばPostgreSQLだとWAL（ログ）を送り、受け側が受け取って追従する仕組みがあるよ〜🧾➡️🪞 ([wiki.postgresql.org][3])

ここで大事なのは細かい用語より、これ👇

* **書き込みは1か所に集める（Leader）**
* **Followerはログを後追いする**
* **だからラグがある**

---

## 7. ミニ課題（やると一気に身につく）📝✨

### 課題A：ラグをいじって“事故りやすさ”を観察しよう 🐢💥

* APPLY_LAG_MS を 0 / 500 / 3000 / 8000 に変えてみてね
* Followerの読めるタイミングがどう変わる？👀

### 課題B：“書いた直後だけLeaderから読む”ルールを入れてみよう 👤✅

ヒント：注文を作った直後の画面は

* 「あなたの操作はLeaderに書けた」って分かってる
  だから「直後だけLeader読む」は、ズレ対策としてよくあるよ〜🧠✨
  （これが次の章の“読む場所を選ぶ”につながるよ！）

---

## 8. AI（Copilot/Codex）に頼むと強いポイント 🤖✨

### 図解を作ってもらう 🗺️

* 「Leader-Followerの時系列図を、文章で短く作って」📝
* 「このコードの挙動を、3行で説明して」🧠

### ログ改善を提案してもらう 🕵️‍♀️

* 「Followerのログに、イベント発生時刻と適用時刻の差をもっと見やすく出して」📈
* 「相関IDっぽいもの（orderId）を毎行に必ず出すように整えて」🧵

---

## 9. 章末チェック（3問）✅🎓

### Q1：Leader-Followerで“基本”として正しいのは？👑🪞

A. どこに書いてもOK
B. 書き込みは基本Leaderに集める
C. Followerの方が常に新しい
→ 答え：B ✅（Leaderが順序を作るのが強み） ([Ivan Fedianin][2])

### Q2：Followerから読んだら古いことがあるのはなぜ？🐢

A. Followerが嘘をつくから
B. 変更が後追いで反映されるから
C. HTTPが遅いから
→ 答え：B ✅

### Q3：Follower読みは何を得やすい？⚡

A. 速さ・分散読み取り
B. 常に最新一致
C. 競合ゼロ
→ 答え：A ✅

---

## 10. この章の結論（1行）✍️✨

**Leaderに書いてFollowerが遅れて追いかけるので、Follower読みは速いけど“古いかも”が基本だよ 🪞🐢⚡**

---

### 参考（最新動向の拾い方メモ）📌✨

* Node.js のリリース線（LTS/Current）は公式ページのスケジュールが基準だよ📅 ([nodejs.org][4])
* TypeScriptは安定版（現行）に加えて、ネイティブ実装プレビューが進んでいて、大規模プロジェクトのビルド/言語サービス高速化が話題だよ🚀 ([Microsoft Developer][5])

[1]: https://valkey.io/topics/replication/ "Valkey Documentation · Replication"
[2]: https://fedianin.com/2025/01/06/understanding-leader-follower-replication/?utm_source=chatgpt.com "Understanding Leader-Follower Replication - Ivan Fedianin"
[3]: https://wiki.postgresql.org/wiki/Binary_Replication_Tutorial?utm_source=chatgpt.com "Binary Replication Tutorial"
[4]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[5]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026 "TypeScript 7 native preview in Visual Studio 2026 - Microsoft for Developers"
