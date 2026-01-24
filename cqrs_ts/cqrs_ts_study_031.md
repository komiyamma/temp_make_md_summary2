# 第31章　Outbox入門（落とさないための基本）📮✅

この章は「**DBの更新**」と「**イベント発行**」を**ズレなく**つなぐための“超重要パターン”を学ぶ回だよ〜！😊✨
結論から言うと、**Outboxは「あとで必ず送るメモ」をDBに残す仕組み**です📮📝

---

## 1. まず、何が困るの？（Dual Write問題）😵‍💫💥

たとえば注文を確定するとき、

1. DBに `Order` を保存する ✅
2. 「OrderPlacedイベント」を発行する ✅

…ってやりたいよね？

でもこれ、順番にやると事故るの🥺

* DB保存 ✅ → イベント発行 ❌（ネットワーク死んだ、ブローカー落ちた…）
  → **注文はあるのに、Readモデル（一覧/集計）が更新されない**😱
* イベント発行 ✅ → DB保存 ❌
  → **イベントだけ飛んで、注文が存在しない**👻

この「DBとイベントを別々に書く（Dual Write）」が危険だよ、って話。
Outboxはこの問題の定番解決策として知られてるよ 📮✨ ([microservices.io][1])

---

## 2. Outboxの考え方（超ざっくり図）🖼️✨

ポイントはこれ👇

✅ **DB更新とOutboxへの書き込みを“同じトランザクション”でやる**
✅ イベント発行はあとで別プロセス（Relay/Worker）がやる

イメージ👇

```
[CommandHandler]
   |
   |  (同じトランザクション)
   |---- insert Order
   |---- insert OutboxMessage  ←「あとで送る」メモ📮
   |
 commit ✅
   |
   v
[Outbox Relay]  ← 定期的にOutboxを見に行く👀
   |
   |---- publish event（投影/ブローカーへ）
   |---- mark as sent（送った印つける✅）
```

この「Outboxに残す」って発想が、**“落とさない”の芯**だよ〜😊📮 ([DEV Community][2])

---

## 3. 最小のOutboxテーブル設計（まずこれでOK）🗂️✨

最低限ほしいのはこんな感じ👇

* `id`：イベントID（重複対策にも使う）🔑
* `type`：イベント種類（例：`OrderPlaced`）🏷️
* `payload`：必要データ（JSONでOK）📦
* `occurredAt`：発生時刻🕒
* `status`：未送信/送信済みなど✅
* `attempts`：リトライ回数🔁（あると運用が楽！）

---

## 4. ハンズオン：Outboxを“最小”で実装してみよう ✍️😊

ここでは「注文作成（PlaceOrder）」のときに、

* `Order` を保存
* `OutboxMessage` を保存（同トランザクション）

までを作るよ！

### 4.1 Prismaの例（DB + Outboxを同時に書く）📮✨

```ts
// PlaceOrderHandler（イメージ）
// “Order保存”と“Outbox保存”を同じトランザクションでやるよ！
await prisma.$transaction(async (tx) => {
  const order = await tx.order.create({
    data: {
      id: orderId,
      status: "ORDERED",
      total: totalAmount,
      createdAt: new Date(),
    },
  });

  await tx.outboxMessage.create({
    data: {
      id: eventId,                // ←重要：イベントID（冪等性の鍵🔑）
      type: "OrderPlaced",
      aggregateId: order.id,
      payload: {
        orderId: order.id,
        total: totalAmount,
        occurredAt: new Date().toISOString(),
      },
      status: "PENDING",
      occurredAt: new Date(),
      attempts: 0,
    },
  });

  return order;
});
```

Prismaのトランザクションの基本は公式ドキュメントにまとまってるよ🧾 ([Prisma][3])

> 💡ここがOutboxの肝！
> 「注文が保存されたのにイベントが消えた」が**起きにくくなる**😊📮

---

## 5. Outbox Relay（送る係）を作るよ📨🤖

Outboxは「メモを残すだけ」なので、**送る係**が必要！

最小構成はこう👇

1. `status=PENDING` のOutboxを数件取る
2. 1件ずつ publish（投影更新 or メッセージブローカー送信）
3. 成功したら `status=SENT` にする ✅
4. 失敗したら `attempts++`、次回リトライ 🔁

### 5.1 Relayの超ミニ例（疑似イベントバスでOK）🚌✨

```ts
type OutboxRow = {
  id: string;
  type: string;
  payload: unknown;
  attempts: number;
};

async function publish(row: OutboxRow) {
  // ここを「Read投影を呼ぶ」「Kafka/PubSubに送る」等に差し替える📨
  console.log("PUBLISH:", row.type, row.id);
}

async function runOutboxRelayOnce() {
  const rows = await prisma.outboxMessage.findMany({
    where: { status: "PENDING" },
    orderBy: { occurredAt: "asc" },
    take: 20,
  });

  for (const row of rows) {
    try {
      await publish(row as any);

      await prisma.outboxMessage.update({
        where: { id: row.id },
        data: { status: "SENT" },
      });
    } catch (e) {
      await prisma.outboxMessage.update({
        where: { id: row.id },
        data: { attempts: { increment: 1 } },
      });
    }
  }
}
```

