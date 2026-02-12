# 第14章：Graceful shutdown：落とされ方を想定する🧯⏳

本番って、ある日いきなり「はい終了〜！」って止められる瞬間があるんだよね😇
そのときに **途中のリクエストがブチ切れたり**、**DBが中途半端になったり**、**ログが途切れて原因不明になったり**…を避けるのがこの章のゴールだよ🚀✨

---

## 1) まず「何が起きるか」を1枚絵で理解しよ🖼️👀

コンテナが終了するときは、だいたいこの流れ👇

1. **SIGTERM**（「そろそろ終わってね」）が来る
2. ちょっと待ってくれる（猶予時間）
3. 終わらないと **SIGKILL**（「強制終了」）でぶった切られる💀

代表例はこんな感じ👇

* Docker の “止める” は基本 **SIGTERM →（待つ）→ SIGKILL**。Linuxコンテナの既定の待ち時間は **10秒**（Windowsコンテナは30秒）だよ⏱️ ([Docker Documentation][1])
* Cloud Run は **SIGTERM → 10秒 → SIGKILL**（この10秒は “終了処理のための猶予”）📌 ([Google Cloud Documentation][2])
* Kubernetes は “termination grace period” の既定が **30秒**（その間に終わらないと強制終了）🧊 ([Google Cloud][3])

つまり…
**「SIGTERMが来たら、猶予時間内にキレイに片付けて出ていく」**
これが Graceful shutdown の基本だよ🧹✨

---

## 2) Graceful shutdown の“やること”は4つだけ🎯

難しく見えるけど、やることは固定👇

1. **新規リクエストを受けない**（入口を閉める🚪）
2. **処理中リクエストを待つ**（ただし上限時間つき⏳）
3. **外部リソースを閉じる**（DB/キュー/キャッシュなど🔌）
4. **時間切れなら諦めて終了**（SIGKILLされる前に自分で終える）

---

## 3) Nodeの落とし穴：server.close()だけだと“閉まらない”ことがある😵

HTTPには「Keep-Alive（接続を使い回す）」があるんだけど、これのせいで

* **server.close() したのにプロセスが終わらない**
  が起きがち💦

そこで便利なのが Node のサーバ機能👇

* **closeIdleConnections()**（アイドル接続だけ閉じる）
* **closeAllConnections()**（全部閉じる）

これらは Node v18.2.0 から使えるよ✅（いまの現行Nodeなら普通にOK） ([Node.js][4])

---

## 4) ハンズオン：Express(+TypeScript)に “安全な終了” を入れる🛠️🧪

ここからは「最小で効く」実装を入れて、Dockerで挙動を確認するよ🐳✨
（既存のAPIにそのまま移植できる形で書くね）

---

## 4-1) 準備：テスト用の “わざと遅いAPI” を作る🐢

まずは「止められたら困る」状況を作るよ😈

```ts
// src/app.ts
import express from "express";

export const app = express();

app.get("/sleep", async (req, res) => {
  const ms = Number(req.query.ms ?? 15000);
  await new Promise((r) => setTimeout(r, ms));
  res.json({ ok: true, sleptMs: ms });
});

app.get("/healthz", (req, res) => {
  res.json({ ok: true });
});
```

---

## 4-2) 本体：Graceful shutdown を実装する（コピペOK）📌✨

ポイントは👇

* “シャットダウン中フラグ” を立てる
* 入口を閉める（新規を503にする）
* in-flight（処理中）カウントが0になるのを待つ
* Keep-Alive を閉じる
* 最後にDB等を閉じて終了

```ts
// src/server.ts
import http from "node:http";
import { app } from "./app";

const port = Number(process.env.PORT ?? 3000);

let shuttingDown = false;
let inflight = 0;

// 入口を閉める（shutdown開始後は新規を受けない）
app.use((req, res, next) => {
  if (shuttingDown) {
    res.setHeader("Connection", "close");
    res.setHeader("Retry-After", "5");
    return res.status(503).json({ ok: false, message: "Server is restarting 😵‍💫" });
  }

  inflight++;
  res.on("finish", () => {
    inflight--;
  });
  next();
});

const server = http.createServer(app);

server.listen(port, "0.0.0.0", () => {
  console.log(`✅ listening on :${port}`);
});

let shutdownStarted = false;

async function gracefulShutdown(signal: string) {
  if (shutdownStarted) return;
  shutdownStarted = true;

  console.log(`🧯 ${signal} received -> starting graceful shutdown...`);
  shuttingDown = true;

  // ① 新規接続を止める（すでに張られてるKeep-Aliveが残ることがある）
  await new Promise<void>((resolve) => server.close(() => resolve()));

  // ② Keep-Aliveの “遊んでる接続” を閉じる（これが地味に効く）
  // Node v18.2+ で利用可能
  server.closeIdleConnections?.();

  // ③ 処理中のリクエストが終わるのを待つ（ただし上限あり）
  const hardTimeoutMs = 9000; // 例：Cloud Runの10秒に収めたいなら9秒くらいが安全
  const startedAt = Date.now();

  while (inflight > 0 && Date.now() - startedAt < hardTimeoutMs) {
    console.log(`⏳ waiting inflight=${inflight} ...`);
    await new Promise((r) => setTimeout(r, 200));
  }

  // ④ まだ残ってたら強制的に閉じる（Keep-Aliveや長い通信の“居残り対策”）
  if (inflight > 0) {
    console.log(`💥 still inflight=${inflight} -> closing all connections`);
    server.closeAllConnections?.();
  }

  // ⑤ DB/キュー等のクリーンアップ（ここに実プロジェクトの後始末を書く）
  // await prisma.$disconnect();
  // await redis.quit();
  // await queue.close();

  console.log("✅ shutdown complete. bye 👋");
  process.exit(0);
}

// Docker/Cloud Run/K8sで来るやつ
process.on("SIGTERM", () => void gracefulShutdown("SIGTERM"));
// ローカルでCtrl+Cしたとき
process.on("SIGINT", () => void gracefulShutdown("SIGINT"));
```

