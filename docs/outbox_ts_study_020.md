# 第20章：契約とバージョン（イベントは将来も残る）🧬🏷️

## この章でできるようになること 🎯✨

* 「イベントの契約（Contract）」って何を指すのか、言葉じゃなく“運用の形”にできる 🙆‍♀️
* payload を変えたいときに **壊さずに進める手順** がわかる 🛠️
* `schemaVersion` を使った **バージョン管理の型** が作れる 🧾
* 受け手（Consumer）が **古いイベントも安全に読める** 仕組みを作れる 🛡️

---

## 20.1 「イベントは未来にも届く」ってどういうこと？🕰️📨

Outbox のイベントって、**送った瞬間だけ存在する**わけじゃないよね。

* 送信が遅れて **数分〜数時間後に届く** ことがある ⏳
* 失敗してリトライされて **明日届く** こともある 🔁
* 監査や調査で **保存されたイベントを後から読み返す** こともある 🕵️‍♀️

つまりイベントは、**未来の誰か（別サービス・別チーム・未来の自分）** が読む “手紙” みたいなもの 💌
だからこそ「契約（Contract）」が超大事になるよ〜！

---

## 20.2 「契約（Contract）」って、何を約束するの？🤝📜

イベントの契約は、ただの「型」だけじゃないよ 🧠✨
ざっくり言うと **“このイベントをこう解釈してね” の約束セット**。

## 契約に入れておくと強いもの 💪📦

* **eventType（何が起きた？）** 🏷️
* **payload（何の情報がある？必須/任意は？）** 📄
* **意味（セマンティクス）** 🧬

  * 金額は「円？税込？端数処理は？」💴
  * 時刻は「UTC？JST？文字列形式は？」🕒
  * `status: "PAID"` は「入金済み？確定？取消不可？」など
* **互換性ルール（変更していい範囲）** ✅⚠️
* **バージョンの付け方（schemaVersion のルール）** 🧾

この章は、その中でも **「互換性ルール」と「バージョンの付け方」** を固める回だよ 📌✨

---

## 20.3 バージョンはどこに持たせる？3つの型 🧩🏗️

イベントのバージョン管理、よくあるのはこの3つ👇

## A) `schemaVersion` をイベントに入れる（おすすめ）🧾✨

* `eventType` は変えず、**中身の版**を `schemaVersion` で表す
* ルーティング（購読）は `eventType` のまま使いやすい 👍

## B) `eventType` 自体にバージョンを入れる 🏷️v1 v2

* `order.confirmed.v1` / `order.confirmed.v2` みたいに分ける
* 受け手は「v2だけ購読」みたいにできて分かりやすい 🙆‍♀️
* ただし eventType が増えやすい（運用が散らかりがち）🌀

## C) “日付バージョン”にする（例：`2026-02`）📅

* 分かりやすいけど、互換性の意味が読み取りにくいことがある 🤔

この教材では **A（schemaVersion）** をメインにするよ ✨

---

## 20.4 後方互換（Backward Compatible）って何？🔄🛡️

**古い受け手でも壊れない変更**のことだよ ✅

## “だいたい安全”な変更 ✅

* フィールドを **追加**（しかも任意）➕
* 新しい値を追加（enum の拡張）※受け手が未知値に耐える前提 🆕
* 新イベントを追加（既存イベントはそのまま）📨➕

## “ほぼ破壊”な変更 ⚠️💥

* フィールドの **削除** ➖
* 型の変更（number → string など）🔧
* 意味の変更（`amount` が “税込” → “税抜” に変わるとか）😱
* 同じ名前で別概念にする（最悪）🌀

ここで便利なのが **SemVer（セマンティックバージョニング）** の考え方だよ 📦
互換性のない変更は **MAJOR**、互換性のある機能追加は **MINOR**、バグ修正は **PATCH**。([Semantic Versioning][1])

---

## 20.5 “壊さずに変える”ための基本戦略 🪜🛠️

## 戦略①：追加して、しばらく両対応（王道）👑

