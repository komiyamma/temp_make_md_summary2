# 第26章：イベント契約（非同期の約束）📣⏱️

## ねらい🎯✨

イベント（非同期メッセージ）って、送った瞬間に相手が見てるとは限らないし、相手が誰かも増えたり減ったりするよね…！😳
だからこそ **「イベントの契約」** をちゃんと作ると、あとで泣かなくて済みます😭🧡

この章では、イベントを **壊さず育てるための設計ルール** を、TypeScriptで手を動かしながら覚えます🧩✨

---

## イベント契約ってなに？🤝💌

イベント契約＝「このイベントはこういう意味で、こういう形で届くよ」という約束だよ📮✨
だいたい次の4点セットでできてることが多いです👇

1. **イベント名（type / topic）**：何が起きたかを表す名前📛
2. **メタ情報（envelope）**：いつ・どこで・どのイベントか、追跡用🧾
3. **payload（data）**：本体データ🎁
4. **互換性ルール**：変更しても壊れないための約束🔁🛡️

---

## まず最重要：イベント名は「過去形の事実」🕰️✅

イベントは「命令」じゃなくて「起きた事実」だよ〜！📣
だから **過去形**（完了した出来事）にするのが王道💡
例👇

* ✅ `UserSignedUp`（ユーザーが登録した）
* ✅ `OrderPaid`（注文が支払われた）
* ✅ `PasswordResetRequested`（リセットが要求された＝事実）
* ❌ `SignUpUser`（命令っぽい😵）
* ❌ `PayOrder`（命令っぽい😵）

この「過去形・事実」ルールはイベント駆動でよく使われる定番の考え方だよ🧠✨ ([Kurrent - event-native data platform][1])

### 命名のコツ🍀

* **ドメイン語彙**で書く（アプリ内の自然な言葉）🗣️
* **短く、でも具体的に**（何が起きたか一発で分かる）🎯
* **「意味」を変えない**（同じ名前で別の意味にしない）⚠️

---

## envelope（封筒）と payload（中身）を分けよう✉️🎁

イベントは「封筒（envelope）」の中に「中身（payload）」が入ってるイメージが超わかりやすい！📮✨

* ✉️ **envelope**：追跡やルーティングのための共通フィールド（なるべく固定）
* 🎁 **payload**：ビジネスのデータ（ここが進化する）

### 便利な“共通封筒”の代表：Cloud Native Computing Foundation配下のCloudEvents✨

CloudEvents形式だと、イベントに最低限の共通フィールド（id/source/type/specversionなど）を持たせやすいよ📦
たとえば `specversion`, `type`, `source`, `id` は “Required” として扱われます🧾 ([Microsoft Learn][2])

さらに、`datacontenttype`（データの種類）や `dataschema`（データが従うスキーマのURI）も付けられるのが強い！🔍✨ ([Cloud Events][3])

---

## イベント仕様テンプレ🧾✨（まずこれを書けばOK）

イベント契約は「文章＋例」で残すのが超大事📚
まずはこのテンプレを埋めるだけで、設計が一気に安定するよ😊💕

* **イベント名（type）**：`com.example.user.UserSignedUp.v1` みたいに（後述）📛
* **意味（What happened）**：何が起きた？🕰️
* **発行者（producer）**：誰が送る？📤
* **購読者（consumer）**：誰が読む？（想定でOK）📥
* **payload（data）**：フィールド一覧・必須/任意・例🎁
* **互換性ルール**：追加OK/変更NGの線引き🔁🛡️
* **冪等性キー**：重複が来たらどうする？（idで？）♻️

---

## 実例：CloudEventsっぽいイベントを作ってみる📮✨

### ① payload（中身）をTypeScriptで定義🟦🧩

```ts
// payload（中身）
export type UserSignedUpV1 = {
  userId: string;          // 必須
  email: string;           // 必須
  plan: "free" | "pro";    // 必須（こういうenumは強い💪）
  signedUpAt: string;      // 必須（ISO文字列を想定）
  
  // 追加しそうなものは、最初から任意にしておくと未来が平和🕊️
  referralCode?: string;   // 任意
};
```

