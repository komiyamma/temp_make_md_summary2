# 第32章 イベントのバージョニング戦略（どう進化させる？）🔖🔢

## この章のゴール 🎯✨

* ドメインイベントを**壊さずに進化**させるための「バージョンの持ち方」を選べるようになる 🧠✅
* 変更が入ったときに、**移行の手順**（段階的に変える流れ）を組めるようになる 🪜🚚
* TypeScriptで「v1 / v2 を安全に扱う」実装パターン（例）を手元に持てる 🧩🔷

---

## 1. まず「互換性」ってなに？💡🔁

イベントは「未来の自分・他機能・別プロセス」が読む**契約（Contract）**だったよね 🤝📜
だから変更するときは、最低でもこの2つを意識するよ〜！👀

### 後方互換（Backward compatibility）🕰️➡️🆕

* **新しい読む側**が、**古いイベント**も読める状態
* 例：v1のイベントが残ってても、最新版の処理が止まらない ✅
  （イベントの世界では特に大事！） ([Confluent Documentation][1])

### 前方互換（Forward compatibility）🆕➡️🕰️

* **古い読む側**が、**新しいイベント**を受け取っても壊れない状態
* 例：知らないフィールドが増えても「無視して動ける」みたいな感じ ✅ ([Confluent][2])

> 理想は「両方OK（FULL）」だけど、現実は段階移行で近づけるのが多いよ〜🧸🧩 ([Confluent Documentation][1])

---

## 2. バージョンの持ち方 3パターン 🔖🔢🧠

この章のアウトラインにあった3つを、**迷わないように**整理するね！📦✨

### A) `version` フィールド方式（おすすめ寄り）✅🔖

イベントの形は同じで、メタ情報に `version` を持つ方式。

* 例：`type: "OrderPlaced"` は固定、`version: 1 / 2` が増える
* いいところ 👍

  * `type` が増えすぎない 🗂️
  * **同じ出来事**の進化だと分かりやすい ✨
  * upcast（後で説明）と相性がいい 🔁
* 気をつけるところ ⚠️

  * 読む側が `version` を見て分岐・変換する必要あり

---

### B) `type` にバージョンを含める方式 🏷️🔢

* 例：`type: "OrderPlaced.v1"` / `type: "OrderPlaced.v2"`
* いいところ 👍

  * ルーティングがラク（文字列で分けられる）📬
  * v1とv2を「別物」として扱いやすい 🧩
* 気をつけるところ ⚠️

  * `type` が増えやすい（一覧が膨らみやすい）📚💦
  * 「同じ出来事の進化」なのに、別イベントっぽく見えることも

---

### C) 段階的廃止（古いのも一定期間受ける）🕰️🧹

これは「持ち方」ってより**運用のやり方**だよ〜！🛠️

* v2を出しても、いきなりv1を捨てない
* 一定期間は **v1も受けて動かす**（または変換して動かす）
* 廃止タイミングを決めて、ログ/監視しつつ片付ける 🧾🔔

---

## 3. どれを選ぶ？🤔🧭（超実用の選び方）

### まず迷ったら：A（`version` フィールド）＋ 段階的廃止（C）💞🔖🕰️

理由はシンプル👇

* 「同じ出来事」を保ちながら進化できる
* 古いイベントが混ざってても、**読む側で吸収**しやすい（upcast）
* 実運用では「いきなり全員同時に更新」ができないことが多いから 🥲🔁

ちなみに「upcast（アップキャスト）」は、古いイベントを**読む瞬間に新しい形へ変換**する考え方だよ〜！ ([MartenDB][3])

---

## 4. “壊さない変更”の鉄板ルール 🧱✅✨

イベントの変更で事故りやすいのは、このへん👇😵‍💫

### ✅ 安全寄り（やりやすい）

* **フィールド追加**（しかも optional にする）➕🧸
* 既存フィールドの意味を変えない（そのままにする）🫶
* 「新フィールドを使うのは新しい読む側だけ」でもOK

スキーマ運用の世界でも「新規フィールドは optional」「リネームは避ける」が王道だよ〜！ ([Solace Documentation][4])