---

## 6. でも…「送ったのにSENT更新に失敗」したら？😱🔁

ここ、超大事！！！

Relayが

* publish ✅（成功！）
* status更新 ❌（DB一時障害！）

ってなると、次回また同じイベントを拾って **2回送っちゃう**可能性があるの🥺
つまりOutboxは基本 **at-least-once（最低1回は届く）** になりやすいよ〜。

だから第30章の「冪等性」がここで効く！！🔁🛡️

✅ **イベントIDで“処理済み判定”**して、2回届いても1回分として扱う
（Read投影側・購読側で守るのが定番！）

---

## 7. Relayを増やしたいとき（並列処理の落とし穴）🧨👀

Relayを2台以上で動かすと、同じ行を2人が同時に拾って二重送信しがち💦

そこでよく使われるのが **行ロック + SKIP LOCKED**（特にPostgreSQL）だよ✨
複数ワーカーが同時に取りに行っても、**ロック中の行はスキップ**して取り合いしない感じ！ ([NP Blog][4])

---

## 8. “最小Outbox”の運用チェックリスト✅🧰

Outboxは作って終わりじゃなくて、運用で差が出るよ〜！

* Outboxが溜まり続けてない？（監視）📈
* `attempts` が増え続けてる行がない？（アラート）🚨
* 古いSENTを削除する？（期限やアーカイブ）🧹
* 失敗時のリトライ間隔（指数バックオフ）⏳
* payloadが肥大化してない？（サイズ管理）📦

---

## 9. ミニ演習（設計だけでOK）📝✨

次の「仕様」を満たすOutbox設計を、あなたの言葉で書いてみてね😊

### お題🎯

* 注文作成（OrderPlaced）と支払い完了（OrderPaid）の2種類イベントをOutboxに残す
* Relayは「古い順」に送る
* 失敗したら最大10回までリトライ
* 10回失敗したら `DEAD` にして人が調査できるようにする

書くもの👇

* Outboxテーブルのカラム案（型もあると最高！）🧾
* Relayの処理フロー（箇条書きでOK）🤖

---

## 10. AI活用プロンプト（コピペで使ってね🤖💖）

### 10.1 Outboxテーブル設計レビュー

```text
Outboxパターンの最小テーブル設計をレビューして！
目的：DB更新とイベント発行のズレを防ぐ。
要件：OrderPlaced/OrderPaid、リトライ回数、送信済み管理、失敗隔離（DEAD）。
不足カラム・命名・インデックス案も提案して。
```

### 10.2 Relay実装たたき台

```text
TypeScriptでOutbox Relayの最小実装案を出して。
やること：PENDINGを古い順に取得→publish→成功ならSENT、失敗ならattempts++、10回でDEAD。
ログ出力と、例外ハンドリング方針も入れて。
```

### 10.3 “二重送信”が起きるケース説明（理解チェック）

```text
Outbox Relayで「publish成功→SENT更新失敗」が起きたとき何が起きる？
なぜ冪等性が必要？どこで守る？初心者向けに例で説明して。
```

---

## まとめ（この章で覚えたい3点）🎁✨

1. **Dual Writeは事故りやすい**（DBとイベントがズレる）😵‍💫
2. **Outboxは「あとで送る」をDBに残す**ことで落としにくくする📮✅ ([microservices.io][1])
3. それでも **二重送信は起こりうる**ので、**冪等性（第30章）**がセットで必須🔁🛡️

---

次の第32章（Read最適化①）に行くと、「Read側を育てる楽しさ」が出てくるよ〜！🔎🚀
もしよければ、今のあなたの教材用プロジェクト（学食アプリ）のDB構成に合わせて、**Outboxテーブルの具体案**もこっちで組み立てるよ😊📮

[1]: https://microservices.io/patterns/data/transactional-outbox.html?utm_source=chatgpt.com "Pattern: Transactional outbox"
[2]: https://dev.to/igor_grieder/dual-write-and-the-transactional-outbox-pattern-aid?utm_source=chatgpt.com "Dual Write and the Transactional Outbox Pattern"
[3]: https://www.prisma.io/docs/orm/prisma-client/queries/transactions?utm_source=chatgpt.com "Transactions and batch queries (Reference) - Prisma Client"
[4]: https://www.npiontko.pro/2025/05/19/outbox-pattern?utm_source=chatgpt.com "Transactional Outbox Pattern: From Theory to Production"
