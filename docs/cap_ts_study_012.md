# 第12章：整合性レベル② セッション保証（自分の書き込みは見たい）👤✅

## 今日の結論（1行）✨

「全員の世界を完全に一致させる」じゃなくて、「**自分の操作だけは矛盾しない世界**を見せる」のがセッション保証だよ😊💡 ([コーネル大学コンピュータサイエンス学科][1])

---

## 1. まず“事故”を想像しよう 😱🛒

### ありがちな悲劇💥

* ユーザーが「注文する」🛒➡️✅
* 直後に「注文詳細を見る」👀
* なのに画面が…

  * 「注文が見つかりません」😇
  * 「ステータスが前のまま」😇😇

これ、**レプリカ（複製）側がまだ追いついてない**と普通に起きるやつ…！⏳🪞

---

## 2. セッション保証ってなに？🤔📌

弱い整合性（最終的整合性）な複製データでも、**同じユーザー（同じセッション）**の操作だけは「自分の行動と矛盾しない見え方」を作るための考え方だよ✨
代表的に次の4つが提案されてるよ（この章は太字の2つに集中！）📚👇 ([コーネル大学コンピュータサイエンス学科][1])

* **Read Your Writes**（自分の書き込みは見える）👤✅
* **Monotonic Reads**（読んだ内容が“巻き戻らない”）⏩✅
* Writes Follow Reads
* Monotonic Writes

---

## 3. 今日やる2つ（超大事）⭐

### 3.1 Read Your Writes（RYW）👤✅

「自分が書いた変更は、そのあと自分が読むとき必ず反映されてる」って保証✨
（論文や解説では “Read My Writes / Read Your Writes” とも呼ばれるよ）📄 

💡たとえば：

* 「住所を変更」🏠✍️
* 直後に「プロフィール確認」👀
* ちゃんと新住所が見える✅

### 3.2 Monotonic Reads（単調読み取り）⏩✅

「一度“新しい状態”を見たなら、次に読んだとき“古い状態”に戻らない」保証✨
つまり **タイムトラベル禁止**🚫🕰️ 

💡たとえば：

* 注文ステータスを「支払い済み💳」まで見た
* 次の画面で「未払い」に戻った
  → それは絶対イヤだよね😇

---

## 4. どうやって実現するの？（現場の定番パターン）🧰✨

### パターンA：しばらく“Primary読み”に寄せる👑📖

* 書き込み直後のユーザーは、**一定時間だけPrimaryから読む**
* いちばん簡単✨
* でもPrimaryが混みやすい😵‍💫

### パターンB：セッショントークン（最低バージョン）を持つ🎫🔢

* ユーザーごとに「私は少なくとも version=123 以降の世界が見たい！」を持たせる
* 読むときに

  * レプリカが追いついてたらレプリカでOK🪞⚡
  * 追いついてなければPrimaryへ👑
* これがめちゃ実用的✨（この章のハンズオンはコレ！）🎉

### パターンC：追いつくまで“待つ”（ブロック）⏳🛑

* レプリカが追いつくまでレスポンスを遅らせる
* 一貫性は強いけど、UXが重くなりがち😵‍♀️

---

## 5. ハンズオン：同一ユーザーだけ新しい値を優先して読む🎮🧪

ここから実装するよ〜！💪😆
やることはシンプル👇

1. Primary/Replica の2つのJSONファイルを用意📄📄
2. Worker が遅れて Replica を更新する（レプリケーション遅延を再現）🐢
3. API が「セッション最小バージョン」を見て、読む場所を切り替える🎛️✨

---

## 6. 実装：ファイルを追加する📁✨

### 6.1 データ保存フォルダを作る📦

プロジェクト直下にフォルダ作成👇

* data/

  * primary.json
  * replica.json

---

## 7. API側（apps/api）🧩🌐

### 7.1 JSONストア（共通処理）を追加🧠

ファイル：apps/api/src/jsonStore.ts

```ts
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export type OrderStatus = "PLACED" | "PAID";

export type Order = {
  id: string;
  userId: string;
  status: OrderStatus;
  version: number;
  updatedAt: number;
};

export type Db = {
  version: number;
  orders: Record<string, Order>;
};

function repoRootFromHere(importMetaUrl: string): string {
  // apps/api/src/jsonStore.ts -> 3つ上がリポジトリ直下想定
  const here = path.dirname(fileURLToPath(importMetaUrl));
  return path.resolve(here, "../../..");
}

const repoRoot = repoRootFromHere(import.meta.url);
const dataDir = path.join(repoRoot, "data");

export const PRIMARY_PATH = path.join(dataDir, "primary.json");
export const REPLICA_PATH = path.join(dataDir, "replica.json");

async function ensureDataFiles(): Promise<void> {
  await fs.mkdir(dataDir, { recursive: true });

  const init: Db = { version: 0, orders: {} };

  await Promise.all([
    fs.access(PRIMARY_PATH).catch(() => fs.writeFile(PRIMARY_PATH, JSON.stringify(init, null, 2), "utf-8")),
    fs.access(REPLICA_PATH).catch(() => fs.writeFile(REPLICA_PATH, JSON.stringify(init, null, 2), "utf-8")),
  ]);
}

export async function readDb(filePath: string): Promise<Db> {
  await ensureDataFiles();
  const raw = await fs.readFile(filePath, "utf-8");
  return JSON.parse(raw) as Db;
}

export async function writeDb(filePath: string, db: Db): Promise<void> {
  await ensureDataFiles();
  await fs.writeFile(filePath, JSON.stringify(db, null, 2), "utf-8");
}

export function newId(prefix = "ord"): string {
  return `${prefix}_${Math.random().toString(16).slice(2)}_${Date.now().toString(16)}`;
}
```

