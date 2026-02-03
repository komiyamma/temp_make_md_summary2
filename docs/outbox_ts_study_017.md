# 第17章：冪等性（同じのが2回来ても壊れない）🛡️🔁

## この章のゴール🎯✨

* Outbox を使っていても「二重送信が起こり得る」理由をちゃんと理解する😇📨
* **冪等（べきとう）**＝「同じものが2回来ても結果が1回分になる」状態を作れるようになる🛡️
* **冪等キー（idempotency key）**の作り方・持たせ方・使い方がわかる🔑
* TypeScript で「重複を安全に捨てる」超定番の実装が書けるようになる🧑‍💻✨

---

## 1) Outboxでも二重送信は“起こり得る”😇📮

Outbox は「送る予定をDBに残す」ので **送信漏れ**を減らせるけど、送信処理は現実世界（ネットワーク、外部API、メッセージ基盤）と戦うから、どうしても **“少なくとも1回” 配信（＝時々重複する）**が起きがちなんだよね📨🌩️
たとえば AWS の標準キューは “at-least-once” で、**同じメッセージが複数回届く可能性がある**って説明されてるよ📦🔁。([AWS ドキュメント][1])

**二重が起きる典型パターン**👇😵‍💫

* 送信自体は成功してたのに、成功レスポンスを受け取る前にタイムアウト→再送🔁⏱️
* ワーカーが処理中に落ちた（送ったか不明）→復旧後に再処理🔁💥
* 並行実行で「同じOutbox行」を別ワーカーが掴んだ（ロックが甘い）👯‍♀️🔒
* メッセージ基盤が「たまに重複配送」する設計（=普通にある）📮📮

なのでこの章の結論はこれ👇
**Outboxの世界は “at-least-once を前提に、冪等性で安全にする” が基本形**🛡️🔁

---

## 2) 冪等性ってなに？🧠✨（超ざっくり）

**冪等**＝「同じ操作を何回やっても、結果が1回分と同じ」って性質だよ🙆‍♀️✨

例で覚えるのが一番👇🍀

* ✅ 冪等：`支払い完了フラグ = true` をセット（何回trueにしてもtrue）
* ❌ 非冪等：`ポイント += 100`（2回来たら200増える）
* ❌ 非冪等：`メール送信`（2回来たら2通送られる）

Outboxのイベント処理って、放っておくと「+=」や「メール送信」みたいな非冪等が混ざりやすいから、**“重複が来ても1回に見せる仕組み”**が必要になるよ🛡️📨

---

## 3) 冪等キー（idempotency key）の考え方🔑✨

冪等キーは「この操作は“同一の操作”だよ」って識別するためのキーだよ🔎🔑

## 3-1) 良い冪等キーの条件✅

* **リトライしても同じ値**（再送のたびに変わると意味ない）🔁❌
* **十分ユニーク**（別の操作と衝突しない）🆔✨
* **“業務的に1回であるべき単位”**を表している🎯

## 3-2) 冪等キーの作り方（定番）🍱

代表的にはこのへん👇

* **イベントID（UUID）**を冪等キーとして使う🆔
* **コマンドID**（例：注文確定ボタン押下1回）を作って、それをイベントに引き継ぐ🛒🆔
* **自然キー**（例：`orderId + "OrderConfirmed"`）みたいに“同一性”が明確ならそれでもOK（ただし注意あり⚠️）

## 3-3) 外部APIの冪等キーは世界標準になりつつある🌍🔑

決済などの外部APIでは「同じPOSTをリトライしても1回分にする」ために **Idempotency-Key** を使う設計がよくあるよ💳✨
たとえば Stripe は「同じ idempotency key なら同じ結果を返す」仕組みを提供してる📨🧾。([docs.stripe.com][2])
HTTP でも **Idempotency-Key ヘッダー**を標準化しようという仕様ドラフトがあるよ🧩📬。([IETF Datatracker][3])

---

## 4) 冪等性はどこで守るのが正解？🛡️🏰

結論：**受け側で守るのが最強**💪✨
（送る側でもできる範囲で守ると、さらに強い）

## 4-1) 送る側（Publisher側）でできること📤🧠

* Outbox 行の `id` をイベントIDとして固定し、**再送でも同じイベントIDを使う**🆔🔁
* 送信先に **Idempotency-Key** を渡せるなら渡す（HTTPでもメッセージでも）📨🔑
* ただし…送る側だけでは「相手が何をしたか」を完全には保証できない🙅‍♀️

