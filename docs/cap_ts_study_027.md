# 第27章：リトライ設計（バックオフ/ジッター/タイムアウト）🔁⏳

## この章の結論（1行）✍️✨

リトライは「**短いタイムアウト＋指数バックオフ＋ジッター＋上限/締切（deadline）＋一時的エラーだけ**」でやると、安定して強いです💪🔁

---

## 27.1 リトライは“薬にも毒にもなる”💊☠️

分散っぽい世界では、ネットワークや相手サーバーは普通に失敗します🔌💥
だから「もう1回やる（リトライ）」は自然な対策です😊

でも！
失敗した瞬間にみんなが一斉にリトライすると、相手が復活できないくらい負荷が増えて、逆に落とし続けます😱❄️（雪崩リトライ / thundering herd）

そのため、**回数や待ち時間を“設計”**します🧠✨
（AWSでも「タイムアウト・リトライ・バックオフ・ジッター」をセットで扱うのが定番です）([Amazon Web Services, Inc.][1])

---

## 27.2 用語をざっくり整理しよう📘🧠

### タイムアウト（timeout）⏰

1回の通信を「何秒まで待つ？」という上限。
待ちすぎは“固まる”のと同じなので、**まず短く区切る**のがコツです⏳✂️

### デッドライン（deadline）🏁

「合計で何秒まで粘る？」という“総予算”です💰
例：1回あたり2秒まで待つ、最大でも合計10秒で諦める、など。

### バックオフ（backoff）📈

失敗したら待ち時間を増やすこと。
代表は **指数バックオフ**（待ち時間が 1 → 2 → 4 → 8… と増える）です📈✨

### ジッター（jitter）🎲

待ち時間に“ランダム”を混ぜること。
全員が同じタイミングで突撃しないようにするための工夫です🎯🎲
AWSやGoogleも「ジッターを入れよう」を強く推しています。([Amazon Web Services, Inc.][2])

---

## 27.3 何をリトライしていい？ダメ？✅❌（超重要）

### リトライしてOK寄り（例）✅

* ネットワーク系の一時失敗（接続失敗、タイムアウトなど）🌧️
* **429 Too Many Requests（混みすぎ）** → `Retry-After` があればそれに従う🧎‍♀️⏳([Microsoft Learn][3])
* **503 Service Unavailable（相手が一時的に無理）** → `Retry-After` があれば従う🛠️⏳([MDN Web Docs][4])
* **408 Request Timeout / 502 / 504** など「一時的っぽい」もの🌀

### リトライしちゃダメ寄り（例）❌

* バリデーションエラー（入力が間違い）📝❌
* 認証エラー（トークンが無効など）🔑❌
* 「やり直しても結果が変わらない」タイプ（恒久エラー）🧱

そして最大の注意点⚠️
**副作用のある操作（例：課金、在庫引当、メール送信）**を“何も考えずに”リトライすると、二重課金💸💥みたいな事故が起きます。
こういうときは、次章の「冪等性🧷」が必須になります👍

---

## 27.4 設計の型（これを守ると事故が激減）🧩✨

### 型A：1回の通信は短く切る（attempt timeout）⏱️

Node.js では `AbortSignal.timeout(ms)` が使えます（一定時間で中断できる）✂️⛔([nodejs.org][5])
（古い `setTimeout` は「timeoutイベントが出るだけで中断しない」系もあるので注意🥲）([nodejs.org][6])

### 型B：合計の締切（deadline）を持つ🏁

「無限にリトライ」はやらない🙅‍♀️
総時間・最大回数・最大待ち時間、どれかは必ず上限を置く✅

### 型C：指数バックオフ＋ジッター🎲📈

* 指数バックオフで“間隔を空ける”
* ジッターで“同期を崩す”（全員同時突撃を防ぐ）

### 型D：リトライは“スタックのどこか1点”に寄せる📍

アプリもSDKもゲートウェイも全部でリトライすると、回数が掛け算になって地獄です😇
AWSも「リトライはスタック内の一点でやる」系の考え方を推しています。([Amazon Web Services, Inc.][1])

---

## 27.5 ハンズオン：失敗率を上げても“安定する”リトライを作る🧪🔁

