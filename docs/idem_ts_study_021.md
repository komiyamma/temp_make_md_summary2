# 第21章：非同期の世界は重複配送が普通（キュー入門）😇📨📨

## 21.1 この章のゴール🎯✨

この章を読み終わったら、こんなことができるようになります💪🌸

* 「キュー／イベントって、なんで重複するの？」を自分の言葉で説明できる🙂
* **At-least-once（少なくとも1回配送）**の前提で、壊れない処理の条件がわかる🔁🧠
* “重複しても平気”な **Idempotent Consumer（冪等な受信側）**の作り方の型を持てる🔒📦
* 次章（Outbox）へつながる「どこで副作用を出す？」の感覚がつかめる📮➡️

---

## 21.2 まずは超ざっくり：キューって何？📮🐣

キュー（Queue）やイベント駆動（Event-driven）は、ざっくり言うとこうです👇

* 👩‍🍳 **送る人（Producer）**：イベントを投げる（例：`OrderPaid` を投げる）
* 📮 **運び屋（Broker / Queue）**：受け取って並べて、配る
* 👩‍💻 **受け取る人（Consumer）**：イベントを処理する（例：請求書発行、在庫引当、メール送信）

ここで大事なのが…
**「運び屋は“確実に届けたい”から、同じものをもう一回届けることがある」**ってこと！😇📨📨

---

## 21.3 “少なくとも1回配送（At-least-once）”って？🔁📦

多くのメッセージングは **At-least-once** が基本です。
意味はシンプルで、

> ✅ メッセージは「最低1回は届く」
> ⚠️ でも「複数回届くこともある」

たとえば Amazon SQS の **Standard Queue** は、まさにこれで、状況によって同じメッセージを再度受け取ることがあるので **アプリ側を冪等に作ってね** と明言しています。 ([AWS ドキュメント][1])

---

## 21.4 なんで重複するの？ありがちな3パターン😵‍💫📨

### パターンA：処理は成功したのに、ACK（完了通知）が届かなかった📡💥

多くのブローカーは「処理できたよ！」という合図（ACK）が来て初めて、メッセージを削除（完了扱い）します。RabbitMQ でも、ACK は「処理できたのでこの配達は消してOK」の合図です。 ([rabbitmq.com][2])

でも、こんな事故が起きると…

* Consumer が処理後にクラッシュ💀
* ネットワークが不安定で ACK が落ちた📡
* ブローカー側が ACK を失った😇

結果：**「ACK来てないから、もう一回送るね📨」** が起きます。

この流れは Idempotent Consumer の説明として超定番で、「DB更新は成功したのにACKできない」→再配送、がまさに重複の原因です。 ([microservices.io][3])

---

### パターンB：可視性タイムアウト（Visibility Timeout）切れ⏳👀

SQS みたいに「受け取ったら一旦見えなくする」仕組みがあります。
でも、**時間内に削除できない**と、メッセージがまた見えるようになって再取得されます😇

SQS の可視性タイムアウトは「配達された瞬間からカウント開始→時間内に削除できないと再び見える」が基本です。 ([AWS ドキュメント][4])
しかも、可視性タイムアウトがあっても **At-least-once なので重複ゼロは保証できない**とも書かれています。 ([AWS ドキュメント][4])

---

### パターンC：「重複しないつもり」でも、世界はそんなに優しくない🌧️

* 再試行（Retry）で同じ送信がもう一回走る🔄
* ブローカーが冗長化されていて、片方だけ削除が間に合わなかった🧯
* 処理が遅い / 一時的に混雑している🚗💨

SQS Standard は、まさに「冗長化の都合で削除できなかったコピーが残ることがある → もう一回受け取ることがある」と説明しています。 ([AWS ドキュメント][1])

---

## 21.5 じゃあ“重複しないキュー”はあるの？（結論：あっても油断NG）🧊🔥

ある程度 “重複しにくくする” 機能はあります！

たとえば SQS FIFO は「Standard と違って重複を入れない」方向で、**5分の重複排除ウィンドウ**などが用意されています。 ([AWS ドキュメント][5])

でもここで大事なのは👇
**“ブローカー側の重複排除”は保険にはなるけど、最終的に守るのはConsumer側（受信側）**ってことです💪

なぜなら…