---

### 7.2 セッション保証つきAPIサーバを作る🚀

ファイル：apps/api/src/server.ts

```ts
import express from "express";
import { readDb, writeDb, PRIMARY_PATH, REPLICA_PATH, newId, type Order } from "./jsonStore.js";

const app = express();
app.use(express.json());

// セッションが持つ「最低でもこのversion以上が見たい」ライン🎫🔢
function getSessionMinVersion(req: express.Request): number {
  const v = Number(req.header("x-session-min-version") ?? "0");
  return Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
}
function setSessionMinVersion(res: express.Response, v: number): void {
  res.setHeader("x-session-min-version", String(Math.max(0, Math.floor(v))));
}

type ReadSource = "primary" | "replica" | "auto";

// 読み取り先を決める🎛️
async function chooseReadDb(source: ReadSource, sessionMinVersion: number) {
  const primary = await readDb(PRIMARY_PATH);
  const replica = await readDb(REPLICA_PATH);

  if (source === "primary") return { db: primary, picked: "primary" as const, primary, replica };
  if (source === "replica") return { db: replica, picked: "replica" as const, primary, replica };

  // auto（セッション保証）
  // レプリカが追いついてないなら、Primaryに逃がす👑
  const picked = replica.version >= sessionMinVersion ? ("replica" as const) : ("primary" as const);
  return { db: picked === "replica" ? replica : primary, picked, primary, replica };
}

// デバッグ：今のPrimary/Replicaのバージョンを見る👀
app.get("/debug/versions", async (_req, res) => {
  const primary = await readDb(PRIMARY_PATH);
  const replica = await readDb(REPLICA_PATH);
  res.json({ primaryVersion: primary.version, replicaVersion: replica.version });
});

// 注文作成🛒
app.post("/orders", async (req, res) => {
  const userId = String(req.body?.userId ?? "");
  if (!userId) return res.status(400).json({ error: "userId required" });

  const primary = await readDb(PRIMARY_PATH);
  const nextVersion = primary.version + 1;

  const order: Order = {
    id: newId(),
    userId,
    status: "PLACED",
    version: nextVersion,
    updatedAt: Date.now(),
  };

  primary.version = nextVersion;
  primary.orders[order.id] = order;
  await writeDb(PRIMARY_PATH, primary);

  // RYW：書いた人のセッション最小versionを更新🎫✨
  setSessionMinVersion(res, nextVersion);

  res.status(201).json({ order });
});

// 支払い確定💳（ステータス更新）
app.post("/orders/:id/pay", async (req, res) => {
  const id = String(req.params.id);

  const primary = await readDb(PRIMARY_PATH);
  const current = primary.orders[id];
  if (!current) return res.status(404).json({ error: "order not found" });

  const nextVersion = primary.version + 1;

  const updated: Order = {
    ...current,
    status: "PAID",
    version: nextVersion,
    updatedAt: Date.now(),
  };

  primary.version = nextVersion;
  primary.orders[id] = updated;
  await writeDb(PRIMARY_PATH, primary);

  // RYW：書いた人（=今操作した人）の最低versionを更新🎫✨
  setSessionMinVersion(res, nextVersion);

  res.json({ order: updated });
});

// 注文取得👀
app.get("/orders/:id", async (req, res) => {
  const id = String(req.params.id);
  const source = (String(req.query.read ?? "auto") as ReadSource);

  const incomingMin = getSessionMinVersion(req);

  const { db, picked, primary, replica } = await chooseReadDb(source, incomingMin);

  const order = db.orders[id];

  // Monotonic Reads：今回見えたversionを、次回以降の最低ラインにする⏩✅
  // （見えたものより古い世界に戻らないため）
  const seenVersion = order?.version ?? incomingMin;
  setSessionMinVersion(res, Math.max(incomingMin, seenVersion));

  res.json({
    picked,
    sessionMinVersion: Math.max(incomingMin, seenVersion),
    versions: { primary: primary.version, replica: replica.version },
    order: order ?? null,
  });
});

app.listen(3000, () => {
  console.log("API listening on http://localhost:3000");
  console.log("GET  /debug/versions");
  console.log("POST /orders  { userId }");
  console.log("POST /orders/:id/pay");
  console.log("GET  /orders/:id?read=auto|replica|primary");
});
```

✅ポイント：

* read=replica を強制すると「最終的整合性のズレ」をわざと見れる👀🪞
* read=auto は「セッション保証つき」🎫✨

---

