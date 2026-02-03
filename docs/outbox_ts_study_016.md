# 第16章：バックオフ＆スケジューリング（賢い再送）⏳📈

## 16.1 この章でできるようになること 🎯✨

* リトライの「間隔」を賢く伸ばす（バックオフ）📈
* 同じタイミングに再送が集中しないように散らす（ジッター）🎲
* Outboxに `nextRetryAt`（次回再送時刻）を持たせて“待ち”を管理する 🕒🧾
* 「今送るべき行」だけを安全に拾えるようにする（スケジューリング）📤✅

---

## 16.2 なんで“すぐ再送”しちゃダメなの？😵‍💫💥

<!-- img: outbox_ts_study_016_backoff.png -->
失敗した瞬間に **0秒で連打リトライ**すると、こうなりがちです👇

* ちょっとしたネットワーク瞬断 🌧️ → みんな一斉に再送 🔁🔁🔁
* 一斉再送が **負荷スパイク**⚡ → さらに落ちる
* さらにみんなが再送…で **障害が雪だるま**☃️💥

この「再送の波（retry ripples）」を避けるために、**ランダム化された指数バックオフ**が推奨されます。([sre.google][1])

---

## 16.3 バックオフの基本：3つだけ覚えよ〜🙂📚

### ① 固定（Fixed）⏱️

* 毎回 3秒待つ、みたいなやつ
* ✗ みんなが同じ周期で揃うと、再び同時アクセスしやすい😵

### ② 線形（Linear）📏

* 3秒 → 6秒 → 9秒…
* △ まだ“同時に揃う”問題が残りやすい🌀

### ③ 指数（Exponential）📈（本命！）

* 1秒 → 2秒 → 4秒 → 8秒 → 16秒…（上限まで）
* 失敗先に“回復する時間”をあげられる🧯✨
* ただし **指数だけ**だと「みんな同じ秒数で待つ」ので、**ジッター**が必須です🎲

  * 背景処理のリトライでは **指数バックオフ＋ジッター**が一般に推奨されます。([Microsoft Learn][2])
  * さらに、ジッター込みの考え方は定番パターンとして整理されています。([Amazon Web Services, Inc.][3])

---

## 16.4 ジッター（Jitter）ってなに？🎲✨

**ジッター = 待ち時間にランダムな揺れを入れる**ことです。
「同じタイミングに再送が集中する」のを避けます。([sre.google][1])

よく使われるジッターの型👇（どれか1つ採用でOK！）

### A) Full Jitter（おすすめ💡）

* ざっくり：`0〜上限` の間でランダム
* “同時リトライの波”を強く崩せる🎲💥
* 定番として紹介されがちです。([Amazon Web Services, Inc.][3])

### B) Equal Jitter（ほどよく安定🙂）

* 「指数バックオフの半分くらいは確保しつつ、残りをランダム」
* レイテンシが極端に短くなりすぎるのを避けたい時に便利🎛️

### C) Decorrelated Jitter（“前回”も使う🧠）

* 前回の待ち時間を参照して、急増しすぎないように調整
* 実装は少しだけ増えるけど、挙動が滑らかになりやすい✨([Amazon Web Services, Inc.][3])

---

## 16.5 Outboxのスケジューリング設計：`nextRetryAt` 🕒🧾

バックオフを“ちゃんと運用できる形”に落とすと、基本はこれです👇

* 失敗したOutbox行に対して
  **「次はいつ再送していい？」** を **DBに刻む** 🧾🕒
* Publisherは
  **「`nextRetryAt <= 今` の行だけ」** を拾う ✅

### 最小で増やしたいカラム案 📦➕

* `attempts`（試行回数）🔁
* `nextRetryAt`（次回再送OK時刻）🕒
* `lastAttemptAt`（最後に試した時刻）🕒
* `lastError`（最後の失敗理由・短め）🧾
* （章14のロックと組み合わせるなら）`lockedAt` / `lockedBy` 🔒👯‍♀️

### 例：テーブル定義イメージ（雰囲気）🧱

