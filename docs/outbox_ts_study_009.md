# 第9章：Outboxテーブル設計（まずは最小カラム）📦🧾✨

## 9.1 Outboxテーブルって、なに置くの？🤔📮

Outboxテーブルは「**あとで送るメッセージ（イベント）を、DBにいったん安全に保管する場所**」です📦
業務データの更新と同じDBに“送る予定”を残しておくことで、**DBは更新できたのに送信だけ失敗**みたいな事故を避けやすくなります😵‍💫💥 ([microservices.io][1])

イメージはこんな感じ👇

* 業務テーブル：注文・ユーザーなど「本体」🧾
* Outboxテーブル：「送る封筒」✉️（イベントを入れておく）
* 送信係（Publisher/Relay）：封筒を拾って外へ届ける📤

---

## 9.2 まずは“最小カラム”でOK！🧠✨（最初の5つ）

<!-- img: outbox_ts_study_009_table_schema.png -->
学習用は、まずこの5つでいけます👍✨

1. **id（イベントID）** 🆔

* 1行＝1イベントの「識別子」
* 型の例：UUID / 連番（bigint）
* **主キー**にするのが基本だよ✅

2. **eventType（種類）** 🏷️

* 例：OrderPlaced / UserRegistered みたいに「何が起きた？」を表す
* 送信先やハンドラの分岐に使えるよ🧭

3. **payload（中身JSON）** 📄

* 「届けたい情報」本体（注文ID、金額、発生時刻など）
* DBの型：JSON（使えるなら） / TEXT（まずはこれでもOK）📦

4. **status（状態）** 🚦

* 例：pending（未送信）/ sent（送信済み）/ failed（失敗）
* 最小は pending と sent だけでも学べる👌

5. **createdAt（作成時刻）** 🕒

* “いつ入った封筒？”が分かる
* 送信遅延の監視にも使える👀📊

---

## 9.3 statusは“未来のあなた”を助ける設計🛟✨

statusは「送信係が安全に動く」ための超重要パーツです🚦

### ✅ まずはこの3つが分かりやすい

* **pending**：まだ送ってない📭
* **processing**：いま誰かが処理中🧲（後で並行処理で効いてくる！）
* **sent**：送信できた✅
* （発展）**failed**：失敗した😢 → リトライや隔離へ

### 👯‍♀️ “送信係が複数”でも二重送信しにくくする考え方

複数ワーカーでOutboxを拾うとき、DBロックで「同じ行を同時に取らない」ようにする方法がよく使われます🔒
代表が **SELECT … FOR UPDATE SKIP LOCKED**（ロックできない行は飛ばす）です🏃‍♀️💨
これは「キューっぽいテーブル」を複数の消費者で処理するときの競合回避に使える、と説明されています📌 ([PostgreSQL][2])

---

## 9.4 “送信係が欲しがる列”を先に想像しよう🧠🔮

Outboxテーブルは、送信係がだいたいこういう条件で取りに来ます👇

* status が pending のもの
* createdAt が古い順（先入れ先出しっぽく）
* （発展）次に再試行する時刻が来てるもの（nextRetryAt <= now）

つまり、**status** と **createdAt** は最小でも必要になりやすいです👍✨

---

## 9.5 最小→実戦の“成長カラム”🪜✨（後から足せる）

最初から全部盛りにしない！でも将来こう足せる！が大事🙂🌱

### レベル0（学習最小）🌱

* id, eventType, payload, status, createdAt

### レベル1（リトライ対応）🔁

* **attempts（試行回数）** 🔢
* **lastError（最後のエラー）** 🧾
* **nextRetryAt（次回再送時刻）** ⏳

### レベル2（並行処理をガッチリ）👯‍♀️🔒

* **lockedAt（確保時刻）** 🧲
* **lockOwner（誰が取ったか）** 👤（ワーカー名など）

### レベル3（運用で泣かない）🥹🫶

