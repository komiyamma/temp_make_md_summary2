# 第16章 同期/非同期と順序（どれを今やる？）⚡🕰️

## 🎯 この章のゴール

* 「この処理は同期でやる？それとも非同期？」を理由つきで判断できるようになる✨
* 「順序が必要な処理」と「順序いらない処理」を見分けて、壊れにくく設計できるようになる🧩
* TypeScriptで「同期ハンドラ」「非同期ハンドラ」を分けた最小ディスパッチを作れるようになる💪💖

---

## 🌱 まず大事：ここで言う「同期/非同期」って何？（超ざっくり）

この章では、こういう意味で使うよ👀

* **同期（このリクエスト中にやり切る）**
  → ユースケースの処理の中で、結果が返る前に完了させたいもの✅
* **非同期（あとでやる）**
  → 今すぐ終わらなくてOK、むしろ「後回しにしたい」もの📮⏳

ポイントはここ👇
**async/await を使っていても、”今の処理の中で待つなら同期扱い”**だよ〜！🧠✨
（`await` は「待つ」ので、待つ範囲＝同期っぽくなる）

ちなみに TypeScript の最新安定版は **5.9.3（2025-10-01）**として公開されてるよ📌 ([GitHub][1])
Node.js は **2026-01-19 更新時点で v25 が Current、v24 が Active LTS** という整理になってるよ🟢 ([Node.js][2])

---

## 🧠 判断フレーム：迷ったらこの4問だけでOK✨

ドメインイベントのハンドラ（副作用）を **同期/非同期**に分けるとき、これを順番に聞いてみてね💬

### Q1️⃣ ユーザーの返事に「今すぐ必要」？

* **YES → 同期**（結果に直結する）✅
* **NO → Q2へ**

例：決済の成功/失敗、在庫の確保、購入の確定など💳📦

---

### Q2️⃣ 失敗したら「ユースケース自体を失敗にしたい」？

* **YES → 同期**（失敗を返したい）🧯
* **NO → Q3へ**

例：在庫確保に失敗したら購入を止めたい → 同期が自然🧱

---

### Q3️⃣ 遅い/不安定（外部API・メール・通知）？

* **YES → 非同期寄り**（遅さを隔離）📡🐢
* **NO → Q4へ**

例：メール送信、Slack通知、外部CRM連携、分析基盤送信📩🔗📊

---

### Q4️⃣ 何度か失敗しても「リトライでなんとかなる」？

* **YES → 非同期**（あとで再挑戦しやすい）🔁
* **NO → 同期 or 設計見直し**（重要すぎる）🧠⚠️

---

## 🕰️ 「順序が必要」ってどういうこと？

順序が必要＝だいたいこう👇

* ✅ **Aが終わった後じゃないとBができない**
* ✅ **Bが先に走ると壊れる（不正状態になる）**
* ✅ **ユーザー体験として順番が大事**（例：決済前に出荷メールが飛ぶのは最悪😇）

---

## 🛒 ミニEC例：同期/非同期の分類やってみよう📦💳

`OrderPaid`（支払い完了）イベントが出た！🔥
ここから起きる処理を分けてみるよ〜✨

### ✅ 同期に寄せたい（順序も大事になりやすい）

* 在庫を確保する（確保できないなら購入を失敗にしたい）📦🔒
* 注文の状態を「支払い済み」に確定する（不変条件）🧾✅
* （場合によって）領収書番号の確定・採番など🧮

### 📮 非同期でOK（順序が要らない or 遅れてOK）

* メール送信📩
* ポイント付与🪙（※二重実行対策は後の章の冪等性へ🔁）
* 売上集計へ送信📊
* Slack通知🔔

---

## ⚡ 「順序」を決めるときのコツ3つ🧩

### ① 依存があるなら、まず「イベントを分ける」✨

たとえば「決済→出荷」を順序で縛りたいなら…

* `OrderPaid`（支払い完了）💳
* `ShipmentRequested`（出荷依頼された）📦
* `ShipmentCompleted`（出荷完了）🚚

