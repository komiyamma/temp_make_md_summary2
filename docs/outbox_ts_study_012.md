# 第12章：実装① 書き込み（業務更新＋Outbox追加）🛠️✅

## この章でできるようになること 🎯✨

* 「注文確定」みたいな**業務更新**をしたときに、同時に **Outbox に“送る予定”を保存**できるようになる📦🧾
* しかも、**片方だけ成功**（＝事故💥）にならないように **1つのトランザクション**でまとめる🔐
* ついでに、**層（Application / Domain / Infra）**を分けて、設計の混乱を防ぐ🧠🧱

> Outboxの基本アイデアは「DBの更新（業務）と、Outboxテーブルへの追加（イベント）を**同じDBトランザクション**で確実に行う」ことだよ📌。([microservices.io][1])

---

## 12.1 まず “正しい流れ” を1分で掴もう ⏱️🙂

## ✅ ゴールの動き（書き込み側）

1. 入力を受ける（例：orderId）📝
2. **トランザクション開始**🔐
3. 注文を読み込み → ドメインルールで「確定」する🧠
4. 注文を保存する💾
5. **Outboxにイベントを1件追加**する📦
6. **コミット**✅（ここまで全部成功したらOK！）
7. トランザクション外で、Publisherがあとで送る📤（第13章）

## ❌ やっちゃダメ（事故のもと）😵‍💫

* 「注文確定した！→ その場で外部へ送信（HTTP/Kafka/etc）」
  → **DBは成功したけど送信は失敗**が起きる（送信漏れ📭）
  → だから “送る” のは後で（Publisher）！

---

## 12.2 層を分けると何が嬉しいの？🍀🧩

## 3層の役割（超ざっくり）🧁

* **Application層**：手順を組み立てる係（ユースケース）🧑‍🍳

  * 例：トランザクションを張る / Repoを呼ぶ / 結果を返す
* **Domain層**：ルールを守る係（ビジネス脳）🧠

  * 例：「未確定→確定」はOK、「キャンセル済→確定」はNG 🙅‍♀️
* **Infrastructure層**：保存する係（DBアクセス）💾

  * 例：PrismaでINSERT/UPDATEする

## よくある混ざり事故 🌀

* Domainの中でDB更新し始める（やめて〜！）😇
* Controllerが直接SQL書き始める（あとで地獄…）🥹
* 「どこでOutbox作るの？」が毎回バラバラ（統一しよ）📏

---

## 12.3 実装方針：Prismaで “1トランザクション” を作る🧰✨

この章は **Prisma ORM（v7系）** を例にするよ（2026年初頭の最新ライン）。([Prisma][2])
TypeScriptも現行リリース（例：TypeScript 5.9系）を想定してOK👌([TypeScript][3])
Node.jsはLTSを使うのが安心（例：Node v24がActive LTS扱い）。([Node.js][4])

---

## 12.4 例題：注文を確定すると「OrderConfirmed」イベントをOutboxに積む🛒📦

## フォルダ構成（迷ったらこれ）📁✨

* `src/application/confirmOrder/ConfirmOrderUseCase.ts`
* `src/domain/order/Order.ts`
* `src/domain/order/OrderEvents.ts`
* `src/infra/prisma.ts`
* `src/infra/repositories/OrderRepository.ts`
* `src/infra/repositories/OutboxRepository.ts`

---

## 12.5 DB（Prisma schema）最低限の形 🧾🧱

```prisma
// prisma/schema.prisma
model Order {
  id        String   @id
  status    String
  updatedAt DateTime @updatedAt
}

model Outbox {
  id         String   @id           // eventId（UUIDなど）
  eventType  String
  payload    Json
  status     String                // "pending" / "sent" / "failed" など
  createdAt  DateTime @default(now())
}
```

ポイント✅

* **payloadはJson**でOK（第10章の設計をそのまま入れる）📄
* statusは最初 `"pending"`（未送信）で積む📌

---

## 12.6 Domain：ルールだけを持つ「注文」🧠✨