### ② envelope（封筒）を足して「イベント型」にする✉️🎁

`id/source/type/specversion/time/datacontenttype` あたりを持たせると、追跡も運用も楽になるよ〜！🧠✨
（CloudEventsでは `source + id` の組み合わせで一意性を意識するのがポイント💡） ([Microsoft Learn][2])

```ts
export type CloudEventLike<T> = {
  specversion: "1.0";
  type: string;     // イベント名（＋バージョン戦略）
  source: string;   // どこで起きたか（サービス名/アプリ名など）
  id: string;       // イベントID（重複排除にも使える）
  time?: string;    // 生成時刻（任意）
  datacontenttype?: "application/json";
  dataschema?: string; // スキーマのURI（任意）
  data: T;
};
```

### ③ 具体イベント型を作る📣✨

```ts
export type UserSignedUpEventV1 = CloudEventLike<UserSignedUpV1> & {
  type: "com.example.user.UserSignedUp.v1";
  source: "user-service";
  datacontenttype: "application/json";
  dataschema: "https://example.com/schemas/user-signed-up/1.json";
};
```

---

## バージョンの置き場所：どこに “v1” を書く？🤔🔁

イベントは進化するから「バージョン戦略」を決めるのが超重要！🧠✨

### よくある実務パターン（おすすめ寄り）✅

* **typeにメジャーバージョンを入れる**：`UserSignedUp.v1`

  * メリット：別物になったときに新旧を明確に併存できる🧡
  * 実際、CloudEventsでも `type` は producerが決めてよく、バージョンを含める場合もあるよ📌 ([Microsoft Learn][2])

### もう1個の強い手（併用OK）🔗

* `dataschema` に **スキーマURI** を入れて、互換性の境界を見える化する✨

  * CloudEventsでも `dataschema` は「dataが従うスキーマ」を示す用途だよ🧾 ([Cloud Events][3])

---

## 互換性の鉄則：イベントは「追加に強く、変更に弱い」🧬⚖️

イベントはログみたいに残ることが多いし、あとから再生（リプレイ）されることもある📼
だから **“過去のイベントを新しいコードが読める”** がめちゃ大事！💥

ConfluentのSchema Registry系ドキュメントでも、Kafkaでは **BACKWARD互換がデフォルトで好まれやすい**（過去データを読めるのが大事）という説明があるよ📚 ([Confluent Documentation][4])

### OK/注意/NGの目安🧁

* ✅ **フィールド追加（任意）**：だいたい安全（consumerが無視できる）🙆‍♀️
* ✅ **任意フィールドの追加**：安全寄り🟢
* ⚠️ **必須フィールド追加**：古いconsumerが死ぬかも😵
* ❌ **フィールド削除**：古いconsumerが参照してたら即死😇
* ❌ **型変更**（string→number等）：破壊になりやすい💥
* ❌ **意味変更**（同じ名前で別の意味）：最悪の地雷🧨

---

## 重複・順序・再送…非同期あるあるへの備え🧟‍♀️📦

非同期は「同じイベントがもう一度来る」こと、普通にあるよ😳
CloudEventsでも `id` は再送時に同じになる場合があり、`source + id` が同じなら重複扱いできる、という考え方が書かれてるよ🧠✨ ([Cloud Events][3])

### 最低限やると強いこと💪

* **重複排除**：`source + id` をキーに「見たことある？」をチェック♻️
* **冪等な処理**：2回来ても結果が同じになるようにする🔁
* **順序に依存しない**：できるだけイベントの到着順を信用しない🌀

---

## ミニ演習①：イベント仕様テンプレを1つ完成させる🧾✍️

次のどれかで、テンプレを埋めてみてね（1つでOK）🌸

* `OrderPaid.v1` 💳
* `ItemAddedToCart.v1` 🛒
* `ProfileUpdated.v1` 👤

