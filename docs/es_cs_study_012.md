# 12章：イベントの中身（Payload）とメタデータ🍱🏷️

## この章のゴール🎯✨

イベントを設計するときに、

* **Payload（中身）🍱＝「起きた事実」**
* **Metadata（ラベル）🏷️＝「配送・追跡・運用のための情報」**
  をスッキリ分けて、**後から壊れにくいイベント**を作れるようになるよ😊💪

---

## まずイメージしよ〜📦🚚

宅配便で言うと…

* **Payload🍱**：箱の中身（商品そのもの）
* **Metadata🏷️**：伝票（注文番号、発送日時、宛先、追跡番号…）

イベントも同じで、**「事実」と「運用の都合」を混ぜない**のが最重要ポイントだよ🔥

---

# 1) Payload（イベントの中身🍱）って何を入れるの？🧠✨

## Payloadは「未来永劫リプレイしても意味が通る事実」📜🔁

イベントソーシングは、イベント列を後から何度も再生して状態を復元するから、Payloadは **“その時起きた事実”** に寄せるのがコツ😊

## Payloadに入れるもの（基本セット）✅

* **集約（Aggregate）を特定できるID**（例：`CartId`）🪪
* **起きたことを説明するために必要な最小の値**（例：`Sku`, `Quantity`）🧺
* **不変条件（Invariants）を判断するために必要な値**（例：上限数、在庫制約に必要な情報があるなら）🛡️

## Payloadに入れないほうが良いもの（事故りやすい）⚠️

* **画面表示用の加工済みデータ**（例：`TotalPriceText = "1,980円"`）🙅‍♀️
* **後から計算できる値**（例：`TotalPrice`, `Points`）※計算ルールが変わると過去が壊れる💥
* **“現在の状態”そのもの**（例：`CartSnapshot`全部）📸←スナップショット章で扱うやつ
* **個人情報（PII）を雑に入れる**（例：住所・電話）📵
  → 取り扱い・マスキング・削除要求などが地獄になることが多いよ😵‍💫

---

# 2) Metadata（メタデータ🏷️）って何を入れるの？🧰✨

## Metadataは「配送ラベル＋追跡タグ」📍🔎

Payloadが“ドメインの真実”なら、Metadataは **保存・追跡・運用・デバッグ**のための情報だよ😊

## まずはこの7つが鉄板セット🥇

1. **EventId**：イベントの一意ID（重複排除にも使える）🆔
2. **StreamId（またはAggregateId）**：どのストリームの出来事？🧵
3. **Version（順番）**：このストリーム内の通し番号📼🔢
4. **OccurredAt**：実際に起きた時刻⏰
5. **RecordedAt**：保存した時刻（遅延がある場合に便利）🗄️
6. **CorrelationId**：一連の流れをまとめるID（例：注文処理全体）🔗
7. **CausationId**：直前の原因イベントID（「これが原因でこれが起きた」）➡️

## あると強い（必要になったら追加）⭐

* **ActorId / UserId**：誰がやった？👤
* **TenantId**：マルチテナントなら必須になりがち🏢
* **SchemaVersion**：イベントの形（スキーマ）バージョン🧬
* **IdempotencyKey**：二重送信対策🔁🧷
* **Trace情報（traceparent等）**：分散トレーシングで追える🕵️‍♀️
  .NET は `ActivityContext` などで **W3C Trace Context** に沿った表現を持っているよ📡✨ ([Microsoft Learn][1])

---

# 3) 「Payload vs Metadata」仕分けルール早見表📝✨

| 迷ったときの質問🤔                 | Payload🍱 | Metadata🏷️ |
| -------------------------- | --------: | ----------: |
| これは“起きた事実”そのもの？            |         ✅ |             |
| これが無いと状態復元（Rehydrate）できない？ |         ✅ |             |
| “追跡・監査・運用”のためだけ？           |           |           ✅ |
| 後から計算できる？                  | ❌（基本入れない） |             |
| 変更が入りやすい（表示文言・UI用）？        |         ❌ |             |

---

# 4) 例：カート題材でイベントを設計してみよう🛒✨

## 例1：`ItemAddedToCart`（商品が追加された）🧺➕

* Payload（事実）🍱

  * `CartId`
  * `Sku`
  * `Quantity`
* Metadata（ラベル）🏷️

  * `EventId`, `StreamId`, `Version`, `OccurredAt`, `CorrelationId`, `CausationId` …

「合計金額」「商品名」「画像URL」みたいな表示用は **Projection側**が担当でOKだよ😊🔎

---

# 5) 実装ミニ：イベントを“包む”入れ物（Envelope）📩✨

`.NET` なら JSON で保存・転送する場面が多いので、**Envelope（外側）にPayloadとMetadataを分けて持たせる**のが定番だよ📦
JSONのシリアライズは `System.Text.Json` が公式の基本セットとして使えるよ🧾✨ ([Microsoft Learn][2])

```csharp
using System;
using System.Collections.Generic;

public sealed record EventMetadata(
    Guid EventId,
    string StreamId,
    long Version,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    string? CorrelationId,
    Guid? CausationId,
    string? ActorId,
    int SchemaVersion,
    string? IdempotencyKey,
    string? TraceParent // W3C traceparent をそのまま持つ案もアリ📡
);

public sealed record EventEnvelope<TPayload>(
    string Type,          // 例: "Cart.ItemAddedToCart"
    TPayload Payload,     // 事実🍱
    EventMetadata Meta    // ラベル🏷️
);

// Payload例🍱
public sealed record ItemAddedToCart(
    string CartId,
    string Sku,
    int Quantity
);
```

