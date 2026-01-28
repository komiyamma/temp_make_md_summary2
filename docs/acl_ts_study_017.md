# 第17章：エラーモデリング② 変換（翻訳）とリトライ可否の設計 🔁⏱️

## この章のゴール 🎯✨

* 外部の失敗（HTTP/ネットワーク/タイムアウト/レート制限…）を、**内側で扱いやすい形に翻訳**できるようになる🧱🗣️
* 「**リトライしていい失敗 / ダメな失敗**」を、ルールとして言語化できる🔍✅
* どの呼び出しでも同じ感覚で扱える **結果の型（Result）** を作れる📦✨

---

## 17.1 「失敗」を翻訳しないと何が困るの？😵‍💫

外部APIの失敗って、だいたいこんな感じでバラバラです👇

* `429 Too Many Requests`（レート制限）🚦
* `503 Service Unavailable`（一時的に無理）🛠️
* タイムアウト⏳
* ネットワーク断🌩️
* でも…内側（ドメイン側）から見たら、知りたいのはだいたいこれ👇

  * **いま一時的に無理？（待てば治る？）**
  * **入力がダメ？（直さないと永遠に無理？）**
  * **認証がダメ？（ログインし直す？）**
  * **そもそも存在しない？**

なので境界（ACL）で、外側の言葉を **内側の言葉に翻訳**します🧱🗣️✨
さらに、`Retry-After` みたいな「待ってね」情報も拾って、リトライ判断に使います⏱️💡（`Retry-After` の意味はHTTP標準やMDNで定義されています。）([datatracker.ietf.org][1])

---

## 17.2 まず「外部の失敗」を型で整理しよう🧺✨（ExternalError）

外部の失敗をそのまま投げると、呼び出し元が毎回つらいです😇
だからまずACL内で、外部失敗を **4種類くらいに整形**します👇

```ts
export type ExternalError =
  | {
      type: "http";
      status: number;
      message: string;
      body?: unknown;
      retryAfterMs?: number | null;
    }
  | { type: "network"; message: string; cause?: unknown }
  | { type: "timeout"; message: string; cause?: unknown }
  | { type: "parse"; message: string; raw: string; cause?: unknown };
```

ポイント💡

* **HTTP失敗**：ステータス、ボディ、`Retry-After`（あれば）
* **ネットワーク/タイムアウト**：だいたい「一時的」になりやすい
* **パース失敗**：外部レスポンスが想定外（仕様変更の気配👻）

---

## 17.3 次に「内側の失敗」を型で作ろう🧠📘（DomainError）

内側は「意味」で扱いたいので、**意図が伝わる名前**にします✨

```ts
export type DomainError =
  | { kind: "RateLimited"; retryAfterMs?: number | null }
  | { kind: "TemporaryUnavailable"; retryAfterMs?: number | null }
  | { kind: "Unauthorized" }
  | { kind: "Forbidden" }
  | { kind: "NotFound" }
  | { kind: "BadRequestToUpstream" } // 送る側の作りが悪い（直す必要あり）
  | { kind: "InvalidExternalResponse"; detail: string }
  | { kind: "UpstreamFailure"; status?: number }
  | { kind: "Unexpected"; detail: string; cause?: unknown };
```

この時点でだいぶ世界が平和になります🌸
呼び出し元は「HTTP 503だから…」じゃなくて「TemporaryUnavailableだから…」で分岐できる🧠✨

---

## 17.4 翻訳ルール（外部 → 内側）を決めよう🗺️🧱

ここがこの章のメインです🔥
「HTTPステータスごとにこう訳す」「リトライ可否はこう」の **辞書** を作ります📚✨

### よく使う翻訳例（シンプル版）📝

* `429` → `RateLimited`（リトライ✅：ただし待つ！）

  * `Retry-After` があれば、それに従う⏱️([MDN Web Docs][2])
* `503` → `TemporaryUnavailable`（リトライ✅：待つ）

  * サーバー過負荷やメンテ中で起きやすい🛠️([MDN Web Docs][3])
  * これも `Retry-After` が来ることがある⏱️([datatracker.ietf.org][1])
