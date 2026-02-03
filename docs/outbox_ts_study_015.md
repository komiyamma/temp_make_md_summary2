# 第15章：リトライ基本（どこで、何回、いつ？）🔁🧠

## この章でできるようになること 🎯✨

* 「**どこで**リトライする？」を迷わず決められる 🧭
* 「**何回**まで？」「**どんな失敗**はやめる？」が説明できる 🧠
* Publisher（送信係）に **安全なリトライ骨組み** を入れられる 🛠️

---

## 15-1. そもそも“リトライ”って、何を守るため？🛡️

Outboxの世界では、Publisherがイベントを送る瞬間に **ネットワーク・相手サービス・一時的な混雑** などで失敗します 🌧️💥
この「一時的な失敗」を **その場で諦めず**、もう一度試すのがリトライです 🔁✨

<!-- img: outbox_ts_study_015_retry_flow.png -->
ただし…！
リトライは万能じゃないです 🙅‍♀️
「どうやっても無理な失敗」を粘ると、むしろ障害が広がります（リトライ嵐🌪️）
だから **“リトライしていい失敗”だけ** を狙い撃ちします 🎯

---

## 15-2. リトライは“どこで”やる？➡️ Outboxではここが鉄板📦📤

Outboxパターンでは、基本こう考えるのがラクです🙂

* ✅ **業務処理（書き込み側）ではリトライを極力しない**
  → ここで粘ると、ユーザー待ち時間やDBロックが増えてツラい 😵‍💫
* ✅ **Publisher（送信係）でリトライする**
  → 送信の失敗を業務から切り離して、落ち着いて再送できる 🧘‍♀️✨

---

## 15-3. “失敗”を3種類に分けると超ラク 🧠🧩

リトライ設計のコツは、失敗を **分類** すること！🗂️✨
この3つに分けると、判断が速くなります 💨

### A) 一時的（Transient）🌧️ → リトライOKになりやすい

* ネットワーク切れ・タイムアウト ⏳
* 相手が一時的に落ちてる（5xx）🧯
* 混雑（429 など）🚦

### B) 恒久的（Permanent）🧱 → リトライしない（しても無駄）

* 認証・権限がダメ（例：401/403系）🔐❌
* URL/設定ミス、宛先が存在しない 🧭💥
* payloadが壊れてる（必須項目なし、型がおかしい）📄💔

### C) 仕様上（Forbidden / Not-allowed）🚫 → “正しい失敗”

* 「今その状態では送っちゃダメ」みたいな業務ルール違反
  例：キャンセル済み注文の通知を送ろうとした、など 🛒🚫

この「分類してからリトライ判断」が基本です 🙂✨
（クラウド各社の推奨でも、**リトライは“安全なものだけ”** が大前提になっています。）([Google Cloud Documentation][1])

---

## 15-4. “何回まで？”は3つの上限で決める 🎛️🧠

回数だけで決めると事故りやすいので、次の3点セットで決めます ✅

1. **最大試行回数**：例）3回、5回、10回…🔢
2. **総リトライ時間（タイムバジェット）**：例）最大30秒まで⏱️
3. **1回あたりのタイムアウト**：例）送信は2秒で諦める⏳

ポイント：

* リトライは待ち時間が伸びるので、**無限に粘らない**（上限を置く）🧯
* タイムアウトとセットで考える（タイムアウト無しは地獄…😇）
  こういう考え方は、分散システムの定番として整理されています。([Amazon Web Services, Inc.][2])

---

## 15-5. “いつ？”は2段階に分けると設計がキレイ 🪜✨

OutboxのPublisherでは、リトライを2種類に分けるのが王道です🙂

### ① その場でちょいリトライ（即時リトライ）⚡🔁

* 例）同じ処理の中で「最大3回」だけ試す
* 目的：瞬間的な揺らぎ（ネットワークぷつっ等）を拾う 📶

### ② DBに残して、後でまた（遅延リトライ）🕒🔁

* 例）attemptCountを増やして、次回のPublisher起動で再挑戦
* 目的：相手が落ちてる/混雑してる等の “時間が必要な失敗” を待つ ⏳

※②の「待ち時間の作り方（バックオフ、ジッター）」は **次の第16章**でがっつりやります📈✨
（指数バックオフ＋ジッターが定番として強く推奨されています。）([Amazon Web Services, Inc.][3])

---

## 15-6. Outboxレコードに最低限もたせたい“リトライ情報”🧾📦

Publisherが賢くなるために、Outboxテーブル（または対応する保存先）にこの辺があると超便利です🙂✨

* `attemptCount`：何回挑戦した？🔢
* `lastError`：最後の失敗理由（短めでもOK）🧯
* `lastAttemptAt`：最後に試した時刻🕒
* `status`：`pending` / `processing` / `sent` / `failed` など🚦

---

## 15-7. 実装（TypeScript）：“分類→回数制限→記録”の骨組み 🛠️✨

### 1) 失敗の分類を型で表す 🧠🏷️