この章では、Worker（`apps/worker`）側に「fetch＋リトライ」ユーティリティを作ります🧰✨
ポイントはこれ👇

* 1回の通信は `AbortSignal.timeout()` で区切る⏱️([nodejs.org][5])
* 失敗したら指数バックオフ📈＋ジッター🎲（AWS/Google推奨）([Amazon Web Services, Inc.][2])
* 429/503 は `Retry-After` があれば優先する📨⏳([Tex2e][7])
* 上限（回数/合計時間/最大待ち）を必ず置く🧱

---

### 27.5.1 実装：リトライ付き fetch ヘルパー🧰🔁

#### `apps/worker/src/retryFetch.ts`（例）

```ts
type RetryOptions = {
  maxAttempts: number;          // 最大試行回数（例: 5）
  perAttemptTimeoutMs: number;  // 1回あたりのタイムアウト（例: 1500）
  overallDeadlineMs: number;    // 合計の締切（例: 8000）

  baseDelayMs: number;          // 初期待ち（例: 200）
  maxDelayMs: number;           // 待ちの上限（例: 3000）
  jitter: "full" | "none";      // ジッター方式（ここでは full を推奨）
};

type RetryResult<T> = {
  ok: boolean;
  value?: T;
  error?: unknown;
  attempts: number;
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// full jitter: 0〜delay のランダム（AWSでよく紹介されるタイプ）
function addJitter(delayMs: number, mode: RetryOptions["jitter"]): number {
  if (mode === "none") return delayMs;
  return Math.floor(Math.random() * delayMs);
}

function calcBackoffDelayMs(attemptIndex: number, baseDelayMs: number, maxDelayMs: number): number {
  // attemptIndex: 1,2,3... を想定
  const raw = baseDelayMs * Math.pow(2, attemptIndex - 1);
  return Math.min(raw, maxDelayMs);
}

function isRetryableHttpStatus(status: number): boolean {
  // 例として最低限：429, 503, 502, 504, 408 あたりを対象に
  return status === 429 || status === 503 || status === 502 || status === 504 || status === 408;
}

function parseRetryAfterToMs(retryAfter: string | null): number | null {
  if (!retryAfter) return null;

  // Retry-After は秒（delta-seconds） or HTTP-date
  // ここでは「秒」だけ対応（学習用にシンプル）
  const sec = Number(retryAfter);
  if (Number.isFinite(sec) && sec >= 0) return sec * 1000;

  // 日付形式も来る可能性はある（本格運用では要対応）
  return null;
}

export async function retryFetchJson<T>(
  url: string,
  init: RequestInit,
  opt: RetryOptions
): Promise<RetryResult<T>> {
  const started = Date.now();

  let lastError: unknown = null;

  for (let attempt = 1; attempt <= opt.maxAttempts; attempt++) {
    const elapsed = Date.now() - started;
    const remainingBudget = opt.overallDeadlineMs - elapsed;

    if (remainingBudget <= 0) {
      return { ok: false, error: new Error("deadline exceeded"), attempts: attempt - 1 };
    }

    // 1回の試行のタイムアウトは「残り予算」を超えないようにする
    const attemptTimeout = Math.min(opt.perAttemptTimeoutMs, remainingBudget);

    try {
      const res = await fetch(url, {
        ...init,
        // Node.js/ブラウザどちらでも使える形（AbortSignal.timeout）
        signal: AbortSignal.timeout(attemptTimeout),
      });

      if (res.ok) {
        const data = (await res.json()) as T;
        return { ok: true, value: data, attempts: attempt };
      }

      // HTTPエラー
      if (!isRetryableHttpStatus(res.status)) {
        // リトライしても意味ない寄り
        return { ok: false, error: new Error(`HTTP ${res.status}`), attempts: attempt };
      }

      // Retry-After があればそれを優先
      const raMs = parseRetryAfterToMs(res.headers.get("retry-after"));
      const backoff = calcBackoffDelayMs(attempt, opt.baseDelayMs, opt.maxDelayMs);
      const waitMs = raMs ?? addJitter(backoff, opt.jitter);

      // 次の試行まで待つ（ただし残り予算を超えない）
      const elapsed2 = Date.now() - started;
      const remaining2 = opt.overallDeadlineMs - elapsed2;
      if (remaining2 <= 0) {
        return { ok: false, error: new Error("deadline exceeded"), attempts: attempt };
      }

      await sleep(Math.min(waitMs, remaining2));
      continue;
    } catch (e) {
      // ネットワークエラーや Abort（timeout）など
      lastError = e;

      const backoff = calcBackoffDelayMs(attempt, opt.baseDelayMs, opt.maxDelayMs);
      const waitMs = addJitter(backoff, opt.jitter);

      const elapsed2 = Date.now() - started;
      const remaining2 = opt.overallDeadlineMs - elapsed2;
      if (remaining2 <= 0) {
        return { ok: false, error: lastError, attempts: attempt };
      }

      await sleep(Math.min(waitMs, remaining2));
      continue;
    }
  }

  return { ok: false, error: lastError ?? new Error("retry exhausted"), attempts: opt.maxAttempts };
}
```