* ブローカーの保証範囲が限定されることがある
* 外部APIやDB更新、メール送信など「外の世界」には別の失敗モードがある

---

## 21.6 配送保証の3兄弟（At-most / At-least / Exactly-once）👪📦

よく出る3種類です👇

* **At-most-once**：重複しないけど、落ちることがある（届かないことがある）🫠
* **At-least-once**：落とさないけど、重複することがある（多くの現場はこれ）😇
* **Exactly-once**：1回だけ処理したい（理想）✨

ただし Exactly-once は **“どこまでを1回とするか”** が難しい…！

Kafka は「イベントを exactly-once で処理できる」系の保証に触れています。 ([kafka.apache.org][6])
さらに Kafka のトランザクションは「consume-transform-produce を原子的に扱って重複を防ぐ」方向で Exactly-once を支えます。 ([Confluent][7])

でも注意：それでも「外部DB/外部API/メール送信」みたいな “Kafkaの外” を含めると難易度が上がりがちです🔥（だから **Consumer冪等** が超大事！）

---

## 21.7 重複配送でも壊れない処理の条件✅🔁

ここがこの章の核心です💖

### 条件1：メッセージに “一意なID” がある🆔✨

* `messageId`（GUID/UUID など）
* もしくはビジネス的に一意なID（例：`paymentId`, `orderId`）

> ポイント：同じ出来事なら同じIDで来るようにする🔁

---

### 条件2：Consumerが「すでに処理済み」を判定できる👀✅

たとえば、処理済みIDを保存しておく👇

* `PROCESSED_MESSAGES` テーブルに `messageId` を保存🗃️
* もしくは「注文テーブルのこの列が埋まってたら処理済み」みたいに本体に刻む🧾

これは Idempotent Consumer パターンのど真ん中で、「重複は起きる前提で、処理済みを記録して捨てよう」が本質です。 ([microservices.io][3])

---

### 条件3：“記録”と“副作用”の順番をミスらない🧠🧯

ありがちな事故👇

* ✅ 副作用（例：メール送信）を実行
* 💥 その直後にクラッシュして「処理済み記録」が残らない
* 🔁 再配送 → もう一回メール送信（地獄）📨📨📨

理想はこう👇

* **処理済み記録を、DB更新と同じトランザクションで残す**
* そして **重複なら即スキップ**
  （この考え方自体が Idempotent Consumer の基本ループで説明されています） ([microservices.io][3])

---

## 21.8 TypeScriptで“冪等なConsumer”のミニ実装🧩🧑‍💻

ここでは学習用に、まずは **インメモリ版**で型をつかみます😊
（実務ではこの “保存先” をDB/Redisに置き換えるイメージだよ🗄️⚡）

### ① メッセージ型を決めよう📦

```ts
type Message<T> = {
  messageId: string;      // 重複判定のカギ🗝️
  type: string;           // イベント種別
  occurredAt: string;     // いつ起きた？
  payload: T;             // 本文
};

type OrderPaidPayload = {
  orderId: string;
  paymentId: string;      // “ビジネス的に一意”なIDがあると強い💪
  amount: number;
};
```

---

### ② “処理済みストア”を作る（TTLつき）⏳🧺

```ts
class ProcessedStore {
  // messageId -> expiresAt(ms)
  private processed = new Map<string, number>();

  constructor(private readonly ttlMs: number) {}

  has(messageId: string): boolean {
    this.gc();
    const expiresAt = this.processed.get(messageId);
    return expiresAt !== undefined && expiresAt > Date.now();
  }

  mark(messageId: string): void {
    this.gc();
    this.processed.set(messageId, Date.now() + this.ttlMs);
  }

  private gc(): void {
    const now = Date.now();
    for (const [id, exp] of this.processed) {
      if (exp <= now) this.processed.delete(id);
    }
  }
}
```

---

### ③ Consumer本体：重複なら即return🔁🚫