```ts
// 失敗分類（リトライ判断の中心！）
export type FailureKind = "transient" | "permanent" | "forbidden";

export class ClassifiedError extends Error {
  constructor(
    message: string,
    public readonly kind: FailureKind,
    public readonly cause?: unknown,
  ) {
    super(message);
    this.name = "ClassifiedError";
  }
}
```

### 2) “分類関数”を作る（最初は雑でもOK）🔎✨

```ts
export function classifySendError(e: unknown): ClassifiedError {
  // 例：ネットワーク系っぽい → transient
  if (e instanceof Error) {
    const msg = e.message.toLowerCase();

    if (msg.includes("timeout") || msg.includes("etimedout") || msg.includes("econnreset")) {
      return new ClassifiedError("Transient network failure", "transient", e);
    }

    if (msg.includes("unauthorized") || msg.includes("forbidden")) {
      return new ClassifiedError("Auth/permission error", "permanent", e);
    }
  }

  // よく分からないものは安全側で permanent 寄りに倒すのも手
  return new ClassifiedError("Unknown failure", "permanent", e);
}
```

### 3) リトライポリシー（回数）を決める 🎛️

```ts
export type RetryPolicy = {
  maxAttempts: number; // 例: 3
};

export const defaultRetryPolicy: RetryPolicy = {
  maxAttempts: 3,
};
```

### 4) “送信処理”をリトライで包む 🔁🧩

```ts
export type SendFn = () => Promise<void>;

export async function runWithRetry(
  send: SendFn,
  policy: RetryPolicy,
  classify: (e: unknown) => ClassifiedError,
): Promise<{ ok: true } | { ok: false; error: ClassifiedError; attempts: number }> {
  for (let attempt = 1; attempt <= policy.maxAttempts; attempt++) {
    try {
      await send();
      return { ok: true };
    } catch (e) {
      const ce = classify(e);

      // forbidden / permanent は即終了（粘らない）
      if (ce.kind === "permanent" || ce.kind === "forbidden") {
        return { ok: false, error: ce, attempts: attempt };
      }

      // transient は次へ（※待ち時間は第16章で追加する）
      if (attempt === policy.maxAttempts) {
        return { ok: false, error: ce, attempts: attempt };
      }
    }
  }

  // ここには基本来ないけど保険
  return { ok: false, error: new ClassifiedError("Unexpected", "permanent"), attempts: policy.maxAttempts };
}
```

### 5) Outbox更新（attemptCount と lastError を残す）🧾🖊️

Publisher側のフローはざっくりこんな感じ👇

* `pending` を拾う
* `processing` にして確保（第14章のロックの話）🔒
* `runWithRetry` で送信
* 成功→`sent`、失敗→`failed` or `pending`（次章のスケジューリング次第）

---

## 15-8. “この章の判断テンプレ”📝✨（コピペで考えられるやつ）

次の質問に答えるだけで、リトライ方針が固まります🙂🧠

* ✅ リトライしていいのは **Transientだけ**？（基本YES）
* ✅ 最大試行回数は？（例：3回）🔢
* ✅ 1回あたりのタイムアウトは？（例：2秒）⏳
* ✅ attemptCount / lastError / lastAttemptAt は残す？（YESだと運用ラク）👀
* ✅ 失敗したらどこへ？（次章：nextRetryAt、さらに次：Dead Letter）📮

---

## 15-9. AIに手伝ってもらう（設計が速くなるやつ）🤖📝✨

### 失敗パターン洗い出し（例）

* 「この送信処理で起こりうる失敗を *Transient / Permanent / Forbidden* に分けて、例を10個ずつ出して」
* 「Permanent扱いにすべき“設定ミス系”を具体化して」

### テスト観点づくり（例）

* 「リトライが *3回で止まる* テストケース」
* 「2回失敗→3回目成功のテストケース」
* 「Permanentなら1回で打ち切るテストケース」

---

## 15-10. 練習問題（ミニ）🧪🍀

次の状況で、A/B/C どれに分類する？そしてリトライする？🙂

1. 送信先が 503 を返した 🧯
2. payloadの必須項目が欠けてた 📄💔
3. APIキーが無効だった 🔑❌
4. 送信先が 429 を返した 🚦
5. 「キャンセル済み注文の通知」を送ろうとしていた 🛒🚫

---

## まとめ 🎀

* リトライは **「分類」→「回数/時間の上限」→「記録」** が基本セット 🔁🧠
* Outboxでは **Publisherでリトライ** するのが設計しやすい 📦📤
* 次の第16章で、待ち時間（バックオフ＋ジッター）を足して **“賢い再送”** に進化させます ⏳📈✨

[1]: https://docs.cloud.google.com/storage/docs/retry-strategy?utm_source=chatgpt.com "Retry strategy | Cloud Storage"
[2]: https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/?utm_source=chatgpt.com "Timeouts, retries and backoff with jitter"
[3]: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/?utm_source=chatgpt.com "Exponential Backoff And Jitter | AWS Architecture Blog"
