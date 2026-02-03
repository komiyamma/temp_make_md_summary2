# 第14章：並行実行とロック（複数ワーカー問題）👯‍♀️🔒

## この章のゴール🎯

* Publisher（送信係）を **2つ以上** 動かしても、同じOutboxを **二重に送らない** ようにする✨
* 「ロックって何？😵‍💫」を、**“先に確保してから処理する”** の感覚でつかむ🧲
* 落ちても詰まっても復帰できる **やさしい実運用寄り** の形にする🪜

---

## 14-1. まず“事故”の絵を見よう😱🌀

Publisherが1つなら平和☀️
でも、処理を速くしたくて **Publisherを2つ** にすると…

* Publisher A「未送信あるじゃん！拾おう」📦
* Publisher B「未送信あるじゃん！拾おう」📦
* **同じレコード** を2人が拾う → **二重送信**🔁💥

“読むだけ”は同時にできちゃうので、**読む前後に「確保」の手続き**が必要になるよ🧾🔒

---

## 14-2. 基本戦略はこれだけ🧠✨

## 「先に確保（claim）→ その後に処理」🧲➡️📤

ポイントは **順番** だけ！

1. DBから「未送信」を探す🔎
2. **DB上で** 「これは私が担当ね！」って **確保** する（ロック/原子的更新）🔒
3. 確保できた分だけ、外部送信する📤
4. 結果をDBに反映（sent / retry / failed）🧾

この “2)確保” がないと、複数ワーカーでだいたい事故る😵‍💫

---

## 14-3. status遷移を「並行実行に強い形」にする🚦✨

よくある最小の状態（第9章の続き）に、並行実行向けの状態を足すよ💡

* **pending**：未送信（拾ってOK）📦
* **processing**：誰かが処理中（基本拾っちゃダメ）⏳
* **sent**：送信済み✅
* **failed**：失敗で隔離（第19章で本格化）📮😢

ここで重要なのが「processing」の扱い👀
ワーカーが落ちたら、ずっとprocessingのまま…ってなりがち😇

そこで次の“救命道具”を用意する🧯✨

## 追加したいカラム案🧩

* `lockedBy`：誰が確保したか（workerId）🪪
* `lockedUntil`：いつまで確保が有効か（リース/期限）⏰
* `attempt`：試行回数🔁
* `nextRetryAt`：次に再送していい時刻⏳

「期限が切れてたら再確保してOK」みたいにできるよ😊

---

## 14-4. ロック（確保）の作り方は大きく2つ🔒🧠

## A) 行ロック（SELECT … FOR UPDATE SKIP LOCKED）で拾う🐘✨（PostgreSQLで鉄板）

* “今ロックできない行”は **スキップ** して、他の仕事を拾える🚶‍♀️💨
* キューみたいな用途に向いてるよ📦
  PostgreSQLでは `SKIP LOCKED` の説明が公式ドキュメントにあるよ。([PostgreSQL][1])

## B) 原子的UPDATE（UPDATE … WHERE status='pending' … RETURNING）で奪い合いに勝つ⚔️✨

* 「pendingのものをprocessingに変える」のを **1発で** やる💥
* `SKIP LOCKED` がなくても成立しやすい（ただしDB方言はある）🧩

どっちでもOKだけど、**Aはキュー用途で気持ちよくスケール**しやすいよ🐘🚀

---

## 14-5. 実装例：PostgreSQLで“確保してから処理”を作る🐘📤

ここでは「確保（claim）だけ」をちゃんと完成させるよ🔒✨
（送信そのものは第13章の“疑似送信”でもOK📢）

## ① SQL：一定件数を“確保”して返す（SKIP LOCKED）🧲

* `pending` かつ `nextRetryAt <= NOW()` のものを対象にする
* 期限切れの `processing`（`lockedUntil < NOW()`）も救出対象にする🧯
* 取れた行を `processing` に更新して返す

```sql
-- Postgres例：claim batch（確保）
WITH picked AS (
  SELECT id
  FROM outbox
  WHERE
    (
      status = 'pending'
      AND (next_retry_at IS NULL OR next_retry_at <= NOW())
    )
    OR
    (
      status = 'processing'
      AND locked_until IS NOT NULL
      AND locked_until < NOW()
    )
  ORDER BY created_at
  LIMIT $1
  FOR UPDATE SKIP LOCKED
)
UPDATE outbox o
SET
  status = 'processing',
  locked_by = $2,
  locked_until = NOW() + ($3::interval),
  attempt = COALESCE(attempt, 0) + 1,
  updated_at = NOW()
FROM picked
WHERE o.id = picked.id
RETURNING o.*;
```

`SKIP LOCKED` は「すぐロックできない行をスキップする」動きだよ🐘🔒([PostgreSQL][1])

---

## ② TypeScript：claimBatch関数（pgで素朴に）🧑‍💻✨

TypeScriptは 5.9 系が現行ラインとして公式ドキュメントが更新されてるよ（2026-02-02更新）📌([TypeScript][2])
Node.jsのLTS系も分岐が進んでるので、バージョン固定（.nvmrc等）もおすすめだよ🟩([nodejs.org][3])