**設計の根拠（要点）**

* `AbortSignal.timeout()` で「1回の通信の待ちすぎ」を防げます⏱️([nodejs.org][5])
* 指数バックオフ＋ジッターは“雪崩リトライ”を抑える定番です🎲([Amazon Web Services, Inc.][2])
* 429 のとき `Retry-After` を尊重するのは Microsoft Graph でも明確に案内されています📨([Microsoft Learn][3])
* 503 の `Retry-After` は仕様上も意味があり、待つべき時間を伝える用途です⏳([Tex2e][7])

> ちょい注意💡
> Node の `fetch` は Undici 由来の“接続レベル”タイムアウトなどが別枠で効くことがあり、「タイムアウト=全部が自由に調整できる」ではありません（ハマりポイント）🕳️([GitHub][8])
> ただ、学習用の「試行の上限を設ける」目的には十分役に立ちます🙆‍♀️✨

---

### 27.5.2 実験：API側に“わざと失敗”を入れる🎛️💥

例として、APIに「たまに503」「たまに遅い」エンドポイントを作ります🐢💣
（前の章で作った fault injection の延長だね！）

```ts
// apps/api/src/faulty.ts（例）
import { randomInt } from "node:crypto";

export function maybeDelayAndFail(req: { failRate: number; maxDelayMs: number }) {
  const roll = randomInt(0, 100);
  const shouldFail = roll < req.failRate;

  const delay = randomInt(0, req.maxDelayMs + 1);

  return { shouldFail, delay };
}
```

```ts
// apps/api/src/routes/payment.ts（例：擬似決済）
import type { FastifyInstance } from "fastify";
import { maybeDelayAndFail } from "../faulty";

export async function paymentRoutes(app: FastifyInstance) {
  app.post("/payment/authorize", async (request, reply) => {
    const failRate = Number(process.env.FAIL_RATE ?? "40");     // 40%失敗😈
    const maxDelayMs = Number(process.env.MAX_DELAY_MS ?? "800"); // 遅延🐢

    const { shouldFail, delay } = maybeDelayAndFail({ failRate, maxDelayMs });
    await new Promise((r) => setTimeout(r, delay));

    if (shouldFail) {
      // たまに「混雑なので後で」っぽく返す
      reply.header("Retry-After", "1"); // 1秒後に来てね⏳
      return reply.code(503).send({ ok: false, reason: "temporary overload" });
    }

    return reply.code(200).send({ ok: true, authorized: true });
  });
}
```

`Retry-After` を返すと、クライアント側は“待つべき時間”を受け取れます📨⏳（仕様の意図どおり）([Tex2e][7])

---

### 27.5.3 Worker側：リトライしながら呼ぶ🚚🔁

```ts
// apps/worker/src/runAuthorize.ts（例）
import { retryFetchJson } from "./retryFetch";

type AuthorizeResponse = { ok: boolean; authorized?: boolean; reason?: string };

export async function runAuthorize() {
  const res = await retryFetchJson<AuthorizeResponse>(
    "http://localhost:3000/payment/authorize",
    { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({}) },
    {
      maxAttempts: 5,
      perAttemptTimeoutMs: 1200,
      overallDeadlineMs: 8000,
      baseDelayMs: 200,
      maxDelayMs: 2500,
      jitter: "full",
    }
  );

  if (!res.ok) {
    console.log("authorize failed:", { attempts: res.attempts, error: String(res.error) });
    return;
  }

  console.log("authorize success:", { attempts: res.attempts, value: res.value });
}
```