### ⚠️ 危険寄り（破壊になりがち）

* フィールド削除 🗑️💥
* フィールド名のリネーム（実質削除＋追加と同じで壊れやすい）🔁💥 ([Solace Documentation][4])
* 型の変更（number→string など）🔄💥
* 意味の変更（同じ名前なのに意味が変わるのが一番怖い）🫠

---

## 5. バージョン番号の考え方（SemVer と混同しない）🧠🔢

アプリのバージョンに **SemVer（MAJOR.MINOR.PATCH）** があるけど、イベントの `version` は「イベントの形（スキーマ）の世代」を表すことが多いよ〜！🔖

SemVerの基本ルール（互換性の増減）はこう👇 ([Semantic Versioning][5])

* 破壊的変更 → MAJOR
* 後方互換の機能追加 → MINOR
* 後方互換のバグ修正 → PATCH

イベントの `version` にも、発想としては似たものを持ち込める（＝壊すときは大きく上げる）けど、**ここでは「イベントスキーマの版」**として扱うと混乱しにくいよ 🧸📌

---

## 6. 段階移行のテンプレ（これ覚えると強い）🪜🚀

「v1 → v2」に変えたいときの**よくある安全手順**だよ〜！✨

### ステップ 0：方針決定 🧭📝

* 何が変わる？（追加？リネーム？意味変更？）
* **追加で済ませられないか**最初に考える（壊さないのが最強）🛡️

### ステップ 1：読む側を先に強くする 🛡️📥

* v2を出す前に、読む側を「v1でもv2でも落ちない」状態へ
* 方法は2つ

  1. **両対応ハンドラ**（versionで分岐）
  2. **upcast層**で v1→v2 に変換してから処理（おすすめ）🔁 ([MartenDB][3])

### ステップ 2：出す側が v2 を出し始める 📤✨

* `version: 2` のイベントを出す
* v1も混ざり得る期間を許容する（現実）🕰️

### ステップ 3：観測して「v1が来なくなった」を確認 👀📈

* ログ/メトリクスで「v1受信数」を見る
* 0が続いたら次へGO ✅

### ステップ 4：廃止（v1サポート削除）🧹🗑️

* upcastや分岐を消す
* 仕様（ドキュメント）も更新する 📝

---

## 7. TypeScript実装例：`version` フィールド方式＋upcast 🔖🔁🔷

ここでは「`type` は固定」「`version` で世代管理」「内部は v2 だけで処理」を作るよ〜！🧸✨
（※読み込んだ瞬間に v2 へ変換しちゃうのがポイント！）

```ts
// 共通フォーマット（Chapter 9でやった形をベースに）🧾✨
export type DomainEvent<TType extends string, TPayload> = {
  eventId: string;
  occurredAt: string;     // ISO文字列
  aggregateId: string;
  type: TType;
  version: number;        // ★ここが今回の主役
  payload: TPayload;
};

// v1 payload 🧩
export type OrderPlacedPayloadV1 = {
  orderId: string;
  userId: string; // v2で customerId に変えたくなった想定
  items: Array<{ sku: string; qty: number }>;
  total: number;
};

// v2 payload 🧩✨（新フィールドも追加した想定）
export type OrderPlacedPayloadV2 = {
  orderId: string;
  customerId: string;
  lines: Array<{ sku: string; quantity: number }>;
  total: number;
  currency: "JPY" | "USD";
};

// v1 / v2 のイベント型 📨
export type OrderPlacedV1 = DomainEvent<"OrderPlaced", OrderPlacedPayloadV1> & { version: 1 };
export type OrderPlacedV2 = DomainEvent<"OrderPlaced", OrderPlacedPayloadV2> & { version: 2 };

// 受信時点では v1/v2 どっちも来る想定 🤹‍♀️
export type OrderPlacedAny = OrderPlacedV1 | OrderPlacedV2;

// upcast: v1 → v2 に寄せる 🔁✨
export function upcastOrderPlaced(event: OrderPlacedAny): OrderPlacedV2 {
  if (event.version === 2) return event;

  // v1 → v2 変換（「埋める」「置き換える」「構造変換」）🧩➡️✨
  return {
    ...event,
    version: 2,
    payload: {
      orderId: event.payload.orderId,
      customerId: event.payload.userId, // rename吸収
      lines: event.payload.items.map((x) => ({ sku: x.sku, quantity: x.qty })), // 構造変換
      total: event.payload.total,
      currency: "JPY", // デフォルト埋め（ルールで決める）💴
    },
  };
}
```

