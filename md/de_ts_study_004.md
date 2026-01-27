# 第4章 TypeScript基礎おさらい（イベント用）🔷🧩

## 4.0 今どきのTypeScript事情（超ミニ）🗞️✨

2026年1月時点だと、TypeScriptは **5.9系** が安定版として提供されています（例：5.9.3）。([GitHub][1])
（この章で扱う「リテラル型・readonly・ユニオン型・型ガード」は、5.xでずっと“ど真ん中”の基礎だよ〜😊）

---

## 4.1 この章のゴール🎯💖

この章が終わると、こんなことができるようになります👇✨

* イベントを **「型」で安全に扱う**（間違ったイベント名をコンパイルで止める🚫）
* イベントを **readonly** にして「勝手に書き換え」事故を減らす🔒
* イベントを **ユニオン型** でまとめて、`switch` で分岐できる⚖️
* 外から来る`unknown`なデータを **型ガード** で安全にイベント化する🛡️

---

## 4.2 まずイベント名を「リテラル型」で固定しよう🏷️✨

イベント名は「文字列」だけど、ただの`string`にしちゃうと危険⚠️
`"OrderPaid"`のつもりで `"OrderPiad"` みたいなタイポでも、`string`だと通っちゃう🥲

ここは **文字列リテラル型** を使って「許可された名前だけ」にします💪✨ ([TypeScript][2])

### ✅ いちばん簡単：ユニオン型でイベント名を列挙🧾

```ts
export type EventType =
  | "OrderPlaced"
  | "OrderPaid";
```

これで `EventType` は **2つの文字列しか許さない** 型になるよ🙌

---

## 4.3 `as const`で「配列からEventTypeを作る」📦➡️🏷️

イベントが増えると、ユニオンを手で書くのがだるい…😵‍💫
そこで「配列を1個作って、そこから型を作る」テクが便利✨

`as const`（constアサーション）を使うと、配列の中身が **リテラル型として固定** されます。([TypeScript][3])

```ts
export const EVENT_TYPES = ["OrderPlaced", "OrderPaid"] as const;

export type EventType = typeof EVENT_TYPES[number];
//   ^ "OrderPlaced" | "OrderPaid" になる🎉
```

### 💡 ここ大事（初心者つまずきポイント）⚠️

`as const`がないとこうなる👇（イベント名がただの`string`に“広がる”ことがある）

* 「固定したいのに、固定されない」＝型のメリットが減る😢

---

## 4.4 イベントは「勝手に変わらない」でいてほしい：`readonly`🔒🧊

イベントは「起きた事実」なので、あとから内容が書き換わるのって怖いよね😱
TypeScriptでは `readonly` をつけると、**代入（書き換え）を型チェックで禁止**できます。([TypeScript][4])

### ✅ 共通フォーマット（基本形）🧾✨

```ts
export type DomainEvent<TType extends string, TPayload> = {
  readonly eventId: string;
  readonly occurredAt: string;   // まずはISO文字列でOK🕰️
  readonly aggregateId: string;
  readonly type: TType;
  readonly payload: TPayload;
};
```

> `readonly`は「実行時に凍結する」わけじゃなくて、**型チェック上で禁止**してくれる仕組みだよ🧠✨ ([TypeScript][4])

---

## 4.5 payloadはイベントごとに違う：ユニオン型でまとめる🔀🎁

イベントごとにpayloadの形が違うのが普通だよね😊
そこで、イベントを **ユニオン型** でまとめて、`type`で判別できるようにします✨（これが「判別可能ユニオン」的な考え方🌈）([TypeScript][5])

### ✅ イベント型を2つ作る（例：注文作成・支払い完了）🛒💳

```ts
export type OrderPlaced = DomainEvent<
  "OrderPlaced",
  {
    readonly orderId: string;
    readonly customerId: string;
    readonly total: number;
  }
>;

export type OrderPaid = DomainEvent<
  "OrderPaid",
  {
    readonly orderId: string;
    readonly paidAt: string;
    readonly method: "card" | "bank";
  }
>;

export type AppEvent = OrderPlaced | OrderPaid;
```

### ✅ `switch`で安全に分岐できる🎛️✨

TypeScriptは`type`を見て、payloadの型を絞り込み（narrowing）してくれます💡 ([TypeScript][6])

```ts
export function handleEvent(e: AppEvent) {
  switch (e.type) {
    case "OrderPlaced":
      console.log("total =", e.payload.total);
      break;

    case "OrderPaid":
      console.log("method =", e.payload.method);
      break;
  }
}
```

---

## 4.6 型ガード：`unknown`から安全にイベントへ🛡️👀

外部から来るデータ（JSONなど）は、まず`unknown`として受けるのが安全✨
そして「本当にイベントっぽい形？」をチェックしてから `AppEvent` にします✅

型ガードは「条件で型を絞る」ための仕組みだよ〜！([TypeScript][7])

---

### 4.6.1 型ガード3パターン（最低限これでOK）🧰✨

#### ① `typeof`（プリミティブ判定）🔍

```ts
function isString(v: unknown): v is string {
  return typeof v === "string";
}
```

`typeof`による絞り込みはTypeScriptの基本テクだよ🧠([TypeScript][6])

#### ② `in`（プロパティがあるか）🏷️

```ts
function hasProp(obj: object, key: string): obj is Record<string, unknown> {
  return key in obj;
}
```

`in`で「そのキーがある」ことをチェックして絞り込めるよ✨([TypeScript][7])

#### ③ 「自作の型ガード関数」（`v is AppEvent`）🧪

これが一番“イベントっぽい”やつ😆✨

