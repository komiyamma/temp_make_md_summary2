# 第9章 イベントの“型”を設計する（共通フォーマット）🧾🛡️

## 9.1 なぜ「共通フォーマット」が必要なの？🤔💡

ドメインイベントって、増えるほど「取り回し」が大事になります📦✨
共通フォーマットにしておくと、いいことがいっぱい👇

* どのイベントも同じ形だから、ログ・保存・配信のコードが共通化できる🧩
* `type` で分岐するときに TypeScript がちゃんと助けてくれる（安全！）🛡️
* `eventId` で「二重処理」を防ぐ土台になる🔁🧷
* `occurredAt` が揃ってると、時系列で追いやすい🕰️👀

この章では、イベントを「同じ箱（フォーマット）」で運べるようにします📦🚚

---

## 9.2 共通フォーマットの“最低限セット”🧾✅

まずはこの5つを固定します👇

* `eventId`：イベント1個に1つのユニークID🆔
* `occurredAt`：その出来事が起きた時刻（文字列）🕰️
* `aggregateId`：どの集約（例：注文）で起きたか🧱
* `type`：イベント名（例：`OrderPlaced`）🏷️
* `payload`：その出来事の中身（必要最小限）🎒

この5つが揃うと、**イベントを「同じルール」で扱える**ようになります😊✨

---

## 9.3 `eventId` は何を使う？（UUID v4 / UUID v7 / ULID）🆔🧠

`eventId` は「世界で一意」が理想です🌍✨
よく使われる選択肢はこのへん👇

### A) UUID v4（ランダム）🎲

* 生成が簡単で、だいたい困らない👍
* ブラウザでも `crypto.randomUUID()` が使える（v4 UUID）🌐✨ ([MDN Web Docs][1])
* Node.js でも `crypto.randomUUID()` が使える（v4 UUID）🟩✨ ([Node.js][2])

### B) UUID v7（時系列に並びやすい）⏱️

* RFC 9562 で定義されている “時間順” UUID（Unix epoch ミリ秒由来）🕰️ ([rfc-editor.org][3])
* ログや保存で「新しい順」に並べたいときに便利📈

### C) ULID（時系列に並びやすい＆短め）📏

* 26文字で、辞書順ソートが時系列になる設計📚⏱️ ([GitHub][4])
* 文字列として扱いやすいのが好きならアリ🙆‍♀️

この教材ではまず **UUID v4** でOKにして、必要になったら v7/ULID を検討する流れがラクです😊

---

## 9.4 `occurredAt` は “文字列” にするのが基本🕰️📝

イベントは保存したり、別プロセスに渡したりします📤
そのとき `Date` オブジェクトのままだと、JSON化で事故りやすい💥

なので `occurredAt` は **ISO 8601 の文字列**が鉄板です👇

* `new Date().toISOString()` で作れる（例：`2026-01-27T03:00:00.000Z`）🧊

ポイントはこれ👇

* **イベントが起きた瞬間**の時刻にする（「保存した時刻」じゃない）⏳
* 文字列で統一（DB・ログ・キューで崩れない）🧱

---

## 9.5 TypeScriptで「イベントの型」を作ろう🔷🧩

ここから実装です💻✨
目標はこれ👇

* `type` によって `payload` の型が自動で決まる🎯
* 間違った payload を入れたらコンパイルで怒られる😾（＝安全）

### 9.5.1 イベントpayloadの対応表を作る📚

まず「イベント名 → payload型」の対応表を作ります👇

```ts
// ✅ ここが「イベント辞書」だよ📚✨
export type EventPayloads = {
  OrderPlaced: {
    orderId: string;      // aggregateId と同じでもOKだけど、payloadにも入れるかは設計次第🙂
    customerId: string;
    totalAmount: number;  // VOで守ってても、イベントはプリミティブに寄せることが多いよ🧱
    currency: "JPY" | "USD";
  };

  OrderPaid: {
    orderId: string;
    paymentId: string;
    paidAmount: number;
    paidAt: string;       // occurredAt と別に「支払いが完了した時刻」が欲しいなら入れる⏱️
  };
};
```