1. v2で新フィールド追加（旧フィールドは残す）➕
2. Consumer は v1/v2 両方読めるようにする 🔄
3. 旧フィールドを **deprecated（非推奨）** にする 🏷️
4. 期限を切って削除（イベントの滞留期間も考える）📅

## 戦略②：Upcaster（アップキャスト）で“最新形”に揃える 🧙‍♀️✨

Consumer 側で、

* v1 を受け取ったら v2 相当に **変換してから** ドメインへ渡す
  ってやり方。

Consumer の中に「過去の歴史」を閉じ込められるのが強みだよ 🧠🔒

---

## 20.6 `schemaVersion` を持つイベント設計（TypeScript例）🧾📦

## 20.6.1 イベントの“外側（Envelope）”を固定する 🧱✨

```ts
export type SchemaVersion = `${number}.${number}.${number}`; // SemVer風（例: "1.0.0"）

export type EventType =
  | "order.confirmed"
  | "order.canceled";

export type OutboxEvent<TPayload> = {
  eventId: string;          // UUIDなど
  eventType: EventType;     // ルーティング用
  schemaVersion: SchemaVersion; // 契約の版
  occurredAt: string;       // ISO文字列（例: 2026-02-03T12:34:56.789Z）
  payload: TPayload;        // 中身
  traceId?: string;         // 観測/追跡用（第21章で本格化）
};
```

ポイントはこれ👇

* `eventType` は **「何が起きたか」**
* `schemaVersion` は **「payload の契約の版」**
  この2つを混ぜないのがコツだよ 🧠✨

---

## 20.6.2 payload を “版” ごとに型で表す 🧩📄

例：注文確定イベントを v1 → v2 に育てる 🌱➡️🌳

```ts
// v1：まず最小
export type OrderConfirmedV1 = {
  orderId: string;
  amountYen: number; // 円固定（v1の割り切り）
};

// v2：通貨対応したくなった！
export type Money = {
  currency: "JPY" | "USD"; // 例
  amount: number;
};

export type OrderConfirmedV2 = {
  orderId: string;
  total: Money;            // v2からはこちら
  amountYen?: number;      // 移行期間だけ残す（deprecated扱い）
};
```

ここが超大事👉

* v2にしたいからって **v1の `amountYen` を即削除しない** 🙅‍♀️
* “移行期間”は **両方持つ** のが平和 🕊️✨

---

## 20.6.3 Consumer 側で Upcaster を作る 🧙‍♀️🔄

<!-- img: outbox_ts_study_020_upcaster.png -->
```ts
type AnyOrderConfirmed =
  | OutboxEvent<OrderConfirmedV1>
  | OutboxEvent<OrderConfirmedV2>;

export function normalizeOrderConfirmed(e: AnyOrderConfirmed): OrderConfirmedV2 {
  if (e.schemaVersion === "1.0.0") {
    // v1 -> v2 に変換（Upcast）
    return {
      orderId: e.payload.orderId,
      total: { currency: "JPY", amount: e.payload.amountYen },
      amountYen: e.payload.amountYen,
    };
  }

  // v2はそのまま
  return e.payload;
}
```

これで Consumer の内部は **常に v2 だけ** 扱えばよくなるよ〜！🥰
“歴史対応”は `normalize...` に隔離できるのが勝ちポイント 🏆

---

## 20.7 JSON Schema を併用すると、契約がもっと強くなる 📜✅

「TypeScriptの型」は便利だけど、**実際に飛んでくるJSON** は `unknown` だよね 😇
だから“機械で検証できる契約書”として **JSON Schema** を持つのはかなり強いよ 💪

JSON Schema は現在 **2020-12** が現行版として案内されてるよ。([json-schema.org][2])