---

## 27.6 よくあるミス集（AIにも出してもらおう）🤖❄️

### ミス1：即リトライ（待たない）🏃‍♀️💨

落ちてる相手に、0秒で何回も殴り込み → さらに落ちます😇

### ミス2：全員同時に同じ間隔でリトライ🧍‍♀️🧍‍♀️🧍‍♀️

バックオフだけだと「同じ倍々タイミング」で同期しがち。
だから **ジッター🎲** が必要です。([Amazon Web Services, Inc.][2])

### ミス3：最大回数がない（無限）♾️

いつか成功するかも…で無限に粘ると、キューやスレッドが詰まって全体が死にます🧱💥

### ミス4：あちこちでリトライ（多重リトライ）🪆

アプリもSDKもLBも…で合計回数が爆増します💣
「一点集中」の発想が大事です📍([Amazon Web Services, Inc.][1])

---

## 27.7 AIに頼むと速いところ（プロンプト例）🤖📝

### ✅ よくあるミス（雪崩リトライ）を言語化してもらう

* 「指数バックオフ＋ジッターが必要な理由を、初心者向けにたとえ話で説明して」
* 「“多重リトライ”が危険な理由を、実例つきで3つ出して」

### ✅ 自分のコードレビュー役にする👀

* 「この retryFetch 実装で、事故りやすい箇所はどこ？（タイムアウト、deadline、Retry-After、ログ観点）」
* 「リトライすべきHTTPステータスの方針が妥当かチェックして」

---

## 27.8 最終チェックリスト（提出前に指差し確認）✅🧷

* [ ] 1回の試行にタイムアウトがある⏱️([nodejs.org][5])
* [ ] 合計の締切（deadline）か最大回数がある🏁
* [ ] 指数バックオフになっている📈
* [ ] ジッターが入っている🎲([Amazon Web Services, Inc.][2])
* [ ] 429/503 の `Retry-After` を尊重している📨([Microsoft Learn][3])
* [ ] リトライ対象（ステータス/例外）を明確にした✅
* [ ] “副作用あり操作”は冪等性なしでリトライしない🧷⚠️（次章へ！）

---

## 27.9 ミニ練習問題（わかったかチェック）✍️🎯

1. **ジッターがない**指数バックオフだけのリトライで起きやすい事故は？🎲❓
2. 429 が返ってきたとき、`Retry-After: 5` があったら基本どうする？📨⏳
3. 「1回のタイムアウト」と「全体のdeadline」を両方置く嬉しさは？⏱️🏁

---

次章は **冪等性🧷✅**。
「リトライしても壊れない」を完成させます🔁✨

[1]: https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/?utm_source=chatgpt.com "Timeouts, retries and backoff with jitter"
[2]: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/?utm_source=chatgpt.com "Exponential Backoff And Jitter | AWS Architecture Blog"
[3]: https://learn.microsoft.com/en-us/graph/throttling?utm_source=chatgpt.com "Microsoft Graph throttling guidance"
[4]: https://developer.mozilla.org/ja/docs/Web/HTTP/Reference/Status?utm_source=chatgpt.com "HTTP レスポンスステータスコード - MDN Web Docs - Mozilla"
[5]: https://nodejs.org/api/globals.html?utm_source=chatgpt.com "Global objects | Node.js v25.5.0 Documentation"
[6]: https://nodejs.org/api/http.html?utm_source=chatgpt.com "HTTP | Node.js v25.5.0 Documentation"
[7]: https://tex2e.github.io/rfc-translater/html/rfc9110.html?utm_source=chatgpt.com "HTTP Semantics (RFC 9110) 日本語訳"
[8]: https://github.com/nodejs/undici/issues/4215?utm_source=chatgpt.com "`fetch()` in Node.js ignores connection timeout; no way to ..."