* `500/502/504` → `UpstreamFailure`（基本リトライ✅）
* `401` → `Unauthorized`（リトライ❌：認証し直す）
* `403` → `Forbidden`（リトライ❌：権限不足）
* `400/422` → `BadRequestToUpstream`（リトライ❌：こちらの送信が悪い）
* `404` → `NotFound`（リトライ❌：存在しない）
* タイムアウト/ネットワーク → `TemporaryUnavailable`（基本リトライ✅）

> ⚠️注意：`409 Conflict` はAPI次第で意味が変わるので、教材では「原則リトライしない（仕様を見て決める）」くらいが安全です🙅‍♀️🧯

---

## 17.5 「リトライしていい？」判断は3点セット🔍✅

リトライ判断は、これだけ守ればかなり事故が減ります👇

### ① 失敗は“一時的”っぽい？🌦️

* ネットワーク断🌩️
* タイムアウト⏳
* `500/502/503/504`
* `429`（待てば通る）🚦

### ② その操作、リトライしても安全？（冪等性）🔁🧷

* **GET** はだいたい安全（同じ取得を何度してもOK）✅
* **POSTで課金/購入/付与** は危険（2回成功したら二重処理💥）😱

  * このタイプは **冪等性キー**（Idempotency Key）や「二重防止の仕組み」が必要になりがち🔑🛡️
  * 仕組みがないなら「自動リトライしない」方が安全🙅‍♀️

### ③ いつまでも粘らない（上限）🧯

* 最大試行回数（例：3回まで）
* 最大待ち時間（例：合計2〜5秒まで）
* これを超えたら、潔く `TemporaryUnavailable` として返す✨

---

## 17.6 バックオフ（待ち時間）の王道は「指数 + ジッター」📈🎲

同時に失敗したクライアントが、同時にリトライすると…
**リトライ嵐（thundering herd）**でまた落ちます😇🌪️

だから「だんだん待つ」＋「少しランダム」を入れます🎲✨

* GoogleのSREでも「ランダム化された指数バックオフ」を推奨しています📘([sre.google][4])
* AWSの設計ガイドでも、指数バックオフ＋ジッター（上限あり）が基本として説明されています🧱([Amazon Web Services, Inc.][5])
* Google Cloudのリトライ戦略でも「truncated exponential backoff + jitter」が推奨です☁️([Google Cloud Documentation][6])

### 実装（Full Jitterの例）🎲

```ts
export function calcBackoffMs(
  attempt: number,
  baseMs = 200,
  capMs = 2_000
): number {
  // attempt: 1,2,3...
  const exp = Math.min(capMs, baseMs * 2 ** (attempt - 1));
  // Full Jitter: 0〜exp のランダム
  return Math.floor(Math.random() * exp);
}
```

---

## 17.7 “結果の型”を揃えて、扱いやすさ爆上げ📦✨（Result）

呼び出し元が毎回 `try/catch` 地獄になるのを防ぐために、**結果を同じ形**にします✨

```ts
export type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });
```

これで呼び出し側はこう書けます👇🌸

* 成功：`result.ok === true`
* 失敗：`result.ok === false`（中身は `DomainError`）

---

## 17.8 実装パーツ① Retry-After を読み取る⏱️📩

`Retry-After` は「何秒待ってね」または「日時」で来ることがあります（HTTP標準・MDN参照）([datatracker.ietf.org][1])

```ts
export function parseRetryAfterMs(value: string | null): number | null {
  if (!value) return null;

  // 1) delta-seconds（例: "120"）
  if (/^\d+$/.test(value)) {
    return Number(value) * 1000;
  }

  // 2) HTTP-date（例: "Wed, 21 Oct 2015 07:28:00 GMT"）
  const ms = Date.parse(value);
  if (Number.isNaN(ms)) return null;

  const diff = ms - Date.now();
  return diff > 0 ? diff : 0;
}
```

---

## 17.9 実装パーツ② 外部エラー → 内側エラーに翻訳🗣️🧱