この実装の「強いところ」💪✨

* shutdown中は新規を 503 で返す（LBが切り替えやすい）
* Keep-Alive問題を “Nodeの機能” で踏みつぶす（closeIdle/closeAll） ([Node.js][4])
* Cloud Runの **10秒猶予**にも寄せやすい（hardTimeoutを短めにしてる） ([Google Cloud Documentation][2])

---

## 4-3) Dockerで実験：止めたときに “/sleep が完走するか” を見る🐳👀

1. 起動（いつものDockerfileでOK）
2. 別ターミナルで遅いAPIを叩く👇

```bash
curl "http://localhost:3000/sleep?ms=15000"
```

3. さらに別ターミナルで止める👇（※ここが大事！）

```bash
docker stop -t 20 <container_name_or_id>
```

* Dockerの stop は基本 **SIGTERMを送って待って、ダメならSIGKILL** という挙動だよ（既定は10秒） ([Docker Documentation][1])
* なので今回は “わざと15秒” のリクエストに合わせて `-t 20` にしてる👍

ログで

* 「SIGTERM受け取った！」
* 「inflightを待ってる！」
* 「終わった！ exit！」
  が見えたら勝ち🏆🎉

---

## 5) 現場での調整ポイント（ここ超重要）🧠🔧

## ✅ A) “猶予時間” と “最大リクエスト時間” を揃える⏱️

* Docker：既定10秒（伸ばせる） ([Docker Documentation][1])
* Cloud Run：終了猶予は **10秒固定**（だからアプリ側が寄せるのが基本） ([Google Cloud Documentation][2])
* Kubernetes：既定30秒（設定で変えられる） ([Google Cloud][3])

👉 結論：
**「猶予時間より長い処理」は、途中で切られても壊れない設計（再試行・冪等など）**を考えるのが本番っぽさ😎✨

## ✅ B) shutdownは “何度呼ばれても安全” にする🔁

SIGTERMが複数回来ることもあるので、今回みたいに
「最初の1回だけ動くガード」
を入れるのが鉄板👍

---

## 6) つまずきTop5 😵‍💫➡️✅

## 1) 「SIGTERMが来てない気がする」

* ローカルで普通に止めるとSIGINT（Ctrl+C）になりがち
* “本番っぽく” なら Docker は `docker stop` で試すのが正解🐳

## 2) 「server.close()したのに終わらない」

Keep-Aliveの居残りが原因のことが多いよ😇
→ `closeIdleConnections()` / `closeAllConnections()` を使う（Node v18.2+） ([Node.js][4])

## 3) 「Cloud Runでたまに途中で切れる」

Cloud Run は **SIGTERMから10秒でSIGKILL** の契約📌 ([Google Cloud Documentation][2])
→ hardTimeoutを短めにして、後始末は “軽く” する（重い処理は別ジョブへ）

## 4) 「終了処理中に新規が入ってきてグチャる」

→ shutdown中フラグで 503（＋Connection: close）を返すのが効く🚪

## 5) 「DB接続が残ってプロセスが落ちない」

→ 終了処理で必ず disconnect を呼ぶ（Prisma/pg/mongoose/redis等）

---

## 7) 章末チェックリスト✅📋

* SIGTERMを受け取ったらログが出る🪵
* shutdown開始後は新規が503になる🚫
* in-flight を待ってから終了する⏳
* Keep-Aliveが残っても最終的に終わる🧯
* DB/キューを閉じる場所がある🔌
* Cloud Runの10秒に収まる設計になってる（目安）⏱️ ([Google Cloud Documentation][2])

---

## 8) Copilot / Codex に投げる “コピペ用プロンプト” 🤖📌

## ✅ 最小で入れたい

```text
Node.js(TypeScript) + Express のAPIに graceful shutdown を入れたい。
SIGTERM/SIGINT を受けて、新規リクエストは 503 にし、in-flight を待ってから http server を閉じ、
最後にDB(Prisma想定)とRedisをdisconnectして終了するコードを提案して。
Keep-Aliveで server.close() が終わらない問題も考慮して、closeIdleConnections/closeAllConnections を使って。
Cloud Run の終了猶予10秒に収まるようにタイムアウト設計も入れて。
```

## ✅ 既存コードに“安全に差分”で入れたい

```text
この server.ts に graceful shutdown を差分で追加したい。
変更点は最小にして、追加箇所にコメントを付けて。
テスト用に /sleep?ms=15000 を追加して、docker stop -t 20 で挙動確認する手順も書いて。
```

---

次の章（第15章：ヘルスチェック🩺✅）に行くと、
「落ちたら戻る」「戻れないなら止める」っていう “復旧力” が一気に上がるよ🔥
もし今のプロジェクト構成（Express / Fastify / Next.js / NestJS など）を教えてくれたら、**第14章のコードをそのフレームワーク版に寄せた完成形**もすぐ出せるよ😆✨

[1]: https://docs.docker.com/reference/cli/docker/container/stop/?utm_source=chatgpt.com "docker container stop"
[2]: https://docs.cloud.google.com/run/docs/container-contract?utm_source=chatgpt.com "Container runtime contract | Cloud Run"
[3]: https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-terminating-with-grace?utm_source=chatgpt.com "Kubernetes best practices: terminating with grace"
[4]: https://nodejs.org/api/https.html?utm_source=chatgpt.com "HTTPS | Node.js v25.6.1 Documentation"