```ts
async function handleOrderPaid(
  msg: Message<OrderPaidPayload>,
  store: ProcessedStore
): Promise<void> {
  // 1) 重複チェック👀
  if (store.has(msg.messageId)) {
    // すでに処理済み → 何もしない（冪等）🙂✨
    return;
  }

  // 2) ここからが本処理（副作用ゾーン）⚠️
  // 例：請求書発行 / 在庫引当 / メール送信…など
  await issueInvoice(msg.payload.orderId, msg.payload.amount);

  // 3) 最後に処理済みを記録✅
  store.mark(msg.messageId);
}

async function issueInvoice(orderId: string, amount: number): Promise<void> {
  // 本当はDB更新とか外部APIとかが入るイメージ🧾
  // 学習用なのでダミー！
}
```

> ⚠️ 注意：このインメモリ版は、プロセスが落ちたら忘れます😇
> だから実務では **DB/Redis** へ！（これは第14章の「保存先」とつながるよ🧰✨）

---

## 21.9 もう一歩だけ実務っぽく：DBで“1回だけ通す”考え方🗄️🔒

実務の定番はこれ👇
**「処理済みIDをINSERTして、入った人だけが処理していい」方式**✨

イメージ（疑似SQL）👇

```sql
BEGIN;

-- すでに処理済みなら入らない（= 重複）
INSERT INTO processed_messages(message_id, processed_at)
VALUES (:messageId, NOW())
ON CONFLICT (message_id) DO NOTHING;

-- ここで「INSERTできたか」を見て、
-- できてなければ重複なので即COMMITして終了

-- できた人だけ、副作用を実行
UPDATE invoices SET ...;
UPDATE orders   SET ...;

COMMIT;
```

この “処理 → ACK” の間で事故が起きると重複が生まれる、という説明は Idempotent Consumer の定番の流れそのものです。 ([microservices.io][3])

---

## 21.10 ミニ演習📝💞（重複配送でも壊れない条件を書いてみよう！）

### 演習1：次の処理、重複したら何が起きる？😱

ミニ注文アプリを想像して、重複すると困るものに「⚠️」つけてね👇

* 請求書を作る🧾
* 在庫を減らす📦
* サンクスメールを送る📩
* 注文一覧を表示する📋
* 売上集計に加算する📈

---

### 演習2：“壊れない条件”を3つ書く✍️✨

ヒント：この章の条件1〜3だよ🆔👀🔒
（例：「イベントに一意IDがある」「処理済みを保存する」「副作用と順番を守る」）

---

## 21.11 AI活用コーナー🤖🧠✨（危険ポイント洗い出し）

次のプロンプトをそのまま貼ってOKだよ💬

* 「`OrderPaid` イベントをConsumerが処理します。**重複配送が起きる前提**で、事故ポイントを10個リストアップして。優先度もつけて。」
* 「重複配送でも安全な設計にするために、`processed_messages` のテーブル案（カラム、ユニーク制約、TTL運用）を提案して。」
* 「“副作用（メール送信）”を伴う処理を冪等にするパターンを3つ出して。メリデメも。」

---

## 21.12 まとめ✅🌸（この章で覚える1行）

**非同期（キュー/イベント）は重複配送が普通。だから受信側は「処理済み判定＋安全な副作用順序」で冪等に作る🔁🛡️**

* SQS Standard は重複が起きうる前提で「冪等に作ってね」と明言してるよ📨 ([AWS ドキュメント][1])
* 可視性タイムアウトがあっても重複ゼロは保証できないよ⏳ ([AWS ドキュメント][4])
* RabbitMQ もACKで「処理済み」を確定するから、ACKが落ちると再配達が起きうるよ🔔 ([rabbitmq.com][2])
* だから Idempotent Consumer（処理済み記録して重複を捨てる）が王道だよ💪✨ ([microservices.io][3])

[1]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html "Amazon SQS at-least-once delivery - Amazon Simple Queue Service"
[2]: https://www.rabbitmq.com/docs/confirms "Consumer Acknowledgements and Publisher Confirms | RabbitMQ"
[3]: https://microservices.io/post/microservices/patterns/2020/10/16/idempotent-consumer.html "Handling duplicate messages using the Idempotent consumer pattern"
[4]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html "Amazon SQS visibility timeout - Amazon Simple Queue Service"
[5]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html "Exactly-once processing in Amazon SQS - Amazon Simple Queue Service"
[6]: https://kafka.apache.org/intro "Introduction | Apache Kafka"
[7]: https://developer.confluent.io/courses/architecture/transactions/ "Kafka Transactional Support: How It Enables Exactly-Once Semantics"