「翻訳」と「リトライ可否」を一緒に返すと便利です✨

```ts
export type TranslatedError = {
  domain: DomainError;
  retryable: boolean;
};

export function translateExternalError(e: ExternalError): TranslatedError {
  if (e.type === "timeout" || e.type === "network") {
    return {
      domain: { kind: "TemporaryUnavailable" },
      retryable: true,
    };
  }

  if (e.type === "parse") {
    return {
      domain: { kind: "InvalidExternalResponse", detail: e.message },
      retryable: false, // パースできないのは「待っても直らない」ことが多い
    };
  }

  // http
  const status = e.status;

  if (status === 429) {
    return {
      domain: { kind: "RateLimited", retryAfterMs: e.retryAfterMs ?? null },
      retryable: true,
    };
  }

  if (status === 503) {
    return {
      domain: {
        kind: "TemporaryUnavailable",
        retryAfterMs: e.retryAfterMs ?? null,
      },
      retryable: true,
    };
  }

  if (status === 401) return { domain: { kind: "Unauthorized" }, retryable: false };
  if (status === 403) return { domain: { kind: "Forbidden" }, retryable: false };
  if (status === 404) return { domain: { kind: "NotFound" }, retryable: false };

  if (status === 400 || status === 422) {
    return { domain: { kind: "BadRequestToUpstream" }, retryable: false };
  }

  if (status >= 500) {
    return { domain: { kind: "UpstreamFailure", status }, retryable: true };
  }

  // その他は「基本リトライしない」
  return {
    domain: { kind: "UpstreamFailure", status },
    retryable: false,
  };
}
```

---

## 17.10 実装パーツ③ リトライの実行（回数・待ち・安全性）🔁🧷

「リトライしていい条件」を全部ここに集約します🧱✨

```ts
const sleep = (ms: number, signal?: AbortSignal) =>
  new Promise<void>((resolve, reject) => {
    const id = setTimeout(resolve, ms);
    if (!signal) return;

    const onAbort = () => {
      clearTimeout(id);
      reject(new Error("aborted"));
    };
    if (signal.aborted) onAbort();
    signal.addEventListener("abort", onAbort, { once: true });
  });

export async function withRetry<T>(
  action: (attempt: number) => Promise<Result<T, ExternalError>>,
  options?: {
    maxAttempts?: number;
    totalBudgetMs?: number;
    signal?: AbortSignal;
    // これが false の操作（例: 課金POST）は自動リトライしない
    safeToRetry?: boolean;
  }
): Promise<Result<T, DomainError>> {
  const maxAttempts = options?.maxAttempts ?? 3;
  const totalBudgetMs = options?.totalBudgetMs ?? 3_000;
  const safeToRetry = options?.safeToRetry ?? true;

  const start = Date.now();

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    if (options?.signal?.aborted) {
      return err({ kind: "Unexpected", detail: "cancelled" });
    }

    const r = await action(attempt);
    if (r.ok) return ok(r.value);

    const translated = translateExternalError(r.error);

    // リトライ不可 or 安全にリトライできない操作
    if (!translated.retryable || !safeToRetry) {
      return err(translated.domain);
    }

    const elapsed = Date.now() - start;
    if (elapsed >= totalBudgetMs || attempt === maxAttempts) {
      return err(translated.domain);
    }

    // Retry-After 優先（なければ指数バックオフ＋ジッター）
    const waitMs =
      (translated.domain.kind === "RateLimited" || translated.domain.kind === "TemporaryUnavailable")
        ? (translated.domain.retryAfterMs ?? null)
        : null;

    const backoffMs = waitMs ?? calcBackoffMs(attempt);
    const remaining = Math.max(0, totalBudgetMs - elapsed);
    const finalWait = Math.min(backoffMs, remaining);

    await sleep(finalWait, options?.signal);
  }

  return err({ kind: "Unexpected", detail: "unreachable" });
}
```

ここが超大事💡

* `Retry-After` があるときは **それ優先**⏱️
* ないときは **指数バックオフ＋ジッター**🎲
* `safeToRetry` が `false` の操作は **自動リトライしない**🧷🛡️