💡コツ

* payload は「**その出来事に必要な事実**」に絞る🎒✨
* あとでDB参照で取れる情報（住所の全文、商品詳細ぜんぶ等）は入れすぎ注意🙅‍♀️

---

### 9.5.2 `DomainEvent` の共通型を作る🧾🛡️

```ts
export type DomainEvent<TType extends keyof EventPayloads> = {
  eventId: string;
  occurredAt: string;         // ISO文字列
  aggregateId: string;
  type: TType;
  payload: EventPayloads[TType];

  // 🍀 おまけ：将来のためのメタ情報置き場（任意）
  meta?: {
    correlationId?: string;   // 追跡用（あとで第24章で効いてくるやつ👀🔗）
    causationId?: string;     // 「何が原因で起きた？」用
    version?: number;         // イベント進化に備える（第32章につながる🔖）
  };
};

// 便利：全イベントのUnion型
export type AnyDomainEvent = {
  [K in keyof EventPayloads]: DomainEvent<K>
}[keyof EventPayloads];
```

これで、`AnyDomainEvent` はこんな感じになります👇

* `type: "OrderPlaced"` のとき payload は OrderPlaced 型
* `type: "OrderPaid"` のとき payload は OrderPaid 型
  🎉🎉🎉

---

## 9.6 “作る人”がラクになる：`createDomainEvent()` を用意しよう🪄🧰

毎回 `eventId` と `occurredAt` 手打ちはつらい…😵‍💫
なので工場（関数）を作ります🏭✨

```ts
import { randomUUID } from "node:crypto"; // Nodeならこれ🟩✨ :contentReference[oaicite:4]{index=4}
import type { DomainEvent, EventPayloads } from "./domainEventTypes";

export function createDomainEvent<TType extends keyof EventPayloads>(args: {
  type: TType;
  aggregateId: string;
  payload: EventPayloads[TType];
  meta?: DomainEvent<TType>["meta"];
}): DomainEvent<TType> {
  return {
    eventId: randomUUID(),            // v4 UUID を生成🎲 :contentReference[oaicite:5]{index=5}
    occurredAt: new Date().toISOString(),
    aggregateId: args.aggregateId,
    type: args.type,
    payload: args.payload,
    meta: args.meta,
  };
}
```

✅ これでイベント生成はこうなる👇

```ts
const ev = createDomainEvent({
  type: "OrderPlaced",
  aggregateId: "order_123",
  payload: {
    orderId: "order_123",
    customerId: "cust_9",
    totalAmount: 3500,
    currency: "JPY",
  },
});
```

---

## 9.7 “使う人”がラクになる：`type` で安全に分岐しよう🚦✨

`AnyDomainEvent` は `type` がタグ（目印）なので、分岐が超きれいになります😍

```ts
import type { AnyDomainEvent } from "./domainEventTypes";

export function handleEvent(event: AnyDomainEvent) {
  switch (event.type) {
    case "OrderPlaced":
      // ✅ ここでは payload が OrderPlaced 型に確定する🎯
      console.log(event.payload.totalAmount);
      return;

    case "OrderPaid":
      // ✅ ここでは payload が OrderPaid 型に確定する🎯
      console.log(event.payload.paymentId);
      return;

    default: {
      // ✅ 将来イベントが増えたとき「分岐漏れ」を検知する保険🧯
      const _exhaustive: never = event;
      return _exhaustive;
    }
  }
}
```

この `never` のやつ、地味だけど超強いです🧯💖
イベントが増えたのに `switch` 直し忘れた！が減ります✨

---

## 9.8 JSONで渡す前提：シリアライズの注意点⚠️📦

イベントはだいたい JSON で渡ります📨
そこで注意👇

* `payload` に関数やクラスインスタンスを入れない🙅‍♀️（JSON化で壊れる）
* `occurredAt` は文字列のまま（Dateに戻すなら受け側で）🧊
* `payload` は「巨大化」しやすいから最小限🎒

---

## 9.9 “よくある失敗”あるある集😇💥

