# 第29章　最終的整合性の肌感覚（“ズレ”と友達になる）🕒🙂✨

この章では、「CQRSでよく出る *“反映の遅れ”*」を **怖がらずに扱える** ようになるのがゴールだよ〜！🫶
（結論：ズレは *バグ* じゃなくて、**設計上のトレードオフ** で、ちゃんと“手当て”できるよ😌）

---

## 1) まず起きること：注文したのに一覧に出ない😵‍💫🍙

学食アプリで…

1. 「注文する」ボタン押した！✅
2. 「注文できました！」って返ってきた！🎉
3. なのに…「注文一覧」に **まだ出てこない** 😭

これ、CQRSで **Write（更新）と Read（参照）が別** になると、かなり起きがちなんだ〜。

---

## 2) それ、バグじゃなく “最終的整合性” 🧠✨

**最終的整合性（Eventual Consistency）** っていうのは、

* 更新した直後の一瞬、読む側（Readモデル）が古いことがある
* でも少し待つと、最終的には新しい状態に追いつく

…っていう “遅れて合流する” 仕組みだよ🕒🙂

実際、AWSのDynamoDBでも「最近の書き込みがすぐ反映されないことがある、少し後に追いつく」って説明されてるよ（これがまさに最終的整合性）📚✨ ([AWS ドキュメント][1])
分散システムでは「全部を常に同期で揃える」のが難しくて、最終的整合性を **前提に設計する必要がある** って有名な解説もあるよ📌 ([martinfowler.com][2])

---

## 3) CQRSで “ズレ” が生まれる場所（図で一発）🪞🔧

ポイントはここ👇

* **Command（更新）** は Write側に入る
* **Query（参照）** は Read側を見る
* Read側は、イベント（または更新結果）を受け取って **投影（Projection）** で追いつく

ざっくり図にするとこう👇

```text
[Client]
  |  POST /orders (Command)
  v
[Write Model] --保存--> [Write DB]
   |
   |  Event: OrderPlaced
   v
[Event / Queue]
   |
   |  (Projectionが非同期で処理) ⏳
   v
[Read Model] --保存--> [Read DB]
  ^
  |  GET /orders (Query)
[Client]
```

この **「⏳の部分」** があると、ズレが自然に起きるよ〜🙂

---

## 4) “ズレOK” と “ズレNG” を決めるコツ🎯🧠

ズレが怖いのは、「どこでもズレる」と思うから！
現実は **ズレていい場所とダメな場所がある** のだ〜✨

### ✅ ズレても大抵OK（Readが遅れても許される）

* 売上集計📊（ちょい遅れても困らない）
* 人気メニューTOP3🏆（数秒遅れでも平和）
* 注文一覧📋（“反映中” 表示があればOK）

### ❌ ズレると困る（強めに揃える or 手当て必須）

* 決済完了の可否💳（ここでズレると炎上しがち🔥）
* 在庫の最終1個🍙（二重販売は事故）
* 「注文できた/できてない」判断そのもの

この判断、マジ大事！✨（設計のセンスが育つやつ🌱）

---

## 5) ズレと友達になる “UX手当て” 6選🫶🔄✨

ズレをゼロにしようとすると、システムが重く＆複雑になりがち。
だから **ユーザー体験で吸収する** のが王道だよ😊

### ① 「反映中…」をちゃんと見せる🕒🫧

* 注文直後に一覧に無くても「反映中です」って出すだけで安心感MAX

### ② 操作ID（correlationId / operationId）を返す🧾✨

* Commandの返り値で **operationId** を返して
* フロントは `/operations/{id}` を見に行く（あとで反映されたか確認）

### ③ ポーリング（再取得）＋指数バックオフ🔁📉

* 0.5秒 → 1秒 → 2秒…みたいに間隔を伸ばして優しく待つ

### ④ Pushで更新（SSE / WebSocket）📡✨

* 反映した瞬間にサーバーから「きたよー！」って通知
* 体感が一気に良くなる（後の章でやると超楽しいやつ🥳）

### ⑤ Readモデルに “反映時刻 / version” を入れる🕰️🔖

* 「この一覧、何秒前の情報か」を見える化できる

### ⑥ 「更新した直後だけはWriteを読む」もアリ✅

* “支払い完了画面だけ” はWrite側の状態を見て確定させる…とかね
  （全部をそうするとCQRSのうまみが減るので、ピンポイントで👍）

---

## 6) ミニ実装：非同期投影で “反映中” を体験しよう🍙🧩

ここから、**わざと遅延を入れて**「ズレ」を再現するよ😆
（“肌感覚” は体験がいちばん！）

### 6-1) まず型：イベントと操作ステータス📦✨