---

## 17.11 ミニ題材で考える🎓🍱（GETとPOSTで扱いを変える）

### ケースA：学生情報の取得（GET）🎓📄

* 失敗：`503` / ネットワーク断
* → **安全に自動リトライOK**✅
* でも回数・時間の上限は必須🧯

### ケースB：ポイント付与（POST）💰➡️🎓

* 失敗：`timeout`
* → **実は危険**⚠️（裏で成功してたら二重付与💥）
* 自動リトライするなら、冪等性キーなどの二重防止が必要🔑🛡️
* 仕組みがないなら `safeToRetry: false` にするのが安全🙅‍♀️

---

## 17.12 AI活用ミニコーナー🤖✨（設計の監督は人間🛡️）

### 使いどころ① 翻訳表のたたき台を作る🗺️

* 「`429/503/500/401/403/404` を、DomainErrorにどう割り当てる？」を箇条書きにしてもらう✍️✨
* ただし、**最終決定は教材の方針に合わせて人間が確定**🛡️

### 使いどころ② “safeToRetry=false” を付けるべき操作洗い出し🧷

* 「このAPI操作は二重実行したら困る？」を一覧にしてもらう📝

---

## 17.13 よくある事故パターン集😇🧨

* 何でもかんでもリトライして **レート制限を悪化**🚦💥
* ジッターなしで同時リトライ → **再崩壊**🌪️（SREでも注意されています📘）([sre.google][4])
* `Retry-After` 無視して即リトライ → 相手の優しさを踏みにじる🥲（仕様として明確に定義あり）([datatracker.ietf.org][1])
* POST課金を自動リトライして **二重課金**💸😱
* リトライ上限なしで **永久ループ**♾️

---

## 17.14 チェックテスト✅🎓（理解できたか確認）

* [ ] 外部の失敗を ExternalError にまとめられる📦
* [ ] ExternalError を DomainError に翻訳できる🧱🗣️
* [ ] `429` と `503` で `Retry-After` を尊重できる⏱️([MDN Web Docs][2])
* [ ] 「一時的」×「安全（冪等）」×「上限あり」でリトライ判断できる🔍✅
* [ ] 指数バックオフ＋ジッターの理由を説明できる🎲📈([Amazon Web Services, Inc.][5])

---

## 17.15 まとめ🌸🏁

* ACLの境界で「外部の失敗」を **内側の意味**に翻訳する🧱🗣️✨
* リトライは **一時的か？安全か？上限あるか？** の3点セット🔍✅🧯
* 待ち方は **指数バックオフ＋ジッター**が王道🎲📈（大規模運用の知見として推奨あり）([Google Cloud Documentation][6])
* `Retry-After` が来たら **最優先で尊重**⏱️（HTTP標準/MDN）([datatracker.ietf.org][1])

---

### おまけ豆知識🍬（ちょい最新ネタ）

TypeScript 5.9 では `--module node20` のように、Nodeの挙動をモデル化した安定オプションが整理されています🧩✨([typescriptlang.org][7])

[1]: https://datatracker.ietf.org/doc/rfc9110/?utm_source=chatgpt.com "RFC 9110 - HTTP Semantics"
[2]: https://developer.mozilla.org/ja/docs/Web/HTTP/Reference/Status/429?utm_source=chatgpt.com "429 Too Many Requests - HTTP - MDN Web Docs"
[3]: https://developer.mozilla.org/ja/docs/Web/HTTP/Reference/Status/503?utm_source=chatgpt.com "503 Service Unavailable - HTTP - MDN Web Docs"
[4]: https://sre.google/sre-book/addressing-cascading-failures/?utm_source=chatgpt.com "Cascading Failures: Reducing System Outage"
[5]: https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/?utm_source=chatgpt.com "Timeouts, retries and backoff with jitter"
[6]: https://docs.cloud.google.com/iam/docs/retry-strategy?utm_source=chatgpt.com "Retry failed requests | Identity and Access Management (IAM)"
[7]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
