# 第16章：止め方① ユニーク制約で“二重登録を物理的に禁止”🗄️🛡️

## この章のゴール🎯

* 「同時に2回きても、**二重登録だけは絶対に起きない**」をDBで保証できる💪✨
* **(userId, idempotencyKey)** みたいな組み合わせを「ユニーク」にする意味がわかる🔑
* ユニーク違反が起きたときに、APIとして **どう返すか（200/201/409）** を決められる📨

---

## 0. まず結論：アプリで「先にSELECTして確認」は負けやすい😵‍💫

よくある発想👇

1. `SELECT` で「まだ無いよね？」を確認
2. `INSERT` で作成

これ、**同時に2人（or 2リクエスト）が来た瞬間に破綻**しやすいです⚡
「確認した直後」に、もう片方が先に入れちゃうからです🏁💥

PostgreSQLのドキュメントでも、（直前に存在チェックしていても）並行トランザクションの衝突でユニーク制約違反が起きうる、という趣旨が書かれています。([PostgreSQL][1])

だから発想を逆にします👇
✅ **“とりあえずINSERTして、ダメなら（ユニーク違反なら）既存を返す”**
これが「同時実行に強い」王道です👑✨

---

## 1. ユニーク制約ってなに？🧷

ユニーク制約（UNIQUE）は、DBにこう言わせる仕組みです👇

> 「同じキーの組み合わせは、2回入れちゃダメ🙅‍♀️」

PostgreSQLはユニーク制約を「ユニークインデックス」で実現して、同じキーが複数入るのを許しません。([PostgreSQL][2])

つまりユニーク制約は、**最終防衛ライン🛡️**
アプリがどれだけ混んでても、最後はDBが止めてくれます💖

---

## 2. どこをユニークにする？（スコープ設計）👤🔑

この教材の「冪等キー方式」では、基本はこれ👇

✅ **(userId, idempotencyKey) をユニーク**

### なぜ “userId も一緒” なの？🤔

* `idempotencyKey` は UUID でも、理論上「他人と被らない」とは言い切れない😇
* それより大事なのは、**スコープが明確**になること✨

  * 「このユーザーのこのキーは1回だけ」って言い切れる👍

---

## 3. “二重登録を止める” 典型2パターン🍰

### パターンA：注文テーブルに冪等キーを持たせる🧾

* `orders` に `user_id`, `idempotency_key` を持たせてユニークにする
* 二重作成が物理的に起きない✅
* ただし「同じキー → 同じレスポンス」をやるなら、レスポンス再現の工夫が必要（次章以降で強化）🔁

### パターンB：冪等キー専用テーブルを作る🗃️（おすすめ寄り✨）

* `idempotency_requests` みたいなテーブルを作る
* `status` / `response_body` / `request_hash` を保存できる
* 「同じキー → 同じ結果」を作りやすい📦

この章では **B** を題材にしていきます😊🌸

---

## 4. テーブル設計（例）🧱✨

```sql
CREATE TABLE idempotency_requests (
  user_id            TEXT NOT NULL,
  idempotency_key    TEXT NOT NULL,
  request_hash       TEXT NOT NULL,      -- ボディが同じか判定用（例: sha256）
  status             TEXT NOT NULL,      -- "processing" | "succeeded" | "failed" など
  response_status    INTEGER,
  response_body      TEXT,
  created_at         TIMESTAMP NOT NULL,
  updated_at         TIMESTAMP NOT NULL,

  CONSTRAINT uq_idem UNIQUE (user_id, idempotency_key)
);
```

ポイント💡

* **uq_idem**（ユニーク制約）が“二重登録禁止スイッチ”🛡️
* **request_hash** を持っておくと「同じキーなのに中身違う😱」を検出できる（409向き）✨

---

## 5. 実装の型（超重要）🧠🔁

流れはこれだけ覚えればOK👌

### ✅ 型：INSERTして、ダメなら既存を読む

1. `INSERT` を試す（成功したら「初回」🎉）
2. ユニーク違反なら「既存をSELECT」して返す（2回目以降）🔁

---

## 6. PostgreSQL例：ON CONFLICT を使う🐘✨

PostgreSQLは `INSERT ... ON CONFLICT` が使えます💪
`ON CONFLICT` は「ユニーク違反が起きたときの代替動作」を指定できて、`DO NOTHING`（何もしない）や `DO UPDATE`（更新する）があります。([PostgreSQL][3])

### 6-1. まずは “枠だけ確保” するSQL（初回だけINSERT）