```ts
type AnyObj = Record<string, unknown>;

function isRecord(v: unknown): v is AnyObj {
  return typeof v === "object" && v !== null;
}

function hasStringField(obj: AnyObj, key: string): boolean {
  return typeof obj[key] === "string";
}

export function isAppEvent(v: unknown): v is AppEvent {
  if (!isRecord(v)) return false;

  // 必須フィールドが文字列かチェック🧾
  if (!hasStringField(v, "eventId")) return false;
  if (!hasStringField(v, "occurredAt")) return false;
  if (!hasStringField(v, "aggregateId")) return false;
  if (!hasStringField(v, "type")) return false;

  // payloadがあるか（中身はイベントごとにさらに検証してもOK）🎒
  if (!("payload" in v)) return false;

  // typeが許可されたものか🏷️
  return v.type === "OrderPlaced" || v.type === "OrderPaid";
}
```

> 「ユニオンのどれか？」の判定は、`type`が**リテラルで固定**されてると超やりやすいよ😊([TypeScript][5])

---

## 4.7 “広がっちゃう”事故（widening）と対策⚠️🧯

TypeScriptはたまに、リテラルを **`string`に広げちゃう**ことがあるよ〜🥲
この章で超重要なのは、「イベント名は広げない」こと！

### ありがちな事故😵‍💫

```ts
const e = {
  type: "OrderPlaced",
  payload: { orderId: "o1", customerId: "c1", total: 1000 },
};
// e.type が "OrderPlaced" じゃなくて string っぽく扱われて困ることがある…💥
```

### 対策①：`as const`で固定する🔒

```ts
const e = {
  type: "OrderPlaced",
  payload: { orderId: "o1", customerId: "c1", total: 1000 },
} as const;
```

`as const`は「できるだけ具体的な型（リテラル型）で推論」してくれる仕組みだよ✨([TypeScript][3])

### 対策②：`satisfies`で“満たしてるか”だけ確認する✅（便利！）

`:`で型注釈しちゃうと、推論が弱くなることがあるけど、`satisfies`は「チェックしつつ推論を保つ」方向💡([TypeScript][8])

```ts
type EventTypeToPayload = {
  OrderPlaced: { orderId: string; customerId: string; total: number };
  OrderPaid: { orderId: string; paidAt: string; method: "card" | "bank" };
};

const samplePayloads = {
  OrderPlaced: { orderId: "o1", customerId: "c1", total: 1000 },
  OrderPaid: { orderId: "o1", paidAt: "2026-01-27T00:00:00Z", method: "card" },
} satisfies EventTypeToPayload;
```

---

## 4.8 ミニ演習（手を動かすやつ）📝💪✨

### 演習1：イベント名ユニオンを作る🏷️

次を作ってみよう👇

* `type EventType = "OrderPlaced" | "OrderPaid"` ✅（ロードマップのやつ！）

### 演習2：共通イベント型を作る🧾

* `DomainEvent<TType, TPayload>` を作る
* `eventId / occurredAt / aggregateId / type / payload` を `readonly` にする🔒

### 演習3：`switch`で分岐してpayloadに触る🎛️

* `AppEvent = OrderPlaced | OrderPaid` を作る
* `switch (e.type)` で `total` と `method` を取り出す💳

### 演習4：型ガードを3種類書く🛡️

* `typeof`を使うやつ
* `in`を使うやつ
* `v is AppEvent` を返すやつ（自作型ガード）

---

## 4.9 AI活用（そのままコピペOK）🤖🪄💬

### ✨ イベント名・payload設計のたたき台

* 「`OrderPlaced`と`OrderPaid`のpayloadを、最小限で2案ずつ提案して。個人情報は入れないで。使う側が困らない形にして。」

### ✨ 型ガードを3パターン生成してもらう（ロードマップ準拠）

* 「TypeScriptで `unknown` を `AppEvent` にする型ガードを3パターン。`typeof` / `in` / 自作型ガード（type predicate）でお願い。初心者向けコメント多めで。」

### ✨ widening事故チェック

* 「このコードで `type` が `string` に広がる可能性ある？あるなら修正案を2つ（`as const`と`satisfies`）で出して。」

---

## 4.10 まとめ（この章の“芯”）🌟

* イベント名は **リテラル型** で固定する🏷️ ([TypeScript][2])
* イベントは **readonly** で「書き換え事故」を減らす🔒 ([TypeScript][4])
* イベントは **ユニオン型＋`type`** で分岐すると強い🎛️ ([TypeScript][5])
* 外から来るものは **型ガード** で安全に扱う🛡️ ([TypeScript][7])

次章からは「混ぜない（SoC）」「境界」みたいな“設計の入口”に入っていくよ〜🧱✨

[1]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[2]: https://www.typescriptlang.org/docs/handbook/literal-types.html?utm_source=chatgpt.com "Handbook - Literal Types"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-4.html?utm_source=chatgpt.com "Documentation - TypeScript 3.4"
[4]: https://www.typescriptlang.org/docs/handbook/2/objects.html?utm_source=chatgpt.com "Documentation - Object Types"
[5]: https://www.typescriptlang.org/docs/handbook/unions-and-intersections.html?utm_source=chatgpt.com "Handbook - Unions and Intersection Types"
[6]: https://www.typescriptlang.org/docs/handbook/2/narrowing.html?utm_source=chatgpt.com "Documentation - Narrowing"
[7]: https://www.typescriptlang.org/docs/handbook/advanced-types.html?utm_source=chatgpt.com "Documentation - Advanced Types"
[8]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html?utm_source=chatgpt.com "Documentation - TypeScript 4.9"