* **correlationId（関連ID）** 🧵（ログ追跡が楽！）
* **traceId（分散トレーシング）** 🛰️
* **schemaVersion（イベントの版）** 🧬

---

## 9.6 CDC（Debeziumなど）に寄せるなら“定番列”もあるよ📡🐘

DBの変更を拾って配信する仕組み（CDC）を使う流派だと、Outboxに **aggregateid / aggregatetype / payload** みたいな列を置く例がよく出てきます📦
DebeziumのOutbox Event Routerの前提でも、このあたりの列が説明されています📝 ([Debezium][3])

（今ここで必須じゃないけど、「あとでCDC方式にしたい！」ってなった時に役立つ豆知識だよ😊）

---

## 9.7 例：SQL（PostgreSQL想定の学習版）🗄️✨

※書き方はDBで少し変わるけど、考え方は同じだよ🧠

```sql
CREATE TABLE outbox_events (
  id         UUID PRIMARY KEY,
  event_type TEXT NOT NULL,
  payload    JSONB NOT NULL,
  status     TEXT NOT NULL,          -- pending / processing / sent / failed
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 送信係が「未送信を古い順に取る」想定のインデックス
CREATE INDEX idx_outbox_status_created
  ON outbox_events (status, created_at);
```

💡ポイント

* status が pending の行を素早く見つけたい → (status, created_at) インデックスが効く⚡
* payload は JSONB にしておくと「後からちょっと検索」もしやすい🔎

---

## 9.8 TypeScript側の型も“雑に始めてOK”👍📘

「payloadはJSONだよね？」を、まずは素直に表すとこう👇

```ts
export type OutboxStatus = "pending" | "processing" | "sent" | "failed";

export type OutboxEvent = {
  id: string;            // UUID文字列
  eventType: string;     // 例: "OrderPlaced"
  payload: unknown;      // まずはunknownでOK（第10章で育てる🌱）
  status: OutboxStatus;
  createdAt: string;     // ISO文字列
};
```

ここで無理にpayloadを厳密型にしなくてOK🙆‍♀️
第10章で「壊れにくいJSON」に育てていくよ🧩✨

---

## 9.9 ミニ演習：あなたなら“封筒”に何を書く？✉️📝✨

題材：**注文確定（OrderPlaced）** 🛒✅

✅ Outbox 1行に入れるものを埋めてみよう👇

* id：どんな形式？（UUID？連番？）🆔
* eventType：OrderPlaced でOK？ もっと細かくする？🏷️
* payload：最低限なにが要る？

  * orderId は要る？✅
  * userId は要る？✅
  * totalAmount は要る？✅
  * occurredAt（発生時刻）は要る？🕒
* status：最初は pending だよね📭

「受け取る側が困らない」を想像できたら勝ち🎉✨

---

## 9.10 AI活用ミニ型（第9章：テーブル設計編）🤖✨🧠

そのまま貼って使える“お願いテンプレ”だよ🪄

* **SQLたたき台を作る** 🗄️
  「Outboxテーブルを最小5カラムで作るSQLをPostgreSQL用に。status+createdAtにインデックスも。」

* **将来カラムの追加案を出す** 🪜
  「リトライ（attempts/nextRetryAt/lastError）と並行処理（lockedAt/lockOwner）を追加するなら、どんな設計が安全？」

* **インデックスの相談** ⚡
  「送信係が status=pending を古い順に拾う。件数が増えても詰まりにくいインデックス案を理由つきで。」

* **命名レビュー** 🏷️
  「eventTypeの命名ルール案を3つ。例もつけて。」

---

[1]: https://microservices.io/patterns/data/transactional-outbox.html?utm_source=chatgpt.com "Pattern: Transactional outbox"
[2]: https://www.postgresql.org/docs/current/sql-select.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 18: SELECT"
[3]: https://debezium.io/documentation/reference/stable/transformations/outbox-event-router.html?utm_source=chatgpt.com "Outbox Event Router"