### AI活用プロンプト例🤖✨

* 「この出来事を“過去形の事実”イベント名で10個出して（短く・自然に）」📛
* 「payloadのフィールド候補を、必須/任意で提案して」🎁
* 「このイベント変更案は互換性を壊す？OK/注意/NGで理由つきで」⚖️

---

## ミニ演習②：consumer側を“追加に強く”する✅🛡️

イベントは将来フィールドが増えるから、**知らないフィールドが来ても落ちない**のが理想だよ🧡

例：Zodで “余計なフィールドは許可” しつつ、必須だけガードする（`passthrough()`）✨

```ts
import { z } from "zod";

const UserSignedUpV1Schema = z.object({
  userId: z.string(),
  email: z.string().email(),
  plan: z.enum(["free", "pro"]),
  signedUpAt: z.string(),
  referralCode: z.string().optional(),
}).passthrough(); // 👈 将来の追加フィールドを許容💕

type UserSignedUpV1 = z.infer<typeof UserSignedUpV1Schema>;
```

---

## イベント契約をドキュメント化する：AsyncAPIという選択肢📚🌈

イベントやメッセージの契約を **機械可読** で書ける仕様として、AsyncAPI Initiative の AsyncAPI があるよ✨
AsyncAPI v3の仕様は「メッセージ駆動APIをプロトコル非依存で記述する」ことを目的にしてる📄 ([AsyncAPI][5])

「イベント仕様テンプレ」をチームで増やしていくなら、AsyncAPI化しておくと生成ツールや検証とも相性よし💪✨

---

## 参考：CloudEventsをTypeScriptで扱う（SDK）📦🟦

CloudEventsのJavaScript/TypeScript SDK（npmパッケージ `cloudevents`）もあるよ📦✨ ([npmjs.com][6])
「ちゃんとCloudEventsとして組み立てたい」って時に便利🧠

---

## 実務チェックリスト✅💖（これだけ守ると強い）

* [ ] イベント名は **過去形の事実** 📣🕰️ ([Kurrent - event-native data platform][1])
* [ ] envelope と payload を分けた✉️🎁
* [ ] `id/source/type/specversion`（最低限）を持つ🧾 ([Microsoft Learn][2])
* [ ] payloadは **追加に強い設計**（任意・デフォルト・無視可能）🧬
* [ ] 破壊変更が必要なら **新しいtype（v2）** を作って併存🔁
* [ ] consumerは **知らないフィールドで落ちない** 🛡️
* [ ] 重複（再送）に備えて冪等性を考えた♻️ ([Cloud Events][3])
* [ ] 契約を文章＋例（できればAsyncAPIなど）で残した📚 ([AsyncAPI][5])

---

## おまけ：Dapr系の世界観だと…👀✨

Daprのpub/subでは、メッセージをCloudEvents 1.0の封筒で包む、という説明があるよ📮
こういう “封筒を標準化する発想” は、イベント契約を安定させるのにめちゃ効くよ〜！🧡 ([Dapr Docs][7])

[1]: https://www.kurrent.io/event-driven-architecture?utm_source=chatgpt.com "A Beginner's Guide to Event-Driven Architecture - Kurrent.io"
[2]: https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/message-format?view=sql-server-ver17 "JSON Message format - change event streaming - SQL Server | Microsoft Learn"
[3]: https://cloudevents.github.io/sdk-javascript/interfaces/CloudEventV1.html "CloudEventV1 | cloudevents"
[4]: https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html?utm_source=chatgpt.com "Schema Evolution and Compatibility for Schema Registry ..."
[5]: https://www.asyncapi.com/docs/reference/specification/v3.0.0 "3.0.0 | AsyncAPI Initiative for event-driven APIs"
[6]: https://www.npmjs.com/package/cloudevents?utm_source=chatgpt.com "cloudevents"
[7]: https://docs.dapr.io/developing-applications/building-blocks/pubsub/pubsub-cloudevents/ "Publishing & subscribing messages with Cloudevents | Dapr Docs"