```ts
import { Pool, PoolClient } from "pg";

type OutboxStatus = "pending" | "processing" | "sent" | "failed";

type OutboxRow = {
  id: string;
  event_type: string;
  payload: unknown;
  status: OutboxStatus;
  created_at: Date;
  updated_at: Date;
  locked_by: string | null;
  locked_until: Date | null;
  attempt: number | null;
  next_retry_at: Date | null;
};

const pool = new Pool({
  // connectionString は環境変数で渡す想定でOK
});

async function claimBatch(params: {
  batchSize: number;
  workerId: string;
  leaseSeconds: number; // 例: 60
}): Promise<OutboxRow[]> {
  const { batchSize, workerId, leaseSeconds } = params;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const sql = `
      WITH picked AS (
        SELECT id
        FROM outbox
        WHERE
          (
            status = 'pending'
            AND (next_retry_at IS NULL OR next_retry_at <= NOW())
          )
          OR
          (
            status = 'processing'
            AND locked_until IS NOT NULL
            AND locked_until < NOW()
          )
        ORDER BY created_at
        LIMIT $1
        FOR UPDATE SKIP LOCKED
      )
      UPDATE outbox o
      SET
        status = 'processing',
        locked_by = $2,
        locked_until = NOW() + ($3::interval),
        attempt = COALESCE(attempt, 0) + 1,
        updated_at = NOW()
      FROM picked
      WHERE o.id = picked.id
      RETURNING o.*;
    `;

    const leaseInterval = `${leaseSeconds} seconds`;

    const res = await client.query<OutboxRow>(sql, [
      batchSize,
      workerId,
      leaseInterval,
    ]);

    await client.query("COMMIT");
    return res.rows;
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}
```

ここまでで **「二重に拾わない」** がかなり強くなるよ💪🔒
（ただし “絶対に二重送信が起きない世界” は幻想なので、冪等性は第17章でガッチリやる🛡️🔁）

---

## ③ processingが詰まるのを防ぐ（リースの考え方）⏰🧯

* `lockedUntil` を超えた `processing` は「迷子」扱い
* 次のワーカーが救出して処理できる
* これで「ワーカー落ちたら永久に止まる😇」が減るよ✨

---

## 14-6. MySQLでもできる？🐬🔒

できるよ！MySQL 8.0 でも `SELECT ... FOR UPDATE` に **NOWAIT / SKIP LOCKED** が使えるって明記されてるよ📚([dev.mysql.com][4])
なので考え方はほぼ同じ👇

* 「拾う」時にロック競合したら **待たずにスキップ**（SKIP LOCKED）
* あるいは **すぐ返す**（NOWAIT）

MySQL公式マニュアルにも説明があるよ🧾([dev.mysql.com][4])

---

## 14-7. SQLiteだとどうする？🪶🧩

SQLiteは学習には最高だけど、並行ワーカーのロック制御はDB特性的に厳しめになりやすいよ😵‍💫
おすすめの割り切りはこれ👇

* **学習中はPublisher 1つ**（二重送信問題が出ない）🙂
* それでも将来に備えて `lockedUntil` の概念は入れておく（移行が楽）🪜✨
* 並行で回したくなったら、PostgreSQL/MySQLに寄せる🐘🐬

---

## 14-8. ありがち罠まとめ（ここで潰すと強い）🕳️🧯✨

## 罠①：処理中に落ちてprocessingのまま😇

✅ 対策：`lockedUntil`（期限）を持って救出できるようにする⏰🧯

## 罠②：ワーカーの時計がズレてる🕰️😵‍💫

✅ 対策：`NOW()` など **DBの時刻** を基準にする（SQL内で計算）🧾✨

## 罠③：一度に拾いすぎて長時間processingのまま📦📦📦

✅ 対策：`batchSize` を小さめに、処理時間に合わせて調整🎛️🙂

## 罠④：処理が遅いイベントに引っ張られて詰まる🐢

✅ 対策：イベント種別で優先度を分ける、別ワーカーに分ける（発展）🚦

---

## 14-9. ミニ演習：2ワーカーで“二重に拾わない”を確認🧪👯‍♀️

## やること🎯

* Publisher A/B を同時に起動
* `claimBatch()` の結果が **重複しない** ことを見る👀✨

## ざっくり手順🪜

1. outboxに pending を10件入れる📦
2. workerId を変えて2プロセスで `claimBatch(5)` を同時実行👯‍♀️
3. 返ってきた `id` が被ってないかチェック✅

（同時実行のテストは、まずは「手動で2ターミナル」でもOKだよ🪟⌨️）

---

## 14-10. AI活用ミニ型（この章向け）🤖✨

## ① レースコンディション検査官👮‍♀️🔍

* 「このSQL、同時実行で二重に拾う可能性ある？」
* 「processingが詰まるケースを想像して、対策案も出して」

## ② status遷移レビュー🚦👀

* 「pending→processing→sent/failed の遷移表を作って、矛盾がないかチェックして」

## ③ テストケース増殖🧪🧠

* 「2ワーカー、3ワーカー、クラッシュ、タイムアウト、再取得…のテスト観点を列挙して」

---

## この章のまとめ📦🔒✨

* 複数Publisherで怖いのは **“同じレコードを2人が拾う”** こと😱
* 解決はシンプルで、**“先に確保してから処理”** 🧲➡️📤
* PostgreSQLの `FOR UPDATE SKIP LOCKED` はキュー用途に相性が良い🐘🔒([PostgreSQL][1])
* 落ちても復帰できるように **`lockedUntil`（リース）** を入れると安心⏰🧯

次の章では、この “processingで拾えた” を前提に、**リトライの設計**に進むよ🔁🧠

[1]: https://www.postgresql.org/docs/current/sql-select.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 18: SELECT"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://dev.mysql.com/doc/refman/8.0/ja/innodb-locking-reads.html?utm_source=chatgpt.com "MySQL 8.0 リファレンスマニュアル :: 15.7.2.4 読取りのロック"