```ts
// src/domain/order/Order.ts
export type OrderStatus = "draft" | "confirmed" | "cancelled";

export class Order {
  constructor(
    public readonly id: string,
    private _status: OrderStatus,
  ) {}

  get status(): OrderStatus {
    return this._status;
  }

  confirm(): void {
    if (this._status === "cancelled") {
      throw new Error("キャンセル済みの注文は確定できません🥲");
    }
    if (this._status === "confirmed") {
      // 2回目の確定は何もしない（冪等っぽくする）🙂
      return;
    }
    this._status = "confirmed";
  }
}
```

ここ大事💡

* Domainは **DBもPrismaも知らない** 🙅‍♀️
* “確認したらconfirmedにする” だけを守る🧠✅

---

## 12.7 Domain Event（Outboxに積む中身）📨🧩

```ts
// src/domain/order/OrderEvents.ts
export type OrderConfirmedV1 = {
  schemaVersion: 1;
  eventType: "OrderConfirmed";
  eventId: string;
  occurredAt: string; // ISO文字列
  data: {
    orderId: string;
  };
};

export function buildOrderConfirmedV1(args: {
  eventId: string;
  occurredAt: Date;
  orderId: string;
}): OrderConfirmedV1 {
  return {
    schemaVersion: 1,
    eventType: "OrderConfirmed",
    eventId: args.eventId,
    occurredAt: args.occurredAt.toISOString(),
    data: { orderId: args.orderId },
  };
}
```

コツ✨

* `schemaVersion` を入れておくと将来助かる（第20章で効く）🧬
* `eventId` はOutboxの `id` と同じにすると追跡が楽🔍

---

## 12.8 Infrastructure：Repository（DBアクセス担当）💾🧰

## Prismaクライアント（共有）🧩

```ts
// src/infra/prisma.ts
import { PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient();
export type Tx = Parameters<PrismaClient["$transaction"]>[0] extends (
  arg: infer A
) => any
  ? A
  : never;
```

> 型は好みでOK！「txを受け取る」形にできれば勝ち🏆

## OrderRepository

```ts
// src/infra/repositories/OrderRepository.ts
import { Order, OrderStatus } from "../../domain/order/Order";

type Db = { order: { findUnique: Function; update: Function } };

export class OrderRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string): Promise<Order | null> {
    const row = await this.db.order.findUnique({ where: { id } });
    if (!row) return null;
    return new Order(row.id, row.status as OrderStatus);
  }

  async save(order: Order): Promise<void> {
    await this.db.order.update({
      where: { id: order.id },
      data: { status: order.status },
    });
  }
}
```

## OutboxRepository

```ts
// src/infra/repositories/OutboxRepository.ts
type Db = { outbox: { create: Function } };

export class OutboxRepository {
  constructor(private readonly db: Db) {}

  async add(args: {
    id: string;
    eventType: string;
    payload: unknown;
  }): Promise<void> {
    await this.db.outbox.create({
      data: {
        id: args.id,
        eventType: args.eventType,
        payload: args.payload as any,
        status: "pending",
      },
    });
  }
}
```

ポイント✅

* `db` に **通常のprisma** も **tx（transaction client）** も入れられる形にしておくと超便利🙂

---

## 12.9 Application：ユースケースで “同時に保存” を確定させる🔐📦

```ts
// src/application/confirmOrder/ConfirmOrderUseCase.ts
import { prisma } from "../../infra/prisma";
import { OrderRepository } from "../../infra/repositories/OrderRepository";
import { OutboxRepository } from "../../infra/repositories/OutboxRepository";
import { buildOrderConfirmedV1 } from "../../domain/order/OrderEvents";
import { randomUUID } from "crypto";

export class ConfirmOrderUseCase {
  async execute(input: { orderId: string }): Promise<{ ok: true }> {
    const eventId = randomUUID(); // NodeならこれでOK👌

    await prisma.$transaction(async (tx) => {
      const orderRepo = new OrderRepository(tx as any);
      const outboxRepo = new OutboxRepository(tx as any);

      const order = await orderRepo.findById(input.orderId);
      if (!order) throw new Error("注文が見つかりません🥲");

      // ① ルール適用（Domain）
      order.confirm();

      // ② 業務保存
      await orderRepo.save(order);

      // ③ Outbox追加（同じトランザクション内！）
      const ev = buildOrderConfirmedV1({
        eventId,
        occurredAt: new Date(),
        orderId: order.id,
      });

      await outboxRepo.add({
        id: ev.eventId,
        eventType: ev.eventType,
        payload: ev,
      });
    });

    return { ok: true };
  }
}
```