```sql
-- 方言はDBで調整してね（ここはイメージ）
attempts        INT        NOT NULL DEFAULT 0,
next_retry_at   TIMESTAMP  NULL,
last_attempt_at TIMESTAMP  NULL,
last_error      TEXT       NULL
```

💡ポイント：`next_retry_at` は **検索される列**なので、インデックス候補です📌

---

## 16.6 「今送るべき行」だけ拾う方法 👀📤

Publisher側の“考え方”は超シンプル👇

1. `status = pending`（未送信）
2. `nextRetryAt IS NULL OR nextRetryAt <= now`（送っていい時刻になってる）
3. 古い順に少しずつ拾う（LIMIT）
4. 拾った瞬間に `processing` にして確保（章14のロック戦略と合体）🔒

### 典型クエリ（方針）🧠

```sql
SELECT *
FROM outbox
WHERE status = 'pending'
  AND (next_retry_at IS NULL OR next_retry_at <= NOW())
ORDER BY COALESCE(next_retry_at, created_at), created_at
LIMIT 50;
```

#### もしPostgreSQLなら（強い選択肢）💪

`FOR UPDATE SKIP LOCKED` で「他のワーカーが掴んだ行は飛ばす」ができます（並行ワーカーで詰まりにくい）🔒✨([Netdata][4])
（章14の続きで“実運用寄り”に寄せる時に使いやすいです）

---

## 16.7 実装：バックオフ関数（TypeScript）🛠️🎲

ここでは **Full Jitter** を採用します（まずこれでOK！）🎯
ざっくり：

* `attempts` が増えるほど上限を倍々に
* その範囲でランダムに待つ 🎲

### ① まずは「待ち時間(ms)を計算」する関数

```ts
import { randomInt } from "crypto";

type BackoffConfig = {
  baseDelayMs: number; // 例: 1000 (1秒)
  maxDelayMs: number;  // 例: 60_000 (60秒)
};

// attempt は 1,2,3...（「失敗して次を待つ回」）
export function calcFullJitterDelayMs(
  attempt: number,
  cfg: BackoffConfig
): number {
  const exp = cfg.baseDelayMs * Math.pow(2, attempt - 1);
  const cap = Math.min(cfg.maxDelayMs, exp);

  // Full Jitter: 0〜cap のランダム（0が怖ければ下限を少し上げてもOK）
  return randomInt(0, cap + 1);
}
```

> ランダム化された指数バックオフが“再送の波”対策として推奨されます。([sre.google][1])

### ② 次回再送時刻 `nextRetryAt` を作る

```ts
export function calcNextRetryAt(
  now: Date,
  attempt: number,
  cfg: BackoffConfig
): Date {
  const delayMs = calcFullJitterDelayMs(attempt, cfg);
  return new Date(now.getTime() + delayMs);
}
```

---

## 16.8 失敗タイプで“待ち”を変えると一気に賢くなる🧠🚦

バックオフは万能じゃないので、**例外分類**で分岐します🙂

### パターン1：レート制限（429）や過負荷（503）📵⚡

相手が `Retry-After` を返してくることがあります。
このヘッダーは「どれくらい待ってから再試行してね」を示します。([datatracker.ietf.org][5])

✅ 対応方針：

* `Retry-After` があれば **それを優先**（ただし上限は持つ）
* なければ通常のバックオフへ

### パターン2：一時的（ネットワーク、タイムアウト）🌧️

✅ 通常の指数＋ジッターでOK

* 背景処理ではこの方針が推奨されがちです。([Microsoft Learn][2])

### パターン3：恒久的（payload不正など）🧱

✅ **すぐに再送しない**

* `failed` に落として Dead Letter（次章）へ 📮😢
* リトライは“薬”だけど、飲みすぎると毒💊⚠️（無限リトライ禁止）([sre.google][1])

---

## 16.9 “待ち行列”を見える化すると運用がラク👀📊

`nextRetryAt` を入れる最大のご褒美はここです🎁✨