```ts
// src/shared/types.ts
export type EventId = string;
export type OperationId = string;

export type DomainEvent =
  | {
      id: EventId;
      type: "OrderPlaced";
      occurredAt: string; // ISO
      operationId: OperationId;
      payload: {
        orderId: string;
        customerName: string;
        totalYen: number;
      };
    };

export type OperationStatus =
  | { operationId: OperationId; state: "PENDING"; createdAt: string }
  | { operationId: OperationId; state: "DONE"; doneAt: string }
  | { operationId: OperationId; state: "FAILED"; failedAt: string; reason: string };
```

---

### 6-2) Write側：注文を保存してイベントを積む（Command）🧾✅

```ts
// src/write/placeOrderHandler.ts
import { randomUUID } from "node:crypto";
import type { DomainEvent, OperationStatus } from "../shared/types.js";

type WriteOrder = {
  orderId: string;
  customerName: string;
  totalYen: number;
  status: "ORDERED";
};

export class WriteOrderRepository {
  private map = new Map<string, WriteOrder>();
  save(order: WriteOrder) {
    this.map.set(order.orderId, order);
  }
  find(orderId: string) {
    return this.map.get(orderId);
  }
}

export class EventQueue {
  private q: DomainEvent[] = [];
  push(e: DomainEvent) {
    this.q.push(e);
  }
  pop(): DomainEvent | undefined {
    return this.q.shift();
  }
}

export class OperationStore {
  private map = new Map<string, OperationStatus>();
  put(status: OperationStatus) {
    this.map.set(status.operationId, status);
  }
  get(operationId: string) {
    return this.map.get(operationId);
  }
}

export class PlaceOrderHandler {
  constructor(
    private readonly writeRepo: WriteOrderRepository,
    private readonly queue: EventQueue,
    private readonly opStore: OperationStore,
  ) {}

  execute(input: { customerName: string; totalYen: number }) {
    // 超ミニバリデーション（第11章の考え方で増やしてね🙂）
    if (!input.customerName) throw new Error("customerName required");
    if (input.totalYen <= 0) throw new Error("totalYen must be > 0");

    const orderId = randomUUID();
    const operationId = randomUUID();

    this.writeRepo.save({
      orderId,
      customerName: input.customerName,
      totalYen: input.totalYen,
      status: "ORDERED",
    });

    this.opStore.put({
      operationId,
      state: "PENDING",
      createdAt: new Date().toISOString(),
    });

    this.queue.push({
      id: randomUUID(),
      type: "OrderPlaced",
      occurredAt: new Date().toISOString(),
      operationId,
      payload: { orderId, customerName: input.customerName, totalYen: input.totalYen },
    });

    // ここで「成功」を返しても、Readはまだ追いついてないかも🙂
    return { orderId, operationId };
  }
}
```

---

### 6-3) Read側：投影ワーカー（わざと遅らせる）⏳🌱

```ts
// src/read/projectionWorker.ts
import type { DomainEvent, OperationStore } from "../shared/types.js";
import { EventQueue } from "../write/placeOrderHandler.js";

type ReadOrderRow = {
  orderId: string;
  customerName: string;
  totalYen: number;
  projectedAt: string;
};

export class ReadOrderRepository {
  private rows: ReadOrderRow[] = [];
  upsert(row: ReadOrderRow) {
    const i = this.rows.findIndex((x) => x.orderId === row.orderId);
    if (i >= 0) this.rows[i] = row;
    else this.rows.unshift(row);
  }
  list() {
    return this.rows;
  }
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export class ProjectionWorker {
  constructor(
    private readonly queue: EventQueue,
    private readonly readRepo: ReadOrderRepository,
    private readonly opStore: OperationStore,
  ) {}

  async start() {
    // ずっと回す簡易版（本番は停止制御など必要だよ🧯）
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const ev = this.queue.pop();
      if (!ev) {
        await sleep(100);
        continue;
      }

      // ✨ここが「ズレ」を作る本体✨
      await sleep(1500); // わざと1.5秒遅らせる😆

      try {
        if (ev.type === "OrderPlaced") {
          this.readRepo.upsert({
            orderId: ev.payload.orderId,
            customerName: ev.payload.customerName,
            totalYen: ev.payload.totalYen,
            projectedAt: new Date().toISOString(),
          });

          this.opStore.put({
            operationId: ev.operationId,
            state: "DONE",
            doneAt: new Date().toISOString(),
          });
        }
      } catch (e) {
        this.opStore.put({
          operationId: ev.operationId,
          state: "FAILED",
          failedAt: new Date().toISOString(),
          reason: e instanceof Error ? e.message : "unknown",
        });
      }
    }
  }
}
```

---

### 6-4) Query：一覧と操作ステータスを見る👀📋

```ts
// src/read/queryService.ts
import { ReadOrderRepository } from "./projectionWorker.js";
import { OperationStore } from "../write/placeOrderHandler.js";

export class QueryService {
  constructor(
    private readonly readRepo: ReadOrderRepository,
    private readonly opStore: OperationStore,
  ) {}

  getOrderList() {
    return this.readRepo.list();
  }

  getOperation(operationId: string) {
    return this.opStore.get(operationId) ?? null;
  }
}
```