### upcast方式のうれしさ 😋💞

* アプリの中身は **v2だけ**を考えればOK（脳がラク）🧠✨
* 変換は1か所に集まる（修正も1か所）🧹
* 「古いイベントが混ざってる」現実に強い 💪🕰️

---

## 8. 実装例：ディスパッチ側は “最新版で固定” 📣✅

```ts
import { upcastOrderPlaced, OrderPlacedAny, OrderPlacedV2 } from "./events";

type Handler<E> = (event: E) => Promise<void> | void;

// v2だけ受け取るハンドラ ✅
const onOrderPlaced: Handler<OrderPlacedV2> = async (e) => {
  // ここは v2 の型しか来ない前提で書ける ✨
  console.log("customerId:", e.payload.customerId);
  console.log("currency:", e.payload.currency);
};

export async function dispatch(event: { type: string; version: number; payload: unknown } & Record<string, any>) {
  // 本当は type で分岐する（ここでは1個だけ例）🧸
  if (event.type === "OrderPlaced") {
    const v2 = upcastOrderPlaced(event as OrderPlacedAny);
    await onOrderPlaced(v2);
  }
}
```

---

## 9. 演習：ミニECで「バージョン方針」を決める 🛒📝✨

### お題 🎁

`OrderPlaced` のpayloadを進化させたい！

* v1：`userId`, `items[].qty`
* v2：`customerId`, `lines[].quantity`, `currency` を追加したい 💴✨

### やること ✅

1. **どの方式で持つか**選ぶ（A/B）🔖
2. 「壊さない変更でいけるか？」をまず検討する 🛡️
3. v1→v2 の **移行手順（ステップ0〜4）**を文章で書く 📝
4. upcast関数を実装（上の例を参考に）🔁

### できたら最高ポイント 🌟

* `currency` のデフォルトは？（JPY固定？注文データから推測？）💴🤔
* リネーム（userId→customerId）は「同じ意味」？それとも意味が違う？🧠

  * もし意味が違うなら、**同じイベントの進化じゃなくて別イベント**を考えるのもアリ（契約の誠実さ）🤝📜

---

## 10. AIメモ：バージョン設計を崩さないための質問テンプレ 🤖🧠✨

* 「この変更は後方互換を壊す？壊すなら理由は？」🧯
* 「追加フィールドで済ませる案を3つ」➕
* 「v1→v2のupcastで、埋めるべきデフォルト値の候補」🧩
* 「廃止までの段階計画（観測指標込み）をチェックリスト化」📋🔔

---

## 11. 章末チェックリスト ✅📋

* [ ] `type` は「出来事の意味」を保ててる？（意味が変わるなら別イベント検討）🏷️🧠
* [ ] 新フィールドは optional / デフォルトで吸収できる？➕🧸 ([Solace Documentation][4])
* [ ] 読む側は v1/v2 混在でも落ちない？🛡️
* [ ] upcast（変換）が1か所に集約されてる？🔁 ([MartenDB][3])
* [ ] 「v1が来なくなった」を確認する観測がある？👀📈
* [ ] 廃止のタイミングが決まってる？🕰️🧹

[1]: https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html?utm_source=chatgpt.com "Schema Evolution and Compatibility for Schema Registry ..."
[2]: https://developer.confluent.io/patterns/event-stream/schema-compatibility/?utm_source=chatgpt.com "Schema Compatibility"
[3]: https://martendb.io/events/versioning.html?utm_source=chatgpt.com "Events Versioning"
[4]: https://docs.solace.com/Schema-Registry/schema-registry-best-practices.htm?utm_source=chatgpt.com "Best Practices for Evolving Schemas in Schema Registry"
[5]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