## ここがこの章の心臓💓

* `prisma.$transaction(async (tx) => { ... })` の中で

  * **注文UPDATE** ✅
  * **Outbox INSERT** ✅
    を “セットで成功” にする🔐✨

> Transactional Outboxは「DB更新 + Outbox書き込み」を同一トランザクションで行い、二重書き込み（dual-write）の事故を避ける狙いがあるよ。([AWS ドキュメント][5])

---

## 12.10 動作確認：本当に “同時に” 入ってる？👀🔍

## ① 注文がconfirmedになってる？✅

* `Order.status` が `"confirmed"` になってるか見る

## ② Outboxに1行増えてる？📦

* `status = "pending"` で1件追加されてるか見る

💡 もし例外が起きたら？

* トランザクションがロールバックされて

  * 注文も戻る
  * Outboxも戻る
    ＝ **片方だけ成功が起きない** 🙌

---

## 12.11 よくあるミス集（先に潰しとこ）💥🧯

## ミス①：Outboxだけ保存して、注文保存が失敗

* ✅ トランザクションなら一緒に戻る

## ミス②：Outbox保存の後に、外部送信までやっちゃう

* ❌ ネットワークは失敗する世界🌧️
* ✅ この章は「Outboxに積むまで」
* 📤 “送る” は第13章のPublisherに任せる

## ミス③：DomainがDBに触り始める

* ❌ DomainがPrismaをimportしたら黄色信号🚥
* ✅ “ルールだけ” にする（Confirmはconfirm()の中）

---

## 12.12 AI活用ミニ型（この章用）🤖💬✨

## ① 責務分離レビュー（SoCチェック）👀✂️

AIにこれ投げてOK👇

* 「DomainにDBアクセスが混ざってない？」
* 「UseCaseが手順を握れてる？」
* 「RepositoryはDB操作だけ？」

例プロンプト💬

```text
このコード構成（Application/Domain/Infra）で責務が混ざっている箇所を指摘して、
「直すならどのファイルへ移すべきか」まで具体的に教えてください。
特に Domain 層にDB/Prisma依存が混ざっていないかを厳しく見てください。
```

## ② “事故シナリオ” 追加してテスト案を出させる🧪

* 注文が存在しない
* cancelled を confirm しようとする
* confirmed を2回 confirm する（冪等っぽく）

---

## 12.13 ミニ演習 🎓🍬

## 演習A：イベントをもう1種類増やす➕📨

* `OrderCancelled` を作って
* `cancel()` → 注文更新 + Outbox追加 を同じトランザクションでやってみよう🙂

## 演習B：payloadに “相関ID（correlationId）” を入れる🔗

* ログ追跡がめちゃ楽になる（第21章で超効く）🔍📊

---

## 12-1. なぜレイヤーを分けるの？🍰

<!-- img: outbox_ts_study_012_layers.png -->
全部 `controller` に書いても動くけど、Outboxは **「インフラ（DB操作）」** と **「ドメイン（業務イベント）」** が混ざりやすい場所です🌀
## まとめ 📌✨

* この章の勝ち筋はこれだけ👇

  * **業務更新**と**Outbox追加**を
  * **同じトランザクション**で実行する🔐📦
* 層を分けると、あとでPublisherやリトライを足すときに崩れにくい🧱🙂
* 次の第13章で、Outboxの `"pending"` を拾って “送る係” を作るよ📤🚀

[1]: https://microservices.io/patterns/data/transactional-outbox.html?utm_source=chatgpt.com "Pattern: Transactional outbox"
[2]: https://www.prisma.io/blog/announcing-prisma-orm-7-2-0?utm_source=chatgpt.com "Announcing Prisma ORM 7.2.0"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[5]: https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html?utm_source=chatgpt.com "Transactional outbox pattern - AWS Prescriptive Guidance"