---

### 6-5) “クライアント”で体験：反映されるまで待つ🔄🙂

フロントがまだ無くても、まずは **fetchで疑似体験** できるよ〜！

```ts
// src/demo/clientDemo.ts
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function demo(baseUrl: string) {
  const res = await fetch(`${baseUrl}/orders`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ customerName: "こみやんま", totalYen: 850 }),
  });

  const { orderId, operationId } = (await res.json()) as {
    orderId: string;
    operationId: string;
  };

  console.log("注文受付！🎉", { orderId, operationId });
  console.log("でも一覧はまだかも…🕒");

  for (let i = 0; i < 10; i++) {
    const op = await fetch(`${baseUrl}/operations/${operationId}`).then((r) => r.json());
    console.log("operation:", op);

    if (op?.state === "DONE") {
      const list = await fetch(`${baseUrl}/orders`).then((r) => r.json());
      console.log("一覧に出た！📋✨", list[0]);
      return;
    }

    await sleep(300 + i * 200); // 少しずつ待つ（やさしめ）🙂
  }

  console.log("まだ反映されない…🥲（ログ見よ！）");
}
```

この体験をすると、「あ、**成功返した直後にReadが古い**って普通に起きるんだ」って腑に落ちるよ😌✨

---

## 7) よくある事故ポイント（ここだけは注意！）⚠️🧯

### ❌ 事故①：ユーザーが連打して二重注文🍙🍙😱

* 「反映されない＝失敗」と思って押し直す
  → だから **“反映中” 表示** めっちゃ大事！

### ❌ 事故②：Readを正として判定しちゃう

* 「一覧にないから未注文」と判断してしまう
  → “確定判定” は **Write側 or OperationStatus** を使うのが安全🙂

### ❌ 事故③：待ちすぎてUIが固まる

* “反映されるまで待つ” をやりすぎると体験が悪い
  → ほどほどにして「あとで追いつく表示」に寄せるのがコツ！

---

## 8) ミニ演習（紙でもOK📝✨）

### 演習A：どこがズレてOK？どこがNG？🎯

次を「OK / NG / 条件付き」で分けてみてね🙂

* 注文一覧の表示
* 売上集計
* 支払い完了表示
* 在庫残数（ラスト1個）
* “注文できたかどうか” の最終判定

### 演習B：UXの文言を作る💬🫶

「反映中」をどう言うと不安が消える？
例：「注文は受け付けました！一覧に反映するまで少し待ってね🙂」

---

## 9) AI活用コーナー🤖✨（この章と相性バツグン）

### ① “ズレOK/NG” の判断を一緒にやってもらう

* 「学食注文アプリで、ズレが許容できる画面とできない画面を列挙して、理由も書いて」

### ② 反映中の文言を10案出してもらう🫧

* 「不安を減らす、短くて優しい文言を10個。絵文字も混ぜて」

### ③ operationId設計レビュー🧠

* 「operationId方式のAPI設計で、危険な点・改善案を指摘して」

---

## 10) まとめ🎉

* CQRSでは Readが遅れて追いつくことがある（最終的整合性）🕒
* ズレは “悪” じゃなくて、**どこで許すかを設計するもの** 🧠
* UX（反映中、operationId、再取得、push）で不安を消せる🫶
* 体験して慣れるのが最短ルート😆✨

ちなみに、分散システムの世界では最終的整合性は普通に使われていて、AWSでも「結果がすぐ見えないかも」と明示されてるよ📚 ([AWS ドキュメント][3])
そして分散では整合性の扱いが難しいから、最終的整合性をちゃんと管理しようね、という有名な指摘もあるよ📌 ([martinfowler.com][2])

---

## おまけ：2026年1月24日時点の “開発環境まわり” 小ネタ🧁

* TypeScriptは **5.9がリリース済み** で、チームは **6.0と7.0を早期2026に向けて進めている** と説明してるよ 🧠✨ ([Microsoft for Developers][4])
* Node.jsは **v24がActive LTS**、v25がCurrentとして更新されてるよ（セキュリティリリースも出てる）🔐 ([Node.js][5])

---

次の第30章（冪等性🔁🛡️）は、この章の「連打・再送・二重処理」を **安全にする本命** だから、ここまで来たら超いい流れだよ〜！🥳

[1]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html?utm_source=chatgpt.com "DynamoDB read consistency"
[2]: https://martinfowler.com/articles/microservice-trade-offs.html?utm_source=chatgpt.com "Microservice Trade-Offs"
[3]: https://docs.aws.amazon.com/ec2/latest/devguide/eventual-consistency.html?utm_source=chatgpt.com "Eventual consistency in the Amazon EC2 API"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[5]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