## 4-2) 受け側（Consumer側）で守ること📥🛡️

受け側の鉄板はこれ👇
**「Inbox（処理済みテーブル）」で重複排除する**🗃️✨

* 受信したイベントIDを **Inboxテーブルに記録**
* すでに存在したら **“重複なのでスキップ”**
* 初回だけ「業務処理」を進める🎯

これが **Outbox と対になる定番**で、実運用の安心感が段違いになるよ🥹🫶

---

## 5) ハンズオン：Inboxで重複排除を実装しよう🧪🛠️✨

ここからは「最小で強い」実装を作るよ💪
ポイントは **DBの一意制約（unique）**に仕事を任せること🎛️✨

## 5-1) Inboxテーブル（最小構成）🗃️

* `event_id`：処理済みかどうかの判定キー🆔
* `processed_at`：いつ処理したか🕒
* `handler`：どのハンドラが処理したか（デバッグ用）🧭

（DBは例として PostgreSQL で書くよ。`ON CONFLICT` の説明は公式ドキュメントにあるよ📚✨）([PostgreSQL][4])

```sql
-- Inbox（処理済み）テーブル
CREATE TABLE inbox_processed (
  event_id     uuid        PRIMARY KEY,
  handler      text        NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);
```

> ✅ **PRIMARY KEY / UNIQUE が超重要**：重複が来たらDBが弾いてくれるからね🛡️

---

## 5-2) 「最強の1行」：まずInboxに“予約”する🔒✨

**イベントを処理する前に**、まず Inbox に insert するよ👇

* insert が成功＝初回🎉 → 処理してOK
* insert が衝突＝重複😇 → 何もせず終了

PostgreSQLならこれが定番👇（衝突したら何もしない）
`ON CONFLICT DO NOTHING` ([PostgreSQL][4])

```sql
INSERT INTO inbox_processed(event_id, handler)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;
```

---

## 5-3) TypeScript実装（例：pgでトランザクション）🧑‍💻✨

**重要ポイント**👇💡

* Inbox insert と 業務更新 は **同じトランザクション**に入れる🔐
* 途中で落ちたらロールバックされて、次回リトライでやり直せる🔁

```ts
import { Pool } from "pg";

type IntegrationEvent = {
  id: string;          // uuid
  type: string;        // eventType
  payload: unknown;    // JSON
};

export class InboxIdempotency {
  constructor(private readonly pool: Pool) {}

  /**
   * 重複なら何もせず return（=副作用を起こさない）🛡️
   * 初回だけ handlerFn を実行する🎯
   */
  async runOnce(
    event: IntegrationEvent,
    handlerName: string,
    handlerFn: (client: any) => Promise<void>,
  ): Promise<"processed" | "duplicate"> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");

      // ① まず Inbox に「処理権」を取りにいく🔒
      const res = await client.query(
        `
        INSERT INTO inbox_processed(event_id, handler)
        VALUES ($1, $2)
        ON CONFLICT DO NOTHING
        RETURNING event_id;
        `,
        [event.id, handlerName],
      );

      // ② 取れなかった＝重複イベント😇（安全に無視）
      if (res.rowCount === 0) {
        await client.query("ROLLBACK");
        return "duplicate";
      }

      // ③ 取れた＝初回だけ業務処理を実行🎯
      await handlerFn(client);

      await client.query("COMMIT");
      return "processed";
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
}
```

### 使い方イメージ🍀

```ts
async function handleOrderConfirmed(event: IntegrationEvent, idem: InboxIdempotency) {
  return idem.runOnce(event, "HandleOrderConfirmed", async (tx) => {
    // 例：通知テーブルに1件入れる（=本当はメール送信など）
    await tx.query(
      "INSERT INTO notifications(order_id, message) VALUES ($1, $2)",
      [(event as any).payload.orderId, "注文が確定しました！"],
    );
  });
}
```

---

## 6) “外部API呼び出し”があるときの冪等性💳📨🛡️

メール送信や決済みたいな外部APIは、こちらのDBトランザクション外で起きるから難易度が上がるよね😵‍💫

## 6-1) 外部APIが Idempotency-Key をサポートしてるなら最優先で使う🔑✨

Stripe みたいに **同じキーなら同じ結果**を返す仕組みがあると、リトライ地獄が一気に楽になるよ🙏✨([docs.stripe.com][2])

```ts
// fetch の例（外部APIが idempotency をサポートしている想定）
await fetch("https://example.com/payments", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Idempotency-Key": event.id, // ✅ イベントIDをそのまま使うのが楽
  },
  body: JSON.stringify(event.payload),
});
```