みたいに、**段階の事実をイベント化**すると超わかりやすいよ🧠💡
（「順序」じゃなくて「状態の遷移」で表現する感じ🌊）

---

### ② “順序が要る”なら「直列（awaitで順番）」が基本✅

`Promise.all()` で一気に投げると、完了順がバラけるよ⚠️
直列で `await` すれば「A→B→C」を守れる🕰️

MDNでも、`await` は（書いた順に）待つので “待ち自体は直列になる” という説明があるよ📌 ([MDN Web Docs][3])

---

### ③ “順序が要らない”なら「並列」で速くできる⚡

メールとSlack通知とか、互いに関係ないなら同時でOK👍
ただし「外部に負荷がかかる」なら、並列数の上限を考えようね🐢💦

---

## 🧑‍💻 TypeScript最小実装：同期/非同期ハンドラを分けて配る📣

ここでは **超ミニマム**に「同期は待つ」「非同期はキューに積む」を作るよ🧩✨
（リトライとかOutboxは後の章で本格的にやるよ〜！）

### 1) イベントとハンドラの型📌

```ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  occurredAt: string;     // ISO string
  aggregateId: string;
  type: TType;
  payload: TPayload;
}>;

export type AnyDomainEvent = DomainEvent<string, unknown>;

export type EventHandler<E extends AnyDomainEvent = AnyDomainEvent> =
  (event: E) => void | Promise<void>;

export type HandlerMode = "sync" | "async";

export type HandlerRegistration = Readonly<{
  type: string;           // event type (e.g., "OrderPaid")
  mode: HandlerMode;      // "sync" or "async"
  order?: number;         // smaller runs first
  name?: string;          // just for logs/debug
  handle: EventHandler;
}>;
```

---

### 2) 非同期用の “超小さい” キュー🧺

「今は待たない」だけを実現する簡易キューだよ📮
（プロセスが落ちたら消えるので、ここは “学習用” ね⚠️）

```ts
export class InMemoryJobQueue {
  private jobs: Array<() => Promise<void>> = [];
  private running = false;

  enqueue(job: () => Promise<void>) {
    this.jobs.push(job);
    this.kick();
  }

  private kick() {
    if (this.running) return;
    this.running = true;

    // 次のイベントループで処理開始（「今すぐ」じゃなくて「ちょい後」）
    setImmediate(() => this.drain().finally(() => (this.running = false)));
  }

  private async drain() {
    while (this.jobs.length > 0) {
      const job = this.jobs.shift()!;
      try {
        await job();
      } catch (err) {
        // ここでは握りつぶさずログだけ（本格対策は後の章へ🔁）
        console.error("[async-handler-failed]", err);
      }
    }
  }
}
```

---

### 3) ディスパッチャ：同期はawait、非同期はenqueue📣

```ts
export class DomainEventDispatcher {
  constructor(
    private readonly regs: readonly HandlerRegistration[],
    private readonly queue: InMemoryJobQueue,
  ) {}

  async dispatch(events: readonly AnyDomainEvent[]) {
    for (const event of events) {
      const targets = this.regs
        .filter(r => r.type === event.type)
        .slice()
        .sort((a, b) => (a.order ?? 0) - (b.order ?? 0));

      // ✅ 同期ハンドラ：順番に await して完了を保証
      for (const r of targets.filter(t => t.mode === "sync")) {
        await r.handle(event);
      }

      // 📮 非同期ハンドラ：キューへ（この場では待たない）
      for (const r of targets.filter(t => t.mode === "async")) {
        this.queue.enqueue(async () => {
          await r.handle(event);
        });
      }
    }
  }
}
```

---

### 4) 使い方（ユースケース側のイメージ）🧾

「保存→配る」の順が自然だよ💾➡️📣
（保存前に配ると、失敗時の整合性が崩れやすい😵‍💫）

```ts
// 例：注文支払いユースケース
async function payOrder(orderId: string) {
  const order = await orderRepo.getById(orderId);

  order.pay(); // ← ここで Domain Event を “ためる” 想定（第12章）
  const events = order.pullDomainEvents();

  await orderRepo.save(order);      // 💾 先に保存
  await dispatcher.dispatch(events); // 📣 それから配る（syncは待つ）
}
```