```sql
INSERT INTO idempotency_requests (
  user_id, idempotency_key, request_hash, status, created_at, updated_at
)
VALUES ($1, $2, $3, 'processing', NOW(), NOW())
ON CONFLICT (user_id, idempotency_key) DO NOTHING;
```

* 成功 → 初回なので処理してOK🎉
* 競合 → すでに同じキーが存在（誰かが先に確保済み）🔁

`DO NOTHING` は衝突時に挿入を避ける動作です。([PostgreSQL][3])

### 6-2. TypeScript（考え方が伝わる最小例）🧑‍💻💗

※DBアクセス部分は雰囲気でOK（要は手順！）

```ts
type IdemRow = {
  userId: string;
  key: string;
  requestHash: string;
  status: "processing" | "succeeded" | "failed";
  responseStatus: number | null;
  responseBody: string | null;
};

async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, "0")).join("");
}

async function handleCreateOrder(userId: string, idempotencyKey: string, bodyJson: unknown) {
  const bodyText = JSON.stringify(bodyJson);
  const requestHash = await sha256Hex(bodyText);

  // ① まず「枠」をINSERT（ユニーク制約が同時実行を止める）
  const inserted = await db.execute(/*sql*/`
    INSERT INTO idempotency_requests(user_id, idempotency_key, request_hash, status, created_at, updated_at)
    VALUES (?, ?, ?, 'processing', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT(user_id, idempotency_key) DO NOTHING
  `, [userId, idempotencyKey, requestHash]);

  // inserted が「入ったかどうか」を返せる想定（ドライバにより差はあるよ）
  if (!inserted.didInsert) {
    // ② すでに存在 → 既存レコードを読む
    const row = await db.queryOne<IdemRow>(/*sql*/`
      SELECT user_id as userId, idempotency_key as key, request_hash as requestHash,
             status, response_status as responseStatus, response_body as responseBody
      FROM idempotency_requests
      WHERE user_id = ? AND idempotency_key = ?
    `, [userId, idempotencyKey]);

    // ③ 同じキーなのに中身違う → 409（競合）
    if (row.requestHash !== requestHash) {
      return { status: 409, body: { message: "Idempotency-Key is reused with different payload." } };
    }

    // ④ すでに完了してたら、その結果を返す（冪等！）
    if (row.status === "succeeded" && row.responseStatus && row.responseBody) {
      return { status: row.responseStatus, body: JSON.parse(row.responseBody) };
    }

    // ⑤ まだ処理中っぽいなら 202（処理中）も選べる（20章で強化）
    return { status: 202, body: { message: "Still processing." } };
  }

  // ⑥ 初回：このあと本処理（注文作成など）して、結果を保存
  const result = await doCreateOrder(bodyJson); // 例：注文作成（副作用）
  await db.execute(/*sql*/`
    UPDATE idempotency_requests
    SET status = 'succeeded', response_status = ?, response_body = ?, updated_at = CURRENT_TIMESTAMP
    WHERE user_id = ? AND idempotency_key = ?
  `, [201, JSON.stringify(result), userId, idempotencyKey]);

  return { status: 201, body: result };
}
```

ここが大事💗

* **二重作成を止めてるのはユニーク制約**（アプリのifじゃない！）🛡️
* 2回目以降は「前回の結果を返す」→ 冪等っぽい✨

---

## 7. MySQL例：ON DUPLICATE KEY UPDATE を使う🐬✨

MySQLは `INSERT ... ON DUPLICATE KEY UPDATE` が使えます✅
この構文では、影響行数（affected-rows）が「新規1 / 更新2 / 同値更新0」になり得ます（接続フラグ等で変動もあり）。([dev.mysql.com][4])

### “何もしないUPDATE” で衝突を吸収する例

```sql
INSERT INTO idempotency_requests(user_id, idempotency_key, request_hash, status, created_at, updated_at)
VALUES (?, ?, ?, 'processing', NOW(), NOW())
ON DUPLICATE KEY UPDATE
  updated_at = updated_at; -- ノーオペ（実質なにもしない）
```

* INSERTできた → 初回🎉
* DUPLICATEになった → 既存があるので次にSELECTして判断🔁

---

## 8. SQLite例：OR IGNORE を使う🪶✨

SQLiteならとてもシンプル👇

```sql
INSERT OR IGNORE INTO idempotency_requests(user_id, idempotency_key, request_hash, status, created_at, updated_at)
VALUES (?, ?, ?, 'processing', datetime('now'), datetime('now'));
```

* 入ったら初回🎉
* 無視されたら既存がある → SELECTへ🔁

（小ネタ）`OR IGNORE` はオートインクリメントIDに“欠番”が出ることがあります。気にしない設計にするのが楽です😇([Michael J. Swart | Database Whisperer][5])

---

## 9. ユニーク違反のとき、APIは何を返す？📨✨

### 9-1. 「同じキー＆同じ内容」なら…

✅ **前回と同じ成功レスポンスを返す**（いちばん親切）💖

### 9-2. 「同じキーなのに内容が違う」なら…

✅ **409 Conflict** がわかりやすいです🧯
409は「リソースの現在状態と競合して完了できない」系の意味として定義されています。([rfc-editor.org][6])

返す例👇

* `status: 409`
* body: `"Idempotency-Key is reused with different payload."`

---

## 10. よくある落とし穴チェック⚠️

* **ユニーク制約を貼ったのに、アプリが先に副作用してる**（例：外部決済→その後DB保存）
  → 二重課金の可能性が残る😱（外部API側の冪等も必要になりやすい）
* **スコープが雑**（`idempotencyKey` だけをユニークにしてる）
  → 別ユーザーの操作と衝突しうる🙃
* **同じキーの再利用を許してる**
  → 「前の結果が返ってきて混乱」か「409地獄」になりがち🌀

---

## 11. ミニ演習📝🌸

### 演習1：ユニーク制約を“言葉で”説明しよう🗣️

* 「アプリのifチェックと何が違う？」を2行で✍️
* ヒント：同時実行🏁／最終防衛🛡️

### 演習2：冪等テーブルの設計を埋めよう🧩

* `request_hash` をなぜ持つ？
* `status` は何種類いる？（processing/succeeded/failed など）
* `response_body` はどこまで入れる？（全部？一部？）📦

### 演習3：409を返す条件を決めよう🔥

* 「同じキー・別内容」の判定条件を箇条書きで✅
* 409の意味も一言で（“競合”）🧯([MDNウェブドキュメント][7])

---

## 12. AI活用プロンプト例🤖✨（コピペOK）

### 12-1. マイグレーション（SQL）を作ってもらう🧱

```text
idempotency_requests テーブルを作りたいです。
カラム: user_id, idempotency_key, request_hash, status, response_status, response_body, created_at, updated_at
(user_id, idempotency_key) にユニーク制約を付けて。
DBは PostgreSQL / MySQL / SQLite の3種類それぞれでSQLを出して。
```

### 12-2. 「同じキーで別内容」を検出する設計レビュー🔍

```text
Idempotency-Key 再利用時に、同じ内容なら前回結果を返し、別内容なら 409 を返す設計にしたい。
request_hash を保存して比較する案の落とし穴と改善案を出して。
```

### 12-3. 競合テスト案を作ってもらう🧪

```text
POST /orders で Idempotency-Key を使うAPIのテストケースを作って。
観点: 同じキー2回、同じキー10回、並列20回、同じキーで別payload(409)
Jest想定で、テスト名と手順を箇条書きで。
```

---

## まとめ🎀

* 同時実行の世界では **「先に確認してからINSERT」** は事故りやすい😵‍💫
* **ユニーク制約**で「二重登録は物理的に無理」にするのが最強🛡️
* 実装は **INSERT → ダメなら既存を返す** が王道👑
* 「同じキーで別内容」は **409 Conflict** が気持ちいい🧯([rfc-editor.org][6])

[1]: https://www.postgresql.org/docs/current/transaction-iso.html?utm_source=chatgpt.com "Documentation: 18: 13.2. Transaction Isolation"
[2]: https://www.postgresql.org/docs/current/index-unique-checks.html?utm_source=chatgpt.com "Documentation: 18: 63.5. Index Uniqueness Checks"
[3]: https://www.postgresql.org/docs/current/sql-insert.html?utm_source=chatgpt.com "Documentation: 18: INSERT"
[4]: https://dev.mysql.com/doc/refman/8.3/en/insert-on-duplicate.html?utm_source=chatgpt.com "15.2.7.2 INSERT ... ON DUPLICATE KEY UPDATE Statement"
[5]: https://michaeljswart.com/2011/09/mythbusting-concurrent-updateinsert-solutions/?utm_source=chatgpt.com "Mythbusting: Concurrent Update/Insert Solutions"
[6]: https://www.rfc-editor.org/rfc/rfc9110.html?utm_source=chatgpt.com "RFC 9110: HTTP Semantics"
[7]: https://developer.mozilla.org/ja/docs/Web/HTTP/Reference/Status/409?utm_source=chatgpt.com "409 Conflict - HTTP - MDN Web Docs - Mozilla"