※ “Idempotency-Key” はHTTPでも広く使われていて、標準化の仕様ドラフトもあるよ📬🧩。([IETF Datatracker][3])

## 6-2) サポートしてない外部APIならどうする？😵‍💫

選択肢は主に2つ👇

* **外部APIを叩く前に** 自分のDBに「送信済み記録」を残して、重複なら叩かない（ただし順序と例外設計が大事）🗃️
* 外部APIの結果を取り込む設計（Webhook/ポーリング）に寄せて「最終結果」を基準にする🧲

このへんはプロジェクト事情で最適解が変わるけど、まずは **Idempotency-Key 対応の外部APIを選ぶ**のが現実的に強いよ💪✨

---

## 7) ありがち落とし穴集⚠️😇

## 落とし穴①：リトライのたびに冪等キーを作り直す🔑❌

* それ、毎回“別操作”になっちゃうよ😭
* ✅ **同じ操作なら同じキー**！

## 落とし穴②：Inboxに書くのが“処理の後”🗃️❌

* 処理→落ちる→リトライ→また処理…で二重になる😵‍💫
* ✅ **最初に Inbox に insert**！

## 落とし穴③：Inboxが「イベント単位」じゃなく「注文単位」だけ🚚⚠️

* 注文に複数イベントがあると、雑に弾いて事故ることがあるよ💥
* ✅ 基本は **event_id（イベント単位）**で弾くのが安全

## 落とし穴④：副作用がDB外（メール/決済）なのに対策なし📨💳❌

* ✅ 可能なら **Idempotency-Key**
* ✅ それが無理なら「送信済み記録」と設計の工夫が必要

---

## 8) テストで安心する🧪✅

## 8-1) 最低限のテスト観点（これだけで強い）💪

* 同じイベントを2回投げる → 1回だけ処理される🛡️🔁
* 途中で例外を投げる → 次のリトライでちゃんと処理される🔁💥
* 並行で同じイベントを処理する → どちらか片方だけが勝つ👯‍♀️🏁

## 8-2) “並行”の簡易テスト（イメージ）👯‍♀️🧪

```ts
// 疑似コード：同じ event を Promise.all で同時に処理
const results = await Promise.all([
  handleOrderConfirmed(event, idem),
  handleOrderConfirmed(event, idem),
]);

// processed が1つ、duplicate が1つになってほしい
```

---

## 9) AI活用ミニ型🤖✨（そのままコピペOK）

## 9-1) 設計レビュー用👀

* 「Inboxで冪等性を担保したい。今の処理は“副作用が先”になってない？危ない順序を指摘して」🧯🔍
* 「このイベントハンドラは冪等？二重実行されたら何が壊れる？」🛡️🧠

## 9-2) テスト増殖用🧪

* 「この runOnce 実装に対して、落ちやすい境界ケースを10個挙げて。テストケースにして」📋✨
* 「並行実行で事故るパターンを作って、どう直すか提案して」👯‍♀️🔒

## 9-3) 命名相談📛

* 「event.id / idempotencyKey / correlationId の役割を混同してないか、名前と用途を整理して提案して」🧩✨

---

## 10) まとめ🌈✨

* Outboxでも **二重配信は起こり得る**（むしろ普通）📨🔁([Amazon Web Services, Inc.][5])
* だから **冪等性で“1回に見せる”**のが必須🛡️
* 鉄板実装は **Inbox（処理済みテーブル）＋一意制約＋最初にinsert**🗃️🔒
* 外部APIは **Idempotency-Key** が使えるなら最優先で使う🔑💳([docs.stripe.com][2])

次章の「順序（Ordering）」に進むと、**“重複は捨てられるけど、順番が崩れると困るケース”**の扱いが見えてくるよ🍱➡️🍱✨

[1]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html?utm_source=chatgpt.com "Amazon SQS at-least-once delivery"
[2]: https://docs.stripe.com/api/idempotent_requests?utm_source=chatgpt.com "Idempotent requests | Stripe API Reference"
[3]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/?utm_source=chatgpt.com "The Idempotency-Key HTTP Header Field - IETF Datatracker"
[4]: https://www.postgresql.org/docs/current/sql-insert.html?utm_source=chatgpt.com "Documentation: 18: INSERT"
[5]: https://aws.amazon.com/documentation-overview/sqs/?utm_source=chatgpt.com "Amazon Simple Queue Service Documentation - AWS"