## 例：OrderConfirmed v1 の JSON Schema（超ミニ）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "order.confirmed v1",
  "type": "object",
  "required": ["orderId", "amountYen"],
  "properties": {
    "orderId": { "type": "string" },
    "amountYen": { "type": "number" }
  },
  "additionalProperties": false
}
```

**おすすめ運用** 🗂️✨

* `schemas/order.confirmed/1.0.0.json`
* `schemas/order.confirmed/2.0.0.json`
  みたいに “版ごとに保存” しておくと、未来の自分が助かるよ 🥹🫶

---

## 20.8 CloudEvents という“封筒の標準”もあるよ（知識として）✉️🌍

イベントの“外側（Envelope）”を標準化する仕様に **CloudEvents** があるよ 📦
CloudEvents は `specversion` を持っていて、v1.0 を使う producers は `1.0` を指定する、という形で定義されてるよ。([cloudevents.github.io][3])

Outbox で必須じゃないけど、将来いろんな基盤と繋ぐときに便利になりやすい ✨
（「標準の封筒に入れておく」イメージだよ 📮）

---

## 20.9 破壊的変更（Breaking Change）をどう“段階的廃止”する？🧨➡️🧯

ここ、実務でめっちゃ大事！🥺✨
やることはシンプルに **“一気に壊さない”**。

## 段階的廃止のテンプレ（おすすめ）🪜

* Phase 1：v2 を出す（v1も送る/読める）📨📨
* Phase 2：Consumer を v2 対応に寄せる 🔄
* Phase 3：v1 を deprecated 扱いにして期限を告知 🏷️📅
* Phase 4：期限後に v1 を停止（ただし滞留イベントは考慮）⛔

Outbox は「失敗して滞留」もあるから、**“どのくらい古いイベントが流れてくるか”** を見て期限を決めるのがポイントだよ ⏳✨

---

## 20.10 AI（Copilot/Codex）に手伝ってもらうコツ 🤖💖

## 便利プロンプト例（そのまま投げてOK）📝✨

* 「この payload 変更は後方互換？破壊？理由もつけて判定して」🔍
* 「v1→v2の Upcaster を TypeScript で書いて。null/undefined 対応も入れて」🧙‍♀️
* 「JSON Schema（2020-12）を v2 用に作って。追加プロパティ禁止で」📜
* 「deprecated にしたフィールドを、いつ削除するのが安全か。Outbox滞留を前提に手順を出して」⏳
* 「Consumer 側が未知のフィールド/未知の enum を受けても落ちないパース方針を提案して」🛡️

---

## 20.11 ミニ演習（手を動かす）🧪🎀

## 演習A：v1 を定義して “契約書” を作る 📝

* `OrderConfirmedV1` 型を作る
* v1 の JSON Schema を作る
* “必須/任意” を言語化してメモする（契約！）📜

## 演習B：v2 を追加して“壊さず進化”させる 🌱➡️🌳

* v2で `total: {currency, amount}` を追加
* v1の `amountYen` は残して deprecated 扱いにする
* Consumer に Upcaster を入れて、内部は v2 だけで動くようにする 🧙‍♀️

## 演習C：やっちゃダメを体験する（学習用）😈➡️😇

* `amountYen` を消してみる
* 古いイベントが来たときにどこで壊れるか確認する
* 「どこで検知できたら嬉しい？」を考える（第21章へつながる）🔍📊

---

## 20.12 ここまでのまとめ 🧡✨

* イベントは未来にも届くから、**契約（Contract）** が超重要 💌
* 壊さず変える基本は **追加→両対応→deprecated→削除** 🪜
* `schemaVersion` を持たせて、Consumer は **Upcasterで最新形に揃える** 🧙‍♀️
* JSON Schema を併用すると、契約が“検証できる形”になって強い 📜✅（現行版は 2020-12）([json-schema.org][2])
* SemVer の考え方で「互換性」を言語化できる 🧾([Semantic Versioning][1])

---

## （次章へのつながり）第21章チラ見せ 👀📊

契約とバージョンを整えたら、次は **「観測」**！
未送信件数・遅延・失敗理由・リトライ回数などを見える化して、運用で泣かない設計にしていくよ 🔍✨

[1]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
[2]: https://json-schema.org/specification?utm_source=chatgpt.com "JSON Schema - Specification [#section]"
[3]: https://cloudevents.github.io/sdk-javascript/interfaces/CloudEventV1.html?utm_source=chatgpt.com "CloudEventV1 - CloudEvents"