---

## 🕰️ 「順序が必要」になったときの設計パターン集✨

### パターンA：同期ハンドラの中で“直列await”する✅

* 依存がある
* 絶対に順番を守りたい
  → 直列がいちばん安全🧱

### パターンB：「順序」を“状態”で守る（おすすめ✨）

* あるイベントを受けたら、次のイベントが起きる条件を満たしたかチェックする
* 満たしてなければ保留（または無視）

つまり「順序に依存」じゃなくて「状態に依存」にする感じ🌊
これができると、非同期でも強いよ💪

### パターンC：並列にしていいものだけ `Promise.all` ⚡

* 通知Aと通知Bみたいに無関係
* 失敗しても本体を止めない
  → 速くて気持ちいい🫶

---

## 🧯 よくある落とし穴あるある（そして対策）😭➡️😎

### ❶ 非同期ハンドラに「ルールチェック」を入れちゃう

* 例：「在庫がなかったらエラー」みたいなのを後回しにする
  → ユースケースが成功したのに後で失敗して地獄😇
  ✅ **不変条件/必須の失敗は同期側へ**🔒

### ❷ `Promise.all` で “順序がある前提” を壊す

→ 「メールが先に飛んでからDBが更新」みたいな事故が起きる💥
✅ **順序が要るなら直列await**🕰️

### ❸ 非同期の失敗を気づかない（ログもない）

→ 静かに落ちて、あとで「なんで通知来てないの？」となる😵
✅ 最低限 `try/catch + ログ` は入れる📌
（本格運用は後の章：リトライ/Outbox/監視へ🔁）

---

## 📝 演習（ミニECでやってみよう）🎀

### 演習1️⃣：同期/非同期の分類📌

次を「同期」「非同期」に分けて、理由も1行で書いてね✍️✨

* A) 在庫確保
* B) 注文ステータス更新
* C) 購入完了メール
* D) 売上集計へ送信
* E) ポイント付与

🎯 目標：**Q1〜Q4の質問で説明できる**こと💡

---

### 演習2️⃣：順序が必要なものに “order” をつける🕰️

`OrderPaid` のハンドラを3つ考えて、順序が必要なら `order` を付けよう🎯
例：

* 在庫確保（sync, order=10）
* 領収書採番（sync, order=20）
* メール送信（async, order=100）

---

### 演習3️⃣：直列/並列の違いを体感しよう⚡🐢

「順序いらない2つの通知」を `Promise.all` にしてOKか考えてみてね👀

* どんな条件ならOK？
* どんな条件ならNG？

---

## 🤖 AI活用プロンプト集（コピペOK）🧠💖

### ✅ 同期/非同期の判断を手伝ってもらう

* 「この処理は同期/非同期どっちが良い？Q1〜Q4で理由つきで答えて」
* 「このハンドラが同期だと遅くなりそう。非同期にして困ることを列挙して」

### ✅ 順序依存を見つける

* 「この処理群に “順序が必要な依存” があるかチェックして。依存があるなら理由を説明して」
* 「順序が必要と言ってるけど、状態遷移（イベント分割）で解決できる形に変えて提案して」

### ✅ 実装レビュー

* 「このdispatcher実装で、awaitの順序保証が必要な場所はどこ？事故ポイントも教えて」
* 「Promise.all にして良い箇所とダメな箇所を分類して」

---

## ✅ まとめ（ここだけは覚えてね）🌟

* 同期/非同期は「今の処理で待つか」「あとでやるか」📌
* 迷ったら **Q1〜Q4**（今必要？失敗したら止める？遅い？リトライ？）で判断✨
* 順序が要るなら **直列await** が基本🕰️
* もっと強くするなら「順序」じゃなく「状態（イベント分割）」で守るのがコツ🧩
* 非同期は失敗・重複が現実に起きるので、次の章以降（最終的整合性/冪等性/Outbox）で強化していくよ🔁🚀 ([MDN Web Docs][3])

[1]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function?utm_source=chatgpt.com "async function - JavaScript - MDN Web Docs"