### 失敗1：`payload` に詰め込みすぎ🎒💣

「後で便利そうだから全部入れとこ！」は、未来の自分を苦しめます😵‍💫
イベントは **契約**なので、肥大化すると変更が怖くなる🧟‍♀️

✅ 対策

* 「今このイベントを受け取った人が必要な事実だけ」にする
* それ以外は `aggregateId` で参照して取る（あとで）🔎

---

### 失敗2：`type` が命令形になってる📮❌

`SendEmail` みたいなのは「やること」であって「起きた事実」じゃない😇

✅ 良い例

* `OrderPaid`（支払いが完了した）💳✅
* `ShipmentRequested`（発送が依頼された）📦✅

---

### 失敗3：`occurredAt` がバラバラ🕰️🌀

ローカル時刻、ISO、UNIX秒…混ざると、並べたとき地獄です😱

✅ 対策

* `occurredAt: ISO文字列` で統一🧊

---

### 失敗4：`eventId` を “連番” にしてしまう🔢💥

複数マシン・複数プロセスになった瞬間にぶつかります😵
UUID/ULID など「分散で安全」なものを使うのが基本です🆔✨ ([rfc-editor.org][5])

---

## 9.10 演習（ミニECでやってみよ〜！）🛒🧪💖

### 演習1：イベント辞書を増やす📚✨

第2章で出したイベント候補から、最低3つ追加してみよう👇
例：`ShipmentStarted`, `OrderCanceled`, `CustomerNotified` など📦📩

* `EventPayloads` に追加
* `AnyDomainEvent` が自動で増えるのを確認👀✨

---

### 演習2：型で “事故” を起こしてみる😈🧨

わざと間違った payload を入れて、エラーを見よう👇

* `totalAmount` を文字列にしてみる
* `currency` に `"EUR"` を入れてみる

TypeScript先生に怒られたら成功です😼✅

---

### 演習3：ハンドラで分岐（`never`保険つき）🚦🧯

`handleEvent()` を作って、各イベントで `console.log` でもいいから処理を書いてみよう📝✨
最後に `never` の分岐漏れ検知も入れてね💖

---

## 9.11 AI活用（レビューしてもらうと爆速）🤖⚡

### 使えるお願い①：payload詰め込みチェック🎒🔍

「この payload、詰め込みすぎ？」を聞く✨

* 追加で「参照で取れる情報はどれ？」も聞くと◎

### 使えるお願い②：イベント辞書からUnion型を整える🧩✨

「`EventPayloads` から `DomainEvent` と `AnyDomainEvent` を作る型を提案して」
→ ほぼこの章のコードを自動生成してくれます⚡

### 使えるお願い③：命名チェック🏷️👀

「このイベント名、命令っぽくない？過去形の事実になってる？」
→ 名前のブレが減ります😊✨

---

## 9.12 まとめ🎁✨

この章でやったことはこれ👇

* イベントの共通フォーマット（`eventId`, `occurredAt`, `aggregateId`, `type`, `payload`）を固定した🧾✅
* `type` から `payload` が決まるように TypeScript の型を組んだ🔷🛡️
* 生成関数で「作る側」をラクにした🪄
* `switch` + `never` で「使う側」も安全にした🚦🧯

次の章では、いよいよ **payload を “必要最小限” にするコツ**を深掘りしていきます🎒✨

[1]: https://developer.mozilla.org/ja/docs/Web/API/Crypto/randomUUID "Crypto: randomUUID() メソッド - Web API | MDN"
[2]: https://nodejs.org/api/crypto.html "Crypto | Node.js v25.4.0 Documentation"
[3]: https://www.rfc-editor.org/rfc/rfc9562.html?utm_source=chatgpt.com "RFC 9562: Universally Unique IDentifiers (UUIDs)"
[4]: https://github.com/ulid/spec?utm_source=chatgpt.com "The canonical spec for ulid"
[5]: https://www.rfc-editor.org/rfc/rfc9562.html "RFC 9562: Universally Unique IDentifiers (UUIDs)"