## 8. Worker側（apps/worker）🐢🪞

### 8.1 レプリケータ（遅延コピー）を作る📨⏳

ファイル：apps/worker/src/replicator.ts

```ts
import { readDb, writeDb, PRIMARY_PATH, REPLICA_PATH } from "../../api/src/jsonStore.js";

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

function rand(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function tick() {
  const primary = await readDb(PRIMARY_PATH);
  const replica = await readDb(REPLICA_PATH);

  if (primary.version <= replica.version) return;

  // わざと遅らせる🐢（200ms〜2500ms）
  const delay = rand(200, 2500);
  await sleep(delay);

  // 追いつく（丸ごとコピーで簡易再現）
  await writeDb(REPLICA_PATH, primary);

  console.log(`[replicator] replica caught up -> v${primary.version} (delay=${delay}ms)`);
}

async function main() {
  console.log("[replicator] started");
  while (true) {
    try {
      await tick();
    } catch (e) {
      console.error("[replicator] error", e);
    }
    await sleep(200);
  }
}

main().catch((e) => console.error(e));
```

---

## 9. 実験：ズレる→セッション保証で直る を見る👀✨

### 9.1 まず起動🏃‍♀️💨

* API を起動
* Worker（replicator）を起動

（起動コマンドはプロジェクトのスクリプトに合わせてOKだよ👍）

---

### 9.2 手動で叩いて“事故”を見る😇🪞

#### ① 注文する🛒

POST /orders に userId を入れて送る（例：userId="u1"）

#### ② 直後に、レプリカ強制で読む👀

GET /orders/{id}?read=replica

ここで order が null になったり、古い状態が返ることがあるよ😇
（replica がまだ遅れてるから）🐢🪞

#### ③ 同じ注文を auto（セッション保証）で読む🎫✨

GET /orders/{id}?read=auto
さらに、リクエストヘッダに x-session-min-version を付ける（注文レスポンスで返ってきたやつ）

すると…

* replica が追いついてなければ primary を選ぶ👑
* だから「自分の書き込みは見える」👤✅

この動きが **Read Your Writes** だよ✨ ([コーネル大学コンピュータサイエンス学科][1])

---

## 10. Monotonic Reads（巻き戻り防止）を体感⏩✅

次の順で試すと分かりやすいよ😊

1. read=primary で新しい状態を見る👑
2. その直後に read=replica を強制すると、古い状態に“戻る”ことがある🪞😇
3. でも read=auto ＋ x-session-min-version があれば戻らない🎫⏩✅

これが **Monotonic Reads**（読んだ内容が増えていく／戻らない）だよ✨ ([コーネル大学コンピュータサイエンス学科][1])

---

## 11. ここが設計のキモ（超重要）🎯✨

### 11.1 セッション保証は「全員」じゃない🙅‍♀️🌍

* あくまで「そのユーザーの体験」を守るもの👤
* 他のユーザーは、まだ古い世界を見ててもOK（最終的整合性）🪞⏳

### 11.2 “どっちで守る？”の選択肢🎛️

* Primaryに寄せて守る👑（速く確実だけど負荷💦）
* 待って守る⏳（確実だけどUXが重くなりがち😵‍♀️）
* トークンで賢く切替える🎫✨（バランス型）

---

## 12. 実システムの例（雰囲気だけ）🏭✨

「セッション（因果整合セッション）」の考え方を取り入れるDBもあるよ📚
たとえば MongoDB の説明では、条件次第で “Read own writes” と “Monotonic reads” などの保証が成立することが整理されてるよ🧠✅ ([MongoDB][2])

---

## 13. AI（Copilot / Codex）での学び方🤖💞

### おすすめプロンプト例📝✨

* 「この実装で Read Your Writes が成立する理由を、処理の流れで説明して」👤✅
* 「Monotonic Reads が壊れる最小ケースを作って、再現手順を書いて」😇🧪
* 「x-session-min-version を改ざんされないように、署名つきトークンにして」🔐🎫
* 「E2Eテストを追加して。レプリカ遅延があっても read=auto では必ず最新が見えることを検証して」🧪✅

---

## 14. 理解チェック（3問）📝💡

1. 「Read Your Writes」は **誰にとって**の保証？（全員？そのユーザー？）👤🌍
2. 「Monotonic Reads」を入れないと、どんな“気持ち悪い挙動”が起きる？🕰️😇
3. 今回の実装で x-session-min-version は何のためにある？🎫🔢

---

## 15. 次章につながる一言🪞👑

セッション保証が分かると、「Leader-Follower（Primary-Replica）」で **なぜ“古い読み”が起きるのか**がスッと理解しやすくなるよ😊✨ ([コーネル大学コンピュータサイエンス学科][1])

[1]: https://www.cs.cornell.edu/courses/cs734/2000FA/cached%20papers/SessionGuaranteesPDIS_1.html "Session Guarantees for Weakly Consistent Replicated Data"
[2]: https://www.mongodb.com/docs/v7.0/core/causal-consistency-read-write-concerns/ "Causal Consistency and Read and Write Concerns - Database Manual v7.0 - MongoDB Docs"