* **今すぐ送れる件数**：`nextRetryAt <= now` の件数
* **待ち中の件数**：`nextRetryAt > now` の件数
* **一番遅れてるやつ**：`MAX(now - createdAt)` みたいな遅延
* **attempts 分布**：リトライ地獄が起きてないか👀

これがあると「再送待ちが積もってる！」が即わかります🧯✨

---

## 16.10 よくある落とし穴集 🕳️😵‍💫

### 落とし穴A：ジッター無しで指数だけ📈

* みんな同じ秒数で再送 → 同時スパイク⚡
* ジッターを入れよう🎲([sre.google][1])

### 落とし穴B：`setTimeout` に未来すぎる時間を入れる🕰️💥

`setTimeout` の delay は最大 `2147483647ms`（約24.85日）で、それ以上は壊れ方があるので注意です。([MDN Web Docs][6])
➡️ だから「未来の再送」は **DBの `nextRetryAt` で管理**して、Publisherが定期的に拾う方が安全です🧾✅

### 落とし穴C：無限リトライ🔁♾️

* 「いつか成功するかも…」は危険
* リトライ回数に上限を持とう（GoogleのSREでも“無限はダメ”寄り）([sre.google][1])

### 落とし穴D：上限（cap）が無い📈➡️🚀

* 2^n が増えすぎて、次回が数日後…みたいになる
* `maxDelayMs` を必ず設定しよう🎛️

---

## 16.11 ミニ演習 🧪🎓

### 演習1：バックオフ関数をテストする✅

* `attempt=1` のとき `0〜base` に入る？
* `attempt` が増えたら上限が増える？
* `maxDelayMs` を超えない？

### 演習2：失敗時にOutbox行を更新する🧾

* `attempts += 1`
* `lastAttemptAt = now`
* `nextRetryAt = calcNextRetryAt(now, attempts, cfg)`
* `lastError = エラー要約`

### 演習3：レート制限っぽい失敗で `Retry-After` 優先📵

* ヘッダーが秒指定なら `now + 秒`
* 日付指定ならその日時
  （`Retry-After` の意味は仕様に整理されています）([datatracker.ietf.org][5])

---

## 16.12 AI活用ミニ型 🤖✨

* **「Full Jitter の境界条件テストを書いて」**🧪

  * attempt=1/2/10、cap超え、乱数の範囲チェック
* **「Retry-After のパース関数を作って」**🕒

  * 秒形式 / HTTP-date 形式の両方（仕様の意味はRFC/MDNで確認できるよ）([datatracker.ietf.org][5])
* **「このOutbox更新ロジック、無限リトライになってない？」**🔁♾️

  * maxAttempts、cap、恒久エラーの分岐が入ってるかレビュー👀

---

## まとめ 🧁✨

* リトライは **指数バックオフ＋ジッター**が基本形🎲📈（再送の波を防ぐ）([sre.google][1])
* Outboxでは `nextRetryAt` を持たせて、Publisherが「今送れるもの」だけ拾う🕒📤
* `Retry-After` が来たら尊重（レート制限・過負荷に優しい）📵💗([datatracker.ietf.org][5])
* タイマー任せで“超未来”を待たない（`setTimeout` の上限もあるよ）⏱️⚠️([MDN Web Docs][6])

[1]: https://sre.google/sre-book/addressing-cascading-failures/?utm_source=chatgpt.com "Cascading Failures: Reducing System Outage"
[2]: https://learn.microsoft.com/en-us/azure/well-architected/design-guides/handle-transient-faults?utm_source=chatgpt.com "Recommendations for handling transient faults"
[3]: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/?utm_source=chatgpt.com "Exponential Backoff And Jitter | AWS Architecture Blog"
[4]: https://www.netdata.cloud/academy/update-skip-locked/?utm_source=chatgpt.com "Using FOR UPDATE SKIP LOCKED for Queue-Based ..."
[5]: https://datatracker.ietf.org/doc/html/rfc9110?utm_source=chatgpt.com "RFC 9110 - HTTP Semantics"
[6]: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout?utm_source=chatgpt.com "Window: setTimeout() method - Web APIs | MDN"