💡ポイント😊

* **Payloadはドメイン都合で最小**
* **Metaは運用都合で拡張しやすい**
* `Type` は「どのイベント？」を判別するための名前（保存時に超便利）📛✨

---

# 6) JSONで保存するイメージ🧾📦

（ざっくりこんな形！）

```json
{
  "type": "Cart.ItemAddedToCart",
  "payload": { "cartId": "CART-001", "sku": "SKU-ABC", "quantity": 2 },
  "meta": {
    "eventId": "7c2f2a5a-5a5d-4d6f-9c5e-8af0e30d1b2d",
    "streamId": "CART-001",
    "version": 3,
    "occurredAt": "2026-02-01T12:34:56+09:00",
    "recordedAt": "2026-02-01T12:34:56+09:00",
    "correlationId": "ORDERFLOW-20260201-0001",
    "causationId": "b1e3d8e1-2a5d-4e2f-8a0c-1d2f3a4b5c6d",
    "actorId": "user-123",
    "schemaVersion": 1,
    "idempotencyKey": "req-999",
    "traceParent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  }
}
```

---

# 7) 「標準のイベント形」に寄せたいとき：CloudEvents🏷️🌍

外部システム連携が増えてくると、**CloudEvents** みたいな「イベントの共通フォーマット」をEnvelopeとして採用する手もあるよ📨✨
CloudEventsは、イベントに付けるメタ情報（属性）を標準化する仕様で、拡張属性も持てるよ🧩 ([GitHub][3])

実際に Microsoft の機能でも **CloudEvents準拠**が使われるケースがあるよ（例：メッセージ形式がCloudEvents準拠の説明）📎 ([Microsoft Learn][4])

---

# 8) よくあるミス集（超あるある）😵‍💫➡️✅

## ミス1：Payloadに“表示用”を入れてしまう📺💥

* ❌ `ProductName`, `PriceText`, `TotalPrice`
* ✅ `Sku`, `Quantity`（必要なら当時の「単価」を入れる判断もあるけど、慎重に⚖️）

## ミス2：Metadataが無さすぎて運用が詰む🪦

* ❌ `OccurredAt` も `CorrelationId` も無い
* ✅ 「追跡できる最低限」を最初から入れる（EventId / StreamId / Version / 時刻 / 相関）🔎✨

## ミス3：Payloadがでかすぎて変更が地獄🧟‍♀️

* ❌ 画面DTOみたいなPayload
* ✅ “事実の差分”に寄せる（粒度は8章の話が効くよ⏳✅）

---

# 9) ミニ演習📝🎀

## 演習A：Payload / Metadata を仕分けしてみよう🧺🏷️

次の候補を、**Payloadに入れる / Metadataに入れる / どちらにも入れない** に分けてみよう😊

* `CartId` / `EventId` / `UserDisplayName` / `OccurredAt` / `TotalPrice` / `Sku` / `CorrelationId` / `ScreenTitle`

## 演習B：「入れすぎPayload」をダイエット🥗✨

次のPayload案から、落とすべき項目を3つ選んで理由を一言で✍️

* `Sku`, `Quantity`, `ProductName`, `ProductImageUrl`, `TotalPrice`, `PriceText`

## 演習C：イベント3つ分の設計🍱🏷️

題材（カート）で、最低この3つを設計してみよう😊

* `CartCreated` 🆕
* `ItemAddedToCart` ➕
* `ItemRemovedFromCart` ➖
  それぞれ **Payload（必須3項目くらい）** と **Metadata（鉄板7つ）** を書こう✍️✨

---

# 10) AI活用（Copilot / Codex向けプロンプト例）🤖💬✨

* 「次のイベント案について、PayloadとMetadataを分離して提案して。**入れすぎ**と**不足**も指摘して。」🔎
* 「このPayload案は将来の仕様変更（価格計算ルール変更・表示文言変更）に耐える？耐えないなら修正案を出して。」🧯
* 「CorrelationId と CausationId の付け方を、カート→注文の流れ例で提案して。」🔗➡️

---

# 11) 章末チェックリスト✅✨

* [ ] Payloadは「起きた事実」だけになってる？🍱
* [ ] 後から計算できる値・表示用は入れてない？📺🙅‍♀️
* [ ] EventId / StreamId / Version / 時刻 / 相関（Correlation/Causation）は揃ってる？🏷️
* [ ] 将来の変更に弱そうな項目（文言・UI用・巨大DTO）が混ざってない？🧨
* [ ] JSON化するときの形（Envelope）を固定できてる？📦🧾 ([Microsoft Learn][2])

[1]: https://learn.microsoft.com/ja-jp/dotnet/api/system.diagnostics.activitycontext?view=net-8.0&utm_source=chatgpt.com "ActivityContext 構造体 (System.Diagnostics)"
[2]: https://learn.microsoft.com/en-us/dotnet/api/system.text.json?view=net-10.0&utm_source=chatgpt.com "System.Text.Json Namespace"
[3]: https://github.com/cloudevents/spec/blob/main/cloudevents/spec.md?utm_source=chatgpt.com "spec/cloudevents/spec.md at main"
[4]: https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/message-format?view=sql-server-ver17&utm_source=chatgpt.com "JSON Message format - change event streaming"
